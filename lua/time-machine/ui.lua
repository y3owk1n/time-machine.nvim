local utils = require("time-machine.utils")
local constants = require("time-machine.constants").constants
local undotree = require("time-machine.undotree")
local diff = require("time-machine.diff")
local tree = require("time-machine.tree")
local window = require("time-machine.window")
local logger = require("time-machine.logger")

local M = {}

local current_timeline_annotation = string.format(
	" %s%s Current timeline",
	constants.icons.line_corner_t_left,
	constants.icons.line_horizontal
)
local is_current_timeline_toggled = false
local ns = constants.ns
local hl = constants.hl
local info_matches = {
	"Timeline View",
	"Persistent:",
	"Content Buffer:",
	"Undo File:",
	"Tag File:",
}
local str_find = string.find
local str_gmatch = string.gmatch

--- Set standard buffer options
---@param bufnr integer The buffer number
---@return nil
function M.set_standard_buf_options(bufnr)
	logger.debug("set_standard_buf_options(%d)", bufnr)

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

	logger.info("Standard buffer options set on %d", bufnr)
end

--- Set highlights for the UI
---@param bufnr integer The buffer number
---@param seq_map TimeMachine.SeqMap The map of line numbers to seqs
---@param curr_seq integer The current seq
---@param lines string[] The lines of the content
---@return nil
local function set_highlights(bufnr, seq_map, curr_seq, lines)
	logger.debug(
		"set_highlights(buf=%d, curr_seq=%s, %d lines)",
		bufnr,
		tostring(curr_seq),
		#lines
	)

	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for i, id in ipairs(seq_map) do
		local row = i - 1
		local line = buf_lines[i]

		--- is not sequence
		if id == "" then
			--- get the keymaps e.g. [g?]
			for keymap in str_gmatch(line, "%b[]") do
				local start_col = str_find(line, keymap, 1, true) - 1
				vim.api.nvim_buf_set_extmark(bufnr, ns, row, start_col, {
					end_col = start_col + #keymap,
					hl_group = hl.keymap,
				})
			end

			--- get the current timeline annotation
			local ann_col = str_find(line, current_timeline_annotation, 1, true)
			if ann_col then
				local start_col = ann_col - 1
				vim.api.nvim_buf_set_extmark(bufnr, ns, row, start_col, {
					end_col = start_col + #current_timeline_annotation,
					hl_group = hl.timeline,
				})
			end
		end

		--- is within sequence
		if type(id) == "number" then
			--- get the first character (current timeline)
			local first_char = line:sub(1 * 2, 1 * 2)
			if first_char and first_char ~= "" then
				local start_col = str_find(line, first_char, 1, true) - 1
				vim.api.nvim_buf_set_extmark(bufnr, ns, row, start_col, {
					end_col = start_col + #first_char,
					hl_group = hl.timeline,
				})
			end

			--- get after first character until the first bracket (alt timeline)
			local first_bracket_start = line:find("%[", 1, false)
			if first_bracket_start and #line > 1 then
				local between_start = 2 * 2 -- after the first character
				local between_end = first_bracket_start - 1
				local between_str = line:sub(between_start, between_end)

				local trimmed = between_str:match("^%s*(.-)%s*$")
				local leading_spaces = #between_str:match("^(%s*)")

				local start_col = between_start - 1 + leading_spaces
				local end_col = start_col + #trimmed

				if #trimmed > 0 then
					vim.api.nvim_buf_set_extmark(bufnr, ns, row, start_col, {
						end_col = end_col,
						hl_group = hl.timeline_alt,
					})
				end
			end

			--- match the sequence number
			for seq in str_gmatch(line, "%b[]") do
				local start_col = str_find(line, seq, 1, true) - 1
				vim.api.nvim_buf_set_extmark(bufnr, ns, row, start_col, {
					end_col = start_col + #seq,
					hl_group = hl.seq,
				})
			end

			--- match time and the rest behind time (which is tags)
			local time, rest = line:match("(%d+%a+ ago)%s*(.*)$")
			if time then
				local start_col = str_find(line, time, 1, true) - 1
				vim.api.nvim_buf_set_extmark(bufnr, ns, row, start_col, {
					end_col = start_col + #time,
					hl_group = hl.info,
				})
			end

			if rest and rest ~= "" then
				local start_col = str_find(line, rest, 1, true) - 1
				vim.api.nvim_buf_set_extmark(bufnr, ns, row, start_col, {
					end_col = start_col + #rest,
					hl_group = hl.tag,
				})
			end
		end

		--- is the current sequence
		if id == curr_seq then
			local end_col = line and #line or 0

			local text_width = vim.fn.strdisplaywidth(line)
			local win_width = vim.api.nvim_win_get_width(0)

			local pad = win_width - text_width

			vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
				end_col = end_col,
				hl_group = hl.current,
				virt_text = { { string.rep(" ", pad), hl.current } },
				virt_text_win_col = text_width,
			})
		end
	end

	for i, line in ipairs(lines) do
		--- get the info area
		for _, info_match in ipairs(info_matches) do
			if str_find(line, info_match, 1, true) then
				local end_col = line and #line or 0

				vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
					end_col = end_col,
					hl_group = hl.info,
				})
			end
		end
	end

	logger.info("Highlights applied to buffer %d", bufnr)
