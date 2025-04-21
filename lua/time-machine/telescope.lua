local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

--- Finder function for snapshots
---@param buf_path string The path to the buffer
---@return TimeMachine.Snapshot[] snapshots The list of snapshots
local function snapshot_finder(buf_path)
	local history = require("time-machine").load_history(buf_path)
	local items = {}

	for _, snap in pairs(history.snapshots) do
		table.insert(items, {
			value = snap,
			display = string.format(
				"%s %s %s",
				os.date("%H:%M", snap.timestamp),
				snap.id:sub(1, 6),
				table.concat(snap.tags, ", ")
			),
			ordinal = snap.timestamp,
		})
	end

	return finders.new_table({
		results = items,
		entry_maker = function(entry)
			return {
				value = entry.value,
				display = entry.display,
				ordinal = entry.ordinal,
			}
		end,
	})
end

--- Show the history for the current buffer
---@return nil
function M.show_history()
	local buf_path = require("time-machine").get_buf_path(0)
	if not buf_path then
		return
	end

	pickers
		.new({}, {
			prompt_title = "Time Machine: " .. vim.fn.fnamemodify(buf_path, ":~:."),
			finder = snapshot_finder(buf_path),
			sorter = conf.generic_sorter(),
			previewer = require("time_machine").diff_previewer(),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					require("time-machine").restore_snapshot(selection.value)
				end)
				return true
			end,
		})
		:find()
end

return M
