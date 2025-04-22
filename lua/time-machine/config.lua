local M = {}

local constants = require("time-machine.constants").constants
local actions = require("time-machine.actions")
local utils = require("time-machine.utils")

M.config = {}

---@type TimeMachine.Config
local defaults = {
	db_dir = vim.fn.stdpath("data") .. "/time-machine",
	auto_save = {
		enabled = false,
		debounce_ms = 2 * 1000,
		events = { "TextChanged", "InsertLeave" },
	},
	ignored_filetypes = {
		"terminal",
		"nofile",
		constants.snapshot_ft,
		"mason",
		"snacks_picker_list",
		"snacks_picker_input",
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

--- Setup Time Machine autocommands
---@return nil
local function setup_autocmds()
	local timers = setmetatable({}, { __mode = "v" }) -- Weak references

	--- Debounced snapshot creation
	---@param buf integer The buffer number
	---@param for_root? boolean Whether to create a snapshot for the root buffer
	---@param silent? boolean Whether to suppress notifications
	---@return nil
	local function debounced_snapshot(buf, for_root, silent)
		if not M.config.auto_save.enabled then
			return
		end

		local prev_timer = timers[buf]
		if prev_timer and not prev_timer:is_closing() then
			prev_timer:close()
		end

		local timer = vim.uv.new_timer()
		timers[buf] = timer

		if not timer then
			vim.notify("TimeMachine: timer is nil")
			return
		end

		timer:start(
			M.config.auto_save.debounce_ms,
			0,
			vim.schedule_wrap(function()
				timer:close()
				actions.create_snapshot(buf, for_root, silent)
				timers[buf] = nil
			end)
		)
	end

	if M.config.auto_save.enabled then
		vim.api.nvim_create_autocmd(M.config.auto_save.events, {
			group = utils.augroup("auto_save_text_changed"),
			callback = function(args)
				if vim.tbl_contains(M.config.ignored_filetypes, vim.bo[args.buf].filetype) then
					return
				end
				debounced_snapshot(args.buf, nil, true)
			end,
		})

		vim.api.nvim_create_autocmd({ "BufReadPost" }, {
			group = utils.augroup("auto_save_buf_read_post"),
			callback = function(args)
				if vim.tbl_contains(M.config.ignored_filetypes, vim.bo[args.buf].filetype) then
					return
				end
				actions.create_snapshot(args.buf, true)
			end,
		})
	end
end

--- Setup Time Machine
---@param user_config TimeMachine.Config
---@return nil
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", defaults, user_config or {})

	setup_autocmds()

	M.setup_highlights()
end

return M
