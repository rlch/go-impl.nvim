local M = {}

---@class Config
M.options = {
	notification = {
		struct_error = true,
	},
	input = {
		win = {
			relative = "editor",
			position = {
				row = 0.3,
				col = 0.5,
			},
			size = 40,
			border = {
				style = "rounded",
				text = {
					top_align = "center",
				},
			},
			win_options = {
				winhighlight = "Normal:Normal,FloatBorder:FzfLuaGoImplGoBlue,FloatTitle:FzfLuaGoImplGoBlue",
			},
		},
	},
	list = {
		query_highlight = {
			enabled = true,
			hl = "@lsp.type.interface",
		},
		prefix = {
			enabled = true,
			text = " ",
			hl = "FzfLuaLiveSym",
		},
		path = {
			file_icons = true,
			color_icons = true,
		},
	},
	preview = {},
}

---Merge the user options with the default options
---@param user_opts Config
function M.init(user_opts)
	M.options = vim.tbl_deep_extend("force", M.options, user_opts)
	vim.api.nvim_set_hl(0, "FzfLuaGoImplGoBlue", { fg = "#6BC6F0", bold = true })
end

return M
