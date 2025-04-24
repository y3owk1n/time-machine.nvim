local M = {}

-- Write an array of lines to a temp file, return its path
local function write_temp(lines)
	-- create a unique temp filename
	local template = vim.fn.tempname() .. ".txt"
	-- write it
	vim.fn.writefile(lines, template, "b")
	return template
end

function M.diff_with_native(old, new)
	local computed_diff = M.compute_diff_lines(new, old)

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

-- Run difftastic on two temp files, show results in a popup
function M.diff_with_difftastic(old_lines, new_lines)
	-- dump snapshots to disk
	local f1 = write_temp(old_lines)
	local f2 = write_temp(new_lines)

	-- create a scratch buffer for the terminal
	local preview_buf = vim.api.nvim_create_buf(false, true)

	local win = require("time-machine.ui").create_native_float(preview_buf, "Preview (Difftastic)")

	if not win then
		return
	end

	-- run difftastic inside the terminal
	vim.fn.jobstart({ "difft", "--width=80", "--color=always", f1, f2 }, {
		term = true,
		on_exit = function()
			-- clean up temp files
			os.remove(f1)
			os.remove(f2)
		end,
	})

	-- map 'q' to close the floating window
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = preview_buf, nowait = true, noremap = true, silent = true })
end

--- Get the diff of a sequence of undos
---@param bufnr number The buffer number
---@param win number The window number
---@param seq string The sequence of undos
---@return string[] lines The diff of the sequence of undos
function M.read_buffer_at_seq(bufnr, win, seq)
	local prev_win = vim.api.nvim_get_current_win()

	vim.api.nvim_set_current_win(win)

	-- grab current seq, jump back
	local cur_seq = vim.fn.undotree().seq_cur
	vim.cmd("undo " .. seq)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	-- restore
	vim.cmd("undo " .. cur_seq)

	-- return to wherever we were (UI or diff)
	vim.api.nvim_set_current_win(prev_win)
	return lines
end

--- Compute the diff of two lines
---@param old_lines string[] The old lines
---@param new_lines string[] The new lines
---@return string[] The diff of the two lines
function M.compute_diff_lines(old_lines, new_lines)
	local old_text = table.concat(old_lines, "\n")
	local new_text = table.concat(new_lines, "\n")

	local diff_text = vim.diff(old_text, new_text, require("time-machine.config").config.diff_opts)

	if not diff_text or diff_text == "" then
		return { "[No differences]" }
	end

	local result = vim.split(diff_text, "\n", { plain = true })
	return result
end

return M
