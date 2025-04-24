local M = {}

local constants = require("time-machine.constants").constants
local utils = require("time-machine.utils")

M.config = {}

---@type TimeMachine.Config
local defaults = {
	ignored_filetypes = {
		"terminal",
		"nofile",
		constants.snapshot_ft,
		"mason",
		"snacks_picker_list",
		"snacks_picker_input",
		"snacks_dashboard",
		"snacks_notif_history",
		"lazy",
	},
}

--- Setup Time Machine colors
---@return nil
function M.setup_highlights()
	local groups = constants.hl

	local defaults_colors = {
		current = { bg = "#3c3836", fg = "#fabd2f", bold = true },
		keymap = { fg = "#8ec07c", italic = true },
		info = { fg = "#939AB7", italic = true },
	}

	for key, group in pairs(groups) do
		vim.api.nvim_set_hl(0, group, defaults_colors[key])
	end
end

--- Setup Time Machine
---@param user_config TimeMachine.Config
---@return nil
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", defaults, user_config or {})

	if user_config.ignored_filetypes and #user_config.ignored_filetypes > 0 then
		M.config.ignored_filetypes = utils.merge_lists(user_config.ignored_filetypes, defaults.ignored_filetypes)
	end

	vim.api.nvim_create_autocmd("FileType", {
		group = utils.augroup("no_undofile"),
		pattern = M.config.ignored_filetypes,
		callback = function()
			vim.opt_local.undofile = false
		end,
	})

	vim.api.nvim_create_autocmd({ "BufWritePost", "TextChanged", "InsertLeave" }, {
		group = utils.augroup("auto_save_buf_write_post"),
		callback = function()
			vim.api.nvim_exec_autocmds("User", { pattern = constants.events.snapshot_created })
		end,
	})

	vim.api.nvim_create_autocmd("BufReadPre", {
		callback = function(ev)
			local path = vim.fn.expand(ev.match)
			if vim.fn.getfsize(path) > 1024 * 1024 then
				vim.opt_local.undofile = false
			end
		end,
	})

	M.setup_highlights()
end

return M
