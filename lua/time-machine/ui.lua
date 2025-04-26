local utils = require("time-machine.utils")
local constants = require("time-machine.constants").constants
local undotree = require("time-machine.undotree")
local diff = require("time-machine.diff")
local tree = require("time-machine.tree")
local window = require("time-machine.window")

local M = {}

local main_timeline_annotation = "╭─ Main timeline"

--- Set standard buffer options
---@param bufnr integer The buffer number
---@return nil
function M.set_standard_buf_options(bufnr)
	vim.api.nvim_set_option_value(
		"filetype",
		constants.time_machine_ft,
		{ scope = "local", buf = bufnr }
	)
	vim.api.nvim_set_option_value(
		"buftype",
		"nofile",
		{ scope = "local", buf = bufnr }
	)
	vim.api.nvim_set_option_value(
		"bufhidden",
		"wipe",
		{ scope = "local", buf = bufnr }
	)
	vim.api.nvim_set_option_value(
		"swapfile",
		false,
		{ scope = "local", buf = bufnr }
	)
	vim.api.nvim_set_option_value(
		"modifiable",
		false,
		{ scope = "local", buf = bufnr }
	)
	vim.api.nvim_set_option_value(
		"readonly",
		true,
		{ scope = "local", buf = bufnr }
	)
	vim.api.nvim_set_option_value(
		"buflisted",
		false,
		{ scope = "local", buf = bufnr }
	)
end

--- Set highlights for the UI
---@param bufnr integer The buffer number
---@param seq_map TimeMachine.SeqMap The map of line numbers to seqs
---@param curr_seq integer The current seq
---@param lines string[] The lines of the content
---@return nil
local function set_highlights(bufnr, seq_map, curr_seq, lines)
	vim.api.nvim_buf_clear_namespace(bufnr, constants.ns, 0, -1)

	for i, id in ipairs(seq_map) do
		--- is not sequence
		if id == "" then
			--- get the keymaps e.g. [g?]
			local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
			for keymap in line:gmatch("%b[]") do
				local start_col = line:find(keymap, 1, true) - 1
				vim.api.nvim_buf_set_extmark(
					bufnr,
					constants.ns,
					i - 1,
					start_col,
					{
						end_col = start_col + #keymap,
						hl_group = constants.hl.keymap,
					}
				)
			end

			--- get the main timeline annotation
			if line:find(main_timeline_annotation) then
				local start_col = line:find(main_timeline_annotation, 1, true)
					- 1
				vim.api.nvim_buf_set_extmark(
					bufnr,
					constants.ns,
					i - 1,
					start_col,
					{
						end_col = start_col + #main_timeline_annotation,
						hl_group = constants.hl.timeline,
					}
				)
			end
		end

		--- is within sequence
		if type(id) == "number" then
			local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
			--- get the first character (main timeline)
			local first_char = line:sub(1, 1)
			if first_char and first_char ~= "" then
				local start_col = line:find(first_char, 1, true) - 1
				vim.api.nvim_buf_set_extmark(
					bufnr,
					constants.ns,
					i - 1,
					start_col,
					{
						end_col = start_col + #first_char,
						hl_group = constants.hl.timeline,
					}
				)
			end

			--- match the sequence number
			for seq in line:gmatch("%b[]") do
				local start_col = line:find(seq, 1, true) - 1
				vim.api.nvim_buf_set_extmark(
					bufnr,
					constants.ns,
					i - 1,
					start_col,
					{
						end_col = start_col + #seq,
						hl_group = constants.hl.seq,
					}
				)
			end

			--- match time and the rest behind time (which is tags)
			local time, rest = line:match("(%d+%a+ ago)%s*(.*)$")
			if time then
				local start_col = line:find(time, 1, true) - 1
				vim.api.nvim_buf_set_extmark(
					bufnr,
					constants.ns,
					i - 1,
					start_col,
					{
						end_col = start_col + #time,
						hl_group = constants.hl.info,
					}
				)
			end

			if rest and rest ~= "" then
				local start_col = line:find(rest, 1, true) - 1
				vim.api.nvim_buf_set_extmark(
					bufnr,
					constants.ns,
					i - 1,
					start_col,
					{
						end_col = start_col + #rest,
						hl_group = constants.hl.tag,
					}
				)
			end
		end

		--- is the current sequence
		if id == curr_seq then
			local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
			local end_col = line and #line or 0

			local text_width = vim.fn.strdisplaywidth(line)
			local win_width = vim.api.nvim_win_get_width(0)

			local pad = win_width - text_width

			vim.api.nvim_buf_set_extmark(bufnr, constants.ns, i - 1, 0, {
				end_col = end_col,
				hl_group = constants.hl.current,
				virt_text = { { string.rep(" ", pad), constants.hl.current } },
				virt_text_win_col = text_width,
			})
		end
	end

	for i, line in ipairs(lines) do
		local info_matches =
			{ "Persistent:", "Buffer:", "Undo File:", "Tag File:" }

		--- get the info area
		for _, info_match in ipairs(info_matches) do
			if line:find(info_match) then
				local current_line =
					vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
				local end_col = current_line and #current_line or 0

				vim.api.nvim_buf_set_extmark(bufnr, constants.ns, i - 1, 0, {
					end_col = end_col,
					hl_group = constants.hl.info,
				})
			end
		end
	end
