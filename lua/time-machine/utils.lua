local M = {}

local bit = require("bit")

--- Create an augroup
---@param name string The name of the augroup
---@return integer The augroup ID
function M.augroup(name)
	return vim.api.nvim_create_augroup("TimeMachine" .. name, { clear = true })
end

--- Encode data to standard Base64
-- @param data string
-- @return string base64 encoded
function M.base64_encode(data)
	local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local result = {}
	for i = 1, #data, 3 do
		local a, b, c = data:byte(i, i + 2)
		local n = (a * 65536) + ((b or 0) * 256) + (c or 0)

		table.insert(result, b64chars:sub((math.floor(n / 262144) % 64) + 1, (math.floor(n / 262144) % 64) + 1))
		table.insert(result, b64chars:sub((math.floor(n / 4096) % 64) + 1, (math.floor(n / 4096) % 64) + 1))
		table.insert(result, b and b64chars:sub((math.floor(n / 64) % 64) + 1, (math.floor(n / 64) % 64) + 1) or "=")
		table.insert(result, c and b64chars:sub((n % 64) + 1, (n % 64) + 1) or "=")
	end
	return table.concat(result)
end

--- Decode standard Base64
-- @param data string
-- @return string decoded
function M.base64_decode(data)
	local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local b64lookup = {}
	for i = 1, #b64chars do
		b64lookup[b64chars:sub(i, i)] = i - 1
	end

	data = data:gsub("[^" .. b64chars .. "=]", "")
	local result = {}
	for i = 1, #data, 4 do
		local a, b, c, d = data:sub(i, i), data:sub(i + 1, i + 1), data:sub(i + 2, i + 2), data:sub(i + 3, i + 3)
		local n = bit.bor(
			bit.lshift(b64lookup[a] or 0, 18),
			bit.lshift(b64lookup[b] or 0, 12),
			bit.lshift(b64lookup[c] or 0, 6),
			(b64lookup[d] or 0)
		)
		table.insert(result, string.char(bit.band(bit.rshift(n, 16), 0xFF)))
		if c ~= "=" then
			table.insert(result, string.char(bit.band(bit.rshift(n, 8), 0xFF)))
		end
		if d ~= "=" then
			table.insert(result, string.char(bit.band(n, 0xFF)))
		end
	end
	return table.concat(result)
end

--- URL-safe Base64 encode (no padding)
function M.base64url_encode(data)
	return M.base64_encode(data):gsub("+", "-"):gsub("/", "_"):gsub("=", "")
end

--- URL-safe Base64 decode
function M.base64url_decode(data)
	local mod = #data % 4
	if mod > 0 then
		data = data .. string.rep("=", 4 - mod)
	end
	data = data:gsub("-", "+"):gsub("_", "/")
	return M.base64_decode(data)
end

--- Slugify a buffer path using URL-safe Base64
function M.slugify_buf_path(buf_path)
	return M.base64url_encode(buf_path)
end

--- Un-slugify a Base64-encoded buffer path
function M.unslugify_buf_path(slug)
	return M.base64url_decode(slug)
end

--- Get the path to a buffer
---@param buf integer The buffer number
---@return string|nil buf_path The path to the buffer
function M.get_buf_path(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	return path ~= "" and path or nil
end

--- Get the root branch ID for a buffer
---@param buf_path string The path to the buffer
---@return string root_branch_id The root branch ID
function M.root_branch_id(buf_path)
	local branch = require("time-machine.git").get_git_branch(buf_path)
	if not branch or branch == "detached" then
		return "root"
	end
	return ("root-%s"):format(branch)
end

--- Get the short ID for a snapshot
---@param snap TimeMachine.Snapshot The snapshot
---@return string short_id The short ID
function M.get_short_id(snap)
	local short_id = (snap.id:sub(1, 4) == "root") and snap.id or snap.id:sub(1, 5)
	return short_id
end

--- Encode a string
---@param str string The string to encode
---@return string encoded_str The encoded string
function M.encode(str)
	local encoded_str = str:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("'", "''")
	return encoded_str
end

--- Decode a string
---@param str string The string to decode
---@return string decoded_str The decoded string
function M.decode(str)
	local decoded_str = str:gsub("\\n", "\n"):gsub("\\\\", "\\")
	return decoded_str
end

--- Find a key with a given prefix in a table
---@param tbl table The table to search
---@param prefix string The prefix to search for
---@return string|nil key The key with the prefix
---@return unknown|nil value The value associated with the key
function M.find_key_with_prefix(tbl, prefix)
	for key, value in pairs(tbl) do
		if type(key) == "string" and key:sub(1, #prefix) == prefix then
			return key, value
		end
	end
end

--- Convert a timestamp into a human-readable relative time
---@param timestamp integer The timestamp to convert
---@return string relative_time The relative time
function M.relative_time(timestamp)
	local now = os.time()
	local diff = now - timestamp
	if diff < 60 then
		return string.format("%ds ago", diff)
	elseif diff < 3600 then
		return string.format("%dm ago", math.floor(diff / 60))
	elseif diff < 86400 then
		return string.format("%dh ago", math.floor(diff / 3600))
	else
		return string.format("%dd ago", math.floor(diff / 86400))
	end
end

--- Get the snapshot ID from a line number
---@param bufnr integer The buffer number
---@param line_num integer The line number
---@return string|nil id The snapshot ID
function M.get_id_from_line(bufnr, line_num)
	local ok, id_map = pcall(vim.api.nvim_buf_get_var, bufnr, "time_machine_id_map")
	return ok and id_map[line_num] or nil
end

--- Generate a UUID
---@return string uuid The UUID
function M.uuid4()
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	local id = template:gsub("[xy]", function(c)
		local v = math.random(0, 15)
		if c == "y" then
			v = (v % 4) + 8 -- ensure the high bits are 10xx
		end
		return string.format("%x", v)
	end)

	return id
end

--- Create a new snapshot ID
---@return string id The new snapshot ID
function M.create_id()
	return M.uuid4()
end

--- Get all files in a directory
---@param dir string The directory to search
---@return string[] files The list of files
function M.get_files(dir)
	local handle = vim.uv.fs_scandir(dir)
	if not handle then
		return {}
	end

	local files = {}
	while true do
		local name, t = vim.uv.fs_scandir_next(handle)
		if not name then
			break
		end
		files[#files + 1] = dir .. "/" .. name
	end
	return files
end

function M.find_snapshot_list_buf()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if
			vim.api.nvim_buf_is_valid(bufnr)
			and vim.api.nvim_buf_is_loaded(bufnr)
			and vim.api.nvim_get_option_value("filetype", { scope = "local", buf = bufnr })
				== require("time-machine.constants").constants.snapshot_ft
		then
			return bufnr
		end
	end
	return nil
end

return M
