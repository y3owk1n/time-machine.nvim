local M = {}

local constants = require("time-machine.constants").constants
local undotree = require("time-machine.undotree")

local tags_dir = vim.fn.stdpath("data") .. "/time_machine/tags"

-- Returns the tag-file path for this buffer’s undo history.
---@param bufnr number The buffer whose undofile we want to find
---@return string|nil The path to the tagfile, or nil if none
function M.get_tags_path(bufnr)
	local uf = undotree.get_undofile(bufnr)
	if not uf then
		return nil
	end

	-- take just the filename (hash) of the undofile
	local base = vim.fn.fnamemodify(uf, ":t")
	vim.fn.mkdir(tags_dir, "p")
	return tags_dir .. "/" .. base .. ".json"
end

-- Load the tags for this buffer’s undo history (or {} if none)
---@param bufnr number The buffer whose undofile we want to find
---@return table<string, string[]> The tags for this buffer’s undo history
function M.load_tags(bufnr)
	local path = M.get_tags_path(bufnr)
	if not path or vim.fn.filereadable(path) == 0 then
		return {}
	end
	local lines = vim.fn.readfile(path)
	local ok, tbl = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
	return (ok and type(tbl) == "table") and tbl or {}
end

-- Save `tags` (a table mapping seq-string → list-of-tags) for `bufnr`
---@param tags table<string, string[]> The tags for this buffer’s undo history
---@param bufnr number The buffer whose undofile we want to find
local function save_tags(tags, bufnr)
	local path = M.get_tags_path(bufnr)
	if not path then
		vim.notify("Cannot save tags: no undofile for this buffer", vim.log.levels.WARN)
		return
	end
	local json = vim.fn.json_encode(tags)
	vim.fn.writefile(vim.split(json, "\n"), path)
end

--- Prompt for comma-sep tags and save them for the undo-sequence under the cursor
---@param line_no number  Cursor line in the snapshot UI buffer
---@param ui_bufnr number  The snapshot UI buffer
---@param main_bufnr number The real buffer whose undo history we're tagging
---@param success_cb function|nil  Optional callback to call after tags are saved
function M.tag_sequence(line_no, ui_bufnr, main_bufnr, success_cb)
	---@type table<string, string[]>
	local seq_map = vim.api.nvim_buf_get_var(ui_bufnr, constants.seq_map_buf_var)
	local seq = seq_map[line_no]
	if not seq or seq == "" or seq == 0 then
		return
	end

	local tags = M.load_tags(main_bufnr)
	local current_tags = tags[tostring(seq)] or {}

	vim.ui.input(
		{ prompt = string.format("Tags for seq %d (comma-sep): ", seq), default = table.concat(current_tags, ", ") },
		function(input)
			if input == nil then
				vim.notify("Tagging aborted", vim.log.levels.INFO)
				return
			end

			if input:match("^%s*$") then
				tags[tostring(seq)] = nil
				save_tags(tags, main_bufnr)
				vim.notify(string.format("Removed tags for seq %d", seq), vim.log.levels.INFO)
				if success_cb then
					success_cb()
				end
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

			-- load, assign, save
			tags[tostring(seq)] = list
			save_tags(tags, main_bufnr)

			vim.notify(string.format("Saved tags [%s] for seq %d", table.concat(list, ", "), seq), vim.log.levels.INFO)

			if success_cb then
				success_cb()
			end
		end
	)
end

function M.remove_tagfiles()
	for _, f in ipairs(vim.fn.glob(tags_dir .. "/*", false, true)) do
		pcall(os.remove, f)
	end
	vim.notify("Removed all tagfiles", vim.log.levels.INFO)
end

function M.remove_tagfile(bufnr)
	local path = M.get_tags_path(bufnr)
	if path and vim.fn.filereadable(path) == 1 then
		os.remove(path)
		vim.notify("Removed tagfile: " .. path, vim.log.levels.INFO)
	else
		vim.notify("No tagfile found: " .. path, vim.log.levels.WARN)
	end
end

return M
