local api = vim.api
local utils = require("time-machine.utils")
local constants = require("time-machine.constants").constants
local storage = require("time-machine.storage")
local M = {}

local native_float = nil

local winborder = vim.api.nvim_get_option_value("winborder", { scope = "local" }) or "none"

---@type vim.api.keyset.win_config
local shared_win_opts = {
	relative = "editor",
	width = 0.8,
	height = 0.8,
	border = winborder,
	title_pos = "center",
	footer = "Press `q` to exit",
	footer_pos = "center",
}

--- Create a floating window for native
---@param buf integer The buffer to open
---@param title? string The title appended after `Time Machine`
---@return nil
local function create_native_float(buf, title)
	if native_float then
		if vim.api.nvim_win_is_valid(native_float) then
			vim.api.nvim_win_set_buf(native_float, buf)
			return
		end
	end

	local win_opts = vim.tbl_deep_extend("force", shared_win_opts, {
		title = "Time Machine" .. (title and (" - " .. title) or ""),
	})

	win_opts.width = math.floor(vim.o.columns * win_opts.width)
	win_opts.height = math.floor(vim.o.lines * win_opts.height)
	win_opts.row = math.floor((vim.o.lines - win_opts.height) / 2)
	win_opts.col = math.floor((vim.o.columns - win_opts.width) / 2)

	vim.api.nvim_open_win(buf, true, win_opts)
end

