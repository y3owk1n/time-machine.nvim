local M = {}

local native_float = nil

local winborder = vim.api.nvim_get_option_value(
	"winborder",
	{ scope = "local" }
) or "none"

--- Create a floating window for native
---@param bufnr integer The buffer to open
---@param title? string The title appended after `Time Machine`
---@return integer|nil win_id The window handle
function M.create_native_float_win(bufnr, title)
	if native_float then
		if vim.api.nvim_win_is_valid(native_float) then
			vim.api.nvim_win_set_buf(native_float, bufnr)
			return
		end
	end

	local config_float_opts = require("time-machine.config").config.float_opts
		or {}

	---@type vim.api.keyset.win_config
	local win_opts = {
		relative = "editor",
		border = winborder,
		width = config_float_opts.width or 0.8,
		height = config_float_opts.height or 0.8,
		title = "Time Machine" .. (title and (" - " .. title) or ""),
		title_pos = "center",
		footer = "Press `q` to exit",
		footer_pos = "center",
	}

	win_opts.width = math.floor(vim.o.columns * win_opts.width)
	win_opts.height = math.floor(vim.o.lines * win_opts.height)
	win_opts.row = math.floor((vim.o.lines - win_opts.height) / 2)
	win_opts.col = math.floor((vim.o.columns - win_opts.width) / 2)

	local win = vim.api.nvim_open_win(bufnr, true, win_opts)

	return win
end

--- Create a floating window for native
---@param bufnr integer The buffer to open
---@return integer|nil win_id The window handle
function M.create_native_split_win(bufnr)
	local config_split_opts = require("time-machine.config").config.split_opts
		or {}

	local width = config_split_opts.width or 50

	if config_split_opts.split == "left" then
		vim.cmd("topleft vnew")
	else
		vim.cmd("botright vnew")
	end

	local win = vim.api.nvim_get_current_win()

	vim.api.nvim_win_set_buf(win, bufnr)

	vim.api.nvim_win_set_width(win, width)

	vim.api.nvim_set_option_value(
		"winfixwidth",
		true,
		{ scope = "local", win = win }
	)
	vim.api.nvim_set_option_value(
		"statusline",
		"",
		{ scope = "local", win = win }
	)
	vim.api.nvim_set_option_value(
		"signcolumn",
		"no",
		{ scope = "local", win = win }
	)
	vim.api.nvim_set_option_value(
		"number",
		false,
		{ scope = "local", win = win }
	)
	vim.api.nvim_set_option_value(
		"relativenumber",
		false,
		{ scope = "local", win = win }
	)

	return win
end

return M
