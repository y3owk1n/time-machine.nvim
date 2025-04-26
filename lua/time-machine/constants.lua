local M = {}

M.constants = {
	time_machine_ft = "time-machine-list",
	seq_map_buf_var = "time_machine_seq_map",
	content_buf_var = "time_machine_content_buf",
	ns = vim.api.nvim_create_namespace("time-machine"),
	events = {
		undo_created = "TimeMachineUndoCreated",
		undo_restored = "TimeMachineUndoRestored",
		undofile_deleted = "TimeMachineUndofileDeleted",
	},
	hl = {
		current = "TimeMachineCurrent",
		timeline = "TimeMachineTimeline",
		keymap = "TimeMachineKeymap",
		info = "TimeMachineInfo",
		seq = "TimeMachineSeq",
		tag = "TimeMachineTag",
	},
	icons = {
		saved = "◆ ",
		point = "○ ",
		tag = "◼ ",
	},
}

return M
