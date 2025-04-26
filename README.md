# time-machine.nvim

Undo. Redo. Time travel.
Take control of your edit history with an interactive timeline, diff previews, taggings, live reloading trees and cleanup functions.

<!-- panvimdoc-ignore-start -->

![time-machine-demo](https://github.com/user-attachments/assets/b35a8ddd-b418-4ff8-a291-ea4c6a80228e)

<!-- panvimdoc-ignore-end -->

> [!warning]
>
> - The documentation may not cover all the features of the plugin. I will update it as we go.
> - There is no test yet for now, but it will be added soon. Hopefully nothing breaks.

## 🚀 Features

- 🔄 **Interactive History Tree**: Navigate your entire undo history in a collapsible tree view, grouping related edits for an intuitive overview.
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
- [API](#-api)
- [Keybindings](#-keybindings)
- [Hlgroup](#-hlgroups)
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
---@alias TimeMachine.DiffTool "native"|"difft"|"diff"
---@alias TimeMachine.SplitDirection 'left'|'right'

---@class TimeMachine.Config
---@field diff_tool? TimeMachine.DiffTool The diff tool to use
---@field native_diff_opts? vim.diff.Opts The options for vim.diff
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
 native_diff_opts = {
  result_type = "unified",
  ctxlen = 3,
  algorithm = "histogram",
 },
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
> `ignored_filesize` and `ignored_filetypes` are does not disable undo, it only prevent the undo to save to the undofile. You don't have to set them if you don't want to.

## 🚀 Quick Start

See the example below for how to configure **time-machine.nvim**.

```lua
{
 "y3owk1n/time-machine.nvim",
 event = { "VeryLazy" },
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
   function()
    require("time-machine").actions.toggle()
   end,
   mode = "n",
   desc = "[Time Machine] Toggle Tree",
  },
  {
   "<leader>tx",
   function()
    require("time-machine").actions.purge_current()
   end,
   mode = "n",
   desc = "[Time Machine] Purge current",
  },
  {
   "<leader>tX",
   function()
    require("time-machine").actions.purge_all()
   end,
   mode = "n",
   desc = "[Time Machine] Purge all",
  },
 },
},
```

## 🌎 API

**time-machine.nvim** provides the following api functions that you can use to map to your own keybindings:

### Toggle the tree

Toggle the undotree based on current buffer.

```lua
require("time-machine").toggle()
```

### Purge undofile for the current buffer

Purge the undofile for the current buffer (including tagfile).

```lua
---@param force? boolean Whether to force the purge
require("time-machine").purge_buffer(force)
```

### Purge all undofiles

Purge all undofiles (including tagfiles).

```lua
---@param force? boolean Whether to force the purge
require("time-machine").purge_all(force)
```

## ⌨️ Keybindings

- `<CR>` **Restore** - Restore to the selected sequence
- `r` **Refresh** - Refresh the data
- `p` **Preview** - Show the diff of the selected sequence
- `t` **Tag** - Tag the selected sequence (only work if the buffer is persistent)
- `q` **Close** - Close the window
- `c` **Toggle timeline** - Toggle the timeline to current timeline or all
- `g?` **Help** - Show the help
- `u` **Undo** - Undo the selected sequence in the current timeline
- `<C-r>` **Redo** - Redo the selected sequence in the current timeline

## 🎨 Hlgroups

- `TimeMachineCurrent` - Current sequence (current line)
- `TimeMachineTimeline` - Current active timeline (for the icon)
- `TimeMachineKeymap` - Keymaps at the header section
- `TimeMachineInfo` - Info at the header section
- `TimeMachineSeq` - Individual sequence number
- `TimeMachineTag` - Tags text

## 🤝 Contributing

Read the documentation carefully before submitting any issue.

Feature and pull requests are welcome.
