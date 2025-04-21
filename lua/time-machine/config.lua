local M = {}

local storage = require("time-machine.storage")
local constants = require("time-machine.constants").constants

M.config = {}

---@type TimeMachine.Config
local defaults = {
	db_path = vim.fn.stdpath("data") .. "/time_machine.db",
	auto_save = false,
	max_indent = 4,
	interval_ms = 30 * 1000,
	debounce_ms = 500,
	retention_days = 30,
	max_snapshots = 1000,
	ignored_buftypes = { "terminal", "nofile", constants.native_float_buftype },
	enable_telescope = false,
}

--- Create an augroup
---@param name string The name of the augroup
---@return integer The augroup ID
local function augroup(name)
	return vim.api.nvim_create_augroup("TimeMachine" .. name, { clear = true })
end

--- Setup Time Machine auto-save timer
---@return nil
local function setup_auto_save_timer()
	local interval_ms = M.config.interval_ms or 2000
	local debounce_ms = M.config.debounce_ms or 500
	local last_changed = {}

	local timer = vim.uv.new_timer()

	if not timer then
		vim.notify("TimeMachine: timer is nil", vim.log.levels.ERROR)
		return
	end

	timer:start(
		0,
		interval_ms,
		vim.schedule_wrap(function()
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if
					vim.api.nvim_buf_is_loaded(buf)
					and vim.bo[buf].modified
					and not vim.tbl_contains(M.config.ignored_buftypes, vim.bo[buf].buftype)
				then
					local now = math.floor(vim.loop.hrtime() / 1e6) -- convert ns to ms
					local last = last_changed[buf]

					if not last then
						last_changed[buf] = now -- start tracking anew
					elseif now - last >= debounce_ms then
						local result = M.create_snapshot(buf, true)

						if result == "no_changes" then
							last_changed[buf] = nil -- stop tracking until next change
							return
						end

						last_changed[buf] = now
						vim.notify("Time Machine: Snapshot saved", vim.log.levels.DEBUG)
					end
				elseif not vim.bo[buf].modified then
					last_changed[buf] = nil -- Reset if not modified
				end
			end
		end)
	)

	-- Track modification time per buffer
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
		group = vim.api.nvim_create_augroup("TimeMachineAutoSave", { clear = true }),
		callback = function(args)
			local buf = args.buf
			if not vim.tbl_contains(M.config.ignored_buftypes, vim.bo[buf].buftype) then
				last_changed[buf] = math.floor(vim.loop.hrtime() / 1e6)
			end
		end,
	})
end

--- Setup Time Machine autocommands
---@return nil
local function setup_autocmds()
	local group = vim.api.nvim_create_augroup("TimeMachine", { clear = true })
	local timers = setmetatable({}, { __mode = "v" }) -- Weak references

	local function debounced_snapshot(buf, for_root)
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
			M.config.debounce_ms,
			0,
			vim.schedule_wrap(function()
				timer:close()
				M.create_snapshot(buf, for_root)
				timers[buf] = nil
			end)
		)
	end

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function(args)
			if vim.tbl_contains(M.config.ignored_buftypes, vim.bo[args.buf].buftype) then
				return
			end
			debounced_snapshot(args.buf)
		end,
	})

	vim.api.nvim_create_autocmd({ "BufReadPost" }, {
		group = group,
		callback = function(args)
			if vim.tbl_contains(M.config.ignored_buftypes, vim.bo[args.buf].buftype) then
				return
			end
			debounced_snapshot(args.buf, true)
		end,
	})
end

--- Setup Time Machine
---@param user_config TimeMachine.Config
---@return nil
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", defaults, user_config or {})

	storage.init(M.config.db_path)

	if M.config.auto_save then
		setup_auto_save_timer()
	end
	-- setup_autocmds()

	if M.config.enable_telescope then
		require("time-machine.telescope").setup()
	end
end

return M
