local api = vim.api
local utils = require("time-machine.utils")
local constants = require("time-machine.constants").constants
local storage = require("time-machine.storage")
local data = require("time-machine.data")

local M = {}

local native_float = nil

local winborder = vim.api.nvim_get_option_value("winborder", { scope = "local" }) or "none"

---@type vim.api.keyset.win_config
local shared_win_opts = {
	relative = "editor",
	width = 0.8,
	height = 0.8,
	border = winborder,
	title_pos = "center",
	footer = "Press `q` to exit",
	footer_pos = "center",
}

--- Create a floating window for native
---@param buf integer The buffer to open
---@param title? string The title appended after `Time Machine`
---@return nil
local function create_native_float(buf, title)
	if native_float then
		if vim.api.nvim_win_is_valid(native_float) then
			vim.api.nvim_win_set_buf(native_float, buf)
			return
		end
	end

	local win_opts = vim.tbl_deep_extend("force", shared_win_opts, {
		title = "Time Machine" .. (title and (" - " .. title) or ""),
	})

	win_opts.width = math.floor(vim.o.columns * win_opts.width)
	win_opts.height = math.floor(vim.o.lines * win_opts.height)
	win_opts.row = math.floor((vim.o.lines - win_opts.height) / 2)
	win_opts.col = math.floor((vim.o.columns - win_opts.width) / 2)

	vim.api.nvim_open_win(buf, true, win_opts)
end

