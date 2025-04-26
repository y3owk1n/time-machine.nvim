local M = {}

local constants = require("time-machine.constants").constants
local utils = require("time-machine.utils")

M.config = {}

---@type TimeMachine.Config
local defaults = {
	split_opts = {
		split = "left",
		width = 50,
	},
	diff_tool = "native",
	native_diff_opts = {
		result_type = "unified",
		ctxlen = 3,
		algorithm = "histogram",
	},
	ignore_filesize = nil,
	ignored_filetypes = {
		"terminal",
		"nofile",
		constants.time_machine_ft,
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
		timeline = { fg = "#fabd2f", bold = true },
		keymap = { fg = "#8bd5ca", italic = true },
		info = { fg = "#939AB7", italic = true },
		seq = { fg = "#ed8796", bold = true },
		tag = { fg = "#f0c6c6", bold = true },
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
		M.config.ignored_filetypes = utils.merge_lists(
			user_config.ignored_filetypes,
			defaults.ignored_filetypes
		)
	end

	--- disable undofile for ignored filetypes
	--- note that this only disable undo to be saved to disk, the undo will still be available in memory
	vim.api.nvim_create_autocmd("FileType", {
		group = utils.augroup("no_undofile"),
		pattern = M.config.ignored_filetypes,
		callback = function()
			vim.opt_local.undofile = false
		end,
	})

	--- emit an event when a new undopoint is created that used to update the UI
	--- this is the best effort of detecting when an undopoint is created
	vim.api.nvim_create_autocmd(
		{ "BufWritePost", "TextChanged", "InsertLeave" },
		{
			group = utils.augroup("undopoint_created"),
			callback = function()
				vim.api.nvim_exec_autocmds(
					"User",
					{ pattern = constants.events.undo_created }
				)
			end,
		}
	)

	--- ignore large files if set up
	vim.api.nvim_create_autocmd("BufReadPre", {
		group = utils.augroup("ignore_large_files"),
		callback = function(ev)
			if not M.config.ignore_filesize then
				return
			end

			local path = vim.fn.expand(ev.match)
			if vim.fn.getfsize(path) > M.config.ignore_filesize then
				vim.opt_local.undofile = false
				vim.notify(
					("Ignoring large file: %s"):format(path),
					vim.log.levels.WARN
				)
			end
		end,
	})

	M.setup_highlights()
end

return M
