local constants = require("time-machine.constants").constants

local M = {}

--- Get the undofile for a given buffer
---@param bufnr number|nil  Buffer number (defaults to current buffer)
---@return string|nil ufile The undofile path
function M.get_undofile(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local name = vim.api.nvim_buf_get_name(bufnr)

	if name == "" then
		vim.notify("Buffer has no name, cannot find undofile", vim.log.levels.WARN)
		return nil
	end

	local abs = vim.fn.fnamemodify(name, ":p")
	local ufile = vim.fn.undofile(abs)

	return ufile
end

--- Get the undotree for a given buffer
---@param bufnr integer The buffer number
---@return vim.fn.undotree.ret|nil
function M.get_undotree(bufnr)
	if vim.api.nvim_buf_is_valid(bufnr) == 0 then
		return nil
	end

	local ut = vim.fn.undotree(bufnr)

	return ut
end

--- Remove all undofiles
---@return boolean ok `true` if we removed it successfully, `false` otherwise
function M.remove_undofiles()
	-- 1) Delete every undofile under your 'undodir'
	local dirs = vim.split(vim.o.undodir, ",", { trimempty = true })
	for _, dir in ipairs(dirs) do
		for _, f in ipairs(vim.fn.glob(dir .. "/*", false, true)) do
			pcall(os.remove, f)
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
		M.remove_undofile(bufnr)
	end

	vim.notify("Purged undo history for all buffers", vim.log.levels.INFO)
	return true
end

--- Remove the persistent-undo file for a given buffer
---@param bufnr number|nil  Buffer number (defaults to current buffer)
---@return boolean ok `true` if we removed a file, `false` otherwise
function M.remove_undofile(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local buf_name = vim.api.nvim_buf_get_name(bufnr)

	local ufile = M.get_undofile(bufnr)
	if ufile ~= "" and vim.fn.filereadable(ufile) == 1 then
		os.remove(ufile)
		vim.notify("Removed undofile: " .. ufile, vim.log.levels.INFO)
	else
		vim.notify("No undofile found: " .. ufile, vim.log.levels.WARN)
	end

	local wins = {}
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(w) == bufnr then
			table.insert(wins, w)
		end
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local mod_flag = vim.api.nvim_get_option_value("modified", { buf = bufnr })
	local ft_flag = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
	local old_ul = vim.api.nvim_get_option_value("undolevels", { buf = bufnr })

	local newbuf = vim.api.nvim_create_buf(true, false)

	vim.api.nvim_set_option_value("undolevels", -1, { buf = newbuf })
	vim.api.nvim_buf_set_lines(newbuf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("undolevels", old_ul, { buf = newbuf })

	vim.api.nvim_set_option_value("modified", mod_flag, { buf = newbuf })
	vim.api.nvim_set_option_value("filetype", ft_flag, { buf = newbuf })

	vim.api.nvim_buf_delete(bufnr, { force = true })

	vim.api.nvim_buf_set_name(newbuf, buf_name)

	for _, w in ipairs(wins) do
		vim.api.nvim_win_set_buf(w, newbuf)
	end

	vim.api.nvim_exec_autocmds("User", { pattern = constants.events.undofile_deleted })

	return true
end

return M