end

--- Set header for the UI
---@param lines string[] The lines of the content
---@param seq_map TimeMachine.SeqMap The map of line numbers to seqs
---@param content_bufnr integer The content buffer number
---@return nil
local function set_header(lines, seq_map, content_bufnr)
	logger.debug("set_header(content_bufnr=%d)", content_bufnr)

	local undofile_path = undotree.get_undofile_path(content_bufnr)

	local persistent = vim.api.nvim_get_option_value(
		"undofile",
		{ scope = "local", buf = content_bufnr }
	)

	local saved_text = string.format("%s = Saved", constants.icons.saved)
	local point_text = string.format("%s = Point", constants.icons.point)

	local annotation = saved_text .. " " .. point_text

	local keymaps = require("time-machine.config").config.keymaps or {}

	local timeline_view_text = is_current_timeline_toggled and "current"
		or "all"

	---@type string[]
	local header_lines = {
		string.format(
			"[%s] Restore [%s] More Actions/Help",
			keymaps.restore_undopoint,
			keymaps.help
		),
		"",
		"Timeline View: " .. timeline_view_text,
		"Persistent: " .. tostring(persistent),
		"Content Buffer: " .. content_bufnr,
		"",
		annotation,
		"",
	}

	if
		persistent
		and undofile_path
		and vim.fn.filereadable(undofile_path) == 1
	then
		table.insert(
			header_lines,
			#header_lines - 2,
			"Undo File: " .. undofile_path
		)
	end

	local tags_path = require("time-machine.tags").get_tags_path(content_bufnr)

	if tags_path and vim.fn.filereadable(tags_path) == 1 then
		table.insert(header_lines, #header_lines - 2, "Tag File: " .. tags_path)
	end

	table.insert(header_lines, current_timeline_annotation)

	for i = #header_lines, 1, -1 do
		table.insert(lines, 1, header_lines[i])
		table.insert(seq_map, 1, "")
	end

	logger.info("Header set with %d lines", #header_lines)
end

--- Refresh the UI
---@param time_machine_bufnr integer The buffer number
---@param seq_map TimeMachine.SeqMap The map of line numbers to seqs
---@param content_bufnr integer The main buffer number
---@param show_current_timeline_only? boolean Whether to only show the current timeline
---@return nil
function M.refresh(
	time_machine_bufnr,
	seq_map,
	content_bufnr,
	show_current_timeline_only
)
	logger.debug(
		"refresh(buf=%d, content=%d, cur_only=%s)",
		time_machine_bufnr,
		content_bufnr,
		tostring(show_current_timeline_only)
	)

	if
		not time_machine_bufnr
		or not vim.api.nvim_buf_is_valid(time_machine_bufnr)
	then
		logger.warn(
			"Invalid time machine buffer: %s",
			tostring(time_machine_bufnr)
		)
		return
	end

	local ut = undotree.get_undotree(content_bufnr)

	if not ut then
		logger.warn("No undotree for buffer %d", content_bufnr)
		vim.notify("No undotree found", vim.log.levels.WARN)
		return
	end

	local tags = require("time-machine.tags").load_tags(content_bufnr)

	local lines = {}

	seq_map = {}

	show_current_timeline_only = show_current_timeline_only
		or is_current_timeline_toggled

	local tree_lines =
		tree.build_tree_lines(ut, seq_map, tags, show_current_timeline_only)

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

	logger.info(
		"Refreshed UI for buffer %d with %d lines",
		time_machine_bufnr,
		#lines
	)
end

--- Show the undo history for a buffer
---@param ut vim.fn.undotree.ret
---@param content_bufnr integer The main buffer number
---@return nil
function M.show_tree(ut, content_bufnr)
	logger.debug("show_tree(content=%d)", content_bufnr)

	local orig_win_id = vim.api.nvim_get_current_win()

	local tags = require("time-machine.tags").load_tags(content_bufnr)

	local seq_map = {}
	local tree_lines =
		tree.build_tree_lines(ut, seq_map, tags, is_current_timeline_toggled)

	if #tree_lines == 0 then
		vim.notify("No undos yet", vim.log.levels.WARN)
		return
	end

	local lines = {}

	for _, line in ipairs(tree_lines) do
		table.insert(lines, line.content)
	end

	set_header(lines, seq_map, content_bufnr)

	local time_machine_bufnr = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_buf_set_lines(time_machine_bufnr, 0, -1, false, lines)

	M.set_standard_buf_options(time_machine_bufnr)

	set_highlights(time_machine_bufnr, seq_map, ut.seq_cur, lines)

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
			constants.events.undo_called,
			constants.events.redo_called,
			constants.events.tags_created,
		},
		callback = function()
			-- only refresh if that buffer is still open
			if vim.api.nvim_buf_is_valid(time_machine_bufnr) then
				M.refresh(
					time_machine_bufnr,
					seq_map,
					content_bufnr,
					is_current_timeline_toggled
				)
			end
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		group = utils.augroup("ui_close"),
		pattern = constants.events.undofile_deleted,
		callback = function()
			utils.close_win(time_machine_win_id)
		end,
	})

	local keymaps = require("time-machine.config").config.keymaps or {}

	vim.api.nvim_buf_set_keymap(
		time_machine_bufnr,
		"n",
		keymaps.preview_sequence_diff,
		"",
		{
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
		}
	)

	vim.api.nvim_buf_set_keymap(
		time_machine_bufnr,
		"n",
		keymaps.restore_undopoint,
		"",
		{
			nowait = true,
			noremap = true,
			silent = true,
			callback = function()
				local cursor_pos = vim.api.nvim_win_get_cursor(0)[1]
				M.handle_restore(cursor_pos, time_machine_bufnr, content_bufnr)
			end,
		}
	)

	vim.api.nvim_buf_set_keymap(
		time_machine_bufnr,
		"n",
		keymaps.refresh_timeline,
		"",
		{
			nowait = true,
			noremap = true,
			silent = true,
			callback = function()
				M.refresh(
					time_machine_bufnr,
					seq_map,
					content_bufnr,
					is_current_timeline_toggled
				)
				vim.notify("Refreshed", vim.log.levels.INFO)
			end,
		}
	)

	vim.api.nvim_buf_set_keymap(
		time_machine_bufnr,
		"n",
		keymaps.tag_sequence,
		"",
		{
			nowait = true,
			noremap = true,
			silent = true,
			callback = function()
				local cursor_pos = vim.api.nvim_win_get_cursor(0)[1]

				require("time-machine.tags").create_tag(
					cursor_pos,
					time_machine_bufnr,
					content_bufnr
				)
			end,
		}
	)

	vim.api.nvim_buf_set_keymap(time_machine_bufnr, "n", keymaps.close, "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			utils.close_win(time_machine_win_id)
		end,
	})

	vim.api.nvim_buf_set_keymap(time_machine_bufnr, "n", keymaps.help, "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.show_help()
		end,
	})

	vim.api.nvim_buf_set_keymap(time_machine_bufnr, "n", keymaps.undo, "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			vim.api.nvim_buf_call(content_bufnr, function()
				vim.cmd("undo")
				utils.emit_event(constants.events.undo_called)
			end)
		end,
	})

	vim.api.nvim_buf_set_keymap(time_machine_bufnr, "n", keymaps.redo, "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			vim.api.nvim_buf_call(content_bufnr, function()
				vim.cmd("redo")
				utils.emit_event(constants.events.redo_called)
			end)
		end,
	})

	vim.api.nvim_buf_set_keymap(
		time_machine_bufnr,
		"n",
		keymaps.toggle_current_timeline,
		"",
		{
			nowait = true,
			noremap = true,
			silent = true,
			callback = function()
				is_current_timeline_toggled = not is_current_timeline_toggled
				M.refresh(
					time_machine_bufnr,
					seq_map,
					content_bufnr,
					is_current_timeline_toggled
				)
				vim.notify(
					"Now in "
						.. (is_current_timeline_toggled and "current" or "all")
						.. " timeline",
					vim.log.levels.INFO
				)
			end,
		}
	)

	logger.info("Time-machine UI opened for buffer %d", content_bufnr)
