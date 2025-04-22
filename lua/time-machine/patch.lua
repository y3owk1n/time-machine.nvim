local M = {}

--- Parse a hunk header
---@param line string The hunk header line
---@return TimeMachine.HunkHeader|nil parsed_hunk_header The parsed hunk header
function M.parse_hunk_header(line)
	-- Allow flexible whitespace and trailing context
	local old_part, new_part = line:match("^@@%s*-%s*(%d+,?%d*)%s+%+%s*(%d+,?%d*)%s*@@.*")
	if not old_part or not new_part then
		return nil
	end

	-- Parse old range (handle single-line cases)
	local old_start, old_count = old_part:match("^(%d+)%,?(%d*)$")
	old_start = tonumber(old_start)
	old_count = old_count == "" and 1 or math.max(tonumber(old_count) or 1, 1)

	-- Parse new range (handle creation/deletion cases)
	local new_start, new_count = new_part:match("^(%d+)%,?(%d*)$")
	new_start = tonumber(new_start)
	new_count = new_count == "" and 1 or math.max(tonumber(new_count) or 1, 1)

	return {
		old_start = old_start,
		old_count = old_count,
		new_start = new_start,
		new_count = new_count,
	}
end

--- Apply a diff to a parent content
---@param parent_content string The parent content
---@param diff string The diff to apply
---@return string diffed_content The updated parent content
function M.apply_diff(parent_content, diff)
	---@type string[]
	local parent_lines = parent_content ~= "" and vim.split(parent_content, "\n") or {}

	---@type TimeMachine.Hunk[]
	local hunks = {}

	---@type TimeMachine.Hunk|nil
	local current_hunk = nil

	for _, line in ipairs(vim.split(diff, "\n")) do
		if line:find("^@@") then
			local header = M.parse_hunk_header(line)
			if header then
				current_hunk = {
					old_start = header.old_start,
					old_count = header.old_count,
					new_start = header.new_start,
					new_count = header.new_count,
					lines = {},
					raw_header = line,
				}
				table.insert(hunks, current_hunk)
			else
				vim.notify("Skipping malformed hunk: " .. line, vim.log.levels.WARN)
			end
		elseif current_hunk then
			table.insert(current_hunk.lines, line)
		end
	end

	if #parent_lines == 0 then
		local new_content = {}
		for _, hunk in ipairs(hunks) do
			for _, line in ipairs(hunk.lines) do
				if line:sub(1, 1) == "+" then
					new_content[#new_content + 1] = line:sub(2)
				end
			end
		end
		return table.concat(new_content, "\n")
	end

	if #hunks == 0 then
		vim.notify("No valid hunks found in diff", vim.log.levels.WARN)
		return parent_content
	end

	-- Apply hunks in reverse order to maintain correct line numbers
	for i = #hunks, 1, -1 do
		local hunk = hunks[i]
		local pos = hunk.old_start - 1
		local to_remove = hunk.old_count
		local new_lines = {}

		-- Process hunk lines
		for _, line in ipairs(hunk.lines) do
			local prefix = line:sub(1, 1)
			local content = line:sub(2)

			if prefix == " " then
				if parent_lines[pos + 1] ~= content then
					error(
						string.format(
							"Patch mismatch at line %d\nExpected: %s\nActual: %s",
							pos,
							content,
							parent_lines[pos + 1] or ""
						)
					)
				end
				table.insert(new_lines, content)
				pos = pos + 1
				to_remove = to_remove - 1
			elseif prefix == "-" then
				-- Track removal from original
				if parent_lines[pos + 1] ~= content then
					error(
						string.format(
							"Deletion mismatch at line %d\nExpected: %s\nActual: %s",
							pos + 1,
							content,
							parent_lines[pos + 1] or ""
						)
					)
				end
				pos = pos + 1
				to_remove = to_remove - 1
			elseif prefix == "+" then
				table.insert(new_lines, content)
			end
		end

		-- Replace the affected section
		local before = { unpack(parent_lines, 1, hunk.old_start - 1) }
		local after = { unpack(parent_lines, hunk.old_start + hunk.old_count) }
		parent_lines = vim.list_extend(before, vim.list_extend(new_lines, after))
	end

	return table.concat(parent_lines, "\n")
end

return M
