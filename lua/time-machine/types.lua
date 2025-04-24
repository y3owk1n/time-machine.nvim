---@class TimeMachine.Config
---@field diff_tool? "native"|"difft" The diff tool to use
---@field diff_opts? vim.diff.Opts The options for vim.diff
---@field ignore_filesize? integer|nil The file size to ignore undo saved to disk
---@field ignored_filetypes? string[] The file types to ignore undo saved to disk

---@class TimeMachine.SeqMapRaw
---@field entry vim.fn.undotree.entry The undotree entry
---@field parent_seq integer|nil The parent sequence number
---@field children_seq integer[] The child sequence numbers
---@field branch_id integer|nil The branch ID

---@class TimeMachine.TreeLine
---@field content string The content of the line
---@field seq integer The sequence number
---@field column integer The column number
