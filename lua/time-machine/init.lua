---@module "time-machine"

---@brief [[
---*time-machine.nvim.txt*
---
---Interactive timeline, diff previews, bookmarks, hot reloading, and undo file management - everything you need to master your editing history.
---@brief ]]

---@toc time-machine.nvim.toc

---@mod time-machine.nvim.api API

local M = {
	actions = {},
}

---Entry point to setup the plugin
---@type fun(user_config?: TimeMachine.Config)
M.setup = require("time-machine.config").setup

---Show the undotree for a buffer
---@type fun()
M.actions.toggle = require("time-machine.actions").toggle

---Restore to an undopoint
---@type fun(seq: integer, content_bufnr: integer)
M.actions.restore = require("time-machine.actions").restore

---Purge all undofiles
---@type fun(force?: boolean)
M.actions.purge_all = require("time-machine.actions").purge_all

---Purge the current buffer undofile
---@type fun(force?: boolean)
M.actions.purge_buffer = require("time-machine.actions").purge_buffer

---Purge the log file, actually instead of clearing it, we just remove the file instead
---@type fun(force?: boolean)
M.actions.clear_log = require("time-machine.actions").clear_log

---Show the log file
---@type fun()
M.actions.show_log = require("time-machine.actions").show_log

return M