--- Set standard buffer options
---@param bufnr integer The buffer number
---@return nil
local function set_standard_buf_options(bufnr)
	api.nvim_set_option_value("filetype", constants.snapshot_ft, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("buftype", "nofile", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("bufhidden", "wipe", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("swapfile", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("modifiable", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", true, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("buflisted", false, { scope = "local", buf = bufnr })
end

--- Set highlights for the UI
---@param bufnr integer The buffer number
---@param id_map table<integer, string> The map of line numbers to snapshot IDs
---@param current TimeMachine.Snapshot The current snapshot
---@param lines table<integer, string> The lines of the snapshot
---@return nil
local function set_highlights(bufnr, id_map, current, lines)
	api.nvim_buf_clear_namespace(bufnr, constants.ns, 0, -1)

	for i, id in ipairs(id_map) do
		if id == current.id then
			local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
			local end_col = line and #line or 0

			api.nvim_buf_set_extmark(bufnr, constants.ns, i - 1, 0, {
				end_col = end_col,
				hl_group = constants.hl.current,
			})
			break
		end
	end

	for i, line in ipairs(lines) do
		for tag in line:gmatch("%b[]") do
			local start_col = line:find(tag, 1, true) - 1
			api.nvim_buf_set_extmark(bufnr, constants.ns, i - 1, start_col, {
				end_col = start_col + #tag,
				hl_group = constants.hl.keymap,
			})
		end

		local info_matches = { "DB Path:", "File:" }

		for _, info_match in ipairs(info_matches) do
			if line:find(info_match) then
				local current_line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
				local end_col = current_line and #current_line or 0

				api.nvim_buf_set_extmark(bufnr, constants.ns, i - 1, 0, {
					end_col = end_col,
					hl_group = constants.hl.info,
				})
			end
		end
	end
end

--- Set header for the UI
---@param lines table<integer, string> The lines of the snapshot
---@param id_map table<integer, string> The map of line numbers to snapshot IDs
---@param buf_path string The path to the buffer
---@return nil
local function set_header(lines, id_map, buf_path)
	--- NOTE: lines are in reversed order

	local db_path = require("time-machine.config").config.db_dir .. "/" .. utils.slugify_buf_path(buf_path)

	local header_lines = {
		"[g?] Actions/Help [<CR>] Preview [<leader>r] Restore [<leader>R] Refresh [<leader>t] Tag [q] Close",
		"",
		"DB Path: " .. db_path,
		"File: " .. buf_path,
		"",
	}

	for i = #header_lines, 1, -1 do
		table.insert(lines, 1, header_lines[i])
		table.insert(id_map, 1, "")
	end
end

--- Refresh the UI
---@param bufnr integer The buffer number
---@param buf_path string The path to the buffer
---@param id_map table<integer, string> The map of line numbers to snapshot IDs
---@param main_bufnr integer The main buffer number
---@return nil
function M.refresh(bufnr, buf_path, id_map, main_bufnr)
	if not bufnr or not api.nvim_buf_is_valid(bufnr) then
		return
	end

	local snapshots = data.get_snapshots(main_bufnr)

	local current = data.get_current_snapshot(main_bufnr)

	if not snapshots then
		vim.notify("No snapshots found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end

	if not current then
		vim.notify("No current snapshot found", vim.log.levels.ERROR)
		return
	end

	local tree = require("time-machine.tree").build_tree(snapshots)

	local lines = {}

	id_map = {}

	require("time-machine.tree").format_graph(tree, lines, id_map, current.id)

	set_header(lines, id_map, buf_path)
	api.nvim_set_option_value("modifiable", true, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", false, { scope = "local", buf = bufnr })

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	api.nvim_set_option_value("modifiable", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", true, { scope = "local", buf = bufnr })

	vim.api.nvim_buf_set_var(bufnr, constants.id_map_buf_var, id_map)

	set_highlights(bufnr, id_map, current, lines)
end

local function find_entry_by_seq(entries, seq)
	for i, entry in ipairs(entries) do
		if entry.seq == seq then
			return entry, i
		end
	end
	return nil, nil
end

-- Build a sequence map with direct parent references
local function build_seq_map(entries)
	if not entries or #entries == 0 then
		return {}
	end

	local seq_map = {}

	-- First pass: collect ALL sequences (including those in nested alts)
	local function collect_sequences(entry, index)
		if not entry.seq then
			return
		end

		-- Create entry if it doesn't exist
		if not seq_map[entry.seq] then
			seq_map[entry.seq] = {
				entry = entry,
				index = index or #entries + 1, -- Use main index or a higher number for alts
				parent_seq = nil,
				children_seq = {},
				branch_id = 0, -- Default to main branch
			}
		end

		-- Recursively process alts
		if entry.alt and type(entry.alt) == "table" then
			for _, alt in ipairs(entry.alt) do
				collect_sequences(alt)
			end
		end
	end

	-- Collect all sequences from main entries and their alts
	for i, entry in ipairs(entries) do
		collect_sequences(entry, i)
	end

	-- Sort all unique sequences
	local all_seqs = {}
	for seq in pairs(seq_map) do
		table.insert(all_seqs, seq)
	end
	table.sort(all_seqs)

	-- Connect linear sequences
	for i = 2, #all_seqs do
		local curr_seq = all_seqs[i]
		local prev_seq = all_seqs[i - 1]

		-- Connect if they're consecutive in the main branch
		if curr_seq == prev_seq + 1 and seq_map[curr_seq].branch_id == 0 and seq_map[prev_seq].branch_id == 0 then
			seq_map[curr_seq].parent_seq = prev_seq
			table.insert(seq_map[prev_seq].children_seq, curr_seq)
		end
	end

	-- Process all alt branches (including nested ones)
	local function process_alts(entry, parent_seq, branch_id)
		if not entry.alt or type(entry.alt) ~= "table" then
			return
		end

		for alt_index, alt in ipairs(entry.alt) do
			if alt.seq and seq_map[alt.seq] then
				-- Assign branch_id (incrementing for each alternative)
				local new_branch_id = branch_id or alt_index

				-- Set parent-child relationship
				seq_map[alt.seq].parent_seq = parent_seq
				seq_map[alt.seq].branch_id = new_branch_id
				table.insert(seq_map[parent_seq].children_seq, alt.seq)

				-- Process any nested alts with the same branch_id
				process_alts(alt, alt.seq, new_branch_id)
			end
		end
	end

	-- Process all entries for alt branches
	for _, entry in ipairs(entries) do
		process_alts(entry, entry.seq)
	end

	return seq_map
end

-- Assign branch IDs
local function assign_branch_ids(seq_map, entries)
	if not entries or #entries == 0 then
		return seq_map, {}
	end

	local next_branch_id = 0
	local branch_columns = {}
	local main_branch_id = 0

	-- First, assign all entries to default main branch
	for seq, info in pairs(seq_map) do
		info.branch_id = main_branch_id
	end

	-- Assign branch IDs to entries
	for i, entry in ipairs(entries) do
		-- Skip if entry doesn't have a sequence number
		if not entry.seq then
			goto continue
		end

		local seq = entry.seq
		local info = seq_map[seq]

		-- Skip if info or parent_seq doesn't exist
		if not info or not info.parent_seq then
			goto continue
		end

		local parent_info = seq_map[info.parent_seq]
		if not parent_info then
			goto continue
		end

		-- If parent has multiple children, create new branch for this child
		if #parent_info.children_seq > 1 and parent_info.children_seq[1] ~= seq then
			-- Not the first child (first child stays on parent's branch)
			next_branch_id = next_branch_id + 1
			info.branch_id = next_branch_id
		else
			-- First child or only child - inherit parent's branch ID
			info.branch_id = parent_info.branch_id
		end

		::continue::
	end

	-- Now ensure entries in alt branches have correct branch IDs
	for _, entry in ipairs(entries) do
		if not entry.seq then
			goto continue
		end

		if entry.alt and type(entry.alt) == "table" then
			for _, alt in ipairs(entry.alt) do
				-- Skip if alt entry doesn't have a sequence number
				if not alt.seq then
					goto continue_alt
				end

				-- Ensure the alt entry exists in seq_map
				if seq_map[alt.seq] then
					next_branch_id = next_branch_id + 1
					seq_map[alt.seq].branch_id = next_branch_id
				end

				::continue_alt::
			end
		end

		::continue::
	end

	-- Assign columns to branches
	for seq, info in pairs(seq_map) do
		if not branch_columns[info.branch_id] then
			branch_columns[info.branch_id] = info.branch_id
		end
	end

	return seq_map, branch_columns
end

-- Create the visual tree representation
local function build_tree_representation(undotree)
	if not undotree or not undotree.entries or #undotree.entries == 0 then
		return {}
	end

	-- Build sequence map and assign branches
	local seq_map = build_seq_map(undotree.entries)
	local seq_map, branch_columns = assign_branch_ids(seq_map, undotree.entries)

	-- Get all sequences sorted newest first
	local all_seqs = {}
	for seq in pairs(seq_map) do
		table.insert(all_seqs, seq)
	end
	table.sort(all_seqs, function(a, b)
		return a > b
	end)

	-- Determine maximum column width
	local max_column = 0
	for _, col in pairs(branch_columns) do
		max_column = math.max(max_column, col)
	end

	local tree_lines = {}
	local active_columns = {} -- Tracks columns needing vertical lines
	local node_positions = {} -- Records x position of each node

	-- First pass: establish node positions
	for _, seq in ipairs(all_seqs) do
		local info = seq_map[seq]
		node_positions[seq] = branch_columns[info.branch_id] or 0
	end

	-- Second pass: build lines
	for _, seq in ipairs(all_seqs) do
		local info = seq_map[seq]
		local entry = info.entry
		local column = node_positions[seq]
		local children = info.children_seq or {}

		-- Initialize line with spaces
		local line = {}
		for c = 0, max_column do
			line[c + 1] = "   "
		end

		-- Draw vertical connections
		for col, _ in pairs(active_columns) do
			line[col + 1] = " │ "
		end

		-- Draw node
		local node_char = "○"
		if entry.seq == undotree.seq_cur then
			node_char = "●"
		end
		if entry.save and entry.save > 0 then
			node_char = "◆"
		end
		line[column + 1] = " " .. node_char .. " "

		-- Calculate connection parameters
		local has_children = #children > 0
		local connection_start = column
		local connection_end = column

		-- Process children connections
		if has_children then
			-- Find leftmost and rightmost child columns
			local min_child_col = math.huge
			local max_child_col = -math.huge
			for _, child_seq in ipairs(children) do
				local child_col = node_positions[child_seq] or column
				min_child_col = math.min(min_child_col, child_col)
				max_child_col = math.max(max_child_col, child_col)
			end

			connection_start = math.min(column, min_child_col)
			connection_end = math.max(column, max_child_col)

			-- Draw horizontal connections
			for c = connection_start + 1, connection_end - 1 do
				line[c + 1] = (line[c + 1] == " │ " and " ┼ ") or " ─ "
			end

			-- Draw left connection
			if min_child_col < column then
				line[min_child_col + 1] = " ╰─"
			end

			-- Draw right connection
			if max_child_col > column then
				line[max_child_col + 1] = " ╭─"
			end

			-- Maintain vertical line in parent column
			active_columns[column] = true
		end

		-- Update active columns
		local new_active = {}
		for col, _ in pairs(active_columns) do
			if col ~= column or has_children then
				new_active[col] = true
			end
		end
		active_columns = new_active

		-- Add children columns to active connections
		for _, child_seq in ipairs(children) do
			local child_col = node_positions[child_seq]
			active_columns[child_col] = true
		end

		-- Add entry information
		local info_text = string.format(
			"%d %s%s%s",
			entry.seq,
			entry.time and os.date("%H:%M:%S", entry.time) or "",
			entry.seq == undotree.seq_cur and " (current)" or "",
			entry.save and entry.save > 0 and " (saved)" or ""
		)

		table.insert(tree_lines, {
			content = table.concat(line) .. info_text,
			seq = entry.seq,
			is_current = entry.seq == undotree.seq_cur,
			is_save = entry.save and entry.save > 0,
			column = column,
		})
	end

	return tree_lines
end

--- Show the Snapshot for a buffer
---@param snapshot vim.fn.undotree.ret
---@param current integer The current snapshot
---@param buf_path string The path to the buffer
---@param main_bufnr integer The main buffer number
---@return nil
function M.show(snapshot, current, buf_path, main_bufnr)
	Snacks.debug(snapshot)
	local tree_lines = build_tree_representation(snapshot)
	-- local tree = require("time-machine.tree").build_tree(snapshot)
	local lines = {}
	local id_map = {}

	local found_bufnr = utils.find_snapshot_list_buf()

	if found_bufnr then
		if api.nvim_buf_is_valid(found_bufnr) then
			vim.api.nvim_buf_delete(found_bufnr, { force = true })
		end
	end

	-- require("time-machine.tree").format_graph(tree, lines, id_map, current.id)

	for _, line in ipairs(tree_lines) do
		table.insert(lines, line.content)
	end

	set_header(lines, id_map, buf_path)

	local bufnr = api.nvim_create_buf(false, true)

	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	set_standard_buf_options(bufnr)

	-- set_highlights(bufnr, id_map, current, lines)

	api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.preview_snapshot(api.nvim_win_get_cursor(0)[1], bufnr, buf_path, main_bufnr)
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "<leader>r", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.handle_restore(api.nvim_win_get_cursor(0)[1], bufnr, buf_path, main_bufnr)
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "<leader>t", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.handle_tag(api.nvim_win_get_cursor(0)[1], bufnr, buf_path)
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "<leader>R", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.refresh(bufnr, buf_path, id_map, main_bufnr)
			vim.notify("Refreshed", vim.log.levels.INFO)
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "q", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			if api.nvim_buf_is_valid(bufnr) then
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "g?", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.show_help()
		end,
	})

	vim.api.nvim_open_win(bufnr, true, {
		split = "right",
	})

	vim.api.nvim_buf_set_var(bufnr, constants.id_map_buf_var, id_map)

	vim.api.nvim_create_autocmd("User", {
		group = utils.augroup("ui_refresh"),
		pattern = { constants.events.snapshot_created, constants.events.snapshot_set_current },
		callback = function()
			-- only refresh if that buffer is still open
			if api.nvim_buf_is_valid(bufnr) then
				M.refresh(bufnr, buf_path, id_map, main_bufnr)
			end
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		group = utils.augroup("ui_close"),
		pattern = constants.events.snapshot_deleted,
		callback = function()
			-- only close if that buffer is still open
			if api.nvim_buf_is_valid(bufnr) then
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end,
	})
end

--- Show the help text
---@return nil
function M.show_help()
	local help_lines = {
		"## Actions/Help",
		"",
		"`<CR>` **Preview** - Show the diff of the selected snapshot",
		"`<leader>r` **Restore** - Restore the selected snapshot",
		"`<leader>R` **Refresh** - Refresh the data",
		"`<leader>t` **Tag** - Tag the selected snapshot",
		"`q` **Close** - Close the window",
		"",
	}

	local bufnr = api.nvim_create_buf(false, true)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, help_lines)

	set_standard_buf_options(bufnr)
	api.nvim_set_option_value("syntax", "markdown", { scope = "local", buf = bufnr })

	api.nvim_buf_set_keymap(bufnr, "n", "q", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			if api.nvim_buf_is_valid(bufnr) then
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end,
	})

	create_native_float(bufnr, "Help")
end

--- Preview a snapshot
---@param line integer The line number
---@param bufnr integer The buffer number
---@param buf_path string The path to the buffer
---@param main_bufnr integer The main buffer number
---@return nil
function M.preview_snapshot(line, bufnr, buf_path, main_bufnr)
	local full_id = utils.get_id_from_line(bufnr, line)
	if not full_id then
		return
	end

	local snapshots = storage.get_snapshots(buf_path)
	if not snapshots then
		vim.notify("No snapshots found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end

	local content = {}

	local root_branch_id = require("time-machine.utils").root_branch_id(buf_path)

	if full_id == root_branch_id then
		local root = storage.get_root_snapshot(buf_path)

		if not root then
			vim.notify("No root snapshot found", vim.log.levels.ERROR)
			return
		end

		content = vim.split(root.content, "\n")
	else
		local current_snapshot = storage.get_snapshot_by_id(full_id, buf_path)

		if not current_snapshot then
			vim.notify("No current snapshot found", vim.log.levels.ERROR)
			return
		end

		if current_snapshot.diff then
			local diff_lines = vim.split(current_snapshot.diff, "\n")
			for j = #diff_lines, 1, -1 do
				table.insert(content, 1, diff_lines[j])
			end
		end
	end

	local preview_buf = api.nvim_create_buf(false, true)

	api.nvim_buf_set_lines(preview_buf, 0, -1, false, content)

	set_standard_buf_options(preview_buf)

	if full_id == root_branch_id then
		local filetype = api.nvim_get_option_value("filetype", { scope = "local", buf = main_bufnr }) or "nofile"
		api.nvim_set_option_value("syntax", filetype, { scope = "local", buf = preview_buf })
	else
		api.nvim_set_option_value("syntax", "diff", { scope = "local", buf = preview_buf })
	end

	api.nvim_buf_set_keymap(preview_buf, "n", "q", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			if api.nvim_buf_is_valid(preview_buf) then
				vim.api.nvim_buf_delete(preview_buf, { force = true })
			end
		end,
	})

	create_native_float(preview_buf, "Preview")
end

--- Handle the restore action
---@param line integer The line number
---@param bufnr integer The buffer number
---@param buf_path string The path to the buffer
---@param main_bufnr integer The main buffer number
---@return nil
function M.handle_restore(line, bufnr, buf_path, main_bufnr)
	local full_id = utils.get_id_from_line(bufnr, line)
	if not full_id or full_id == "" then
		return
	end

	local seq = tonumber(full_id)
	if not seq then
		vim.notify(("Invalid snapshot id: %q"):format(full_id), vim.log.levels.ERROR)
		return
	end

	require("time-machine.actions").restore_snapshot(seq, buf_path, main_bufnr)
end

--- Handle the restore action
---@param line integer The line number
---@param bufnr integer The buffer number
---@param buf_path string The path to the buffer
---@return nil
function M.handle_tag(line, bufnr, buf_path)
	local full_id = utils.get_id_from_line(bufnr, line)
	if not full_id or full_id == "" then
		return
	end

	local snapshot = storage.get_snapshot_by_id(full_id, buf_path)

	if not snapshot then
		vim.notify("No snapshot found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end

	require("time-machine.actions").tag_snapshot(nil, snapshot, buf_path)
end

return M
