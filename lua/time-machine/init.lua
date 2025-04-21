---@module "time-machine"

local git = require("time-machine.git")
local storage = require("time-machine.storage")

local M = {}

M.setup = require("time-machine.config").setup

local function get_buf_path(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	return path ~= "" and path or nil
end

local function is_binary(buf)
	return vim.bo[buf].binary or vim.bo[buf].filetype == "git"
end

function M.root_branch_id(buf_path)
	local branch = git.get_git_branch(buf_path)
	if not branch or branch == "detached" then
		return "root"
	end
	return ("root-%s"):format(branch)
end

function M.create_snapshot(buf, for_root)
	buf = buf or vim.api.nvim_get_current_buf()
	if is_binary(buf) then
		return M.create_binary_snapshot(buf)
	end

	local config = require("time-machine.config").config

	if vim.tbl_contains(config.ignored_buftypes, vim.bo[buf].buftype) then
		return
	end

	local buf_path = get_buf_path(buf)
	if not buf_path then
		return
	end

	local history = storage.load_history(buf_path)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	--- Convert lines to string
	local new_content = table.concat(lines, "\n")

	if not history then
		local id = M.root_branch_id(buf_path)
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

	if diff == "" then
		vim.notify("No changes detected", vim.log.levels.WARN)
		return "no_changes"
	end

	local new_id = ("%x"):format(os.time()) .. "-" .. math.random(1000, 9999)

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

	storage.prune(config.retention_days)
end

function M.create_binary_snapshot(buf)
	local buf_path = get_buf_path(buf)

	local history = storage.load_history(buf_path)

	if not history then
		local id = M.root_branch_id(buf_path)
		storage.insert_snapshot(buf_path, {
			id = id,
			parent = nil,
			content = "",
			timestamp = os.time(),
			tags = {},
			binary = false,
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

function M.show_history()
	local buf_path = get_buf_path(0)
	local bufnr = vim.api.nvim_get_current_buf()
	if not buf_path then
		return
	end
	local history = require("time-machine.storage").load_history(buf_path)
	if not history then
		vim.notify("No history found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end
	require("time-machine.ui").show(history, buf_path, bufnr)
end

function M.tag_snapshot(tag_name)
	local buf_path = get_buf_path(0)
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
		})
	end
end

function M.restore_snapshot(target_snap, buf_path, main_bufnr)
	local bufnr = main_bufnr

	if not bufnr then
		vim.notify("No main buffer found", vim.log.levels.ERROR)
	end

	buf_path = buf_path or get_buf_path(0)
	if not buf_path then
		return
	end

	local history = require("time-machine.storage").load_history(buf_path)
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
			content = M.apply_diff(content, snap.diff)
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

local function parse_hunk_header(line)
	-- Allow flexible whitespace and trailing context
	local old_part, new_part = line:match("^@@%s*-%s*(%d+,?%d*)%s+%+%s*(%d+,?%d*)%s*@@.*")
	if not old_part or not new_part then
		return nil
	end

	-- Parse old range (handle single-line cases)
	local old_start, old_count = old_part:match("^(%d+)%,?(%d*)$")
	old_start = tonumber(old_start)
	old_count = old_count == "" and 1 or math.max(tonumber(old_count) or 1, 1)

	-- Parse new range (handle creation/deletion cases)
	local new_start, new_count = new_part:match("^(%d+)%,?(%d*)$")
	new_start = tonumber(new_start)
	new_count = new_count == "" and 1 or math.max(tonumber(new_count) or 1, 1)

	return {
		old_start = old_start,
		old_count = old_count,
		new_start = new_start,
		new_count = new_count,
	}
end

function M.apply_diff(parent_content, diff)
	local parent_lines = parent_content ~= "" and vim.split(parent_content, "\n") or {}
	local hunks = {}

	local current_hunk = nil

	for _, line in ipairs(vim.split(diff, "\n")) do
		if line:find("^@@") then
			local header = parse_hunk_header(line)
			if header then
				current_hunk = {
					old_start = header.old_start,
					old_count = header.old_count,
					new_start = header.new_start,
					new_count = header.new_count,
					lines = {},
					raw_header = line,
				}
				table.insert(hunks, current_hunk)
			else
				vim.notify("Skipping malformed hunk: " .. line, vim.log.levels.WARN)
			end
		elseif current_hunk then
			table.insert(current_hunk.lines, line)
		end
	end

	if #parent_lines == 0 then
		local new_content = {}
		for _, hunk in ipairs(hunks) do
			for _, line in ipairs(hunk.lines) do
				if line:sub(1, 1) == "+" then
					new_content[#new_content + 1] = line:sub(2)
				end
			end
		end
		return table.concat(new_content, "\n")
	end

	-- Validate hunks before processing
	if #hunks == 0 then
		vim.notify("No valid hunks found in diff", vim.log.levels.WARN)
		return parent_content
	end

	-- Apply hunks in reverse order to maintain correct line numbers
	for i = #hunks, 1, -1 do
		local hunk = hunks[i]
		local pos = hunk.old_start - 1 -- Convert to 0-based index
		local to_remove = hunk.old_count
		local new_lines = {}

		-- Process hunk lines
		for _, line in ipairs(hunk.lines) do
			local prefix = line:sub(1, 1)
			local content = line:sub(2)

			if prefix == " " then
				-- Verify context matches
				if parent_lines[pos + 1] ~= content then
					error(
						string.format(
							"Patch mismatch at line %d\nExpected: %s\nActual: %s",
							pos,
							content,
							parent_lines[pos + 1] or ""
						)
					)
				end
				table.insert(new_lines, content)
				pos = pos + 1
				to_remove = to_remove - 1
			elseif prefix == "-" then
				-- Track removal from original
				if parent_lines[pos + 1] ~= content then
					error(
						string.format(
							"Deletion mismatch at line %d\nExpected: %s\nActual: %s",
							pos + 1,
							content,
							parent_lines[pos + 1] or ""
						)
					)
				end
				pos = pos + 1
				to_remove = to_remove - 1
			elseif prefix == "+" then
				table.insert(new_lines, content)
			end
		end

		-- Replace the affected section
		local before = { unpack(parent_lines, 1, hunk.old_start - 1) }
		local after = { unpack(parent_lines, hunk.old_start + hunk.old_count) }
		parent_lines = vim.list_extend(before, vim.list_extend(new_lines, after))
	end

	return table.concat(parent_lines, "\n")
end

function M.find_child(history, parent_id)
	for _, snap in pairs(history.snapshots) do
		if snap.parent == parent_id then
			return snap
		end
	end
	return nil
end

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

function M.purge_current(force)
	local buf_path = get_buf_path(0)
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

function M.clean_orphans()
	local count = storage.clean_orphans()
	vim.notify(string.format("Removed %d orphaned histories", count), vim.log.levels.INFO)
end

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