end

--- Set header for the UI
---@param lines string[] The lines of the content
---@param seq_map TimeMachine.SeqMap The map of line numbers to seqs
---@param content_bufnr integer The content buffer number
---@return nil
local function set_header(lines, seq_map, content_bufnr)
	local undofile_path = undotree.get_undofile_path(content_bufnr)

	local persistent = vim.api.nvim_get_option_value(
		"undofile",
		{ scope = "local", buf = content_bufnr }
	)

	local saved_text = constants.icons.saved .. "= Saved"
	local point_text = constants.icons.point .. "= Point"

	local annotation = saved_text .. " " .. point_text

	---@type string[]
	local header_lines = {
		"[<CR>] Restore [g?] More Actions/Help",
		"",
		"Persistent: " .. tostring(persistent),
		"Buffer: " .. content_bufnr,
		"",
		annotation,
		"",
	}

	if persistent then
		table.insert(
			header_lines,
			#header_lines - 2,
			"Undo File: " .. undofile_path
		)
	end

	local tags_path = require("time-machine.tags").get_tags_path(content_bufnr)

	if tags_path then
		table.insert(header_lines, #header_lines - 2, "Tag File: " .. tags_path)
	end

	table.insert(header_lines, main_timeline_annotation)

	for i = #header_lines, 1, -1 do
		table.insert(lines, 1, header_lines[i])
		table.insert(seq_map, 1, "")
	end
end

--- Refresh the UI
---@param time_machine_bufnr integer The buffer number
---@param seq_map TimeMachine.SeqMap The map of line numbers to seqs
---@param content_bufnr integer The main buffer number
---@return nil
function M.refresh(time_machine_bufnr, seq_map, content_bufnr)
	if
		not time_machine_bufnr
		or not vim.api.nvim_buf_is_valid(time_machine_bufnr)
	then
		return
	end

	local ut = undotree.get_undotree(content_bufnr)

	if not ut then
		vim.notify("No undotree found", vim.log.levels.WARN)
		return
	end

	local tags = require("time-machine.tags").load_tags(content_bufnr)

	local lines = {}

	seq_map = {}

	local tree_lines = tree.build_tree_lines(ut, seq_map, tags)

	for _, line in ipairs(tree_lines) do
		table.insert(lines, line.content)
	end

	set_header(lines, seq_map, content_bufnr)

	vim.api.nvim_set_option_value(
		"modifiable",
		true,
		{ scope = "local", buf = time_machine_bufnr }
	)
	vim.api.nvim_set_option_value(
		"readonly",
		false,
		{ scope = "local", buf = time_machine_bufnr }
	)

	vim.api.nvim_buf_set_lines(time_machine_bufnr, 0, -1, false, lines)

	vim.api.nvim_set_option_value(
		"modifiable",
		false,
		{ scope = "local", buf = time_machine_bufnr }
	)
	vim.api.nvim_set_option_value(
		"readonly",
		true,
		{ scope = "local", buf = time_machine_bufnr }
	)

	vim.api.nvim_buf_set_var(
		time_machine_bufnr,
		constants.seq_map_buf_var,
		seq_map
	)

	set_highlights(time_machine_bufnr, seq_map, ut.seq_cur, lines)
end

--- Show the undo history for a buffer
---@param ut vim.fn.undotree.ret
---@param content_bufnr integer The main buffer number
---@return nil
function M.show_tree(ut, content_bufnr)
	local orig_win_id = vim.api.nvim_get_current_win()

	local tags = require("time-machine.tags").load_tags(content_bufnr)

	local seq_map = {}
	local tree_lines = tree.build_tree_lines(ut, seq_map, tags)
	local lines = {}

	for _, line in ipairs(tree_lines) do
		table.insert(lines, line.content)
	end

	set_header(lines, seq_map, content_bufnr)

	local time_machine_bufnr = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_buf_set_lines(time_machine_bufnr, 0, -1, false, lines)

	M.set_standard_buf_options(time_machine_bufnr)

	set_highlights(time_machine_bufnr, seq_map, ut.seq_cur, lines)

	vim.api.nvim_buf_set_keymap(time_machine_bufnr, "n", "p", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			local cursor_pos = vim.api.nvim_win_get_cursor(0)[1]
			M.preview_diff(
				cursor_pos,
				time_machine_bufnr,
				content_bufnr,
				orig_win_id
			)
		end,
	})

	vim.api.nvim_buf_set_keymap(time_machine_bufnr, "n", "<CR>", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			local cursor_pos = vim.api.nvim_win_get_cursor(0)[1]
			M.handle_restore(cursor_pos, time_machine_bufnr, content_bufnr)
		end,
	})

	vim.api.nvim_buf_set_keymap(time_machine_bufnr, "n", "r", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.refresh(time_machine_bufnr, seq_map, content_bufnr)
			vim.notify("Refreshed", vim.log.levels.INFO)
		end,
	})

	vim.api.nvim_buf_set_keymap(time_machine_bufnr, "n", "t", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			local cursor_pos = vim.api.nvim_win_get_cursor(0)[1]

			require("time-machine.tags").create_tag(
				cursor_pos,
				time_machine_bufnr,
				content_bufnr,
				function()
					M.refresh(time_machine_bufnr, seq_map, content_bufnr)
				end
			)
		end,
	})

	vim.api.nvim_buf_set_keymap(time_machine_bufnr, "n", "q", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			utils.close_buf(time_machine_bufnr)
		end,
	})

	vim.api.nvim_buf_set_keymap(time_machine_bufnr, "n", "g?", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.show_help()
		end,
	})

	local time_machine_win_id =
		window.create_native_split_win(time_machine_bufnr)

	if time_machine_win_id then
		--- Set the cursor to the current sequence
		for i, id in ipairs(seq_map) do
			if id == ut.seq_cur then
				vim.api.nvim_win_set_cursor(time_machine_win_id, { i, 0 })
				break
			end
		end
	end

	vim.api.nvim_buf_set_var(
		time_machine_bufnr,
		constants.seq_map_buf_var,
		seq_map
	)
	vim.api.nvim_buf_set_var(
		time_machine_bufnr,
		constants.content_buf_var,
		content_bufnr
	)

	vim.api.nvim_create_autocmd("User", {
		group = utils.augroup("ui_refresh"),
		pattern = {
			constants.events.undo_created,
			constants.events.undo_restored,
		},
		callback = function()
			-- only refresh if that buffer is still open
			if vim.api.nvim_buf_is_valid(time_machine_bufnr) then
				M.refresh(time_machine_bufnr, seq_map, content_bufnr)
			end
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		group = utils.augroup("ui_close"),
		pattern = constants.events.undofile_deleted,
		callback = function()
			utils.close_buf(time_machine_bufnr)
		end,
	})
