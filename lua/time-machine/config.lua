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
	float_opts = {
		width = 0.8,
		height = 0.8,
	},
	diff_tool = "native",
	native_diff_opts = {
		result_type = "unified",
		ctxlen = 3,
		algorithm = "histogram",
	},
	external_diff_args = {},
	keymaps = {
		undo = "u",
		redo = "<C-r>",
		restore_undopoint = "<CR>",
		refresh_timeline = "r",
		preview_sequence_diff = "p",
		tag_sequence = "t",
		close = "q",
		help = "g?",
		toggle_current_timeline = "c",
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
	log_level = vim.log.levels.WARN,
	log_file = vim.fn.stdpath("cache") .. "/time-machine.log",
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

--- Setup logger
---@return nil
function M.setup_logger()
	local logger = require("time-machine.logger")

	logger.setup({
		level = M.config.log_level,
		logfile = M.config.log_file,
	})
end

--- Setup autocommands
---@return nil
function M.setup_autocmds()
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
end

--- Setup user commands
---@return nil
function M.setup_usercmds()
	local actions = require("time-machine.actions")

	vim.api.nvim_create_user_command("TimeMachineToggle", function()
		actions.toggle()
	end, {
		desc = "Toggle the Time Machine UI",
	})

	vim.api.nvim_create_user_command("TimeMachinePurgeBuffer", function(opts)
		actions.purge_buffer(opts.bang)
	end, {
		bang = true,
		desc = "Purge the current buffer's undofile",
	})

	vim.api.nvim_create_user_command("TimeMachinePurgeAll", function(opts)
		actions.purge_all(opts.bang)
	end, {
		bang = true,
		desc = "Purge all undofiles",
	})

	vim.api.nvim_create_user_command("TimeMachineLogShow", function()
		actions.show_log()
	end, {
		desc = "Show Time Machine log",
	})

	vim.api.nvim_create_user_command("TimeMachineLogClear", function(opts)
		actions.clear_log(opts.bang)
	end, {
		bang = true,
		desc = "Clear Time Machine log",
	})
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

	M.setup_logger()
	M.setup_autocmds()
	M.setup_usercmds()
	M.setup_highlights()
end

return M
