-- Create time_machine/patch.lua
local M = {}

local function parse_hunk_header(header)
	local pattern = "@@ -(%d+),(%d+) %+(%d+),(%d+) @@"
	local old_start, old_count, new_start, new_count = header:match(pattern)
	return {
		old_start = tonumber(old_start),
		old_count = tonumber(old_count),
		new_start = tonumber(new_start),
		new_count = tonumber(new_count),
	}
end

function M.apply(original, diff)
	local lines = vim.split(diff, "\n")
	local result = vim.deepcopy(original)
	local hunk = nil
	local offset = 0

	for _, line in ipairs(lines) do
		if line:find("^@@") then
			hunk = parse_hunk_header(line)
			offset = 0
		elseif hunk then
			local mode = line:sub(1, 1)
			local content = line:sub(2)

			-- Calculate positions considering previous offsets
			local pos = hunk.old_start + offset - 1

			if mode == "-" then
				table.remove(result, pos)
				offset = offset - 1
			elseif mode == "+" then
				table.insert(result, pos, content)
				offset = offset + 1
			elseif mode == " " then
				-- Verify unchanged line matches
				if result[pos] ~= content then
					error("Patch mismatch at line " .. pos)
				end
			end
		end
	end

	return result
end

return M
