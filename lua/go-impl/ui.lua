local nui_input = require("nui.input")
local nui_autocmd = require("nui.utils.autocmd")
local fl = require("fzf-lua")
local fl_defaults = require("fzf-lua.defaults")
local fl_utils = require("fzf-lua.utils")
local fl_make_entry = require("fzf-lua.make_entry")

local config = require("go-impl.config")
local helper = require("go-impl.helper")

local M = {}

local function to_line(item, query)
	-- User query highlight
	if config.options.list.query_highlight.enabled then
		local sym, text = item.text:match("^(.+%])(.*)$")
		local pattern = "["
			.. fl_utils.lua_regex_escape(string.gsub(query, "%a", function(x)
				return string.upper(x) .. string.lower(x)
			end))
			.. "]+"
		item.text = sym
			.. text:gsub(pattern, function(x)
				return fl_utils.ansi_codes[config.options.list.query_highlight.hl](x)
			end)
	end

	-- Prefix
	if config.options.list.prefix.enabled then
		local styled = fl_utils.ansi_from_hl(config.options.list.prefix.hl, config.options.list.prefix.text)
		if styled then
			item.text = item.text:gsub("%[.-%]", styled, 1)
		end
	else
		-- Because vim.lsp.util.symbols_to_items() already adds the symbol kind to the text, remove it
		item.text = item.text:gsub("%[.-%] ", "", 1)
	end

	-- Path
	local symbol = item.text
	item.text = nil
	local line = fl_make_entry.lcol(item, {})
	if line then
		line = fl_make_entry.file(line, {
			file_icons = config.options.list.path.file_icons,
			color_icons = config.options.list.path.color_icons,
		})
	end

	if line then
		return symbol .. fl_utils.nbsp .. line
	end
end

---Contents that uses the LSP to filter interfaces in the workspace
---@param gopls vim.lsp.Client
---@return table
function M.fzf_lua_settings(bufnr, gopls)
	-- Establish the ansi escape sequence for the live symbol highlighting
	local hl_query = config.options.list.query_highlight.hl
	if not fl_utils.ansi_codes[hl_query] then
		local _, escseq = fl_utils.ansi_from_hl(hl_query)
		fl_utils.cache_ansi_escseq(hl_query, escseq)
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

function M.get_interface(bufnr, gopls, callback)
	local settings = M.fzf_lua_settings(bufnr, gopls)

	fl.fzf_live(settings.contents, {
		prompt = "Interface> ",
		func_async_callback = false,
		previewer = fl_defaults._default_previewer_fn,
		actions = { ["default"] = callback },
	})
end

---Get the receiver input
---@param callback fun(receiver: string)
function M.get_receiver(callback)
	local opts = vim.tbl_deep_extend("force", config.options.input.win, {
		border = { text = { top = " [  Recevier ] " } },
	})

	local cursor_struct_name = helper.get_struct_name_at_cursor()
	local default_value = cursor_struct_name and helper.predict_abbreviation(cursor_struct_name) or ""

	local input = nui_input(opts, {
		prompt = " 󰆼  ",
		default_value = default_value,
		keymap = config.options.input.keymap,
		on_close = function() end,
		on_submit = callback,
		on_change = function() end,
	})

	input:mount()
	input:on(nui_autocmd.event.BufLeave, function()
		input:unmount()
	end)
end

return M
