local ui = require("time-machine.ui")
local constants = require("time-machine.constants").constants
local undotree = require("time-machine.undotree")
local tags = require("time-machine.tags")
local utils = require("time-machine.utils")

local M = {}

--- Show the undotree for a buffer
---@return nil
function M.toggle()
	local cur_bufnr = vim.api.nvim_get_current_buf()

	-- Skip unnamed buffers
	if vim.api.nvim_buf_get_name(cur_bufnr) == "" then
		vim.notify(
			"Current buffer has no name, cannot show undotree",
			vim.log.levels.WARN
		)
		return
	end

	-- Skip unlisted buffers
	if not vim.api.nvim_get_option_value("buflisted", { buf = cur_bufnr }) then
		vim.notify(
			"Current buffer is not listed, cannot show undotree",
			vim.log.levels.WARN
		)
		return
	end

	--- if the current buffer is a time machine buffer, close it
	if utils.is_time_machine_active(cur_bufnr) then
		utils.close_buf(cur_bufnr)
		return
	end

	local time_machine_win = utils.get_time_machine_win()

	--- if time machine buffer is found, check if it's refering the same buffer as current buffer, if not then close it and later open the latest version
	if time_machine_win then
		if vim.api.nvim_win_is_valid(time_machine_win) then
			local time_machine_bufnr =
				vim.api.nvim_win_get_buf(time_machine_win)
			local content_bufnr = vim.api.nvim_buf_get_var(
				time_machine_bufnr,
				constants.content_buf_var
			)

			if content_bufnr ~= cur_bufnr then
				utils.close_win(time_machine_win)
			else
				utils.close_buf(time_machine_bufnr)
				return
			end
		end
	end

	local ut = undotree.get_undotree(cur_bufnr)

	if not ut then
		vim.notify("No undotree found", vim.log.levels.WARN)
		return
	end

	ui.show_tree(ut, cur_bufnr)
end

--- Restore to an undopoint
---@param seq integer The sequence to restore to
---@param content_bufnr integer The main buffer number
---@return nil
function M.restore(seq, content_bufnr)
	if not content_bufnr then
		vim.notify("No content buffer found", vim.log.levels.ERROR)
	end

	vim.api.nvim_buf_call(content_bufnr, function()
		vim.cmd(("undo %d"):format(seq))
	end)

	vim.notify(("Restored to undopoint %d"):format(seq), vim.log.levels.INFO)

	vim.api.nvim_exec_autocmds(
		"User",
		{ pattern = constants.events.undo_restored }
	)
end

--- Purge all undofiles
---@param force? boolean Whether to force the purge
---@return nil
function M.purge_all(force)
	if not force then
		local confirm = vim.fn.input("Delete ALL undofiles? [y/N] ")
		if confirm:lower() ~= "y" then
			return
		end
	end

	local ok, err = pcall(function()
		--- remove tag files first, as it needs the undotree info
		tags.remove_tagfiles()
		undotree.remove_undofiles()
	end)

	if not ok then
		vim.notify(
			"Failed to purge all undofiles: " .. tostring(err),
			vim.log.levels.ERROR
		)
	end
end

--- Purge the current buffer undofile
---@param force? boolean Whether to force the purge
---@return nil
function M.purge_buffer(force)
	local cur_bufnr = vim.api.nvim_get_current_buf()

	local persistent = vim.api.nvim_get_option_value(
		"undofile",
		{ scope = "local", buf = cur_bufnr }
	)

	--- no need to purge if there's no persistent undofile
	if not persistent then
		vim.notify("No undofile found for current buffer", vim.log.levels.WARN)
		return
	end

	if not force then
		local confirm =
			vim.fn.input("Delete the current undofile" .. "? [y/N] ")
		if confirm:lower() ~= "y" then
			return
		end
	end

	--- remove tag file first, as it needs the undotree info
	tags.remove_tagfile(0)
	undotree.remove_undofile(0)
end

return M
