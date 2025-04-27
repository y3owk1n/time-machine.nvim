local fmt = string.format

local M = {}

local levels_reverse = {}
for k, v in pairs(vim.log.levels) do
	levels_reverse[v] = k
end

--- Get current timestamp
---@return string|osdate date The current timestamp
local function timestamp()
	return os.date("%Y-%m-%d %H:%M:%S")
end

--- Ensure directory exists
---@param path string The path to the directory
---@return nil
local function ensure_dir(path)
	local dir = vim.fs.dirname(path)
	vim.fn.mkdir(dir, "p")
end

--- Open the log file
---@return nil
function M._open()
	if M._fd then
		return
	end
	ensure_dir(M.logfile)
	local _, err
	M._fd, err = io.open(M.logfile, "a+")
	if not M._fd then
		vim.notify(
			fmt("[time-machine] failed to open log file: %s", err),
			vim.log.levels.ERROR
		)
	end
end

--- Internal write method
---@param line string The line to write
function M._write(line)
	if not M._fd then
		return
	end
	M._fd:write(line, "\n")
	M._fd:flush()
end

--- Format logs
---@param level integer
---@param msg string
---@param ... any
---@return string formatted The formatted log
local function safe_format(level, msg, ...)
	local ok, text = pcall(fmt, msg, ...)
	local name = levels_reverse[level] or tostring(level)
	local t = timestamp()
	if ok then
		return fmt("%s [%s] %s", t, name, text)
	else
		local info = vim.inspect({ msg = msg, args = { ... } })
		return fmt("%s [ERROR] failed to format log: %s", t, info)
	end
end

--- Setup logger options
---@param opts { level: integer, logfile: string }
function M.setup(opts)
	opts = opts or {}
	M.level = opts.level or M.level
	M.logfile = opts.logfile or M.logfile

	-- reopen handle if path changed
	if M._fd then
		M._fd:close()
		M._fd = nil
	end
end

--- Generic log method
---@param level integer The log level
---@param msg string The message to log
---@param ... any The rest of the arguments
---@return nil
function M.log(level, msg, ...)
	if level < M.level then
		return
	end
	M._open()
	local line = safe_format(level, msg, ...)
	M._write(line)
end

-- Clear the log file content
---@return nil
function M.delete_log_file()
	local path = M.logfile

	if path and vim.fn.filereadable(path) == 1 then
		local ok, err = pcall(os.remove, path)
		if ok then
			vim.notify("Cleared log file: " .. path, vim.log.levels.INFO)
		else
			M.error("Failed to remove log file %s: %s", path, tostring(err))
		end
	else
		vim.notify("No log file found: " .. path, vim.log.levels.WARN)
	end
end

function M.trace(...)
	M.log(vim.log.levels.TRACE, ...)
end
function M.debug(...)
	M.log(vim.log.levels.DEBUG, ...)
end
function M.info(...)
	M.log(vim.log.levels.INFO, ...)
end
function M.warn(...)
	M.log(vim.log.levels.WARN, ...)
end
function M.error(...)
	M.log(vim.log.levels.ERROR, ...)
end

return M
