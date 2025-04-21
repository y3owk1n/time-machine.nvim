local utils = require("time-machine.utils")
local storage = require("time-machine.storage")
local ui = require("time-machine.ui")

local M = {}

--- Create a snapshot for a binary buffer
---@param buf number The buffer to snapshot
---@return nil
local function create_binary_snapshot(buf)
	local buf_path = utils.get_buf_path(buf)

	if not buf_path then
		vim.notify("No buffer path found", vim.log.levels.ERROR)
		return
	end

	local history = storage.load_history(buf_path)

	if not history then
		local id = utils.root_branch_id(buf_path)
		storage.insert_snapshot(buf_path, {
			id = id,
			parent = nil,
			content = "",
			timestamp = os.time(),
			tags = {},
			binary = false,
			is_current = true,
		})
		return
	end

	local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, true), "\n")
	local new_id = ("%x"):format(os.time()) .. "-" .. math.random(1000, 9999)

	storage.insert_snapshot(buf_path, {
		id = new_id,
		parent = nil,
		content = content,
		timestamp = os.time(),
		tags = {},
		binary = true,
		is_current = true,
	})

	local config = require("time-machine.config").config

	storage.prune(config.retention_days)
end

--- Create a snapshot for the current buffer
---@param buf? number The buffer to snapshot
---@param for_root? boolean Whether to create a snapshot for the root branch
---@return nil
function M.create_snapshot(buf, for_root)
	buf = buf or vim.api.nvim_get_current_buf()
	if utils.is_binary(buf) then
		return create_binary_snapshot(buf)
	end

	local config = require("time-machine.config").config

	if vim.tbl_contains(config.ignored_buftypes, vim.bo[buf].buftype) then
		return
	end

	local buf_path = utils.get_buf_path(buf)
	if not buf_path then
		return
	end

	local history = storage.load_history(buf_path)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	--- Convert lines to string
	local new_content = table.concat(lines, "\n")

	if not history then
		local id = utils.root_branch_id(buf_path)
		storage.insert_snapshot(buf_path, {
			id = id,
			parent = nil,
			content = new_content,
			timestamp = os.time(),
			tags = {},
			binary = false,
			is_current = true,
		})
		return
	end

	if for_root then
		return
	end

	local current = history.current
	local old_content = current.content or ""
	local diff = vim.diff(old_content, new_content, { result_type = "unified", ctxlen = 6 })

	if type(diff) ~= "string" then
		diff = ""
	end

	if diff == "" then
		vim.notify("No changes detected", vim.log.levels.WARN)
		return "no_changes"
	end

	local children = storage.get_history_children(current.id)

	local num_children = #children

	local new_branch_id = utils.create_id()
	local new_id = utils.create_id()

	--- there is a children, branch out
	if children and num_children > 0 then
		local tag = "branch-" .. current.id:sub(5, 8)

		--- duplicate the same content but with tag
		storage.insert_snapshot(buf_path, {
			id = new_branch_id,
			parent = current.parent,
			diff = current.diff,
			content = current.content,
			timestamp = os.time(),
			tags = { tag },
			binary = false,
			is_current = false,
		})

		storage.insert_snapshot(buf_path, {
			id = new_id,
			parent = new_branch_id,
			diff = diff,
			content = new_content,
			timestamp = os.time(),
			tags = {},
			binary = false,
			is_current = true,
		})
	else
		storage.insert_snapshot(buf_path, {
			id = new_id,
			parent = current.id,
			diff = diff,
			content = new_content,
			timestamp = os.time(),
			tags = {},
			binary = false,
			is_current = true,
		})
	end

	storage.prune(config.retention_days)
end

--- Show the history for a buffer
---@return nil
function M.show_history()
	local buf_path = utils.get_buf_path(0)
	local bufnr = vim.api.nvim_get_current_buf()
	if not buf_path then
		return
	end
	local history = storage.load_history(buf_path)
	if not history then
		vim.notify("No history found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end
	require("time-machine.ui").show(history, buf_path, bufnr)
end

--- Tag a snapshot
---@param tag_name? string The tag name
---@return nil
function M.tag_snapshot(tag_name)
	local buf_path = utils.get_buf_path(0)
	if not buf_path then
		return
	end

	local history = storage.load_history(buf_path)
	if not history then
		return
	end

	local current_id = history.current.id

	if not tag_name or tag_name == "" then
		tag_name = vim.fn.input("Tag name: ")
	end

	if tag_name and tag_name ~= "" then
		storage.insert_snapshot(buf_path, {
			id = current_id,
			parent = history.current.parent,
			diff = history.snapshots[current_id].diff,
			content = history.current.content,
			timestamp = history.current.timestamp,
			tags = vim.tbl_extend("force", history.snapshots[current_id].tags, { tag_name }),
			binary = history.snapshots[current_id].binary,
			is_current = history.current.is_current,
		})
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

	local history = storage.load_history(buf_path)
	if not history then
		vim.notify("No history found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end

	-- Collect the snapshot chain from target to root
	local chain = {}
	local current_snap = target_snap
	while current_snap do
		table.insert(chain, 1, current_snap) -- Insert at front to reverse order
		current_snap = history.snapshots[current_snap.parent]
	end

	local content = history.root.content

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

	storage.set_current(buf_path, target_snap.id)

	-- Apply to buffer and save
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

--- Purge all snapshots
---@param force? boolean Whether to force the purge
---@return nil
function M.purge_all(force)
	if not force then
		local confirm = vim.fn.input("Delete ALL history? [y/N] ")
		if confirm:lower() ~= "y" then
			return
		end
	end
	local ok, err = pcall(function()
		storage.purge_all()
		vim.notify("Cleared all Time Machine history", vim.log.levels.INFO)
	end)
	if not ok then
		vim.notify("Failed to purge all history: " .. tostring(err), vim.log.levels.ERROR)
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
		local confirm = vim.fn.input("Delete history for " .. vim.fn.fnamemodify(buf_path, ":~:.") .. "? [y/N] ")
		if confirm:lower() ~= "y" then
			return
		end
	end
	storage.purge_current(buf_path)
	vim.notify("Cleared history for current file", vim.log.levels.INFO)
end

--- Purge orphaned snapshots
---@return nil
function M.clean_orphans()
	local count = storage.clean_orphans()
	vim.notify(string.format("Removed %d orphaned histories", count), vim.log.levels.INFO)
end

--- Reset the database
---@param force? boolean Whether to force the reset
---@return nil
function M.reset_database(force)
	local config = require("time-machine.config").config
	if not force then
		local confirm = vim.fn.input("Delete TimeMachine database at " .. config.db_path .. "? [y/N] ")
		if confirm:lower() ~= "y" then
			return
		end
	end
	local ok, err = storage.delete_db()
	if not ok then
		vim.notify("Failed to delete TimeMachine database: " .. tostring(err), vim.log.levels.ERROR)
		return
	end
	storage.init(config.db_path)
	vim.notify("TimeMachine database has been reset", vim.log.levels.INFO)
end

return M
