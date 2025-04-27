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
	-- create a unique temp filename
	local template = vim.fn.tempname() .. ".txt"
	-- write it
	vim.fn.writefile(lines, template, "b")
	return template
end

--- Diff with the native diff (vim.diff)
---@param old_lines string[] The old lines
---@param new_lines string[] The new lines
---@return nil
function M.preview_diff_native(old_lines, new_lines)
	local computed_diff = M.compute_diff_lines(new_lines, old_lines)

	local preview_buf = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, computed_diff)

	require("time-machine.ui").set_standard_buf_options(preview_buf)

	vim.api.nvim_set_option_value(
		"syntax",
		"diff",
		{ scope = "local", buf = preview_buf }
	)

	vim.api.nvim_buf_set_keymap(preview_buf, "n", "q", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			if vim.api.nvim_buf_is_valid(preview_buf) then
				vim.api.nvim_buf_delete(preview_buf, { force = true })
			end
		end,
	})

	require("time-machine.window").create_native_float_win(
		preview_buf,
		"Preview (Native)"
	)
end

--- Diff with an external tool
---@param diff_type TimeMachine.DiffTool The diff tool to use
---@param old_lines string[] The old lines
---@param new_lines string[] The new lines
---@return nil
function M.preview_diff_external(diff_type, old_lines, new_lines)
	if diff_type == "native" then
		return
	end

	local cmd = ext_cmds[diff_type]

	if not cmd then
		vim.notify(
			"Diff tool not supported: " .. diff_type,
			vim.log.levels.ERROR
		)
		return
	end

	if vim.fn.executable(cmd.cmd) == 0 then
		vim.notify("Diff tool not found: " .. cmd.cmd, vim.log.levels.ERROR)
		return
	end

	local old_lines_file = write_temp(old_lines)
	local new_lines_file = write_temp(new_lines)

	local preview_buf = vim.api.nvim_create_buf(false, true)

	local win = require("time-machine.window").create_native_float_win(
		preview_buf,
		"Preview (" .. diff_type .. ")"
	)

	if not win then
		os.remove(old_lines_file)
		os.remove(new_lines_file)
		return
	end

	local cmd_args =
		vim.list_extend({ old_lines_file, new_lines_file }, cmd.args)

	local ok = pcall(vim.fn.jobstart, { cmd.cmd, unpack(cmd_args) }, {
		term = true,
		on_exit = function()
			os.remove(old_lines_file)
			os.remove(new_lines_file)
		end,
	})

	if not ok then
		vim.notify(
			"Failed to start diff tool: " .. cmd[1],
			vim.log.levels.ERROR
		)
		require("time-machine.utils").close_win(win)
		os.remove(old_lines_file)
		os.remove(new_lines_file)
	end

	vim.keymap.set("n", "q", function()
		require("time-machine.utils").close_win(win)
	end, { buffer = preview_buf, nowait = true, noremap = true, silent = true })
end

--- Get the diff of a sequence of undos
---@param content_bufnr number The buffer number
---@param content_win_id number The window number
---@param seq string The sequence of undos
---@return string[] lines The diff of the sequence of undos
function M.read_buffer_at_seq(content_bufnr, content_win_id, seq)
	local lines
	vim.api.nvim_buf_call(content_bufnr, function()
		vim.api.nvim_set_current_win(content_win_id)
		local cur = vim.fn.undotree().seq_cur
		vim.cmd("undo " .. seq)
		lines = vim.api.nvim_buf_get_lines(content_bufnr, 0, -1, false)
		vim.cmd("undo " .. cur)
	end)
	return lines
end

--- Compute the diff of two lines
---@param old_lines string[] The old lines
---@param new_lines string[] The new lines
---@return string[] The diff of the two lines
function M.compute_diff_lines(old_lines, new_lines)
	local old_text = table.concat(old_lines, "\n")
	local new_text = table.concat(new_lines, "\n")

	local diff_result = vim.diff(
		old_text,
		new_text,
		require("time-machine.config").config.native_diff_opts
	)

	if not diff_result then
		return { "[No differences]" }
	end

	--- Handle unified diff
	if type(diff_result) == "string" then
		if diff_result == "" then
			return { "[No differences]" }
		end
		return vim.split(diff_result, "\n", { plain = true })
	end

	--- indices diff
	if type(diff_result) == "table" then
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
		if #lines == 0 then
			return { "[No differences]" }
		end
		return lines
	end

	return { "[Invalid diff format]" }
end

return M
