local M = {}

--- Get the path to a buffer
---@param buf integer The buffer number
---@return string|nil buf_path The path to the buffer
function M.get_buf_path(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	return path ~= "" and path or nil
end

--- Check if a buffer is binary
---@param buf integer The buffer number
---@return boolean is_binary Whether the buffer is binary
function M.is_binary(buf)
	return vim.bo[buf].binary or vim.bo[buf].filetype == "git"
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

return M
