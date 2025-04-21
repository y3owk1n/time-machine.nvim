local api = vim.api
local utils = require("time-machine.utils")
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
	footer = "Remember to :wq to save and exit",
	footer_pos = "center",
}

--- Create a floating window for native
---@param buf integer The buffer to open
local function create_native_float(buf)
	if native_float then
		if vim.api.nvim_win_is_valid(native_float) then
			vim.api.nvim_win_set_buf(native_float, buf)
			return
		end
	end

	local win_opts = vim.tbl_deep_extend("force", shared_win_opts, {
		title = "Time Machine",
	})

	win_opts.width = math.floor(vim.o.columns * win_opts.width)
	win_opts.height = math.floor(vim.o.lines * win_opts.height)
	win_opts.row = math.floor((vim.o.lines - win_opts.height) / 2)
	win_opts.col = math.floor((vim.o.columns - win_opts.width) / 2)

	vim.api.nvim_open_win(buf, true, win_opts)
end

function M.refresh(bufnr, buf_path, id_map)
	if not bufnr or not api.nvim_buf_is_valid(bufnr) then
		return
	end

	local history = require("time-machine.storage").load_history(buf_path)

	if not history then
		vim.notify("No history found for " .. vim.fn.fnamemodify(buf_path, ":~:."), vim.log.levels.ERROR)
		return
	end

	local tree = require("time-machine.tree").build_tree(history)

	local lines = {}

	require("time-machine.tree").format_tree(tree, 0, {}, true, lines, id_map, history.current.id)

	table.insert(id_map, 1, "")
	table.insert(id_map, 1, "")

	api.nvim_set_option_value("modifiable", true, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", false, { scope = "local", buf = bufnr })

	vim.api.nvim_buf_set_lines(bufnr, 2, -1, false, lines)

	api.nvim_set_option_value("modifiable", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", true, { scope = "local", buf = bufnr })

	vim.api.nvim_buf_set_var(bufnr, "time_machine_id_map", id_map)
end

function M.show(history, buf_path, main_bufnr)
	local tree = require("time-machine.tree").build_tree(history)
	local lines = {}
	local id_map = {} -- Maps line numbers to full IDs

	require("time-machine.tree").format_tree(tree, 0, {}, true, lines, id_map, history.current.id)

	-- Insert keymap hints at the top
	table.insert(lines, 1, "")
	table.insert(lines, 1, "[g?] Actions/Help [<CR>] Preview [<leader>r] Restore [q] Close")

	table.insert(id_map, 1, "")
	table.insert(id_map, 1, "")

	local bufnr = api.nvim_create_buf(false, true)

	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	api.nvim_set_option_value("filetype", "time-machine-history", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("buftype", "nofile", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("bufhidden", "wipe", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("swapfile", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("modifiable", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", true, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("buflisted", false, { scope = "local", buf = bufnr })

	api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.preview_snapshot(history, api.nvim_win_get_cursor(0)[1], bufnr, buf_path, main_bufnr)
		end,
	})

	api.nvim_buf_set_keymap(bufnr, "n", "<leader>r", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			M.handle_restore(history, api.nvim_win_get_cursor(0)[1], bufnr, buf_path, main_bufnr)
			M.refresh(bufnr, buf_path, id_map)
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

	vim.api.nvim_buf_set_var(bufnr, "time_machine_id_map", id_map)
end

function M.show_help()
	local help_lines = {
		"## Actions/Help",
		"",
		"`<CR>` **Preview** - Show the diff of the selected snapshot",
		"`<leader>r` **Restore** - Restore the selected snapshot",
		"`q` **Close** - Close the history window",
		"",
	}

	local bufnr = api.nvim_create_buf(false, true)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, help_lines)
	api.nvim_set_option_value("filetype", "markdown", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("buftype", "nofile", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("bufhidden", "wipe", { scope = "local", buf = bufnr })
	api.nvim_set_option_value("swapfile", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("modifiable", false, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("readonly", true, { scope = "local", buf = bufnr })
	api.nvim_set_option_value("buflisted", false, { scope = "local", buf = bufnr })

	api.nvim_buf_set_keymap(bufnr, "n", "q", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			vim.api.nvim_win_close(0, true)
		end,
	})

	create_native_float(bufnr)
end

function M.preview_snapshot(history, line, bufnr, buf_path, main_bufnr)
	local full_id = utils.get_id_from_line(bufnr, line)
	if not full_id then
		return
	end

	local content = {}

	local root_branch_id = require("time-machine.utils").root_branch_id(buf_path)

	if full_id == root_branch_id then
		content = vim.split(history.root.content, "\n")
	else
		local current = history.snapshots[full_id]
		local chain = {}

		-- Collect chain of snapshots from selected to root
		while current do
			table.insert(chain, current)
			current = history.snapshots[current.parent]
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
		local filetype = api.nvim_get_option_value("filetype", { scope = "local", buf = main_bufnr })
		vim.api.nvim_set_option_value("filetype", filetype, { scope = "local", buf = preview_buf })
	else
		vim.api.nvim_set_option_value("filetype", "diff", { scope = "local", buf = preview_buf })
	end

	api.nvim_set_option_value("buftype", "nofile", { scope = "local", buf = preview_buf })
	api.nvim_set_option_value("bufhidden", "wipe", { scope = "local", buf = preview_buf })
	api.nvim_set_option_value("swapfile", false, { scope = "local", buf = preview_buf })
	api.nvim_set_option_value("modifiable", false, { scope = "local", buf = preview_buf })
	api.nvim_set_option_value("readonly", true, { scope = "local", buf = preview_buf })
	api.nvim_set_option_value("buflisted", false, { scope = "local", buf = preview_buf })

	api.nvim_buf_set_keymap(preview_buf, "n", "q", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			vim.api.nvim_win_close(0, true)
		end,
	})

	create_native_float(preview_buf)
end

function M.handle_restore(history, line, bufnr, buf_path, main_bufnr)
	local full_id = utils.get_id_from_line(bufnr, line)
	if not full_id or full_id == "" then
		return
	end

	require("time-machine.actions").restore_snapshot(history.snapshots[full_id], buf_path, main_bufnr)
end

return M
