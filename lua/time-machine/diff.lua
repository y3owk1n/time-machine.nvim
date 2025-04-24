local M = {}

-- Write an array of lines to a temp file, return its path
local function write_temp(lines)
	-- create a unique temp filename
	local template = vim.fn.tempname() .. ".txt"
	-- write it
	vim.fn.writefile(lines, template, "b")
	return template
end

-- Run difftastic on two temp files, show results in a popup
function M.diff_with_difftastic(old_lines, new_lines)
	local f1 = write_temp(old_lines)
	local f2 = write_temp(new_lines)

	-- prepare an output buffer
	local buf = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_set_option_value("syntax", "diff", { scope = "local", buf = buf })

	vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end,
	})

	-- spawn difftastic
	vim.fn.jobstart({ "difft", "--width=80", "--color=never", f1, f2 }, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				-- append each line of colored diff
				vim.api.nvim_buf_set_lines(buf, -1, -1, false, data)
			end
		end,
		on_exit = function()
			-- open popup once difftastic finishes
			local width = math.floor(vim.o.columns * 0.8)
			local height = math.floor(vim.o.lines * 0.8)
			vim.api.nvim_open_win(buf, true, {
				relative = "editor",
				row = (vim.o.lines - height) / 2,
				col = (vim.o.columns - width) / 2,
				width = width,
				height = height,
				style = "minimal",
				border = "rounded",
			})
			-- optionally clean up temp files
			os.remove(f1)
			os.remove(f2)
		end,
	})
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
