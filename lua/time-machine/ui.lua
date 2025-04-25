local api = vim.api
local utils = require("time-machine.utils")
local constants = require("time-machine.constants").constants
local undotree = require("time-machine.undotree")
local diff = require("time-machine.diff")

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
---@return integer|nil The window handle
function M.create_native_float(buf, title)
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

	local win = vim.api.nvim_open_win(buf, true, win_opts)

	return win
end

--- Set standard buffer options
---@param bufnr integer The buffer number
---@return nil
function M.set_standard_buf_options(bufnr)
	api.nvim_set_option_value("filetype", constants.time_machine_ft, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("buftype", "nofile", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("bufhidden", "wipe", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("swapfile", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("modifiable", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", true, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("buflisted", false, { scope = "local", buf = bufnr })
end

--- Set highlights for the UI
---@param bufnr integer The buffer number
---@param seq_map table<integer, integer> The map of line numbers to seqs
---@param current_seq integer The current seq
---@param lines table<integer, string> The lines of the content
---@return nil
local function set_highlights(bufnr, seq_map, current_seq, lines)
	api.nvim_buf_clear_namespace(bufnr, constants.ns, 0, -1)

	for i, id in ipairs(seq_map) do
		if id == current_seq then
			local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
			local end_col = line and #line or 0

			local text_width = vim.fn.strdisplaywidth(line)
			local win_width = vim.api.nvim_win_get_width(0)

			local pad = win_width - text_width

			api.nvim_buf_set_extmark(bufnr, constants.ns, i - 1, 0, {
				end_col = end_col,
				hl_group = constants.hl.current,
				virt_text = { { string.rep(" ", pad), constants.hl.current } },
				virt_text_win_col = text_width,
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

		local info_matches = { "Persistent:", "Buffer:", "Undo File:", "Tag File:" }

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
---@param lines table<integer, string> The lines of the content
---@param seq_map table<integer, integer> The map of line numbers to seqs
---@param bufnr integer The buffer number
---@return nil
local function set_header(lines, seq_map, bufnr)
	local undofile = undotree.get_undofile(bufnr)

	local persistent = vim.api.nvim_get_option_value("undofile", { scope = "local", buf = bufnr })

	local saved_text = constants.icons.saved .. "= Saved"
	local point_text = constants.icons.point .. "= Point"

	local annotation = saved_text .. " " .. point_text

	local header_lines = {
		"[g?] Actions/Help [<CR>] Restore [r] Refresh [p] Preview [t] Tag [q] Close",
		"",
		"Persistent: " .. tostring(persistent),
		"Buffer: " .. bufnr,
		"",
		annotation,
		"",
	}

	if persistent then
		table.insert(header_lines, #header_lines - 2, "Undo File: " .. undofile)
	end

	local tags_path = require("time-machine.tags").get_tags_path(bufnr)

	if tags_path then
		table.insert(header_lines, #header_lines - 2, "Tag File: " .. tags_path)
	end

	for i = #header_lines, 1, -1 do
		table.insert(lines, 1, header_lines[i])
		table.insert(seq_map, 1, "")
	end
end

-- Build a sequence map with direct parent references
---@param entries vim.fn.undotree.entry[]
---@param tags table<string, string[]> The tags for this buffer’s undo history
---@return table<integer, TimeMachine.SeqMapRaw>
local function build_seq_map_raw(entries, tags)
	local seq_map_raw = {}
	local function walk(entry, branch_idx)
		seq_map_raw[entry.seq] = seq_map_raw[entry.seq]
			or {
				entry = entry,
				branch_id = branch_idx,
				tags = tags[tostring(entry.seq)] or {},
			}
		if entry.alt then
			for _, child in ipairs(entry.alt) do
				walk(child, (branch_idx or 0) + 1)
			end
		end
	end

	for _, entry in ipairs(entries) do
		walk(entry, 0)
	end

	table.insert(seq_map_raw, 1, { branch_id = 0, entry = { seq = 0 } })

	return seq_map_raw
end

-- Create the visual tree representation
---@param ut vim.fn.undotree.ret
---@param seq_map table<integer, integer> The map of line numbers to seqs
---@param tags table<string, string[]> The tags for this buffer’s undo history
---@return TimeMachine.TreeLine[] tree_lines The tree lines
local function build_tree_representation(ut, seq_map, tags)
	if not ut or not ut.entries or #ut.entries == 0 then
		return {}
	end

	local seq_map_raw = build_seq_map_raw(ut.entries, tags)

	-- 3. Render tree with proper connections
	---@type integer[]
	local all_seqs = {}
	for seq in pairs(seq_map_raw) do
		table.insert(all_seqs, seq)
	end

	table.sort(all_seqs, function(a, b)
		return a > b
	end) -- Newest first

	local function get_max_column()
		local max_branch_id = 0
		for _, seq in ipairs(seq_map_raw) do
			if seq.branch_id and seq.branch_id > max_branch_id then
				max_branch_id = seq.branch_id
			end
		end

		return max_branch_id
	end

	local max_column = get_max_column()
	local tree_lines = {}
	local verticals = {} -- Track active vertical lines per column

	for _, seq in ipairs(all_seqs) do
		local info = seq_map_raw[seq]
		local entry = info.entry
		local col = info.branch_id or 0

		local line = {}
		for c = 0, max_column do
			line[c + 1] = verticals[c] and "│ " or "  "
		end

		-- Draw node symbol
		line[col + 1] = (entry.save and entry.save > 0 and constants.icons.saved) or constants.icons.point

		verticals[col] = true

		-- Add info text
		local info_text = string.format(
			"%s %s %s",
			(entry.seq == 0 and "[root]") or ("[" .. tostring(entry.seq) .. "]"),
			entry.time and utils.relative_time(entry.time) or "",
			info.tags and #info.tags > 0 and (constants.icons.tag .. table.concat(info.tags, ", ") .. " ") or ""
			-- entry.seq == ut.seq_cur and " (current)" or "",
			-- entry.save and entry.save > 0 and " (saved)" or ""
		)

		table.insert(tree_lines, {
			content = table.concat(line) .. info_text,
			seq = entry.seq,
			column = col,
		})
		seq_map[#tree_lines] = seq - 1
	end

	return tree_lines
end

--- Refresh the UI
---@param bufnr integer The buffer number
---@param seq_map table<integer, integer> The map of line numbers to seqs
---@param main_bufnr integer The main buffer number
---@return nil
function M.refresh(bufnr, seq_map, main_bufnr)
	if not bufnr or not api.nvim_buf_is_valid(bufnr) then
		return
	end

	local ut = undotree.get_undotree(main_bufnr)

	if not ut then
		vim.notify("No undotree found", vim.log.levels.WARN)
		return
	end

	local tags = require("time-machine.tags").load_tags(main_bufnr)

	local lines = {}

	seq_map = {}

	local tree_lines = build_tree_representation(ut, seq_map, tags)

	for _, line in ipairs(tree_lines) do
		table.insert(lines, line.content)
	end

	set_header(lines, seq_map, main_bufnr)
	api.nvim_set_option_value("modifiable", true, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", false, { scope = "local", buf = bufnr })

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	api.nvim_set_option_value("modifiable", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", true, { scope = "local", buf = bufnr })

	vim.api.nvim_buf_set_var(bufnr, constants.seq_map_buf_var, seq_map)

	set_highlights(bufnr, seq_map, ut.seq_cur, lines)
end

--- Show the undo history for a buffer
---@param ut vim.fn.undotree.ret
---@param main_bufnr integer The main buffer number
---@return nil
function M.show(ut, main_bufnr)
	local orig_win = vim.api.nvim_get_current_win()

	local tags = require("time-machine.tags").load_tags(main_bufnr)

	local seq_map = {}
	local tree_lines = build_tree_representation(ut, seq_map, tags)
	local lines = {}

	local found_bufnr = utils.find_time_machine_list_buf()

	if found_bufnr then
		if api.nvim_buf_is_valid(found_bufnr) then
			vim.api.nvim_buf_delete(found_bufnr, { force = true })
		end
	end

	for _, line in ipairs(tree_lines) do
		table.insert(lines, line.content)
	end

	set_header(lines, seq_map, main_bufnr)

	local bufnr = api.nvim_create_buf(false, true)

	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	M.set_standard_buf_options(bufnr)

	set_highlights(bufnr, seq_map, ut.seq_cur, lines)

	api.nvim_buf_set_keymap(bufnr, "n", "p", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.preview_diff(api.nvim_win_get_cursor(0)[1], bufnr, main_bufnr, orig_win)
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.handle_restore(api.nvim_win_get_cursor(0)[1], bufnr, main_bufnr)
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "r", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.refresh(bufnr, seq_map, main_bufnr)
			vim.notify("Refreshed", vim.log.levels.INFO)
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "t", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			require("time-machine.tags").tag_sequence(api.nvim_win_get_cursor(0)[1], bufnr, main_bufnr, function()
				M.refresh(bufnr, seq_map, main_bufnr)
			end)
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

	vim.api.nvim_buf_set_var(bufnr, constants.seq_map_buf_var, seq_map)

	vim.api.nvim_create_autocmd("User", {
		group = utils.augroup("ui_refresh"),
		pattern = { constants.events.undo_created, constants.events.undo_restored },
		callback = function()
			-- only refresh if that buffer is still open
			if api.nvim_buf_is_valid(bufnr) then
				M.refresh(bufnr, seq_map, main_bufnr)
			end
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		group = utils.augroup("ui_close"),
		pattern = constants.events.undofile_deleted,
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
		"`p` **Preview** - Show the diff of the selected sequence",
		"`<CR>` **Restore** - Restore to the selected sequence",
		"`r` **Refresh** - Refresh the data",
		"`q` **Close** - Close the window",
		"",
	}

	local bufnr = api.nvim_create_buf(false, true)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, help_lines)

	M.set_standard_buf_options(bufnr)
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

	M.create_native_float(bufnr, "Help")
end

--- Preview the diff of a sequence
---@param line integer The line number
---@param bufnr integer The buffer number
---@param main_bufnr integer The main buffer number
---@param orig_win integer The original window
---@return nil
function M.preview_diff(line, bufnr, main_bufnr, orig_win)
	local full_id = utils.get_seq_from_line(bufnr, line)
	if not full_id or full_id == "" then
		return
	end

	local old = diff.read_buffer_at_seq(main_bufnr, orig_win, full_id)
	local new = vim.api.nvim_buf_get_lines(main_bufnr, 0, -1, false)

	local config = require("time-machine.config").config

	if config.diff_tool == "native" then
		diff.diff_with_native(old, new)
	end

	if config.diff_tool == "difft" then
		diff.diff_with_difftastic(old, new)
	end
end

--- Handle the restore action
---@param line integer The line number
---@param bufnr integer The buffer number
---@param main_bufnr integer The main buffer number
---@return nil
function M.handle_restore(line, bufnr, main_bufnr)
	local full_id = utils.get_seq_from_line(bufnr, line)
	if not full_id or full_id == "" then
		return
	end

	local seq = tonumber(full_id)
	if not seq then
		vim.notify(("Invalid sequence id: %q"):format(full_id), vim.log.levels.ERROR)
		return
	end

	require("time-machine.actions").restore_undopoint(seq, main_bufnr)
end

return M
