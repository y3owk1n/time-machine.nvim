local M = {}

M.constants = {
	time_machine_ft = "time-machine-list",
	seq_map_buf_var = "time_machine_seq_map",
	ns = vim.api.nvim_create_namespace("time-machine"),
	events = {
		undo_created = "TimeMachineUndoCreated",
		undo_restored = "TimeMachineUndoRestored",
		undofile_deleted = "TimeMachineUndofileDeleted",
	},
	hl = {
		current = "TimeMachineCurrent",
		keymap = "TimeMachineKeymap",
		info = "TimeMachineInfo",
	},
}

return M
