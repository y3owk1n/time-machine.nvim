---@class TimeMachine.Config
---@field ignore_filesize? integer|nil The file size to ignore undo
---@field ignored_filetypes? string[] The file types to ignore

---@class TimeMachine.Config.AutoSave
---@field enabled? boolean Whether to automatically save snapshots
---@field debounce_ms? number The debounce time in milliseconds
---@field events? string[] The events to trigger auto snapshot saving
---@field save_on_buf_read? boolean Whether to save a snapshot on `BufReadPost`
---@field save_on_write? boolean Wether to save a snapshot on write

---@class TimeMachine.Snapshot
---@field id string The snapshot ID
---@field parent string|nil The parent snapshot ID
---@field diff? string The diff between the parent and current snapshot
---@field content string The content of the snapshot
---@field timestamp integer The timestamp of the snapshot
---@field tags string[] The tags associated with the snapshot
---@field is_current boolean Whether the snapshot is the current snapshot

---@class TimeMachine.SeqMap
---@field entry vim.fn.undotree.entry The undotree entry
---@field parent_seq integer|nil The parent sequence number
---@field children_seq integer[] The child sequence numbers
---@field branch_id integer|nil The branch ID

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
