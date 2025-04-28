local logger = require("time-machine.logger")

local M = {}

local ext_cmds = {
	difft = { cmd = "difft", args = {} },
	diff = { cmd = "diff", args = { "--color=always" } },
	delta = { cmd = "delta", args = {} },
}

-- Write an array of lines to a temp file, return its path
---@param lines string[] The lines to write
---@return string path The path to the temp file
local function write_temp(lines)
	logger.debug("write_temp() called with %d lines", #lines)

	local path = vim.fn.tempname() .. ".txt"
	logger.info("Creating temp file at %s", path)

	local fd = assert(vim.uv.fs_open(path, "w", 420)) -- 0o644

	local data = table.concat(lines, "\n")
	local written = vim.uv.fs_write(fd, data, -1)
	if written ~= #data then
		logger.warn(
			"Incomplete write: %d of %d bytes written to %s",
			written,
			#data,
			path
		)
	end

	vim.uv.fs_close(fd)

	logger.debug("Wrote %d bytes to %s", written, path)
	return path
end

--- Diff with the native diff (vim.diff)
---@param old_lines string[] The old lines
---@param new_lines string[] The new lines
---@return nil
function M.preview_diff_native(old_lines, new_lines)
	logger.debug("preview_diff_native() called")

	local computed_diff = M.compute_diff_lines(new_lines, old_lines)

	local preview_buf = vim.api.nvim_create_buf(false, true)
	logger.info("Created native preview buffer %d", preview_buf)

	vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, computed_diff)

	require("time-machine.ui").set_standard_buf_options(preview_buf)

	vim.api.nvim_set_option_value(
		"syntax",
		"diff",
		{ scope = "local", buf = preview_buf }
	)

	local keymaps = require("time-machine.config").config.keymaps or {}

	vim.api.nvim_buf_set_keymap(preview_buf, "n", keymaps.close, "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			logger.info("Closing native preview buffer %d", preview_buf)
			require("time-machine.utils").close_buf(preview_buf)
		end,
	})

	require("time-machine.window").create_native_float_win(
		preview_buf,
		"Preview (Native)"
	)
	logger.info("Displayed native diff preview")
end

--- Diff with an external tool
---@param diff_type TimeMachine.DiffTool The diff tool to use
---@param old_lines string[] The old lines
---@param new_lines string[] The new lines
---@return nil
function M.preview_diff_external(diff_type, old_lines, new_lines)
	logger.debug("preview_diff_external(%s) called", diff_type)

	if diff_type == "native" then
		logger.debug("External preview skipped for 'native'")
		return
	end

	local cmd = ext_cmds[diff_type]

	if not cmd then
		logger.error("Diff tool not supported: %s", diff_type)
		vim.notify(
			"Diff tool not supported: " .. diff_type,
			vim.log.levels.ERROR
		)
		return
	end

	if vim.fn.executable(cmd.cmd) == 0 then
		logger.error("Diff tool not found: %s", cmd.cmd)
		vim.notify("Diff tool not found: " .. cmd.cmd, vim.log.levels.ERROR)
		return
	end

	local old_lines_file = write_temp(old_lines)
	local new_lines_file = write_temp(new_lines)
	logger.debug("Temp files: %s, %s", old_lines_file, new_lines_file)

	local preview_buf = vim.api.nvim_create_buf(false, true)

	local win = require("time-machine.window").create_native_float_win(
		preview_buf,
		"Preview (" .. diff_type .. ")"
	)

	if not win then
		logger.warn("Could not create float window for external diff")
		os.remove(old_lines_file)
		os.remove(new_lines_file)
		return
	end

	local cmd_args = {}
	vim.list_extend(cmd_args, cmd.args or {})

	local user_args =
		require("time-machine.config").config.external_diff_args[diff_type]

	if user_args then
		vim.list_extend(cmd_args, user_args)
	end

	table.insert(cmd_args, old_lines_file)
	table.insert(cmd_args, new_lines_file)

	logger.info(
		"Starting external diff: %s %s",
		cmd.cmd,
		table.concat(cmd_args, " ")
	)
	local ok = pcall(vim.fn.jobstart, { cmd.cmd, unpack(cmd_args) }, {
		term = true,
		on_exit = function()
			logger.debug("External diff job exited; cleaning up temp files")
			os.remove(old_lines_file)
			os.remove(new_lines_file)
		end,
	})

	if not ok then
		logger.error("Failed to start diff tool: %s", cmd.cmd)
		vim.notify(
			"Failed to start diff tool: " .. cmd.cmd,
			vim.log.levels.ERROR
		)
		require("time-machine.utils").close_win(win)
		os.remove(old_lines_file)
		os.remove(new_lines_file)
	end

	local keymaps = require("time-machine.config").config.keymaps or {}

	vim.keymap.set("n", keymaps.close, function()
		logger.info("Closing external diff preview window %d", win)
		require("time-machine.utils").close_win(win)
	end, { buffer = preview_buf, nowait = true, noremap = true, silent = true })

	logger.info("External diff preview running in window %d", win)
end

--- Get the diff of a sequence of undos
---@param content_bufnr number The buffer number
---@param content_win_id number The window number
---@param seq string The sequence of undos
---@return string[] lines The diff of the sequence of undos
function M.read_buffer_at_seq(content_bufnr, content_win_id, seq)
	logger.debug(
		"read_buffer_at_seq(buf=%d, win=%d, seq=%s)",
		content_bufnr,
		content_win_id,
		seq
	)

	local lines
	vim.api.nvim_buf_call(content_bufnr, function()
		vim.api.nvim_set_current_win(content_win_id)
		local cur = vim.fn.undotree().seq_cur
		vim.cmd("undo " .. seq)
		lines = vim.api.nvim_buf_get_lines(content_bufnr, 0, -1, false)
		vim.cmd("undo " .. cur)
	end)

	logger.info(
		"Read %d lines from buffer %d at seq %s",
		#lines,
		content_bufnr,
		seq
	)
	return lines
end

--- Compute the diff of two lines
---@param old_lines string[] The old lines
---@param new_lines string[] The new lines
---@return string[] The diff of the two lines
function M.compute_diff_lines(old_lines, new_lines)
	logger.debug("compute_diff_lines() called")

	local old_text = table.concat(old_lines, "\n")
	local new_text = table.concat(new_lines, "\n")

	local diff_result = vim.diff(
		old_text,
		new_text,
		require("time-machine.config").config.native_diff_opts
	)

	if
		not diff_result or (type(diff_result) == "string" and diff_result == "")
	then
		logger.info("No differences detected")
		return { "[No differences]" }
	end

	--- unified diff
	if type(diff_result) == "string" then
		logger.debug("Unified diff string received")
		return vim.split(diff_result, "\n", { plain = true })
	end

	--- indices diff
	logger.debug("Indices diff received with %d hunks", #diff_result)
	local lines = {}
	for _, hunk in ipairs(diff_result) do
		local a_start, a_count, b_start, b_count = unpack(hunk)
		table.insert(
			lines,
			string.format(
				"@@ -%d,%d +%d,%d @@",
				a_start,
				a_count,
				b_start,
				b_count
			)
		)

		for i = 0, a_count - 1 do
			table.insert(lines, "-" .. (old_lines[a_start + i] or ""))
		end
		for i = 0, b_count - 1 do
			table.insert(lines, "+" .. (new_lines[b_start + i] or ""))
		end
	end

	logger.info("Computed diff with %d lines", #lines)
	return #lines > 0 and lines or { "[No differences]" }
end

return M
