# time-machine.nvim

> Undo. Redo. **Time travel**. Take control of your edit history like never before.

Interactive timeline, diff previews, bookmarks, hot reloading, and undo file management - everything you need to master your editing history.

<!-- panvimdoc-ignore-start -->

![time-machine-demo](https://github.com/user-attachments/assets/b35a8ddd-b418-4ff8-a291-ea4c6a80228e)

<!-- panvimdoc-ignore-end -->

> [!warning]
>
> - The documentation may not cover all the features of the plugin. I will update it as we go.
> - There is no test yet for now, but it will be added soon. Hopefully nothing breaks.
> - The plugin will never be perfect for everyone, but if you have any workflow or feature request, please open an issue, better yet, a PR.

## ✨ Why Time Machine?

Unlike standard undo/redo functionality, Time Machine gives you:

- Complete visibility into your entire editing history
- Non-linear navigation through branches of changes
- Persistent bookmarks to save important states
- Visual representation of edits for better understanding
- Cleanup tools to manage your undo history files
- Written in Lua and zero dependencies

## 🚀 Features

- 🔄 **Interactive History Tree**: Navigate your entire undo history in a graph view or focus on current undo timeline for an intuitive overview.
- 🔍 **Live Diff Preview**: Instantly preview the changes introduced at any point in time with unified or custom diff formats.
- 🏷️ **Tag & Bookmark**: Mark important snapshots with custom tags for quick access—never lose your critical checkpoints.
- 🔧 **Multiple Diff Engines**: Out-of-the-box support for native Vim diff, difft, or standard diff—use whichever suits your workflow.
- 🖥️ **Hot Reload**: Keep your undo tree up-to-date without manually refreshing, with automatic snapshot reloads happening in the background.
- 🔒 **Undo File Cleaning**: Easily purge individual buffers or all undo files, with optional force flags to prevent accidental data loss.

<!-- panvimdoc-ignore-start -->

## 📕 Contents

- [Installation](#-installation)
- [Configuration](#%EF%B8%8F-configuration)
- [Quick Start](#-quick-start)
- [Usage Examples](#-usage-examples)
- [API](#-api)
- [Keybindings](#%EF%B8%8F-keybindings)
- [Events](#%EF%B8%8F-events)
- [Hlgroup](#-hlgroups)
- [FAQ](#-frequently-asked-questions)
- [Contributing](#-contributing)

<!-- panvimdoc-ignore-end -->

## 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
-- time-machine.lua
return {
 "y3owk1n/time-machine.nvim",
 version = "*", -- remove this if you want to use the `main` branch
 opts = {
  -- your configuration comes here
  -- or leave it empty to use the default settings
  -- refer to the configuration section below
 }
}
```

If you are using other package managers you need to call `setup`:

```lua
require("time-machine").setup({
  -- your configuration
})
```

### Requirements

- Neovim 0.11+ with Lua support
- Optional diff utilities in your $PATH:
  - `difft` for syntax-aware diffs
  - Standard `diff` utility
- Recommended Neovim settings:

```lua
vim.opt.undofile = true                      -- Enable persistent undo
vim.opt.undodir = vim.fn.expand("~/.undodir") -- Set custom undo directory
```

## ⚙️ Configuration

> [!important]
> Make sure to run `:checkhealth time-machine` if something isn't working properly.

**time-machine.nvim** is highly configurable. And the default configurations are as below.

### Default Options

```lua
---@type TimeMachine.Config
{
 split_opts = {
  split = "left", -- where to open the tree panel
  width = 50, -- columns number
 },
 float_opts = {
  width = 0.8, -- between 0 and 1
  height = 0.8, -- between 0 and 1
 },
 diff_tool = "native", -- default diff engine
 native_diff_opts = { -- only used when diff_tool is "native"
  result_type = "unified",
  ctxlen = 3,
  algorithm = "histogram",
 },
 external_diff_args = {}, -- set additional arguments for external diff tools
 keymaps = {
  undo = "u",
  redo = "<C-r>",
  restore_undopoint = "<CR>",
  refresh_timeline = "r",
  preview_sequence_diff = "p",
  tag_sequence = "t",
  close = "q",
  help = "g?",
  toggle_current_timeline = "c",
 },
 ignore_filesize = nil, -- e.g. 10 * 1024 * 1024
 ignored_filetypes = {
  "terminal",
  "nofile",
  "time-machine-list",
  "mason",
  "snacks_picker_list",
  "snacks_picker_input",
  "snacks_dashboard",
  "snacks_notif_history",
  "lazy",
 },
}
```

> [!note]
> `ignored_filesize` and `ignored_filetypes` does not disable the undo functionality, it only prevents the undo to be saved to the undofile.
> You don't have to set them if you don't want to.

### Type Definitions

```lua
---@alias TimeMachine.DiffTool "native"|TimeMachine.DiffToolExternal
---@alias TimeMachine.DiffToolExternal "difft"|"diff"|"delta"
---@alias TimeMachine.SplitDirection 'left'|'right'

---@class TimeMachine.Config
---@field diff_tool? TimeMachine.DiffTool The diff tool to use
---@field native_diff_opts? vim.diff.Opts The options for vim.diff
---@field external_diff_args? table<TimeMachine.DiffToolExternal, string[]> The arguments for external diff tools
---@field ignore_filesize? integer|nil The file size to ignore undo saved to disk
---@field ignored_filetypes? string[] The file types to ignore undo saved to disk
---@field split_opts? TimeMachine.Config.SplitOpts The split options
---@field float_opts? TimeMachine.Config.FloatOpts The floating window options
---@field keymaps? TimeMachine.Config.Keymaps The keymaps for actions

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
```

## 🚀 Quick Start

See the example below for how to configure **time-machine.nvim** with keybindings.

```lua
{
 "y3owk1n/time-machine.nvim",
 cmd = {
  "TimeMachineToggle",
  "TimeMachinePurgeBuffer",
  "TimeMachinePurgeAll",
 },
 ---@type TimeMachine.Config
 opts = {},
 keys = {
  {
   "<leader>t",
   "",
   desc = "Time Machine",
  },
  {
   "<leader>tt",
   "<cmd>TimeMachineToggle<cr>",
   desc = "[Time Machine] Toggle Tree",
  },
  {
   "<leader>tx",
   "<cmd>TimeMachinePurgeCurrent<cr>",
   desc = "[Time Machine] Purge current",
  },
  {
   "<leader>tX",
   "<cmd>TimeMachinePurgeAll<cr>",
   desc = "[Time Machine] Purge all",
  },
 },
},
```

## 💡 Usage Examples

### Navigating the Timeline

Navigate through the timeline:

- Open the time machine panel with `<leader>tt`
- Navigate like normal buffers, no special keys or mappings for those
- Press `c` to toggle between all timelines or current timeline only

### Tagging Important States

In a long coding session, mark important milestones, think of it like a mini git commit for your undo histories:

- Open the time machine panel with `<leader>tt`
- Navigate to an important state in the tree
- Press `t` to tag it (e.g., "working-version-1") or multiple tags (e.g., "working-version-1, working-version-2")
- Continue editing worry-free

> [!note]
> Deleting tags is as easy as pressing `t` again and just make the input empty and submit.

### Comparing Different Versions And Restoration

When you need to understand what changed:

- Navigate to a specific point in history
- Press `p` to see exactly what changed at that point compared to the active version
- Press `<CR>` to restore if needed

### Undo & Redo on Time Machine Panel

> [!note]
> You can always undo and redo on the content buffer or time machine panel. Both will sync the panel information.

Undo and redo changes in the time machine panel on the current timeline:

- Press `u` to undo just like you would normally
- Press `r` to redo just like you would normally
- The panel will automatically reload the changes

### Refreshing the Timeline

Refresh the timeline if something is not updating properly:

- Press `r` to refresh the timeline

## 🌎 API

**time-machine.nvim** provides the following api functions that you can use to map to your own keybindings:

### Toggle the tree

Toggle the undotree based on current buffer.

```lua
require("time-machine").toggle()

-- or any of the equivalents

:TimeMachineToggle
:lua require("time-machine").toggle()
```

### Purge undofile for the current buffer

Purge the undofile for the current buffer (including tagfile).

```lua
---@param force? boolean Whether to force the purge
require("time-machine").purge_buffer(force)

-- or any of the equivalents

:TimeMachinePurgeBuffer
:TimeMachinePurgeBuffer! -- force
:lua require("time-machine").purge_buffer()
```

### Purge all undofiles

Purge all undofiles (including tagfiles).

```lua
---@param force? boolean Whether to force the purge
require("time-machine").purge_all(force)

-- or any of the equivalents

:TimeMachinePurgeAll
:TimeMachinePurgeAll! -- force
:lua require("time-machine").purge_all()
```

## ⌨️ Keybindings

All the keybindings are customizable in config via `keymaps` field.

| Key | Action | Description |
| -------------- | --------------- | ------------ |
| `<CR>` | Restore | Restore to the selected sequence |
| `r` | Refresh | Refresh the data |
| `p` | Preview | Show the diff of the selected sequence |
| `t` | Tag | Tag the selected sequence (only work if the buffer has persistent undo) |
| `q` | Close | Close the window |
| `c` | Toggle timeline | Toggle the timeline to current timeline or all |
| `g?` | Help | Show the help |
| `u` | Undo | Undo the selected sequence in the current timeline |
| `<C-r>` | Redo | Redo the selected sequence in the current timeline |

## 🕰️ Events

- `TimeMachineUndoCreated` - Fired when a new undopoint is created (Best effort to match what Neovim does)
- `TimeMachineUndoCalled` - Fired when an undo from time machine panel is called (Not on the content buffer)
- `TimeMachineRedoCalled` - Fired when a redo from time machine panel is called (Not on the content buffer)
- `TimeMachineUndoRestored` - Fired when a specific undopoint sequence is restored
- `TimeMachineUndofileDeleted` - Fired when an undofile is deleted (purging)
- `TimeMachineTagsCreated` - Fired when tags are created from time machine panel

> [!note]
> If you want to be safe, you can use the `constants` to get the event instead of the string.
> For example `require("time-machine").constants.events.ev_that_you_want`

You can then listen to these user events and do something with them.

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "TimeMachineUndoCreated",
  callback = function()
    -- do something
  end,
})
```

## 🎨 Hlgroups

- `TimeMachineCurrent` - Current sequence (current line)
- `TimeMachineTimeline` - Current active timeline (for the icon)
- `TimeMachineKeymap` - Keymaps at the header section
- `TimeMachineInfo` - Info at the header section
- `TimeMachineSeq` - Individual sequence number
- `TimeMachineTag` - Tags text

### Example hlgroups customisation

```lua
vim.api.nvim_set_hl(0, "TimeMachineCurrent", { link = "Visual" })
vim.api.nvim_set_hl(0, "TimeMachineCurrent", { fg = "#7dcfff", bold = true })
```

## ❓ Frequently Asked Questions

### General Questions

**Q: How does Time Machine differ from other undo plugins?**

A: Time Machine focuses on visualizing your edit history as a tree, making it easier to understand branching edits. It also provides tagging, multiple diff engines, and cleanup functions all in one package.

**Q: Will this slow down my editor?**

A: No, Time Machine is designed to be lightweight and only loads the undo tree when requested. Background reloading is optimized to avoid performance impact.

**Q: Does Time Machine work with all filetypes?**

A: Yes, Time Machine works with all filetypes that Neovim supports, though you can configure `ignored_filetypes` to prevent undo history from being saved for specific types.

**Q: Is Time Machine compatible with Neovim stable?**

A: Time Machine requires Neovim 0.11+ as it was developed with 0.11 as stable version. It might work with older versions, but it's not guaranteed.

### Features & Usage

**Q: Do tags persist between Neovim sessions?**

A: Yes, tags are stored alongside your undo files and will persist between Neovim sessions.

**Q: How far back does Time Machine store my edit history?**

A: Time Machine relies on Neovim's native undo system, which stores history indefinitely when `undofile` is enabled. The history is limited only by your disk space.

**Q: Can I use Time Machine with files larger than 10MB?**

A: Yes, but for performance reasons, you might want to set `ignore_filesize` to prevent undo history from being saved to disk for very large files.

### Troubleshooting

**Q: My diff preview isn't showing syntax highlighting - why?**

A: Make sure you're using a diff tool that supports syntax highlighting (like `difft`) and that it's properly installed in your system. Also make sure you passed the correct arguments to the `external_diff_args` field in your config.

**Q: How can I recover if I accidentally purged my undo files?**

A: Unfortunately, once purged, undo files cannot be recovered unless you have a backup system in place. This is why purge commands have confirmation prompts and force flags.

**Q: Can I disable automatic reloading if it causes performance issues?**

A: Currently, there's no way to disable automatic reloading for the time machine panel, however, the automatic reloading only happens when the panel is toggled on. Under the hood, all relevant actions are emiting events and the panel is listening to them and refresh itself whenever it's needed.

### Integration & Comparison

**Q: How does Time Machine compare to vim-mundo or undotree.vim or undotree.nvim?**

A: Time Machine offers more features including tagging, multiple diff engines, and cleanup functions. It's also designed specifically for Neovim, taking advantage of its newer APIs.

**Q: Can I integrate Time Machine with git workflows?**

A: While Time Machine isn't directly integrated with git, you can use tags to mark important points that correspond to commits. This gives you finer granularity than git commits alone.

**Q: Does Time Machine work with remote files (over SSH/SCP)?**

A: Time Machine works with any file that Neovim can edit, including remote files, but the undo files are stored locally on your machine.

**Q: What happens if I edit a file outside of Neovim after creating undo points?**

A: If a file changes outside of Neovim, the undo history may become invalid. Neovim will detect the external changes and prompt you to reload, which may reset the undo history.

<!-- panvimdoc-ignore-start -->

## 🤝 Contributing

Read the documentation carefully before submitting any issue.

Feature and pull requests are welcome.

<!-- panvimdoc-ignore-end -->
