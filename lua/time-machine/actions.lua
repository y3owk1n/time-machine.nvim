local utils = require("time-machine.utils")
local storage = require("time-machine.storage")
local ui = require("time-machine.ui")
local constants = require("time-machine.constants").constants
local data = require("time-machine.data")

local M = {}

--- Show the snapshot for a buffer
---@return nil
function M.show_snapshots()
	local buf_path = utils.get_buf_path(0)
	local bufnr = vim.api.nvim_get_current_buf()
	if not buf_path then
		return
	end

	local snapshots = data.get_snapshots(bufnr)

	Snacks.debug(snapshots)

	local current = data.get_current_snapshot(bufnr)

	if not snapshots then
		vim.notify("No snapshots found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end

	if not current then
		vim.notify("No current snapshot found", vim.log.levels.ERROR)
		return
	end

	ui.show(snapshots, current, buf_path, bufnr)
end

--- Restore a snapshot
---@param id integer The snapshot id
---@param buf_path string The path to the buffer
---@param main_bufnr integer The main buffer number
---@return nil
function M.restore_snapshot(id, buf_path, main_bufnr)
	local bufnr = main_bufnr

	if not bufnr then
		vim.notify("No main buffer found", vim.log.levels.ERROR)
	end

	buf_path = buf_path or utils.get_buf_path(0)
	if not buf_path then
		return
	end

	-- 3) in the target buffer, do undo {seq}
	vim.api.nvim_buf_call(main_bufnr, function()
		-- this jumps the undo‐tree to exactly that sequence
		vim.cmd(("undo %d"):format(id))
	end)
	vim.notify(("Restored to snapshot %d"):format(id), vim.log.levels.INFO)
	vim.api.nvim_exec_autocmds("User", { pattern = constants.events.snapshot_created })
end

--- Purge all snapshots
---@param force? boolean Whether to force the purge
---@return nil
function M.purge_all(force)
	if not force then
		local confirm = vim.fn.input("Delete ALL snapshots? [y/N] ")
		if confirm:lower() ~= "y" then
			return
		end
	end
	local ok, err = pcall(function()
		storage.purge_all()
	end)
	if not ok then
		vim.notify("Failed to purge all snapshots: " .. tostring(err), vim.log.levels.ERROR)
	end
end

--- Purge the current buffer snapshot
---@param force? boolean Whether to force the purge
---@return nil
function M.purge_current(force)
	local buf_path = utils.get_buf_path(0)
	if not buf_path then
		return
	end
	if not force then
		local confirm = vim.fn.input("Delete snapshots for " .. vim.fn.fnamemodify(buf_path, ":~:.") .. "? [y/N] ")
		if confirm:lower() ~= "y" then
			return
		end
	end
	data.remove_undofile(0)
end

--- Purge orphaned snapshots
---@return nil
function M.clean_orphans()
	local count = storage.clean_orphans()
	vim.notify(string.format("Removed %d orphaned snapshots", count), vim.log.levels.INFO)
end

--- Reset the database
---@param force? boolean Whether to force the reset
---@return nil
function M.reset_database(force)
	if not force then
		local confirm = vim.fn.input("Delete all the databases" .. "? [y/N] ")
		if confirm:lower() ~= "y" then
			return
		end
	end
	local ok, err = storage.delete_db()
	if not ok then
		vim.notify("Failed to delete TimeMachine database: " .. tostring(err), vim.log.levels.ERROR)
		return
	end
	vim.notify("TimeMachine database has been reset", vim.log.levels.INFO)
end

return M
