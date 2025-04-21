local uv = vim.loop
local M = {}
local sqlite_cmd = "sqlite3"
local git = require("time-machine.git")

local function encode(str)
	return str:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("'", "''")
end

local function decode(str)
	return str:gsub("\\n", "\n"):gsub("\\\\", "\\")
end

function M.init(db_path)
	M.db_path = db_path

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
      binary INTEGER,
      tags TEXT,
      is_current INTEGER DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS idx_snapshots_buf_branch ON snapshots(buf_path, branch);
  ]]
	vim.fn.system({ sqlite_cmd, db_path, sql })
end

-- Clear current flag for a buffer
function M.clear_current(buf_path)
	local branch = git.get_git_branch(buf_path)

	local safe = buf_path:gsub("'", "''")
	local sql = string.format(
		"UPDATE snapshots SET is_current=0 WHERE buf_path='%s' AND branch='%s' AND is_current=1;",
		safe,
		branch
	)
	vim.fn.system({ sqlite_cmd, M.db_path, sql })
end

-- Set a specific snapshot as current
function M.set_current(buf_path, snap_id)
	M.clear_current(buf_path)
	local branch = git.get_git_branch(buf_path)
	local safe = buf_path:gsub("'", "''")
	local sql = string.format(
		"UPDATE snapshots SET is_current=1 WHERE buf_path='%s' AND branch='%s' AND id='%s';",
		safe,
		branch,
		snap_id:gsub("'", "''")
	)
	vim.fn.system({ sqlite_cmd, M.db_path, sql })
end

function M.insert_snapshot(buf_path, snap)
	local branch = git.get_git_branch(buf_path)

	local tags_enc = snap.tags and table.concat(snap.tags, ",") or ""
	local binary_val = snap.binary and 1 or 0
	local diff_enc = encode(snap.diff or "")
	local content_enc = encode(snap.content or "")
	local is_curr = snap.is_current and 1 or 0
	local safe_path = buf_path:gsub("'", "''")
	local safe_branch = branch:gsub("'", "''")
	local sql = string.format(
		"INSERT OR REPLACE INTO snapshots VALUES('%s','%s','%s','%s','%s','%s',%d,%d,'%s',%d);",
		snap.id,
		safe_branch,
		safe_path,
		snap.parent or "",
		diff_enc,
		content_enc,
		snap.timestamp,
		binary_val,
		tags_enc,
		is_curr
	)

	vim.fn.system({ sqlite_cmd, M.db_path, sql })
end

function M.load_history(buf_path)
	local branch = git.get_git_branch(buf_path)

	local safe = buf_path:gsub("'", "''")
	local safe_branch = branch:gsub("'", "''")
	local sql = string.format(
		"SELECT id,parent,diff,content,timestamp,binary,tags,is_current,branch "
			.. "FROM snapshots WHERE buf_path='%s' AND branch='%s' ORDER BY timestamp;",
		safe,
		safe_branch
	)
	local rows = vim.fn.systemlist({ sqlite_cmd, M.db_path, "-separator", "|", sql })
	if vim.v.shell_error ~= 0 or #rows == 0 then
		return nil
	end
	local history = { snapshots = {}, root = nil, current = nil }
	for _, row in ipairs(rows) do
		local fields = vim.split(row, "|", true)
		local id, parent, diff_enc, content_enc, ts, binary, tags, is_curr = unpack(fields)
		local snap = {
			id = id,
			parent = (parent ~= "") and parent or nil,
			diff = (diff_enc ~= "") and decode(diff_enc) or nil,
			content = decode(content_enc),
			timestamp = tonumber(ts),
			binary = (binary == "1"),
			tags = (tags and #tags > 0) and vim.split(tags, ",", true) or {},
			is_current = (is_curr == "1"),
		}
		history.snapshots[id] = snap
		if not snap.parent then
			history.root = snap
		end
		if snap.is_current then
			history.current = snap
		end
	end
	-- Fallback: if none flagged, use last entry
	if not history.current then
		history.current = history.snapshots[rows[#rows]:match("^[^|]+")] -- first field of last row
	end
	return history
end

function M.prune(retention_days)
	local cutoff = os.time() - retention_days * 86400
	local sql = string.format("DELETE FROM snapshots WHERE timestamp < %d;", cutoff)
	vim.fn.system({ sqlite_cmd, M.db_path, sql })
end

-- Delete all snapshot records
function M.purge_all()
	local sql = "DELETE FROM snapshots;"
	vim.fn.system({ sqlite_cmd, M.db_path, sql })
end

-- Delete records for a single buffer path
function M.purge_current(buf_path)
	local branch = git.get_git_branch(buf_path)
	local safe = buf_path:gsub("'", "''")
	local safe_branch = branch:gsub("'", "''")
	local sql = string.format("DELETE FROM snapshots WHERE buf_path='%s' AND branch='%s';", safe, safe_branch)
	vim.fn.system({ sqlite_cmd, M.db_path, sql })
end

-- Remove snapshots for files that no longer exist
function M.clean_orphans()
	local sql = "SELECT DISTINCT buf_path, branch FROM snapshots;"
	local rows = vim.fn.systemlist({ sqlite_cmd, M.db_path, "-separator", "|", sql })
	local count = 0

	local branches = git.get_git_branches()

	local branch_set = {}
	for _, branch in ipairs(branches) do
		branch_set[branch] = true
	end

	for _, row in ipairs(rows) do
		-- Split each row into buf_path and branch
		local buf_path, branch = unpack(vim.split(row, "|", true))

		-- Check if the file exists
		local file_exists = vim.fn.filereadable(buf_path) == 1

		-- Check if the branch exists in the repository
		local branch_exists = branch_set[branch] ~= nil

		if not file_exists or not branch_exists then
			local safe_path = buf_path:gsub("'", "''")
			local safe_branch = branch:gsub("'", "''")
			local del =
				string.format("DELETE FROM snapshots WHERE buf_path='%s' AND branch='%s';", safe_path, safe_branch)
			vim.fn.system({ sqlite_cmd, M.db_path, del })
			count = count + 1
		end
	end
	return count
end

-- Delete the database file itself
function M.delete_db()
	local path = M.db_path
	local ok, err = pcall(function()
		-- remove file via Lua io
		os.remove(path)
	end)
	return ok, err
end

return M
