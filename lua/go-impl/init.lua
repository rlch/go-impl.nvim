local config = require("go-impl.config")
local cmd = require("go-impl.cmd")

local M = {}

---Setup the plugin with the given options
---@param user_opts Config
function M.setup(user_opts)
	config.init(user_opts)

	M.open = cmd.open -- require("go-impl").open()
end

return M
