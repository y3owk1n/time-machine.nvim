---@class TimeMachine.Config
---@field db_path? string The path to the database file
---@field auto_save? boolean Whether to automatically save snapshots
---@field max_indent? number The maximum indent level for snapshots
---@field interval_ms? number The interval in milliseconds to check for changes
---@field debounce_ms? number The debounce time in milliseconds
---@field retention_days? number The number of days to retain snapshots
---@field max_snapshots? number The maximum number of snapshots to retain
---@field ignored_buftypes? string[] The buffer types to ignore
---@field enable_telescope? boolean Whether to enable the Telescope extension

---@class TimeMachine.History
---@field snapshots TimeMachine.Snapshot[] The list of snapshots
---@field root TimeMachine.Snapshot The root snapshot
---@field current TimeMachine.Snapshot The current snapshot

---@class TimeMachine.Snapshot
---@field id string The snapshot ID
---@field parent string|nil The parent snapshot ID
---@field diff? string The diff between the parent and current snapshot
---@field content string The content of the snapshot
---@field timestamp integer The timestamp of the snapshot
---@field binary boolean Whether the snapshot is binary
---@field tags string[] The tags associated with the snapshot
---@field is_current boolean Whether the snapshot is the current snapshot

---@class TimeMachine.Hunk : TimeMachine.HunkHeader
---@field lines string[] The lines in the hunk
---@field raw_header string The raw header line

---@class TimeMachine.HunkHeader
---@field old_start integer The start line of the old hunk
---@field old_count integer The number of lines in the old hunk
---@field new_start integer The start line of the new hunk
---@field new_count integer The number of lines in the new hunk

---@class TimeMachine.TreeNode
---@field snap TimeMachine.Snapshot The snapshot
---@field children TimeMachine.TreeNode[] The list of child nodes
