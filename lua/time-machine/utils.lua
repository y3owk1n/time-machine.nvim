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

return M
