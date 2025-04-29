local constants = require("time-machine.constants").constants
local utils = require("time-machine.utils")
local logger = require("time-machine.logger")

local M = {}

--- Get the undofile for a given buffer
---@param bufnr number|nil  Buffer number (defaults to current buffer)
---@return string|nil undofile The undofile path
function M.get_undofile_path(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	logger.debug("get_undofile_path(%d) called", bufnr)

	local name = vim.api.nvim_buf_get_name(bufnr)

	if name == "" then
		logger.warn("Buffer %d has no name; cannot find undofile", bufnr)
		vim.notify(
			"Buffer has no name, cannot find undofile",
			vim.log.levels.WARN
		)
		return nil
	end

	local filename = vim.fn.fnamemodify(name, ":p")
	local undofile = vim.fn.undofile(filename)

	logger.info(
		"Resolved undofile for buffer %d: %s",
		bufnr,
		tostring(undofile)
	)

	return undofile
end

--- Get the undotree for a given buffer
---@param bufnr integer The buffer number
---@return vim.fn.undotree.ret|nil undotree The undotree
function M.get_undotree(bufnr)
	logger.debug("get_undotree(%d) called", bufnr)

	if vim.api.nvim_buf_is_valid(bufnr) == 0 then
		logger.warn("Buffer %d is not valid; cannot get undotree", bufnr)
		return nil
	end

	local ut = vim.fn.undotree(bufnr)

	logger.info(
		"Fetched undotree for buffer %d; seq_cur=%s",
		bufnr,
		tostring(ut.seq_cur)
	)
	return ut
end

--- Remove all undofiles
---@return boolean ok `true` if we removed it successfully, `false` otherwise
function M.remove_undofiles()
	logger.info("remove_undofiles() called; purging all undofiles")
	local dirs = vim.split(vim.o.undodir, ",", { trimempty = true })

	for _, dir in ipairs(dirs) do
		for _, f in ipairs(vim.fn.glob(dir .. "/*", false, true)) do
			local ok, err = pcall(os.remove, f)
			if ok then
				logger.debug("Removed undofile %s", f)
			else
				logger.error(
					"Failed to remove undofile %s: %s",
					f,
					tostring(err)
				)
			end
		end
	end

	vim.notify("Removed all undofiles from disk", vim.log.levels.INFO)

	local names = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		local n = vim.api.nvim_buf_get_name(bufnr)
		if n ~= "" then
			names[#names + 1] = n
		end
	end

	for _, n in ipairs(names) do
		local bufnr = vim.fn.bufnr(n)

		logger.debug("Refreshing buffer window for %s (buf=%d)", n, bufnr)
		M.refresh_buffer_window(bufnr)

		utils.emit_event(constants.events.undofile_deleted)
	end

	logger.info("remove_undofiles() completed successfully")
	vim.notify("Purged undo history for all buffers", vim.log.levels.INFO)

	return true
end

--- Remove the persistent-undo file for a given buffer
---@param bufnr number|nil  Buffer number (defaults to current buffer)
---@return boolean ok `true` if we removed a file, `false` otherwise
function M.remove_undofile(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	logger.debug("remove_undofile(%d) called", bufnr)

	local undofile = M.get_undofile_path(bufnr)
	if undofile ~= "" and vim.fn.filereadable(undofile) == 1 then
		local ok, err = pcall(os.remove, undofile)
		if ok then
			logger.info("Removed undofile: %s", undofile)
			vim.notify("Removed undofile: " .. undofile, vim.log.levels.INFO)
		else
			logger.error(
				"Failed to remove undofile %s: %s",
				undofile,
				tostring(err)
			)
			return false
		end
	else
		logger.warn(
			"No undofile found for buffer %d: %s",
			bufnr,
			tostring(undofile)
		)
		vim.notify("No undofile found: " .. undofile, vim.log.levels.WARN)
		return false
	end

	logger.debug("Refreshing buffer window (buf=%d)", bufnr)
	M.refresh_buffer_window(bufnr)
	logger.info("remove_undofile(%d) completed", bufnr)

	utils.emit_event(constants.events.undofile_deleted)
	return true
end

--- Refresh all the buffers and windows
---@param bufnr integer The buffer number
---@return nil
function M.refresh_buffer_window(bufnr)
	logger.debug("refresh_buffer_window(%d) called", bufnr)

	local buf_name = vim.api.nvim_buf_get_name(bufnr)

	local wins = {}
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(w) == bufnr then
			table.insert(wins, w)
		end
	end

	logger.info("Buffer %d is displayed in %d windows", bufnr, #wins)

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local mod_flag = vim.api.nvim_get_option_value("modified", { buf = bufnr })
	local ft_flag = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
	local old_ul = vim.api.nvim_get_option_value("undolevels", { buf = bufnr })

	local newbuf = vim.api.nvim_create_buf(true, false)
	logger.debug("Created new scratch buffer %d for refresh", newbuf)

	vim.api.nvim_set_option_value("undolevels", -1, { buf = newbuf })
	vim.api.nvim_buf_set_lines(newbuf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("undolevels", old_ul, { buf = newbuf })

	vim.api.nvim_set_option_value("modified", mod_flag, { buf = newbuf })
	vim.api.nvim_set_option_value("filetype", ft_flag, { buf = newbuf })

	--- set the new buffer to the current window
	for _, w in ipairs(wins) do
		vim.api.nvim_win_set_buf(w, newbuf)
		logger.debug("Set window %d to new buffer %d", w, newbuf)
	end

	--- delete the old buffer, this must be done before setting the name
	vim.api.nvim_buf_delete(bufnr, { force = true })
	logger.info("Deleted old buffer %d", bufnr)

	--- set the new buffer name
	vim.api.nvim_buf_set_name(newbuf, buf_name)

	-- to avoid the `file exists, use ! to override` error after replacing the buffer
	vim.api.nvim_buf_call(newbuf, function()
		vim.cmd("cabbrev <buffer> w w!")
		vim.cmd("cabbrev <buffer> W W!")
	end)

	logger.info("Refreshed buffer window for %d -> %d", bufnr, newbuf)
end

return M
