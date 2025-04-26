local M = {}

local constants = require("time-machine.constants").constants
local utils = require("time-machine.utils")

-- Build a sequence map with direct parent references
---@param entries vim.fn.undotree.entry[]
---@param tags string[] The tags for this buffer’s undo history
---@return TimeMachine.SeqMapRaw seq_map_raw The sequence map in raw
local function build_seq_map_raw(entries, tags)
	local seq_map_raw = {}

	local function walk(entry, branch_idx)
		seq_map_raw[entry.seq] = seq_map_raw[entry.seq]
			or {
				entry = entry,
				branch_id = branch_idx,
				tags = tags[tostring(entry.seq)] or {},
			}
		if entry.alt then
			for _, child in ipairs(entry.alt) do
				walk(child, (branch_idx or 0) + 1)
			end
		end
	end

	for _, entry in ipairs(entries) do
		walk(entry, 0)
	end

	table.insert(seq_map_raw, 1, { branch_id = 0, entry = { seq = 0 } })

	return seq_map_raw
end

--- Get the max column for indentation
---@param seq_map_raw TimeMachine.SeqMapRaw
---@return integer max_column
local function get_max_column(seq_map_raw)
	local max_branch_id = 0
	for _, seq in ipairs(seq_map_raw) do
		if seq.branch_id and seq.branch_id > max_branch_id then
			max_branch_id = seq.branch_id
		end
	end

	return max_branch_id
end

-- Create the visual tree representation
---@param ut vim.fn.undotree.ret
---@param seq_map TimeMachine.SeqMap The map of line numbers to seqs
---@param tags string[] The tags for this buffer’s undo history
---@param show_current_timeline_only? boolean Whether to only show the current timeline
---@return TimeMachine.TreeLine[] tree_lines The tree lines
function M.build_tree_lines(ut, seq_map, tags, show_current_timeline_only)
	if not ut or not ut.entries or #ut.entries == 0 then
		return {}
	end

	show_current_timeline_only = show_current_timeline_only or false

	local seq_map_raw = build_seq_map_raw(ut.entries, tags)

	if show_current_timeline_only then
		for i, seq in ipairs(seq_map_raw) do
			if seq.branch_id ~= 0 then
				seq_map_raw[i] = nil
			end
		end
	end

	local all_seqs = {}
	for seq in pairs(seq_map_raw) do
		table.insert(all_seqs, seq)
	end

	--- newest first
	table.sort(all_seqs, function(a, b)
		return a > b
	end)

	local max_column = get_max_column(seq_map_raw)
	local tree_lines = {}
	local verticals = {} --- track active vertical lines per column

	for _, seq in ipairs(all_seqs) do
		local info = seq_map_raw[seq]
		local entry = info.entry
		local col = info.branch_id or 0

		local line = {}

		--- draw vertical lines
		for c = 0, max_column do
			line[c + 1] = verticals[c] and "│ " or "  "

			--- force main timeline to have separator always
			if c == 0 then
				line[c + 1] = "│ "
			end
		end

		-- draw symbol
		line[col + 1] = (
			entry.save
			and entry.save > 0
			and constants.icons.saved
		) or constants.icons.point

		verticals[col] = true

		-- Add info text
		local info_text = string.format(
			"%s %s %s",
			(entry.seq == 0 and "[root]") or ("[" .. tostring(entry.seq) .. "]"),
			entry.time and utils.relative_time(entry.time) or "",
			info.tags
					and #info.tags > 0
					and (constants.icons.tag .. table.concat(info.tags, ", ") .. " ")
				or ""
		)

		table.insert(tree_lines, {
			content = table.concat(line) .. info_text,
			seq = entry.seq,
			column = col,
		})
		seq_map[#tree_lines] = seq - 1
	end

	return tree_lines
end

return M
