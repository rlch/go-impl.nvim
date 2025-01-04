local nui_input = require("nui.input")
local nui_popup = require("nui.popup")
local nui_text = require("nui.text")
local nui_line = require("nui.line")
local nui_layout = require("nui.layout")
local nui_event = require("nui.utils.autocmd").event
local fl = require("fzf-lua")
local fl_defaults = require("fzf-lua.defaults")
local fl_utils = require("fzf-lua.utils")
local fl_make_entry = require("fzf-lua.make_entry")

local config = require("go-impl.config")

local M = {}

---Convert the gopls result to a line
---@param item any gopls result
---@param query string the query string
---@return string? line the line to be displayed in the fzf window
local function to_line(item, query)
	-- Query highlight
	if config.options.style.interface_selector.query_highlight then
		local sym, text = item.text:match("^(.+%])(.*)$")
		local pattern = "["
			.. fl_utils.lua_regex_escape(string.gsub(query, "%a", function(x)
				return string.upper(x) .. string.lower(x)
			end))
			.. "]+"
		item.text = sym
			.. text:gsub(pattern, function(x)
				return fl_utils.ansi_codes[config.options.style.interface_selector.query_highlight_hl](x)
			end)
	end

	-- Icon
	if config.options.style.interface_selector.interface_icon then
		local styled = fl_utils.ansi_from_hl(config.options.icons.interface.hl, config.options.icons.interface.text)
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
		local styled = fl_utils.ansi_from_hl(config.options.style.interface_selector.package_highlight_hl, package_info)
		if styled then
			package_info = styled
		end
	end
	item.text = item.text .. fl_utils.nbsp .. package_info

	-- Path
	local symbol = item.text
	item.text = nil
	local line = fl_make_entry.lcol(item, {})

	if line then
		return symbol .. fl_utils.nbsp .. line
	end
end

---Contents that uses the LSP to filter interfaces in the workspace
---@param gopls vim.lsp.Client
---@return table
function M.fzf_lua_settings(bufnr, gopls)
	-- Establish the ansi escape sequence for the live symbol highlighting
	local hl_query = config.options.style.interface_selector.query_highlight_hl
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

---Open the interface selector
---@param bufnr integer
---@param gopls vim.lsp.Client
---@param callback fun(selected: table)
function M.get_interface(bufnr, gopls, callback)
	local settings = M.fzf_lua_settings(bufnr, gopls)

	fl.fzf_live(settings.contents, {
		prompt = config.options.prompt.interface,
		func_async_callback = false,
		previewer = fl_defaults._default_previewer_fn,
		actions = { ["default"] = callback },
	})
end

---Get the receiver input
---@param default_value string? defualt value
---@param callback fun(receiver: string?)
function M.get_receiver(default_value, callback)
	local nui_opts = vim.tbl_deep_extend("force", config.options.style.receiver_input, {
		border = {
			text = {
				top = nui_line({
					nui_text(" [ "),
					nui_text(config.options.icons.go.text, config.options.icons.go.hl),
					nui_text("Receiver", "Fg"),
					nui_text(" ] "),
				}),
			},
		},
	})

	local input = nui_input(nui_opts, {
		prompt = nui_text(config.options.prompt.receiver, "GoImplHighlight"),
		default_value = default_value,
		on_close = callback,
		on_submit = callback,
		on_change = function() end,
	})

	input:mount()
	for _, event in ipairs({
		nui_event.BufWinLeave,
		nui_event.BufLeave,
		nui_event.InsertLeavePre,
	}) do
		input:on(event, function()
			input:unmount()
		end)
	end
end

---@class GenericOpts
---@field name string
---@field type string
---@field interface_base_name string
---@field generic_parameter_list string
---@field interface_declaration string

---Get the receiver input
---@param opts GenericOpts
---@param callback fun(argument?: string)
function M.get_generic_argument(opts, callback)
	local bottom_text = nil

	-- Generate type highlighted help text
	local params = vim.split(opts.generic_parameter_list, ",")
	local checked_params = {}
	for i = 1, #params do
		local param = params[i]
		local items = vim.split(vim.trim(param), " ")
		if string.find(items[1], opts.name) then
			local remain = table.concat(params, ",", i)
			local n_start, n_end = string.find(remain, opts.name)
			local t_start, t_end = string.find(remain, opts.type)

			if i > 1 then
				table.insert(checked_params, "") -- add last comma in concatenation
			end
			local normal_left = nui_text(table.concat(checked_params, ",") .. string.sub(remain, 1, n_start - 1))
			local hl_name = nui_text(opts.name, "GoImplHighlight")
			local normal_middle = nui_text(string.sub(remain, n_end + 1, t_start - 1))
			local hl_type = nui_text(opts.type, "GoImplHighlight")
			local normal_right = nui_text(string.sub(remain, t_end + 1))

			bottom_text = nui_line({ normal_left, hl_name, normal_middle, hl_type, normal_right })
			break
		end

		table.insert(checked_params, param)
	end

	local nui_opts = vim.tbl_deep_extend("force", config.options.style.generic_argument_input, {
		border = {
			text = {
				top = nui_line({
					nui_text(" [ "),
					nui_text(config.options.icons.interface.text, config.options.icons.interface.hl),
					nui_text(opts.interface_base_name, "Fg"),
					nui_text(" ] "),
				}),
				bottom = bottom_text,
			},
		},
	})

	local prompt_text = string.gsub(config.options.prompt.generic, "%{name%}", opts.name)

	local input = nui_input(nui_opts, {
		prompt = nui_text(prompt_text, "GoImplHighlight"),
		default_value = "",
		on_close = callback,
		on_submit = callback,
		on_change = function() end,
	})

	local previewer = nui_popup(vim.tbl_deep_extend("force", config.options.style.generic_argument_previewer, {
		enter = false,
		focusable = false,
		buf_options = {
			modifiable = false,
			readonly = true,
			filetype = "go",
		},
	}))

	local preview_lines = vim.split(opts.interface_declaration, "\n")
	vim.api.nvim_buf_set_lines(previewer.bufnr, 0, -1, false, preview_lines)

	local layout = nui_layout(
		config.options.style.generic_argument_layout,
		nui_layout.Box({
			nui_layout.Box(input, { size = 3 }),
			nui_layout.Box(previewer, { grow = 1 }),
		}, { dir = "col" })
	)
	layout:mount()
	input:on({
		nui_event.BufWinLeave,
		nui_event.BufLeave,
		nui_event.InsertLeavePre,
	}, function()
		layout:unmount()
	end)

	-- Weirdly, the popup is not in insert mode by default, so we need to force it
	vim.defer_fn(function()
		vim.api.nvim_command("startinsert!")
	end, 40)
end

return M
