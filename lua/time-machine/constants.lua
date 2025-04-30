local M = {}

M.constants = {
	time_machine_ft = "time-machine-list",
	seq_map_buf_var = "time_machine_seq_map",
	content_buf_var = "time_machine_content_buf",
	ns = vim.api.nvim_create_namespace("time-machine"),
	events = {
		undo_created = "TimeMachineUndoCreated",
		undo_called = "TimeMachineUndoCalled",
		redo_called = "TimeMachineRedoCalled",
		undo_restored = "TimeMachineUndoRestored",
		undofile_deleted = "TimeMachineUndofileDeleted",
		tags_created = "TimeMachineTagsCreated",
	},
	hl = {
		current = "TimeMachineCurrent",
		timeline = "TimeMachineTimeline",
		timeline_alt = "TimeMachineTimelineAlt",
		keymap = "TimeMachineKeymap",
		info = "TimeMachineInfo",
		seq = "TimeMachineSeq",
		tag = "TimeMachineTag",
		normal = "TimeMachineNormal",
		border = "TimeMachineBorder",
	},
	icons = {
		saved = "◆",
		point = "○",
		tag = "◼",
		line_vertical = "│",
		line_t_down = "┴",
		line_corner_b_right = "╯",
		line_corner_t_left = "╭",
		line_horizontal = "─",
	},
}

return M
