local M = {}

function M.get_buf_path(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	return path ~= "" and path or nil
end

function M.is_binary(buf)
	return vim.bo[buf].binary or vim.bo[buf].filetype == "git"
end

function M.root_branch_id(buf_path)
	local branch = require("time-machine.git").get_git_branch(buf_path)
	if not branch or branch == "detached" then
		return "root"
	end
	return ("root-%s"):format(branch)
end

function M.encode(str)
	return str:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("'", "''")
end

function M.decode(str)
	return str:gsub("\\n", "\n"):gsub("\\\\", "\\")
end

function M.find_key_with_prefix(tbl, prefix)
	for key, value in pairs(tbl) do
		if type(key) == "string" and key:sub(1, #prefix) == prefix then
			return key, value
		end
	end
end

--- Convert a timestamp into a human-readable relative time (e.g., "16s ago", "5m ago")
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

function M.get_id_from_line(bufnr, line_num)
	local ok, id_map = pcall(vim.api.nvim_buf_get_var, bufnr, "time_machine_id_map")
	return ok and id_map[line_num] or nil
end

return M
