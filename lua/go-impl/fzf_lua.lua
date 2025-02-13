local config = require("go-impl.config")

local M = {}

function M.env()
	if M.env_initiated then
		return
	end
	M.env_initiated = true
	M.core = require("fzf-lua")
	M.defaults = require("fzf-lua.defaults")
	M.make_entry = require("fzf-lua.make_entry")
	M.utils = require("fzf-lua.utils")
	M.path = require("fzf-lua.path")
end

---Convert the gopls result to a line
---@param item any gopls result
---@param query string the query string
---@return string? line the line to be displayed in the fzf window
local function to_line(item, query)
	-- Query highlight
	if config.options.style.interface_selector.query_highlight then
		local sym, text = item.text:match("^(.+%])(.*)$")
		local pattern = "["
			.. M.utils.lua_regex_escape(string.gsub(query, "%a", function(x)
				return string.upper(x) .. string.lower(x)
			end))
			.. "]+"
		item.text = sym
			.. text:gsub(pattern, function(x)
				return M.utils.ansi_codes[config.options.style.interface_selector.query_highlight_hl](x)
			end)
	end

	-- Icon
	if config.options.style.interface_selector.interface_icon then
		local styled = M.utils.ansi_from_hl(config.options.icons.interface.hl, config.options.icons.interface.text)
		if styled then
			item.text = item.text:gsub("%[.-%]", styled, 1)
		end
	else
		-- Because vim.lsp.util.symbols_to_items() already adds the symbol kind to the text, remove it
		item.text = item.text:gsub("%[.-%] ", "", 1)
	end

	-- Package
	local package_info = string.format("(%s)", item.package)
	if config.options.style.interface_selector.package_highlight then
		local styled = M.utils.ansi_from_hl(config.options.style.interface_selector.package_highlight_hl, package_info)
		if styled then
			package_info = styled
		end
	end
	item.text = item.text .. M.utils.nbsp .. package_info

	-- Path
	local symbol = item.text
	item.text = nil

	local line = M.make_entry.lcol(item, {})

	if line then
		return symbol .. M.utils.nbsp .. line
	end
end

---Contents that uses the LSP to filter interfaces in the workspace
---@param bufnr integer current buffer number
---@param gopls vim.lsp.Client gopls (go language server)
---@return table
local function fzf_lua_settings(bufnr, gopls)
	-- Establish the ansi escape sequence for the live symbol highlighting
	local hl_query = config.options.style.interface_selector.query_highlight_hl
	if not M.utils.ansi_codes[hl_query] then
		local _, escseq = M.utils.ansi_from_hl(hl_query)
		M.utils.cache_ansi_escseq(hl_query, escseq)
	end

	---@type integer?
	local running_request_id = nil

	---@type fun(query: string): function
	local contents = function(query)
		---@param fzf_cb fun(line?: string, cb?: fun())
		return function(fzf_cb)
			-- Cancel the previous request
			if gopls and running_request_id then
				gopls.cancel_request(running_request_id)
			end

			-- If gopls is not found, return an error
			if not gopls then
				return fzf_cb("No gopls detected in the current buffer")
			end

			coroutine.wrap(function()
				local co = coroutine.running()
				local request_success, request_id = gopls.request("workspace/symbol", {
					query = query,
				}, function(err, result)
					running_request_id = nil
					if err or not result or type(result) ~= "table" then
						return fzf_cb("Failed to fetch workspace symbols")
					end

					local interface_symbols = vim.iter(result)
						:filter(function(symbol)
							return vim.lsp.protocol.SymbolKind[symbol.kind] == "Interface"
						end)
						:totable()

					local items = vim.lsp.util.symbols_to_items(interface_symbols, bufnr)

					-- Add the package name to the items
					for i, item in ipairs(items) do
						item.package = interface_symbols[i].containerName
					end

					coroutine.resume(co, items)
				end, bufnr)

				if not request_success then
					return fzf_cb("Failed to fetch workspace symbols")
				end

				running_request_id = request_id

				for _, item in ipairs(coroutine.yield()) do
					fzf_cb(to_line(item, query))
				end

				fzf_cb()
			end)()
		end
	end

	return {
		contents = contents,
	}
end

---Parse the package name from the fzf entry
---@param raw_fzf_entry string?
---@return string? package The package name
local function parse_package(raw_fzf_entry)
	if not raw_fzf_entry then
		return
	end
	local parts = vim.split(raw_fzf_entry, M.utils.nbsp)
	for _, part in ipairs(parts) do
		if string.match(part, "%(([^)]+)%)") then
			return string.match(part, "%(([^)]+)%)")
		end
	end
end

---Check if the fzf-lua plugin is loaded
---@return boolean
function M.is_loaded()
	local is_loaded = pcall(require, "fzf-lua")
	if is_loaded then
		M.env()
	end
	return is_loaded
end

---Get the interface from the user using fzf-lua
---@param co thread
---@param bufnr integer current buffer number
---@param gopls vim.lsp.Client gopls (go language server)
---@return InterfaceData
function M.get_interface(co, bufnr, gopls)
	local settings = fzf_lua_settings(bufnr, gopls)

	M.core.fzf_live(settings.contents, {
		prompt = config.options.prompt.interface,
		func_async_callback = false,
		previewer = M.defaults._default_previewer_fn,
		actions = {
			["default"] = function(selected)
				coroutine.resume(co, selected)
			end,
		},
	})

	local selected = coroutine.yield()
	local file = M.path.entry_to_file(selected and selected[1])

	return {
		package = selected and parse_package(selected[1]),
		path = file.path,
		col = file.col,
		line = file.line,
	}
end

return M