--- Set standard buffer options
---@param bufnr integer The buffer number
---@return nil
local function set_standard_buf_options(bufnr)
	api.nvim_set_option_value("buftype", "nofile", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("bufhidden", "wipe", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("swapfile", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("modifiable", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", true, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("buflisted", false, { scope = "local", buf = bufnr })
end

--- Set highlights for the UI
---@param bufnr integer The buffer number
---@param id_map table<integer, string> The map of line numbers to snapshot IDs
---@param current TimeMachine.Snapshot The current snapshot
---@param lines table<integer, string> The lines of the snapshot
---@return nil
local function set_highlights(bufnr, id_map, current, lines)
	api.nvim_buf_clear_namespace(bufnr, constants.ns, 0, -1)

	-- Highlight current snapshot line
	for lineno, id in ipairs(id_map) do
		if id == current.id then
			local line = vim.api.nvim_buf_get_lines(bufnr, lineno - 1, lineno, false)[1]
			local end_col = line and #line or 0

			api.nvim_buf_set_extmark(bufnr, constants.ns, lineno - 1, 0, {
				end_col = end_col,
				hl_group = "TimeMachineCurrent",
			})
			break
		end
	end

	-- Highlight preview markers and tags
	for i, line in ipairs(lines) do
		if line:sub(1, 1) == ">" then
			api.nvim_buf_set_extmark(bufnr, constants.ns, i - 1, 0, {
				end_col = 1,
				hl_group = "TimeMachinePreview",
			})
		end

		for tag in line:gmatch("%b[]") do
			local start_col = line:find(tag, 1, true) - 1
			api.nvim_buf_set_extmark(bufnr, constants.ns, i - 1, start_col, {
				end_col = start_col + #tag,
				hl_group = "TimeMachineTag",
			})
		end
	end
end

--- Set header for the UI
---@param lines table<integer, string> The lines of the snapshot
---@param id_map table<integer, string> The map of line numbers to snapshot IDs
---@return nil
local function set_header(lines, id_map)
	-- Insert keymap hints at the top
	table.insert(lines, 1, "")
	table.insert(
		lines,
		1,
		"[g?] Actions/Help [<CR>] Preview [<leader>r] Restore [<leader>R] Refresh [<leader>t] Tag [q] Close"
	)

	table.insert(id_map, 1, "")
	table.insert(id_map, 1, "")
end

--- Refresh the UI
---@param bufnr integer The buffer number
---@param buf_path string The path to the buffer
---@param id_map table<integer, string> The map of line numbers to snapshot IDs
---@return nil
function M.refresh(bufnr, buf_path, id_map)
	if not bufnr or not api.nvim_buf_is_valid(bufnr) then
		return
	end

	local snapshots = storage.get_snapshots(buf_path)

	local current = storage.get_current_snapshot(buf_path)

	if not snapshots then
		vim.notify("No snapshots found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end

	if not current then
		vim.notify("No current snapshot found", vim.log.levels.ERROR)
		return
	end

	local tree = require("time-machine.tree").build_tree(snapshots)

	local lines = {}

	id_map = {}

	require("time-machine.tree").format_graph(tree, lines, id_map, current.id)

	set_header(lines, id_map)
	api.nvim_set_option_value("modifiable", true, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", false, { scope = "local", buf = bufnr })

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	api.nvim_set_option_value("modifiable", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", true, { scope = "local", buf = bufnr })

	vim.api.nvim_buf_set_var(bufnr, constants.id_map_buf_var, id_map)

	set_highlights(bufnr, id_map, current, lines)
end

--- Show the Snapshot for a buffer
---@param snapshot TimeMachine.Snapshot The snapshot history
---@param current TimeMachine.Snapshot The current snapshot
---@param buf_path string The path to the buffer
---@param main_bufnr integer The main buffer number
---@return nil
function M.show(snapshot, current, buf_path, main_bufnr)
	local tree = require("time-machine.tree").build_tree(snapshot)
	local lines = {}
	local id_map = {} -- Maps line numbers to full IDs

	require("time-machine.tree").format_graph(tree, lines, id_map, current.id)

	set_header(lines, id_map)

	local bufnr = api.nvim_create_buf(false, true)

	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	api.nvim_set_option_value("filetype", constants.native_float_buftype, { scope = "local", buf = bufnr })

	set_standard_buf_options(bufnr)

	set_highlights(bufnr, id_map, current, lines)

	api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.preview_snapshot(api.nvim_win_get_cursor(0)[1], bufnr, buf_path, main_bufnr)
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "<leader>r", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.handle_restore(api.nvim_win_get_cursor(0)[1], bufnr, buf_path, main_bufnr)
			vim.schedule(function()
				M.refresh(bufnr, buf_path, id_map)
			end)
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "<leader>t", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.handle_tag(api.nvim_win_get_cursor(0)[1], bufnr, buf_path)
			vim.schedule(function()
				M.refresh(bufnr, buf_path, id_map)
			end)
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "<leader>R", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.refresh(bufnr, buf_path, id_map)
			vim.notify("Refreshed", vim.log.levels.INFO)
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "q", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			vim.api.nvim_win_close(0, true)
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "g?", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.show_help()
		end,
	})

	vim.api.nvim_open_win(bufnr, true, {
		split = "right",
	})

	vim.api.nvim_buf_set_var(bufnr, constants.id_map_buf_var, id_map)
end

--- Show the help text
---@return nil
function M.show_help()
	local help_lines = {
		"## Actions/Help",
		"",
		"`<CR>` **Preview** - Show the diff of the selected snapshot",
		"`<leader>r` **Restore** - Restore the selected snapshot",
		"`<leader>R` **Refresh** - Refresh the data",
		"`<leader>t` **Tag** - Tag the selected snapshot",
		"`q` **Close** - Close the window",
		"",
	}

	local bufnr = api.nvim_create_buf(false, true)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, help_lines)
	api.nvim_set_option_value("filetype", "markdown", { scope = "local", buf = bufnr })

	set_standard_buf_options(bufnr)

	api.nvim_buf_set_keymap(bufnr, "n", "q", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			vim.api.nvim_win_close(0, true)
		end,
	})

	create_native_float(bufnr, "Help")
end

--- Preview a snapshot
---@param line integer The line number
---@param bufnr integer The buffer number
---@param buf_path string The path to the buffer
---@param main_bufnr integer The main buffer number
---@return nil
function M.preview_snapshot(line, bufnr, buf_path, main_bufnr)
	local full_id = utils.get_id_from_line(bufnr, line)
	if not full_id then
		return
	end

	local snapshots = storage.get_snapshots(buf_path)
	if not snapshots then
		vim.notify("No snapshots found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end

	local root = storage.get_root_snapshot(buf_path)
	if not root then
		vim.notify("No root snapshot found", vim.log.levels.ERROR)
		return
	end

	local content = {}

	local root_branch_id = require("time-machine.utils").root_branch_id(buf_path)

	if full_id == root_branch_id then
		content = vim.split(root.content, "\n")
	else
		local current = snapshots[full_id]
		local chain = {}

		-- Collect chain of snapshots from selected to root
		while current do
			table.insert(chain, current)
			current = snapshots[current.parent]
		end

		-- Append each snapshot diff in order: newest to oldest
		for i = #chain, 1, -1 do
			local snap = chain[i]
			if snap.diff then
				local diff_lines = vim.split(snap.diff, "\n")
				for j = #diff_lines, 1, -1 do
					table.insert(content, 1, diff_lines[j])
				end
			end
		end
	end

	local preview_buf = api.nvim_create_buf(false, true)

	api.nvim_buf_set_lines(preview_buf, 0, -1, false, content)

	if full_id == root_branch_id then
		local filetype = api.nvim_get_option_value("filetype", { scope = "local", buf = main_bufnr }) or "nofile"
		vim.api.nvim_set_option_value("filetype", filetype, { scope = "local", buf = preview_buf })
	else
		vim.api.nvim_set_option_value("filetype", "diff", { scope = "local", buf = preview_buf })
	end

	set_standard_buf_options(preview_buf)

	api.nvim_buf_set_keymap(preview_buf, "n", "q", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			vim.api.nvim_win_close(0, true)
		end,
	})

	create_native_float(preview_buf, "Preview")
end

--- Handle the restore action
---@param line integer The line number
---@param bufnr integer The buffer number
---@param buf_path string The path to the buffer
---@param main_bufnr integer The main buffer number
---@return nil
function M.handle_restore(line, bufnr, buf_path, main_bufnr)
	local full_id = utils.get_id_from_line(bufnr, line)
	if not full_id or full_id == "" then
		return
	end

	local snapshot = storage.get_snapshot_by_id(full_id, buf_path)

	if not snapshot then
		vim.notify("No snapshot found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end

	require("time-machine.actions").restore_snapshot(snapshot, buf_path, main_bufnr)
end

--- Handle the restore action
---@param line integer The line number
---@param bufnr integer The buffer number
---@param buf_path string The path to the buffer
---@return nil
function M.handle_tag(line, bufnr, buf_path)
	local full_id = utils.get_id_from_line(bufnr, line)
	if not full_id or full_id == "" then
		return
	end

	local snapshot = storage.get_snapshot_by_id(full_id, buf_path)

	if not snapshot then
		vim.notify("No snapshot found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end

	require("time-machine.actions").tag_snapshot(nil, snapshot, buf_path)
end

return M
