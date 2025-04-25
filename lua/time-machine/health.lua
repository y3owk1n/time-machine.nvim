local M = {}

---Reports a status message using vim.health.
---Supports boolean values (true for OK, false for error) and string levels ("ok", "warn", "error").
---@param level "ok"|"warn"|"error" The status level.
---@param msg string The message to display.
local function report_status(level, msg)
	local health = vim.health or {}
	if level == "ok" then
		health.ok(msg)
	elseif level == "warn" then
		if health.warn then
			health.warn(msg)
		else
			health.ok("WARN: " .. msg)
		end
	elseif level == "error" then
		health.error(msg)
	else
		error("Invalid level: " .. level)
	end
end

---Prints a separator header for a new section.
---@param title string The section title.
local function separator(title)
	vim.health.start(title)
end

function M.check()
	separator("Time Machine - Neovim Version Check")
	report_status(vim.fn.has("nvim-0.11.0") == 1 and "ok" or "error", "Time Machine requires Neovim 0.11.0 or higher.")

	separator("Time Machine - Undo configuration check")
	report_status(vim.o.undofile and "ok" or "warn", "Time Machine recommends undofile to be enabled.")
	report_status(vim.o.undodir and "ok" or "warn", "Time Machine recommends undodir to be set.")
	report_status(vim.o.undolevels and "ok" or "warn", "Time Machine recommends undolevels to be set.")

	separator("Time Machine - Diff Tools Check")
	local config = require("time-machine.config").config
	if config.diff_tool ~= "native" then
		report_status("ok", "Diff tools configured: " .. config.diff_tool)

		local diff_tools_map = {
			difft = "difft",
			diff = "diff",
		}

		if diff_tools_map[config.diff_tool] then
			if vim.fn.executable(config.diff_tool) == 1 then
				report_status("ok", diff_tools_map[config.diff_tool] .. " is installed.")
			else
				report_status(
					"error",
					diff_tools_map[config.diff_tool]
						.. " is not installed. Please install "
						.. diff_tools_map[config.diff_tool]
						.. " or set the diff_tool to `native`."
				)
			end
		else
			report_status("warn", "Diff tools configured: " .. config.diff_tool .. " is not supported.")
		end
	end
end

return M
