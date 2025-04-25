local ui = require("time-machine.ui")
local constants = require("time-machine.constants").constants
local undotree = require("time-machine.undotree")
local tags = require("time-machine.tags")

local M = {}

--- Show the undotree for a buffer
---@return nil
function M.show_tree()
	local bufnr = vim.api.nvim_get_current_buf()

	local ut = undotree.get_undotree(bufnr)

	if not ut then
		vim.notify("No undotree found", vim.log.levels.WARN)
		return
	end

	ui.show(ut, bufnr)
end

--- Restore to an undopoint
---@param seq integer The seq to restore to
---@param main_bufnr integer The main buffer number
---@return nil
function M.restore_undopoint(seq, main_bufnr)
	local bufnr = main_bufnr

	if not bufnr then
		vim.notify("No main buffer found", vim.log.levels.ERROR)
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
		tags.remove_tagfiles()
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

	if not force then
		local confirm = vim.fn.input("Delete the current undofile" .. "? [y/N] ")
		if confirm:lower() ~= "y" then
			return
		end
	end

	--- remove tag file first, as it needs the undotree info
	tags.remove_tagfile(0)
	undotree.remove_undofile(0)
end

return M
