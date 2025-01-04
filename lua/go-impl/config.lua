local M = {}

---@class Config
M.options = {
	insert = {
		---@type "after"|"before"|"end"
		---@usage "after" - insert after the receiver's struct declaration
		---@usage "before" - insert before the receiver's struct declaration
		---@usage "end" - insert at the end of the file
		position = "after",
		before_newline = true, -- additional newline before the implementation
		after_newline = false, -- additional newline after the implementation
	},
	icons = {
		interface = {
			text = "󰰄 ",
			hl = "GoImplInterfaceIcon",
		},
		go = {
			text = " ",
			hl = "GoImplGoBlue",
		},
	},
	prompt = {
		receiver = " 󰆼  > ",
		interface = " 󰰄  > ",
		generic = " 󰘻  {name} > ",
	},
	style = {
		---@type nui_popup_options
		---The NuiPopup options for the popup that used to get the receiver
		receiver_input = {
			relative = "cursor",
			position = { row = 1, col = 0 },
			size = 40,
			border = { style = "rounded", text = { top_align = "center" } },
			win_options = {
				winhighlight = "Normal:Normal,FloatBorder:GoImplGoBlue,FloatTitle:GoImplGoBlue",
			},
		},
		---@type nui_popup_options
		---The NuiPopup options for the previewer that used to get the generic arguments
		generic_argument_input = {
			border = {
				style = "rounded",
				text = {
					top_align = "center",
				},
			},
			win_options = {
				winhighlight = "Normal:Normal,FloatBorder:GoImplGoBlue,FloatTitle:GoImplGoBlue",
			},
		},
		---@type nui_popup_options
		---The NuiPopup options for the previewer that used to show the interface declaration
		generic_argument_previewer = {
			border = {
				padding = {
					top = 0,
					bottom = 0,
					left = 2,
					right = 2,
				},
				style = "rounded",
			},
			win_options = {
				winhighlight = "Normal:Normal,FloatBorder:Normal",
			},
		},
		---@type nui_layout_options
		---The NuiLayout options for the popup that used to get the generic arguments
		generic_argument_layout = {
			position = "50%",
			size = {
				width = 80,
				height = 20,
			},
		},
		interface_selector = {
			interface_icon = true,
			query_highlight = true,
			query_highlight_hl = "GoImplGoBlue",
			package_highlight = true,
			package_highlight_hl = "GoImplHighlight",
		},
	},
}

---Merge the user options with the default options
---@param user_opts Config
function M.init(user_opts)
	M.options = vim.tbl_deep_extend("force", M.options, user_opts)
	vim.api.nvim_set_hl(0, "GoImplGoBlue", { fg = "#6BC6F0", bold = true })
	vim.api.nvim_set_hl(0, "GoImplInterfaceIcon", { fg = "#a9b665", bold = true })
	vim.api.nvim_set_hl(0, "GoImplHighlight", { fg = "#ea6962", bold = true })
end

return M
