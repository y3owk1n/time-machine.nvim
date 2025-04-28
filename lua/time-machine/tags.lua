local M = {}

local constants = require("time-machine.constants").constants
local undotree = require("time-machine.undotree")
local logger = require("time-machine.logger")

local tags_dir = vim.fn.stdpath("data") .. "/time_machine/tags"

--- Returns the tag-file path for this buffer’s undo history.
---@param content_bufnr number The buffer whose undofile we want to find
---@return string|nil tagfile_path The path to the tagfile, or nil if none
function M.get_tags_path(content_bufnr)
	logger.debug("get_tags_path(%d) called", content_bufnr)

	local ut = undotree.get_undofile_path(content_bufnr)
	if not ut then
		logger.warn(
			"No undofile path for buffer %d; cannot derive tags path",
			content_bufnr
		)
		return nil
	end

	-- filename of the undofile for easier lookup
	local base = vim.fn.fnamemodify(ut, ":t")
	vim.fn.mkdir(tags_dir, "p")
	local path = tags_dir .. "/" .. base .. ".json"
	logger.info("Tagfile path for buffer %d is %s", content_bufnr, path)

	return path
end

--- Load the tags for this buffer’s undo history (or {} if none)
---@param content_bufnr number The buffer whose undofile we want to find
---@return table<string, string[]> tags The tags for this buffer’s undo history
function M.load_tags(content_bufnr)
	logger.debug("load_tags(%d) called", content_bufnr)

	local path = M.get_tags_path(content_bufnr)
	if not path or vim.fn.filereadable(path) == 0 then
		logger.info(
			"No tagfile found at %s; returning empty tags",
			tostring(path)
		)
		return {}
	end

	local lines = vim.fn.readfile(path)
	local ok, tbl = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
	if not ok or type(tbl) ~= "table" then
		logger.error("Failed to decode JSON tags from %s", path)
		return {}
	end

	logger.info("Loaded %d tag entries from %s", vim.tbl_count(tbl), path)
	return tbl
end

--- Save the provided tags
---@param tags_to_save table<string, string[]> The tags for this buffer’s undo history
---@param content_bufnr number The buffer whose undofile we want to find
local function save_tags(tags_to_save, content_bufnr)
	logger.debug(
		"save_tags(buffer=%d) called with %d entries",
		content_bufnr,
		vim.tbl_count(tags_to_save)
	)

	local path = M.get_tags_path(content_bufnr)

	if not path then
		logger.warn(
			"Cannot save tags: no undofile for buffer %d",
			content_bufnr
		)
		vim.notify(
			"Cannot save tags: no undofile for this buffer",
			vim.log.levels.WARN
		)
		return
	end

	local json = vim.fn.json_encode(tags_to_save)
	local ok, err = pcall(vim.fn.writefile, vim.split(json, "\n"), path)
	if not ok then
		logger.error("Failed to write tags to %s: %s", path, tostring(err))
	else
		logger.info("Saved %d tags to %s", vim.tbl_count(tags_to_save), path)
	end
end

--- Prompt for comma-sep tags and save them for the undo-sequence under the cursor
---@param cur_line_no number  Cursor line in the snapshot UI buffer
---@param time_machine_bufnr number  The snapshot UI buffer
---@param content_bufnr number The real buffer whose undo history we're tagging
function M.create_tag(cur_line_no, time_machine_bufnr, content_bufnr)
	logger.debug(
		"create_tag(line=%d, tm_buf=%d, buf=%d)",
		cur_line_no,
		time_machine_bufnr,
		content_bufnr
	)

	local persistent = vim.api.nvim_get_option_value(
		"undofile",
		{ scope = "local", buf = content_bufnr }
	)

	if not persistent then
		logger.warn(
			"Persistent undofile not enabled for buffer %d",
			content_bufnr
		)
		vim.notify("Persistent undofile is not enabled", vim.log.levels.WARN)
		return
	end

	--- Get the sequences map from the buffer variables
	---@type TimeMachine.SeqMap
	local seq_map =
		vim.api.nvim_buf_get_var(time_machine_bufnr, constants.seq_map_buf_var)

	local seq = seq_map[cur_line_no]
	if not seq or seq == "" or seq == 0 then
		logger.info(
			"No valid seq at line %d in buffer %d",
			cur_line_no,
			time_machine_bufnr
		)
		return
	end

	local tags = M.load_tags(content_bufnr)
	local current_tags = tags[tostring(seq)] or {}

	vim.ui.input({
		prompt = string.format("Tags for seq %d (comma-sep): ", seq),
		default = table.concat(current_tags, ", "),
	}, function(input)
		if input == nil then
			logger.info("Tagging aborted for seq %d", seq)
			vim.notify("Tagging aborted", vim.log.levels.INFO)
			return
		end

		if input:match("^%s*$") then
			tags[tostring(seq)] = nil
			save_tags(tags, content_bufnr)
			logger.info("Removed tags for seq %d", seq)
			vim.notify(
				string.format("Removed tags for seq %d", seq),
				vim.log.levels.INFO
			)

			vim.api.nvim_exec_autocmds(
				"User",
				{ pattern = constants.events.tags_created }
			)

			logger.info("Event emitted: %s", constants.events.tags_created)
			return
		end

		-- split & trim
		local list = {}
		for tag in input:gmatch("[^,]+") do
			tag = tag:match("^%s*(.-)%s*$")
			if #tag > 0 then
				table.insert(list, tag)
			end
		end

		tags[tostring(seq)] = list
		save_tags(tags, content_bufnr)

		logger.info("Saved tags [%s] for seq %d", table.concat(list, ", "), seq)

		vim.notify(
			string.format(
				"Saved tags [%s] for seq %d",
				table.concat(list, ", "),
				seq
			),
			vim.log.levels.INFO
		)

		vim.api.nvim_exec_autocmds(
			"User",
			{ pattern = constants.events.tags_created }
		)

		logger.info("Event emitted: %s", constants.events.tags_created)
	end)
end

--- Remove all tagfiles
---@return nil
function M.remove_tagfiles()
	logger.info("remove_tagfiles() called")

	for _, f in ipairs(vim.fn.glob(tags_dir .. "/*", false, true)) do
		local ok, err = pcall(os.remove, f)
		if not ok then
			logger.error("Failed to remove tagfile %s: %s", f, tostring(err))
		else
			logger.debug("Removed tagfile %s", f)
		end
	end

	logger.info("All tagfiles have been removed")
	vim.notify("Removed all tagfiles", vim.log.levels.INFO)
end

-- Remove the tagfile for the given buffer
---@param content_bufnr number The buffer whose tagfile we want to remove
---@return nil
function M.remove_tagfile(content_bufnr)
	logger.debug("remove_tagfile(%d) called", content_bufnr)

	local path = M.get_tags_path(content_bufnr)
	if path and vim.fn.filereadable(path) == 1 then
		local ok, err = pcall(os.remove, path)
		if ok then
			logger.info("Removed tagfile %s", path)
			vim.notify("Removed tagfile: " .. path, vim.log.levels.INFO)
		else
			logger.error("Failed to remove tagfile %s: %s", path, tostring(err))
		end
	else
		logger.warn(
			"No tagfile found to remove for buffer %d at %s",
			content_bufnr,
			tostring(path)
		)
		vim.notify("No tagfile found: " .. path, vim.log.levels.WARN)
	end
end

return M
