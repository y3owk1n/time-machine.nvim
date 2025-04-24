local M = {}

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
