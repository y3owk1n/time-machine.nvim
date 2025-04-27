---@alias TimeMachine.DiffTool "native"|TimeMachine.DiffToolExternal
---@alias TimeMachine.DiffToolExternal "difft"|"diff"|"delta"
---@alias TimeMachine.SplitDirection 'left'|'right'
---@alias TimeMachine.SeqMap table<integer, string|integer[]>

---@class TimeMachine.Config
---@field diff_tool? TimeMachine.DiffTool The diff tool to use
---@field native_diff_opts? vim.diff.Opts The options for vim.diff
---@field external_diff_args? table<TimeMachine.DiffToolExternal, string[]> The arguments for external diff tools
---@field ignore_filesize? integer|nil The file size to ignore undo saved to disk
---@field ignored_filetypes? string[] The file types to ignore undo saved to disk
---@field split_opts? TimeMachine.Config.SplitOpts The split options
---@field float_opts? TimeMachine.Config.FloatOpts The floating window options
---@field keymaps? TimeMachine.Config.Keymaps The keymaps for actions
---@field log_level? integer The log level
---@field log_file? string The log file path

---@class TimeMachine.Config.Keymaps
---@field undo? string The keymap to undo
---@field redo? string The keymap to redo
---@field restore_undopoint? string The keymap to restore the undopoint
---@field refresh_timeline? string The keymap to refresh the timeline
---@field preview_sequence_diff? string The keymap to preview the sequence diff
---@field tag_sequence? string The keymap to tag the sequence
---@field close? string The keymap to close the timeline
---@field help? string The keymap to show the help
---@field toggle_current_timeline? string The keymap to toggle to only show the current timeline

---@class TimeMachine.Config.SplitOpts
---@field split? TimeMachine.SplitDirection The split direction
---@field width? integer The width of the split

---@class TimeMachine.Config.FloatOpts
---@field width? integer The width of the window
---@field height? integer The height of the window

---@class TimeMachine.SeqMapRaw
---@field entry vim.fn.undotree.entry The undotree entry
---@field branch_id integer|nil The branch ID
---@field tags string[] The tags

---@class TimeMachine.TreeLine
---@field content string The content of the line
---@field seq integer The sequence number
---@field column integer The column number
