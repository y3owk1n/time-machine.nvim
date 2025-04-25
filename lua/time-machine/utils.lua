local M = {}

--- Check if a buffer is a time machine buffer
---@param bufnr integer The buffer number
---@return boolean is_time_machine `true` if the buffer is a time machine buffer, `false` otherwise
function M.is_time_machine_active(bufnr)
	return vim.api.nvim_buf_is_valid(bufnr)
		and vim.api.nvim_buf_is_loaded(bufnr)
		and vim.api.nvim_get_option_value(
				"filetype",
				{ scope = "local", buf = bufnr }
			)
			== require("time-machine.constants").constants.time_machine_ft
end

--- Create an augroup
---@param name string The name of the augroup
---@return integer The augroup ID
function M.augroup(name)
	return vim.api.nvim_create_augroup("TimeMachine" .. name, { clear = true })
end

--- Convert a timestamp into a human-readable relative time
---@param timestamp integer The timestamp to convert
---@return string relative_time The relative time
function M.relative_time(timestamp)
	local now = os.time()
	local diff = now - timestamp
	if diff < 60 then
		return string.format("%ds ago", diff)
	elseif diff < 3600 then
		return string.format("%dm ago", math.floor(diff / 60))
	elseif diff < 86400 then
		return string.format("%dh ago", math.floor(diff / 3600))
	else
		return string.format("%dd ago", math.floor(diff / 86400))
	end
end

--- Get the sequence from a line number
---@param bufnr integer The buffer number
---@param line_num integer The line number
---@return string|nil seq The sequence
function M.get_seq_from_line(bufnr, line_num)
	local ok, seq_map = pcall(
		vim.api.nvim_buf_get_var,
		bufnr,
		require("time-machine.constants").constants.seq_map_buf_var
	)
	return ok and seq_map[line_num] or nil
end

--- Get the time machine window
---@return integer|nil winid The window ID
function M.get_time_machine_win()
	local bufnr = M.get_time_machine_bufnr()

	if not bufnr then
		return nil
	end

	for _, winid in ipairs(vim.api.nvim_list_wins()) do
		if
			vim.api.nvim_win_is_valid(winid)
			and vim.api.nvim_win_get_buf(winid) == bufnr
		then
			return winid
		end
	end
end

--- Get the time machine buffer number
---@return integer|nil bufnr The buffer number
function M.get_time_machine_bufnr()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if
			vim.api.nvim_buf_is_valid(bufnr)
			and vim.api.nvim_buf_is_loaded(bufnr)
			and vim.api.nvim_get_option_value(
					"filetype",
					{ scope = "local", buf = bufnr }
				)
				== require("time-machine.constants").constants.time_machine_ft
		then
			return bufnr
		end
	end
	return nil
end

--- Merge two lists (arrays), preserving order and removing duplicates.
---@generic T
---@param default T[] The default list
---@param user T[] The user-provided list
---@return T[] The merged, deduplicated list
function M.merge_lists(default, user)
	local seen = {}
	local result = {}

	for _, item in ipairs(default) do
		if not seen[item] then
			table.insert(result, item)
			seen[item] = true
		end
	end

	for _, item in ipairs(user) do
		if not seen[item] then
			table.insert(result, item)
			seen[item] = true
		end
	end

	return result
end

--- Close a buffer
---@param bufnr integer The buffer number
---@return nil
function M.close_buf(bufnr)
	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end
end

--- Close a window
---@param win integer The window number
---@return nil
function M.close_win(win)
	if vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

return M
