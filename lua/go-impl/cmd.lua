local fl_path = require("fzf-lua.path")

local ui = require("go-impl.ui")
local helper = require("go-impl.helper")

local M = {}

---Open the go-impl user interface
function M.open()
	local bufnr = vim.api.nvim_get_current_buf()
	local gopls = helper.get_gopls(bufnr)

	if not gopls then
		vim.notify("No gopls client found in the current buffer")
		return
	end

	coroutine.wrap(function()
		local co = coroutine.running()

		-- Receiver
		local current_struct_name = helper.get_struct_at_cursor()
		local default_value = current_struct_name and helper.predict_abbreviation(current_struct_name) or ""
		ui.get_receiver(default_value, function(recevier)
			coroutine.resume(co, recevier)
		end)
		local receiver = coroutine.yield()

		-- Get the line number to insert the implentation
		local lnum = helper.get_lnum(receiver)
		if not lnum then
			vim.notify("Invalid receiver provided")
			return
		end

		-- Interface
		ui.get_interface(bufnr, gopls, function(selected)
			coroutine.resume(co, selected)
		end)

		local selected = coroutine.yield()
		local package = selected and helper.parse_package(selected[1])
		local path_data = fl_path.entry_to_file(selected and selected[1])

		if not package or not path_data or not path_data.path or not path_data.col or not path_data.line then
			vim.notify("Failed to parse the selected item")
			return
		end

		-- Generic Arguments
		local interface_declaration, interface_base_name, generic_parameter_list, generic_parameters =
			helper.parse_interface(path_data.path, path_data.line, path_data.col)
		if not interface_declaration or not interface_base_name or not generic_parameters then
			vim.notify("Failed to parse the selected item")
			return
		end

		local generic_arguments = {}
		if generic_parameter_list then
			for _, generic_parameter in ipairs(generic_parameters) do
				ui.get_generic_argument({
					name = generic_parameter.name,
					type = generic_parameter.type,
					interface_declaration = interface_declaration,
					interface_base_name = interface_base_name,
					generic_parameter_list = generic_parameter_list,
				}, function(arg)
					coroutine.resume(co, arg)
				end)
				local arg = coroutine.yield()
				if not arg then
					vim.notify("Failed to get the generic type: " .. generic_parameter.name)
					return
				end
				table.insert(generic_arguments, arg)
			end
		end

		-- Run impl
		local interface_name = interface_base_name
		if #generic_arguments > 0 then
			interface_name = string.format("%s[%s]", interface_base_name, table.concat(generic_arguments, ","))
		end
		helper.impl(receiver, package, interface_name, lnum)
	end)()
end

return M
