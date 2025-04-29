local logger = require("time-machine.logger")

local M = {}

local winborder = vim.api.nvim_get_option_value(
	"winborder",
	{ scope = "local" }
) or "none"

--- Create a floating window for native
---@param bufnr integer The buffer to open
---@param title? string The title appended after `Time Machine`
---@return integer|nil win_id The window handle
function M.create_native_float_win(bufnr, title)
	logger.debug(
		"create_native_float_win(buf=%d, title=%s)",
		bufnr,
		tostring(title)
	)

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

	if not win then
		logger.error("Failed to open native float window for buffer %d", bufnr)
		return
	end

	vim.api.nvim_set_option_value(
		"winblend",
		config_float_opts.winblend or 0,
		{ scope = "local", win = win }
	)

	logger.info("Opened native float window %d (buf=%d)", win, bufnr)

	return win
end

--- Create a split window for native
---@param bufnr integer The buffer to open
---@return integer|nil win_id The window handle
function M.create_native_split_win(bufnr)
	logger.debug("create_native_split_win(buf=%d)", bufnr)

	local config_split_opts = require("time-machine.config").config.split_opts
		or {}

	local width = config_split_opts.width or 50

	local side = config_split_opts.split == "left" and "topleft" or "botright"

	if not vim.api.nvim_buf_is_valid(bufnr) then
		logger.error("Invalid buffer %d", bufnr)
		return
	end

	vim.cmd(string.format("%s vertical sbuffer %d", side, bufnr))
	logger.info("Opening split on %s for buffer %d", side, bufnr)

	local win = vim.api.nvim_get_current_win()

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

	logger.info(
		"Opened native split window %d (buf=%d) width=%d",
		win,
		bufnr,
		width
	)
	return win
end

return M
