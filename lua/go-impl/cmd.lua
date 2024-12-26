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
		ui.get_receiver(function(...)
			coroutine.resume(co, ...)
		end)

		local receiver = coroutine.yield()

		if not helper.is_valid_recevier(receiver) then
			vim.notify("Invalid receiver provided")
			return
		end

		vim.notify(receiver)

		ui.get_interface(bufnr, gopls, function(...)
			coroutine.resume(co, ...)
		end)

		vim.notify(vim.inspect({ coroutine.yield() }))
	end)()
end

return M
