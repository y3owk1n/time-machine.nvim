local utils = require("time-machine.utils")
local ui = require("time-machine.ui")
local constants = require("time-machine.constants").constants
local undotree = require("time-machine.undotree")

local M = {}

--- Show the undotree for a buffer
---@return nil
function M.show_tree()
	local buf_path = utils.get_buf_path(0)
	local bufnr = vim.api.nvim_get_current_buf()
	if not buf_path then
		return
	end

	local ut = undotree.get_undotree(bufnr)

	if not ut then
		vim.notify("No undotree found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end

	local current_seq = ut.seq_cur

	ui.show(ut, current_seq, buf_path, bufnr)
end

--- Restore to an undopoint
---@param seq integer The seq to restore to
---@param buf_path string The path to the buffer
---@param main_bufnr integer The main buffer number
---@return nil
function M.restore_undopoint(seq, buf_path, main_bufnr)
	local bufnr = main_bufnr

	if not bufnr then
		vim.notify("No main buffer found", vim.log.levels.ERROR)
	end

	buf_path = buf_path or utils.get_buf_path(0)
	if not buf_path then
		return
	end

	vim.api.nvim_buf_call(main_bufnr, function()
		vim.cmd(("undo %d"):format(seq))
	end)
	vim.notify(("Restored to undopoint %d"):format(seq), vim.log.levels.INFO)
	vim.api.nvim_exec_autocmds("User", { pattern = constants.events.undo_restored })
end

--- Purge all undofiles
---@param force? boolean Whether to force the purge
---@return nil
function M.purge_all(force)
	if not force then
		local confirm = vim.fn.input("Delete ALL undofiles? [y/N] ")
		if confirm:lower() ~= "y" then
			return
		end
	end
	local ok, err = pcall(function()
		undotree.remove_undofiles()
	end)
	if not ok then
		vim.notify("Failed to purge all undofiles: " .. tostring(err), vim.log.levels.ERROR)
	end
end

--- Purge the current buffer undofile
---@param force? boolean Whether to force the purge
---@return nil
function M.purge_current(force)
	local bufnr = vim.api.nvim_get_current_buf()
	local persistent = vim.api.nvim_get_option_value("undofile", { scope = "local", buf = bufnr })

	if not persistent then
		vim.notify("No undofile found for current buffer", vim.log.levels.WARN)
		return
	end

	local buf_path = utils.get_buf_path(0)
	if not buf_path then
		return
	end
	if not force then
		local confirm = vim.fn.input("Delete undofile for " .. vim.fn.fnamemodify(buf_path, ":~:.") .. "? [y/N] ")
		if confirm:lower() ~= "y" then
			return
		end
	end
	undotree.remove_undofile(0)
end

return M
