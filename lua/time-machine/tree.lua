local M = {}

local constants = require("time-machine.constants").constants
local utils = require("time-machine.utils")
local logger = require("time-machine.logger")

-- Build a sequence map with direct parent references
---@param entries vim.fn.undotree.entry[]
---@param tags string[] The tags for this buffer’s undo history
---@return TimeMachine.SeqMapRaw seq_map_raw The sequence map in raw
local function build_seq_map_raw(entries, tags)
	logger.debug(
		"build_seq_map_raw() called with %d entries, %d tag entries",
		#entries,
		vim.tbl_count(tags or {})
	)

	local seq_map_raw = {}

	local function walk(entry, branch_idx)
		logger.debug("Visiting seq %d on branch %d", entry.seq, branch_idx or 0)

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
	logger.info("Built raw seq map with %d entries", #seq_map_raw)

	return seq_map_raw
end

--- Get the max column for indentation
---@param seq_map_raw TimeMachine.SeqMapRaw
---@return integer max_column
local function get_max_column(seq_map_raw)
	logger.debug("get_max_column() called")

	local max_branch_id = 0
	for _, seq in ipairs(seq_map_raw) do
		if seq.branch_id and seq.branch_id > max_branch_id then
			max_branch_id = seq.branch_id
		end
	end

	logger.info("Max indentation column: %d", max_branch_id)
	return max_branch_id
end

-- Create the visual tree representation
---@param ut vim.fn.undotree.ret
---@param seq_map TimeMachine.SeqMap The map of line numbers to seqs
---@param tags string[] The tags for this buffer’s undo history
---@param show_current_timeline_only? boolean Whether to only show the current timeline
---@return TimeMachine.TreeLine[] tree_lines The tree lines
function M.build_tree_lines(ut, seq_map, tags, show_current_timeline_only)
	local entry_count = ut and ut.entries and #ut.entries or 0
	logger.debug(
		"build_tree_lines() called with %d entries, %d tags, show_current=%s",
		entry_count,
		vim.tbl_count(tags or {}),
		tostring(show_current_timeline_only)
	)

	if entry_count == 0 then
		logger.warn("No undotree entries found; returning empty tree_lines")
		return {}
	end

	show_current_timeline_only = show_current_timeline_only or false

	local seq_map_raw = build_seq_map_raw(ut.entries, tags)

	if show_current_timeline_only then
		logger.info("Filtering to current timeline only")
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
	logger.debug("Sorted %d sequences for display", #all_seqs)

	local max_column = get_max_column(seq_map_raw)
	local tree_lines = {}
	local verticals = {} --- track active vertical lines per column

	for _, seq in ipairs(all_seqs) do
		local info = seq_map_raw[seq]
		local entry = info.entry
		local col = info.branch_id or 0

		logger.debug("Rendering seq %d at column %d", seq, col)

		local line = {}

		--- draw vertical lines
		for c = 0, max_column do
			--- only draw for the root node
			if seq == 1 then
				--- last character
				if c == max_column then
					line[c + 1] =
						string.format("%s ", constants.icons.tree_vertical_last)
				else
					line[c + 1] =
						string.format("%s ", constants.icons.tree_vertical_join)
				end
			else
				line[c + 1] = verticals[c]
						and string.format("%s ", constants.icons.tree_vertical)
					or "  "
			end

			--- force current timeline to have separator always (1st column)
			if c == 0 then
				line[c + 1] =
					string.format("%s ", constants.icons.tree_vertical)
			end
		end

		-- draw symbol
		line[col + 1] = (
			entry.save
			and entry.save > 0
			and string.format("%s ", constants.icons.saved)
		) or string.format("%s ", constants.icons.point)

		verticals[col] = true

		-- Add info text
		local info_text = string.format(
			"%s %s %s",
			(entry.seq == 0 and "[root]") or ("[" .. tostring(entry.seq) .. "]"),
			entry.time and utils.relative_time(entry.time) or "",
			info.tags
					and #info.tags > 0
					and (string.format("%s ", constants.icons.tag) .. table.concat(
						info.tags,
						", "
					) .. " ")
				or ""
		)

		table.insert(tree_lines, {
			content = table.concat(line) .. info_text,
			seq = entry.seq,
			column = col,
		})
		seq_map[#tree_lines] = seq - 1
	end

	logger.info("Built %d tree lines", #tree_lines)

	return tree_lines
end

return M
