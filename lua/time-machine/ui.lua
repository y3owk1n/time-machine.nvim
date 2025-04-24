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
---@param current integer The current snapshot id
---@param lines table<integer, string> The lines of the snapshot
---@return nil
local function set_highlights(bufnr, id_map, current, lines)
	api.nvim_buf_clear_namespace(bufnr, constants.ns, 0, -1)

	for i, id in ipairs(id_map) do
		if id == current then
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

-- Build a sequence map with direct parent references
---@param entries vim.fn.undotree.entry[]
---@return table<integer, TimeMachine.SeqMap>
local function build_seq_map(entries)
	local seq_map = {}
	local function walk(entry, parent_seq)
		seq_map[entry.seq] = seq_map[entry.seq]
			or {
				entry = entry,
				parent_seq = parent_seq,
				children_seq = {},
				branch_id = nil,
			}
		if parent_seq then
			table.insert(seq_map[parent_seq].children_seq, entry.seq)
		end
		if entry.alt then
			for _, child in ipairs(entry.alt) do
				walk(child, entry.seq)
			end
		end
	end

	for _, entry in ipairs(entries) do
		walk(entry, nil)
	end

	return seq_map
end

-- Create the visual tree representation
---@param undotree vim.fn.undotree.ret
local function build_tree_representation(undotree, id_map)
	if not undotree or not undotree.entries or #undotree.entries == 0 then
		return {}
	end

	local seq_map = build_seq_map(undotree.entries)

	Snacks.debug(undotree.entries)
	Snacks.debug(seq_map)

	-- 2) BFS for branch assignment (O(N) queue + cycle guard)
	---@type {seq: integer, branch_id: integer}[]
	local queue = {}
	local head = 1
	local tail = 0
	---@type table<integer, boolean>
	local visited = {}
	local next_column = 0
	local main_branch_id = 0

	-- Enqueue roots (pre_seq == 0)
	for seq, info in pairs(seq_map) do
		if not info.parent_seq then
			tail = tail + 1
			queue[tail] = { seq = seq, branch_id = main_branch_id }
			info.branch_id = main_branch_id
		end
	end

	while head <= tail do
		local cur = queue[head]
		head = head + 1
		if not visited[cur.seq] then
			visited[cur.seq] = true
			local info = seq_map[cur.seq]
			for i, child_seq in ipairs(info.children_seq) do
				local child = seq_map[child_seq]
				if child then
					if i == 1 then
						child.branch_id = info.branch_id
					else
						next_column = next_column + 1
						child.branch_id = next_column
					end
					tail = tail + 1
					queue[tail] = { seq = child_seq, branch_id = child.branch_id }
				end
			end
		end
	end

	-- 3. Render tree with proper connections
	---@type integer[]
	local all_seqs = {}
	for seq in pairs(seq_map) do
		table.insert(all_seqs, seq)
	end

	table.sort(all_seqs, function(a, b)
		return a > b
	end) -- Newest first

	local max_column = next_column
	local tree_lines = {}
	local verticals = {} -- Track active vertical lines per column

	for _, seq in ipairs(all_seqs) do
		local info = seq_map[seq]
		local entry = info.entry
		local col = info.branch_id or 0

		local line = {}
		for c = 0, max_column do
			line[c + 1] = verticals[c] and "│ " or "  "
		end

		-- Draw connection from parent if necessary
		if info.parent_seq and seq_map[info.parent_seq] then
			local parent_info = seq_map[info.parent_seq]
			local parent_col = parent_info.branch_id or 0

			if parent_col ~= col then
				local start_col = math.min(parent_col, col)
				local end_col = math.max(parent_col, col)

				for c = start_col + 1, end_col - 1 do
					line[c + 1] = "──"
				end

				line[parent_col + 1] = "╭─"
				line[col + 1] = "╰─"
			end
		end

		-- Draw node symbol
		line[col + 1] = (entry.seq == undotree.seq_cur and "● ")
			or (entry.save and entry.save > 0 and "◆ ")
			or "○ "

		verticals[col] = #info.children_seq > 0

		-- Add info text
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
			column = col,
		})
		id_map[#tree_lines] = seq
	end

	return tree_lines
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

	if not snapshots then
		vim.notify("No snapshots found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end

	local lines = {}

	id_map = {}

	local tree_lines = build_tree_representation(snapshots, id_map)

	for _, line in ipairs(tree_lines) do
		table.insert(lines, line.content)
	end

	set_header(lines, id_map, buf_path)
	api.nvim_set_option_value("modifiable", true, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", false, { scope = "local", buf = bufnr })

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	api.nvim_set_option_value("modifiable", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", true, { scope = "local", buf = bufnr })

	vim.api.nvim_buf_set_var(bufnr, constants.id_map_buf_var, id_map)

	set_highlights(bufnr, id_map, snapshots.seq_cur, lines)
end

--- Show the Snapshot for a buffer
---@param snapshot vim.fn.undotree.ret
---@param current integer The current snapshot
---@param buf_path string The path to the buffer
---@param main_bufnr integer The main buffer number
---@return nil
function M.show(snapshot, current, buf_path, main_bufnr)
	local id_map = {}
	local tree_lines = build_tree_representation(snapshot, id_map)
	-- local tree = require("time-machine.tree").build_tree(snapshot)
	local lines = {}

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

	set_highlights(bufnr, id_map, current, lines)

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

return M
