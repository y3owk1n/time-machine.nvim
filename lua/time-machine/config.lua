local M = {}

local storage = require("time-machine.storage")
local constants = require("time-machine.constants").constants
local actions = require("time-machine.actions")
local utils = require("time-machine.utils")

M.config = {}

---@type TimeMachine.Config
local defaults = {
	db_path = vim.fn.stdpath("data") .. "/time_machine.db",
	auto_save = {
		enabled = false,
		debounce_ms = 2 * 1000,
		events = { "TextChanged", "TextChangedI" },
	},
	retention_days = 30,
	max_snapshots = 1000,
	ignored_buftypes = { "terminal", "nofile", constants.native_float_buftype },
	enable_telescope = false,
}

--- Setup Time Machine colors
---@param opts TimeMachine.Config
---@return nil
function M.setup_highlights(opts)
	opts = opts or {}
	local groups = {
		current = "TimeMachineCurrent",
		preview = "TimeMachinePreview",
		tag = "TimeMachineTag",
	}
	local defaults_colors = {
		current = { bg = "#3c3836", fg = "#fabd2f", bold = true },
		preview = { bg = "#504945", fg = "#83a598" },
		tag = { fg = "#8ec07c", italic = true },
	}

	for key, group in pairs(groups) do
		local setting = opts[key]
		if type(setting) == "string" then
			-- Link to an existing highlight group
			vim.cmd(string.format("highlight! link %s %s", group, setting))
		elseif type(setting) == "table" then
			-- User-defined highlight attributes
			vim.api.nvim_set_hl(0, group, setting)
		else
			-- Apply default attributes
			vim.api.nvim_set_hl(0, group, defaults_colors[key])
		end
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
				if vim.tbl_contains(M.config.ignored_buftypes, vim.bo[args.buf].buftype) then
					return
				end
				debounced_snapshot(args.buf, nil, true)
			end,
		})

		vim.api.nvim_create_autocmd({ "BufReadPost" }, {
			group = utils.augroup("auto_save_buf_read_post"),
			callback = function(args)
				if vim.tbl_contains(M.config.ignored_buftypes, vim.bo[args.buf].buftype) then
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

	storage.init(M.config.db_path)

	setup_autocmds()

	if M.config.enable_telescope then
		require("time-machine.telescope").setup()
	end

	M.setup_highlights(user_config)
end

return M
