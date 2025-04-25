local M = {}

local constants = require("time-machine.constants").constants

-- Returns the on-disk path of the undo-file Neovim would use for `bufnr`.
---@param bufnr number The buffer whose undofile we want to find
---@return string|nil The path to the undofile, or nil if none
local function get_undofile_path(bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return nil
	end
	local uf = vim.fn.undofile(name)
	return (uf ~= "" and uf) or nil
end

-- Returns the tag-file path for this buffer’s undo history.
---@param bufnr number The buffer whose undofile we want to find
---@return string|nil The path to the tagfile, or nil if none
function M.get_tags_path(bufnr)
	local uf = get_undofile_path(bufnr)
	if not uf then
		return nil
	end

	-- take just the filename (hash) of the undofile
	local base = vim.fn.fnamemodify(uf, ":t")
	local dir = vim.fn.stdpath("data") .. "/time_machine/tags"
	vim.fn.mkdir(dir, "p")
	return dir .. "/" .. base .. ".json"
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
	local seq_map = vim.api.nvim_buf_get_var(ui_bufnr, constants.seq_map_buf_var)
	local seq = seq_map[line_no]
	if not seq then
		vim.notify("No undo-seq on this line!", vim.log.levels.WARN)
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

return M
