---@alias TimeMachine.DiffTool "native"|"difft"|"diff"
---@alias TimeMachine.SplitDirection 'left'|'right'|'above'|'below'

---@class TimeMachine.Config
---@field diff_tool? TimeMachine.DiffTool The diff tool to use
---@field native_diff_opts? vim.diff.Opts The options for vim.diff
---@field ignore_filesize? integer|nil The file size to ignore undo saved to disk
---@field ignored_filetypes? string[] The file types to ignore undo saved to disk
---@field split_opts? TimeMachine.SplitOpts The split options

---@class TimeMachine.SplitOpts
---@field split? TimeMachine.SplitDirection The split direction
---@field width? integer The width of the split
---@field height? integer The height of the split

---@class TimeMachine.SeqMapRaw
---@field entry vim.fn.undotree.entry The undotree entry
---@field parent_seq integer|nil The parent sequence number
---@field children_seq integer[] The child sequence numbers
---@field branch_id integer|nil The branch ID
---@field tags string[] The tags

---@class TimeMachine.TreeLine
---@field content string The content of the line
---@field seq integer The sequence number
---@field column integer The column number
