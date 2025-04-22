local M = {}

M.constants = {
	native_float_buftype = "time-machine-list",
	id_map_buf_var = "time_machine_id_map",
	ns = vim.api.nvim_create_namespace("time-machine"),
	events = {
		snapshot_created = "TimeMachineSnapshotCreated",
		snapshot_set_current = "TimeMachineSnapshotSetCurrent",
		snapshot_deleted = "TimeMachineSnapshotDeleted",
	},
}

return M