end

--- Show the help text
---@return nil
function M.show_help()
	local help_lines = {
		"## Actions/Help",
		"",
		"`<CR>` **Restore** - Restore to the selected sequence",
		"`r` **Refresh** - Refresh the data",
		"`p` **Preview** - Show the diff of the selected sequence",
		"`t` **Tag** - Tag the selected sequence",
		"`q` **Close** - Close the window",
		"",
	}

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, help_lines)

	M.set_standard_buf_options(bufnr)
	vim.api.nvim_set_option_value(
		"syntax",
		"markdown",
		{ scope = "local", buf = bufnr }
	)

	vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			utils.close_buf(bufnr)
		end,
	})

	window.create_native_float_win(bufnr, "Help")
end

--- Preview the diff of a sequence
---@param line_num integer The line number
---@param time_machine_bufnr integer The buffer number
---@param content_bufnr integer The main buffer number
---@param orig_win_id integer The original window
---@return nil
function M.preview_diff(
	line_num,
	time_machine_bufnr,
	content_bufnr,
	orig_win_id
)
	local full_id = utils.get_seq_from_line(time_machine_bufnr, line_num)
	if not full_id or full_id == "" then
		return
	end

	local old_lines =
		diff.read_buffer_at_seq(content_bufnr, orig_win_id, full_id)
	local new_lines = vim.api.nvim_buf_get_lines(content_bufnr, 0, -1, false)

	local config = require("time-machine.config").config

	if config.diff_tool == "native" then
		diff.preview_diff_native(old_lines, new_lines)
	else
		diff.preview_diff_external(config.diff_tool, old_lines, new_lines)
	end
end

--- Handle the restore action
---@param line_num integer The line number
---@param time_machine_bufnr integer The buffer number
---@param content_bufnr integer The main buffer number
---@return nil
function M.handle_restore(line_num, time_machine_bufnr, content_bufnr)
	local full_id = utils.get_seq_from_line(time_machine_bufnr, line_num)
	if not full_id or full_id == "" then
		return
	end

	local seq = tonumber(full_id)
	if not seq then
		vim.notify(
			("Invalid sequence id: %q"):format(full_id),
			vim.log.levels.ERROR
		)
		return
	end

	require("time-machine.actions").restore(seq, content_bufnr)
end

return M
