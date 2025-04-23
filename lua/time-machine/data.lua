local constants = require("time-machine.constants").constants

local M = {}

--- Recursively collect snapshots from one entry (and its nested alts)
---@param entry table               one element of ut.entries or an alt entry
---@param parent_id string|nil      the parent snapshot’s seq (or nil for roots)
---@param current_seq number        ut.seq_cur, so we can mark is_current
---@param new_head number|nil       the new head sequence
---@return TimeMachine.Snapshot[]   a flat list of snapshots
local function collect_snaps(entry, parent_id, current_seq, new_head)
	local snaps = {}

	-- 1) Add this entry
	local id = tostring(entry.seq)
	if new_head and new_head > 0 then
		parent_id = tostring(new_head)
	end
	table.insert(snaps, {
		id = id,
		parent = parent_id,
		timestamp = entry.time,
		is_current = (entry.seq == current_seq),
	})

	-- 2) Recurse into every nested alt
	if entry.alt then
		for _, alt in ipairs(entry.alt) do
			new_head = entry.newhead or new_head
			local child_snaps = collect_snaps(alt, id, current_seq, new_head)
			for _, s in ipairs(child_snaps) do
				table.insert(snaps, s)
			end
		end
	end

	return snaps
end

--- Format the full undotree into a flat TimeMachine.Snapshot[] array
---@param ut table  result of vim.fn.undotree()
---@return TimeMachine.Snapshot[] snapshots
local function format_undotree_as_snapshots(ut)
	Snacks.debug(ut)
	local snaps = {}
	for idx, entry in ipairs(ut.entries) do
		-- the “linear” parent is the previous entry in ut.entries
		local parent_id = (idx > 1) and tostring(ut.entries[idx - 1].seq) or nil

		if entry.newhead then
			parent_id = tostring(entry.newhead)
		end

		-- collect this entry + all its nested alts
		local entry_snaps = collect_snaps(entry, parent_id, ut.seq_cur, ut.new_head)
		for _, s in ipairs(entry_snaps) do
			table.insert(snaps, s)
		end
	end

	local timestamp = os.time()

	if #snaps > 0 then
		timestamp = snaps[1].timestamp
		-- for _, s in ipairs(snaps) do
		-- 	if s.parent == nil then
		-- 		s.parent = tostring(0)
		-- 	end
		-- end
	end

	local root = {
		id = "0",
		parent = nil,
		timestamp = timestamp,
		is_current = #snaps == 0,
	}

	table.insert(snaps, 1, root)

	Snacks.debug(snaps)
	return snaps
end

--- Get the current snapshot from undotree
---@param bufnr integer The buffer number
---@return TimeMachine.Snapshot|nil The current snapshot
function M.get_snapshots(bufnr)
	if vim.api.nvim_buf_is_valid(bufnr) == 0 then
		return nil
	end

	local ut = vim.fn.undotree(bufnr)

	return format_undotree_as_snapshots(ut)
end

function M.get_current_snapshot(bufnr)
	local snaps = M.get_snapshots(bufnr)

	if not snaps then
		return nil
	end

	for _, snap in ipairs(snaps) do
		if snap.is_current then
			return snap
		end
	end

	return nil
end

--- Remove the persistent-undo file for a given buffer
---@param bufnr number|nil  Buffer number (defaults to current buffer)
---@return boolean ok       `true` if we removed a file, `false` otherwise
function M.remove_undofile(bufnr)
	bufnr = bufnr or 0
	-- 1) Get the absolute path of the buffer’s file
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	if bufname == "" then
		vim.notify("Buffer has no name, cannot find undofile", vim.log.levels.WARN)
		return false
	end

	-- If you want to be certain it’s absolute, you can do:
	bufname = vim.fn.fnamemodify(bufname, ":p")

	-- 2) Ask Vim what its undo-file path would be
	local ufile = vim.fn.undofile(bufname)

	if ufile == "" then
		vim.notify("‘undofile’ not enabled or no undodir set", vim.log.levels.WARN)
		return false
	end

	-- 3) Check it exists, then delete it
	if vim.fn.filereadable(ufile) == 1 then
		local ok, err = pcall(os.remove, ufile)
		if ok then
			vim.notify("Removed undofile: " .. ufile, vim.log.levels.INFO)

			local opts = vim.api.nvim_buf_get_option
			local set_opts = vim.api.nvim_buf_set_option

			-- save original undolevels & modified‐flag
			local old_ul = opts(bufnr, "undolevels")
			local old_mod = opts(bufnr, "modified")

			-- tell Vim to throw away all undo info for the next change
			set_opts(bufnr, "undolevels", -1)

			-- fetch the current lines (no visual diff) and immediately reset them
			local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

			-- restore undolevels *before* restoring the modified flag
			set_opts(bufnr, "undolevels", old_ul)
			set_opts(bufnr, "modified", old_mod)

			vim.api.nvim_exec_autocmds("User", { pattern = constants.events.snapshot_deleted })

			return true
		else
			vim.notify("Failed to remove undofile: " .. err, vim.log.levels.ERROR)
			return false
		end
	else
		vim.notify("No undofile found at: " .. ufile, vim.log.levels.WARN)
		return false
	end
end

return M
