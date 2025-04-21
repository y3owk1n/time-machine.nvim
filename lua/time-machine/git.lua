local M = {}

function M.get_git_branch(buf_path)
	local dir = vim.fn.fnamemodify(buf_path, ":h")
	local git_cmd = { "git", "-C", dir, "rev-parse", "--abbrev-ref", "HEAD" }
	local branch = vim.fn.systemlist(git_cmd)[1]
	if vim.v.shell_error ~= 0 then
		return "detached"
	end
	return branch
end

function M.get_git_branches()
	local handle = vim.fn.systemlist("git branch --list") -- Run the git command to list branches
	if vim.v.shell_error ~= 0 then
		vim.notify("Failed to fetch Git branches", vim.log.levels.ERROR)
		return {}
	end
	local branches = {}
	for _, branch in ipairs(handle) do
		-- Clean up the branch names by removing any leading/trailing whitespace or '*'
		local clean_branch = branch:gsub("^%s*", ""):gsub("%s*$", ""):gsub("^[*]%s*", "")
		table.insert(branches, clean_branch)
	end
	return branches
end

return M