end

--- Show the help text
---@return nil
function M.show_help()
	logger.debug("show_help() called")

	local keymaps = require("time-machine.config").config.keymaps or {}

	local help_descriptions = {
		undo = "Undo the selected sequence in the current timeline",
		redo = "Redo the selected sequence in the current timeline",
		restore_undopoint = "Restore to the selected sequence",
		refresh_timeline = "Refresh the data",
		preview_sequence_diff = "Show the diff of the selected sequence",
		tag_sequence = "Tag the selected sequence",
		close = "Close the window/bufffer",
		toggle_current_timeline = "Toggle to only show the current timeline",
	}

	local help_lines = {
		"## Actions/Help",
		"",
	}

	for help_key, help_line in pairs(help_descriptions) do
		local line = string.format("`%s` **%s**", keymaps[help_key], help_line)
		table.insert(help_lines, line)
	end

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, help_lines)

	M.set_standard_buf_options(bufnr)

	local win = window.create_native_float_win(bufnr, "Help")

	vim.api.nvim_set_option_value(
		"syntax",
		"markdown",
		{ scope = "local", buf = bufnr }
	)

	vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.close, "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			utils.close_win(win)
		end,
	})

	logger.info("Help window displayed")
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
	logger.debug("preview_diff(line=%d)", line_num)

	local full_id = utils.get_seq_from_line(time_machine_bufnr, line_num)
	if not full_id or full_id == "" then
		logger.warn("No seq under cursor at line %d", line_num)
		return
	end

	local old_lines =
		diff.read_buffer_at_seq(content_bufnr, orig_win_id, full_id)
	local new_lines = vim.api.nvim_buf_get_lines(content_bufnr, 0, -1, false)

	local config = require("time-machine.config").config

	if config.diff_tool == "native" then
		logger.info("Using native diff tool")
		diff.preview_diff_native(old_lines, new_lines)
	else
		logger.info("Using external diff tool: %s", config.diff_tool)
		diff.preview_diff_external(config.diff_tool, old_lines, new_lines)
	end
