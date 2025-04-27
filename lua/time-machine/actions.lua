local ui = require("time-machine.ui")
local constants = require("time-machine.constants").constants
local undotree = require("time-machine.undotree")
local tags = require("time-machine.tags")
local utils = require("time-machine.utils")
local logger = require("time-machine.logger")

local M = {}

--- Show the undotree for a buffer
---@return nil
function M.toggle()
	local cur_bufnr = vim.api.nvim_get_current_buf()
	logger.debug("toggle() called for buffer %d", cur_bufnr)

	--- if the current buffer is a time machine buffer, close it
	if utils.is_time_machine_active(cur_bufnr) then
		logger.info("Time-machine buffer %d is active, closing it", cur_bufnr)
		utils.close_buf(cur_bufnr)
		return
	end

	-- Skip unnamed buffers
	if vim.api.nvim_buf_get_name(cur_bufnr) == "" then
		logger.info("Skipping unnamed buffer %d", cur_bufnr)
		return
	end

	-- Skip unlisted buffers
	if not vim.api.nvim_get_option_value("buflisted", { buf = cur_bufnr }) then
		logger.info("Skipping unlisted buffer %d", cur_bufnr)
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
				logger.debug(
					"Window %d refers to buffer %d, not current %d; closing",
					time_machine_win,
					content_bufnr,
					cur_bufnr
				)
				utils.close_win(time_machine_win)
			else
				logger.info(
					"Time-machine already open for buffer %d; closing view",
					cur_bufnr
				)
				utils.close_buf(time_machine_bufnr)
				return
			end
		end
	end

	local ut = undotree.get_undotree(cur_bufnr)

	if not ut then
		logger.warn("No undotree found for buffer %d", cur_bufnr)
		vim.notify("No undotree found", vim.log.levels.WARN)
		return
	end

	logger.info("Rendering undotree for buffer %d", cur_bufnr)
	ui.show_tree(ut, cur_bufnr)
end

--- Restore to an undopoint
---@param seq integer The sequence to restore to
---@param content_bufnr integer The main buffer number
---@return nil
function M.restore(seq, content_bufnr)
	logger.debug("restore(%d, %s) called", seq, tostring(content_bufnr))

	if not content_bufnr then
		logger.error("restore() missing content_bufnr for seq %d", seq)
		vim.notify("No content buffer found", vim.log.levels.ERROR)
		return
	end

	vim.api.nvim_buf_call(content_bufnr, function()
		vim.cmd(("undo %d"):format(seq))
	end)

	logger.info("Restored buffer %d to undopoint %d", content_bufnr, seq)
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
	logger.info("purge_all(force=%s) called", tostring(force))

	local function action()
		logger.debug("Removing all tagfiles and undofiles")
		--- remove tag files first, as it needs the undotree info
		tags.remove_tagfiles()
		undotree.remove_undofiles()
		logger.info("Successfully purged ALL undofiles")
	end

	if not force then
		vim.ui.select(
			{ "Yes", "No" },
			{ prompt = "Delete ALL undofiles?" },
			function(choice)
				if choice == "Yes" then
					local ok, err = pcall(action)

					if not ok then
						logger.error(
							"Failed to purge all undofiles: %s",
							tostring(err)
						)
						vim.notify(
							"Failed to purge all undofiles: " .. tostring(err),
							vim.log.levels.ERROR
						)
					end
				else
					logger.info("User canceled purge_all()")
				end
			end
		)

		return
	end

	local ok, err = pcall(action)

	if not ok then
		logger.error("Failed to purge all undofiles: %s", tostring(err))
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
	logger.info("purge_buffer(buffer=%d, force=%s)", cur_bufnr, tostring(force))

	local persistent = vim.api.nvim_get_option_value(
		"undofile",
		{ scope = "local", buf = cur_bufnr }
	)

	--- no need to purge if there's no persistent undofile
	if not persistent then
		logger.warn("No persistent undofile for buffer %d", cur_bufnr)
		vim.notify("No undofile found for current buffer", vim.log.levels.WARN)
		return
	end

	local function action()
		logger.debug("Removing tagfile and undofile for buffer %d", cur_bufnr)
		--- remove tag file first, as it needs the undotree info
		tags.remove_tagfile(cur_bufnr)
		undotree.remove_undofile(cur_bufnr)
		logger.info("Successfully purged undofile for buffer %d", cur_bufnr)
	end

	if not force then
		vim.ui.select(
			{ "Yes", "No" },
			{ prompt = "Delete the current undofile?" },
			function(choice)
				if choice == "Yes" then
					local ok, err = pcall(action)

					if not ok then
						logger.error(
							"Failed to purge undofile for buffer %d: %s",
							cur_bufnr,
							tostring(err)
						)
						vim.notify(
							"Failed to purge the current undofiles: "
								.. tostring(err),
							vim.log.levels.ERROR
						)
					end
				else
					logger.info(
						"User canceled purge_buffer() on buffer %d",
						cur_bufnr
					)
				end
			end
		)
		return
	end

	local ok, err = pcall(action)

	if not ok then
		logger.error(
			"Failed to purge undofile for buffer %d: %s",
			cur_bufnr,
			tostring(err)
		)
		vim.notify(
			"Failed to purge the current undofiles: " .. tostring(err),
			vim.log.levels.ERROR
		)
	end
end

--- Purge the log file, actually instead of clearing it, we just remove the file instead
---@param force? boolean Whether to force the purge
---@return nil
function M.clear_log(force)
	logger.info("clear_log(force=%s) called", tostring(force))

	if not force then
		vim.ui.select(
			{ "Yes", "No" },
			{ prompt = "Clear the log file?" },
			function(choice)
				if choice == "Yes" then
					local ok, err = pcall(logger.delete_log_file)

					if not ok then
						logger.error(
							"Failed to clear the log file: %s",
							tostring(err)
						)
					end
				else
					logger.info("User canceled clear_log()")
				end
			end
		)

		return
	end

	local ok, err = pcall(logger.delete_log_file)

	if not ok then
		logger.error("Failed to clear the log file: %s", tostring(err))
	end
end

--- Show the log file
---@return nil
function M.show_log()
	require("time-machine.ui").show_log()
end

return M
