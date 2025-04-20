local M = {}

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