end

--- Handle the restore action
---@param line_num integer The line number
---@param time_machine_bufnr integer The buffer number
---@param content_bufnr integer The main buffer number
---@return nil
function M.handle_restore(line_num, time_machine_bufnr, content_bufnr)
	logger.debug("handle_restore(line=%d)", line_num)

	local full_id = utils.get_seq_from_line(time_machine_bufnr, line_num)
	if not full_id or full_id == "" then
		logger.warn("Invalid seq at line %d", line_num)
		return
	end

	local seq = tonumber(full_id)
	if not seq then
		logger.error("Invalid sequence id: %q", full_id)
		vim.notify(
			("Invalid sequence id: %q"):format(full_id),
			vim.log.levels.ERROR
		)
		return
	end

	logger.info("Restoring to seq %d", seq)
	require("time-machine.actions").restore(seq, content_bufnr)
end

--- Show the help text
---@return nil
function M.show_log()
	logger.debug("show_log() called")

	local keymaps = require("time-machine.config").config.keymaps or {}
	local log_file = require("time-machine.config").config.log_file

	if not log_file or log_file == "" then
		logger.warn("No log_file configured; aborting show_log()")
		vim.notify("No log file found", vim.log.levels.WARN)
		return
	end

	logger.info("Opening log file: %s", log_file)
	local f, err = io.open(log_file, "r")
	if not f then
		logger.error("Failed to open log file %s: %s", log_file, tostring(err))
		vim.notify("No log file found at " .. log_file, vim.log.levels.WARN)
		return
	end

	local lines = {}
	for line in f:lines() do
		table.insert(lines, line)
	end
	f:close()
	logger.debug("Read %d lines from log file", #lines)

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	M.set_standard_buf_options(bufnr)
	vim.api.nvim_set_option_value(
		"syntax",
		"log",
		{ scope = "local", buf = bufnr }
	)
	logger.info("Log buffer %d populated and options set", bufnr)

	local win = window.create_native_float_win(bufnr, "Log")

	vim.api.nvim_buf_set_keymap(bufnr, "n", keymaps.close, "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			logger.info("Closing log buffer %d", bufnr)
			utils.close_win(win)
		end,
	})

	if win then
		logger.info("Log window %d displayed", win)
	else
		logger.error("Failed to display log window")
	end
end

return M
