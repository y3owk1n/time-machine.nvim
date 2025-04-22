local utils = require("time-machine.utils")
local storage = require("time-machine.storage")
local ui = require("time-machine.ui")
local constants = require("time-machine.constants").constants

local M = {}

--- Create a snapshot for the current buffer
---@param buf? number The buffer to snapshot
---@param for_root? boolean Whether to create a snapshot for the root branch
---@param silent? boolean Whether to suppress notifications
---@return nil
function M.create_snapshot(buf, for_root, silent)
	buf = buf or vim.api.nvim_get_current_buf()

	local config = require("time-machine.config").config

	if vim.tbl_contains(config.ignored_buftypes, vim.bo[buf].buftype) then
		return
	end

	local buf_path = utils.get_buf_path(buf)
	if not buf_path then
		return
	end

	storage.try_init(buf_path)

	local count = storage.count_snapshots(buf_path)
	local current = storage.get_current_snapshot(buf_path)

	if not count then
		vim.notify("No snapshot count", vim.log.levels.ERROR)
		return
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	--- Convert lines to string
	local new_content = table.concat(lines, "\n")

	if count == 0 then
		local id = utils.root_branch_id(buf_path)
		storage.insert_snapshot(buf_path, {
			id = id,
			parent = nil,
			content = new_content,
			timestamp = os.time(),
			tags = {},
			is_current = true,
		})

		vim.api.nvim_exec_autocmds("User", { pattern = constants.events.snapshot_created })
		return
	end

	if for_root then
		return
	end

	if not current then
		vim.notify("No current snapshot found", vim.log.levels.ERROR)
		return
	end

	local old_content = current.content or ""
	local diff = vim.diff(old_content, new_content, { result_type = "unified", ctxlen = 6 })

	if type(diff) ~= "string" then
		diff = ""
	end

	if diff == "" then
		if not silent then
			vim.notify("No changes detected", vim.log.levels.WARN)
		end
		return "no_changes"
	end

	local new_id = utils.create_id()

	storage.insert_snapshot(buf_path, {
		id = new_id,
		parent = current.id,
		diff = diff,
		content = new_content,
		timestamp = os.time(),
		tags = {},
		is_current = true,
	})

	storage.set_current_snapshot(buf_path, new_id)

	vim.api.nvim_exec_autocmds("User", { pattern = constants.events.snapshot_created })
end

--- Show the snapshot for a buffer
---@return nil
function M.show_snapshots()
	local buf_path = utils.get_buf_path(0)
	local bufnr = vim.api.nvim_get_current_buf()
	if not buf_path then
		return
	end

	storage.try_init(buf_path)

	local snapshots = storage.get_snapshots(buf_path)

	local current = storage.get_current_snapshot(buf_path)

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

--- Tag a snapshot
---@param tag_name? string The tag name
---@param target_snap? TimeMachine.Snapshot The snapshot to restore
---@param buf_path? string The path to the buffer
---@return nil
function M.tag_snapshot(tag_name, target_snap, buf_path)
	buf_path = buf_path or utils.get_buf_path(0)
	if not buf_path then
		return
	end

	storage.try_init(buf_path)

	if not target_snap then
		local current = storage.get_current_snapshot(buf_path)
		if not current then
			return
		end

		target_snap = current
	end

	local current_id = target_snap.id

	if not tag_name or tag_name == "" then
		tag_name = vim.fn.input("Tag name: ")
	end

	if tag_name and tag_name ~= "" then
		local tags = target_snap.tags or {}
		table.insert(tags, tag_name)

		storage.insert_snapshot(buf_path, {
			id = current_id,
			parent = target_snap.parent,
			diff = target_snap.diff,
			content = target_snap.content,
			timestamp = target_snap.timestamp,
			tags = tags,
			is_current = target_snap.is_current,
		})

		vim.api.nvim_exec_autocmds("User", { pattern = constants.events.snapshot_created })
	end
end

--- Restore a snapshot
---@param target_snap TimeMachine.Snapshot The snapshot to restore
---@param buf_path string The path to the buffer
---@param main_bufnr integer The main buffer number
---@return nil
function M.restore_snapshot(target_snap, buf_path, main_bufnr)
	local bufnr = main_bufnr

	if not bufnr then
		vim.notify("No main buffer found", vim.log.levels.ERROR)
	end

	buf_path = buf_path or utils.get_buf_path(0)
	if not buf_path then
		return
	end

	storage.try_init(buf_path)

	local root = storage.get_root_snapshot(buf_path)

	if not root then
		vim.notify("No root snapshot found", vim.log.levels.ERROR)
		return
	end

	local snapshots = storage.get_snapshots(buf_path)
	if not snapshots then
		vim.notify("No snapshots found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end

	-- Collect the snapshot chain from target to root
	local chain = {}
	local current_snap = target_snap
	while current_snap do
		table.insert(chain, 1, current_snap) -- Insert at front to reverse order
		current_snap = snapshots[current_snap.parent]
	end

	local content = root.content

	for i = 2, #chain do
		local snap = chain[i]
		if snap.diff then
			content = require("time-machine.patch").apply_diff(content, snap.diff)
		else
			vim.notify("Missing diff for snapshot " .. snap.id, vim.log.levels.WARN)
		end
	end

	-- Split into lines for buffer operations
	local lines = vim.split(content, "\n")

	storage.set_current_snapshot(buf_path, target_snap.id)

	-- Apply to buffer and save
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

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
		vim.notify("Cleared all Time Machine snapshots", vim.log.levels.INFO)
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
	storage.purge_current(buf_path)
	vim.notify("Cleared snapshots for current file", vim.log.levels.INFO)
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
