local M = {}

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

	vim.api.nvim_set_option_value("syntax", "diff", { scope = "local", buf = preview_buf })

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

	require("time-machine.ui").create_native_float(preview_buf, "Preview (Native)")
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

	local cmds = {
		["difft"] = { "difft", "--width=80", "--color=always" },
		["diff"] = { "diff", "--color=always" },
	}

	local cmd = cmds[diff_type]

	if not cmd then
		vim.notify("Invalid diff tool: " .. diff_type, vim.log.levels.ERROR)
		return
	end

	local old_lines_file = write_temp(old_lines)
	local new_lines_file = write_temp(new_lines)

	local preview_buf = vim.api.nvim_create_buf(false, true)

	local win = require("time-machine.ui").create_native_float(preview_buf, "Preview (" .. diff_type .. ")")

	if not win then
		return
	end

	--- run the diff tool inside the terminal
	vim.fn.jobstart({ cmd[1], unpack(cmd, 2, cmd.n), old_lines_file, new_lines_file }, {
		term = true,
		on_exit = function()
			os.remove(old_lines_file)
			os.remove(new_lines_file)
		end,
	})

	vim.keymap.set("n", "q", function()
		require("time-machine.ui").close_win(win)
	end, { buffer = preview_buf, nowait = true, noremap = true, silent = true })
end

--- Get the diff of a sequence of undos
---@param content_bufnr number The buffer number
---@param content_win number The window number
---@param seq string The sequence of undos
---@return string[] lines The diff of the sequence of undos
function M.read_buffer_at_seq(content_bufnr, content_win, seq)
	local cur_win = vim.api.nvim_get_current_win()

	--- Set the current window to the main content window
	vim.api.nvim_set_current_win(content_win)

	-- grab current seq, jump back
	local cur_seq = vim.fn.undotree().seq_cur
	vim.cmd("undo " .. seq)
	local lines = vim.api.nvim_buf_get_lines(content_bufnr, 0, -1, false)
	-- restore
	vim.cmd("undo " .. cur_seq)

	-- return to wherever we were
	vim.api.nvim_set_current_win(cur_win)

	return lines
end

--- Compute the diff of two lines
---@param old_lines string[] The old lines
---@param new_lines string[] The new lines
---@return string[] The diff of the two lines
function M.compute_diff_lines(old_lines, new_lines)
	local old_text = table.concat(old_lines, "\n")
	local new_text = table.concat(new_lines, "\n")

	local diff_result = vim.diff(old_text, new_text, require("time-machine.config").config.native_diff_opts)

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
			table.insert(lines, string.format("@@ -%d,%d +%d,%d @@", a_start, a_count, b_start, b_count))

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
