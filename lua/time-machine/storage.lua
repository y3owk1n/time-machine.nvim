local uv = vim.loop
local M = {}
local sqlite_cmd = "sqlite3"
local git = require("time-machine.git")
local utils = require("time-machine.utils")

--- Get the path to the database file for a buffer
---@param buf_path string The path to the buffer
---@return string db_path The path to the database file
local function get_db_path(buf_path)
	return require("time-machine.config").config.db_dir .. "/" .. utils.slugify_buf_path(buf_path)
end

--- Perform a database action
---@param buf_path string The path to the buffer
---@param sql string The SQL statement
---@param opts? { separator?: string }
---@return string[]|nil output The output lines if return_output is true
local function db_action(buf_path, sql, opts)
	opts = opts or {}
	local db_path = get_db_path(buf_path)
	if not db_path then
		vim.notify("No database path configured", vim.log.levels.ERROR)
		return nil
	end

	local cmd = { sqlite_cmd, db_path }
	if opts.separator then
		vim.list_extend(cmd, { "-separator", opts.separator })
	end
	table.insert(cmd, sql)

	return vim.fn.systemlist(cmd)
end

--- Try to initialize the database
---@param buf_path string The path to the buffer
---@return nil
function M.try_init(buf_path)
	local db_path = get_db_path(buf_path)

	if uv.fs_stat(db_path) then
		return
	end

	local dir = db_path:match("(.*)[/\\]")
	if dir and uv.fs_stat(dir) == nil then
		vim.fn.mkdir(dir, "p")
	end
	local sql = [[
    CREATE TABLE IF NOT EXISTS snapshots (
      id TEXT PRIMARY KEY,
      branch TEXT,
      buf_path TEXT,
      parent TEXT,
      diff TEXT,
      content TEXT,
      timestamp INTEGER,
      tags TEXT,
      is_current INTEGER DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS idx_snapshots_buf_branch ON snapshots(buf_path, branch);
  ]]

	db_action(buf_path, sql)
end

--- Get the current snapshot for a buffer
---@param buf_path string The path to the buffer
---@return TimeMachine.Snapshot|nil snapshot The current snapshot
function M.get_current_snapshot(buf_path)
	local branch = git.get_git_branch(buf_path)

	local safe = buf_path:gsub("'", "''")
	local safe_branch = branch:gsub("'", "''")
	local sql = string.format(
		"SELECT id,parent,diff,content,timestamp,tags,is_current,branch "
			.. "FROM snapshots WHERE buf_path='%s' AND branch='%s' AND is_current=1;",
		safe,
		safe_branch
	)
	local rows = db_action(buf_path, sql, { separator = "|" })
	if vim.v.shell_error ~= 0 or not rows or #rows == 0 then
		return nil
	end
	local fields = vim.split(rows[1], "|")
	local id, parent, diff_enc, content_enc, ts, tags, is_curr = unpack(fields)
	local snap = {
		id = id,
		parent = (parent ~= "") and parent or nil,
		diff = (diff_enc ~= "") and utils.decode(diff_enc) or nil,
		content = utils.decode(content_enc),
		timestamp = tonumber(ts),
		tags = (tags and #tags > 0) and vim.split(tags, ",") or {},
		is_current = (is_curr == "1"),
	}
	return snap
end

--- Clear current flag for a buffer
---@param buf_path string The path to the buffer
---@return nil
function M.clear_current_snapshot(buf_path)
	local branch = git.get_git_branch(buf_path)

	local safe = buf_path:gsub("'", "''")
	local sql = string.format(
		"UPDATE snapshots SET is_current=0 WHERE buf_path='%s' AND branch='%s' AND is_current=1;",
		safe,
		branch
	)

	db_action(buf_path, sql)
end

-- Set a specific snapshot as current
---@param buf_path string The path to the buffer
---@param snap_id string The snapshot ID
---@return nil
function M.set_current_snapshot(buf_path, snap_id)
	M.clear_current_snapshot(buf_path)
	local branch = git.get_git_branch(buf_path)

	local safe = buf_path:gsub("'", "''")
	local sql = string.format(
		"UPDATE snapshots SET is_current=1 WHERE buf_path='%s' AND branch='%s' AND id='%s';",
		safe,
		branch,
		snap_id:gsub("'", "''")
	)

	db_action(buf_path, sql)
end

--- Insert a snapshot into the database
---@param buf_path string The path to the buffer
---@param snap TimeMachine.Snapshot The snapshot to insert
---@return nil
function M.insert_snapshot(buf_path, snap)
	local branch = git.get_git_branch(buf_path)

	local tags_enc = snap.tags and table.concat(snap.tags, ",") or ""
	local diff_enc = utils.encode(snap.diff or "")
	local content_enc = utils.encode(snap.content or "")
	local is_curr = snap.is_current and 1 or 0
	local safe_path = buf_path:gsub("'", "''")
	local safe_branch = branch:gsub("'", "''")
	local sql = string.format(
		"INSERT OR REPLACE INTO snapshots VALUES('%s','%s','%s','%s','%s','%s',%d,'%s',%d);",
		snap.id,
		safe_branch,
		safe_path,
		snap.parent or "",
		diff_enc,
		content_enc,
		snap.timestamp,
		tags_enc,
		is_curr
	)

	db_action(buf_path, sql)
end

--- Count the number of snapshots for a buffer
---@param buf_path string The path to the buffer
---@return integer|nil count The number of snapshots
function M.count_snapshots(buf_path)
	local branch = git.get_git_branch(buf_path)

	local safe = buf_path:gsub("'", "''")
	local safe_branch = branch:gsub("'", "''")
	local sql = string.format("SELECT COUNT(*) FROM snapshots WHERE buf_path='%s' AND branch='%s';", safe, safe_branch)
	local rows = db_action(buf_path, sql, { separator = "|" })
	if vim.v.shell_error ~= 0 or not rows or #rows == 0 then
		return nil
	end
	local fields = vim.split(rows[1], "|")
	local count = tonumber(fields[1])
	return count
end

function M.get_root_snapshot(buf_path)
	local branch = git.get_git_branch(buf_path)

	local safe = buf_path:gsub("'", "''")
	local safe_branch = branch:gsub("'", "''")
	local sql = string.format(
		[[
    SELECT s.id,
           s.parent,
           s.diff,
           s.content,
           s.timestamp,
           s.tags,
           s.is_current,
           s.branch
    FROM snapshots AS s
    LEFT JOIN snapshots AS p
      ON p.id = s.parent
    WHERE s.buf_path = '%s'
      AND s.branch   = '%s'
      AND s.parent IS NOT NULL
      AND p.id     IS NULL;
  ]],
		safe,
		safe_branch
	)
	local rows = db_action(buf_path, sql, { separator = "|" })
	if vim.v.shell_error ~= 0 or not rows or #rows == 0 then
		return nil
	end

	local fields = vim.split(rows[1], "|")
	local id, parent, diff_enc, content_enc, ts, tags, is_curr = unpack(fields)
	local snap = {
		id = id,
		parent = (parent ~= "") and parent or nil,
		diff = (diff_enc ~= "") and utils.decode(diff_enc) or nil,
		content = utils.decode(content_enc),
		timestamp = tonumber(ts),
		tags = (tags and #tags > 0) and vim.split(tags, ",") or {},
		is_current = (is_curr == "1"),
	}
	return snap
end

--- Get a snapshot history by ID
---@param snapshot_id string The snapshot ID
---@param buf_path string The path to the buffer
---@return TimeMachine.Snapshot|nil history The snapshot history
function M.get_snapshot_by_id(snapshot_id, buf_path)
	local branch = git.get_git_branch(buf_path)

	local safe = buf_path:gsub("'", "''")
	local safe_branch = branch:gsub("'", "''")
	local sql = string.format(
		"SELECT id,parent,diff,content,timestamp,tags,is_current,branch "
			.. "FROM snapshots WHERE buf_path='%s' AND branch='%s' AND id='%s';",
		safe,
		safe_branch,
		snapshot_id
	)
	local rows = db_action(buf_path, sql, { separator = "|" })
	if vim.v.shell_error ~= 0 or not rows or #rows == 0 then
		return nil
	end
	local fields = vim.split(rows[1], "|")
	local id, parent, diff_enc, content_enc, ts, tags, is_curr = unpack(fields)
	local snap = {
		id = id,
		parent = (parent ~= "") and parent or nil,
		diff = (diff_enc ~= "") and utils.decode(diff_enc) or nil,
		content = utils.decode(content_enc),
		timestamp = tonumber(ts),
		tags = (tags and #tags > 0) and vim.split(tags, ",") or {},
		is_current = (is_curr == "1"),
	}
	return snap
end

--- Load a snapshot history for a buffer
---@param buf_path string The path to the buffer
---@return TimeMachine.Snapshot|nil snapshot The snapshot history
function M.get_snapshots(buf_path)
	local branch = git.get_git_branch(buf_path)

	local safe = buf_path:gsub("'", "''")
	local safe_branch = branch:gsub("'", "''")
	local sql = string.format(
		"SELECT id,parent,diff,content,timestamp,tags,is_current,branch "
			.. "FROM snapshots WHERE buf_path='%s' AND branch='%s' ORDER BY timestamp;",
		safe,
		safe_branch
	)
	local rows = db_action(buf_path, sql, { separator = "|" })
	if vim.v.shell_error ~= 0 or not rows or #rows == 0 then
		return nil
	end
	local snapshots = {}
	for _, row in ipairs(rows) do
		local fields = vim.split(row, "|")
		local id, parent, diff_enc, content_enc, ts, tags, is_curr = unpack(fields)
		local snap = {
			id = id,
			parent = (parent ~= "") and parent or nil,
			diff = (diff_enc ~= "") and utils.decode(diff_enc) or nil,
			content = utils.decode(content_enc),
			timestamp = tonumber(ts),
			tags = (tags and #tags > 0) and vim.split(tags, ",") or {},
			is_current = (is_curr == "1"),
		}
		snapshots[id] = snap
	end
	return snapshots
end

--- Get the children of a snapshot
---@param id string The snapshot ID
---@param buf_path string The path to the buffer
---@return string[]|nil children The children of the snapshot
function M.get_snapshot_children(id, buf_path)
	if not id then
		return nil
	end
	local sql = string.format("SELECT id FROM snapshots WHERE parent='%s';", id)
	return db_action(buf_path, sql)
end

--- Prune snapshots older than a certain number of days
---@param retention_days number The number of days to retain snapshots
---@return nil
function M.prune(retention_days)
	local db_dir = require("time-machine.config").config.db_dir

	if not db_dir then
		vim.notify("No database directory configured", vim.log.levels.ERROR)
		return
	end

	local files = utils.get_files(db_dir)

	for _, file in ipairs(files) do
		local stat = uv.fs_stat(file)
		if stat and stat.type == "file" then
			local filename = vim.fn.fnamemodify(file, ":t")
			local file_path = utils.unslugify_buf_path(filename)

			local cutoff = os.time() - retention_days * 86400
			local sql = string.format("DELETE FROM snapshots WHERE timestamp < %d;", cutoff)

			db_action(file_path, sql)
		end
	end
end

-- Delete all snapshot records
---@return nil
function M.purge_all()
	local db_dir = require("time-machine.config").config.db_dir

	if not db_dir then
		vim.notify("No database directory configured", vim.log.levels.ERROR)
		return
	end

	local files = utils.get_files(db_dir)

	for _, file in ipairs(files) do
		local stat = uv.fs_stat(file)
		if stat and stat.type == "file" then
			local filename = vim.fn.fnamemodify(file, ":t")
			local file_path = utils.unslugify_buf_path(filename)

			local sql = "DELETE FROM snapshots;"
			db_action(file_path, sql)
		end
	end
end

-- Delete records for a single buffer path
---@param buf_path string The path to the buffer
---@return nil
function M.purge_current(buf_path)
	local branch = git.get_git_branch(buf_path)
	local safe = buf_path:gsub("'", "''")
	local safe_branch = branch:gsub("'", "''")
	local sql = string.format("DELETE FROM snapshots WHERE buf_path='%s' AND branch='%s';", safe, safe_branch)
	db_action(buf_path, sql)
end

-- Remove snapshots for files that no longer exist
---@return integer|nil count The number of orphaned snapshots removed
function M.clean_orphans()
	local db_dir = require("time-machine.config").config.db_dir

	if not db_dir then
		vim.notify("No database directory configured", vim.log.levels.ERROR)
		return
	end

	local files = utils.get_files(db_dir)

	local count = 0

	for _, file in ipairs(files) do
		local stat = uv.fs_stat(file)
		if stat and stat.type == "file" then
			local filename = vim.fn.fnamemodify(file, ":t")
			local file_path = utils.unslugify_buf_path(filename)

			local sql = "SELECT DISTINCT buf_path, branch FROM snapshots;"
			local rows = db_action(file_path, sql, { separator = "|" }) or {}

			local branches = git.get_git_branches()

			local branch_set = {}
			for _, branch in ipairs(branches) do
				branch_set[branch] = true
			end

			for _, row in ipairs(rows) do
				-- Split each row into buf_path and branch
				local buf_path, branch = unpack(vim.split(row, "|"))

				-- Check if the file exists
				local file_exists = vim.fn.filereadable(buf_path) == 1

				-- Check if the branch exists in the repository
				local branch_exists = branch_set[branch] ~= nil

				if not file_exists or not branch_exists then
					local safe_path = buf_path:gsub("'", "''")
					local safe_branch = branch:gsub("'", "''")
					local del = string.format(
						"DELETE FROM snapshots WHERE buf_path='%s' AND branch='%s';",
						safe_path,
						safe_branch
					)
					db_action(file, del)
					count = count + 1
				end
			end
		end
	end

	return count
end

-- Delete the database file itself
---@return boolean ok Whether the file was deleted
---@return unknown|nil err The error message
function M.delete_db()
	local db_dir = require("time-machine.config").config.db_dir

	if not db_dir then
		return false, "No database directory configured"
	end

	local stat = uv.fs_stat(db_dir)
	if not stat or stat.type ~= "directory" then
		return false, "No database directory configured"
	end

	local ok, err = pcall(function()
		vim.fn.delete(db_dir, "rf") -- recursive + force
		vim.fn.mkdir(db_dir, "p") -- recreate the (now empty) directory
	end)
	return ok, err
end

return M
