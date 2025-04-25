# time-machine.nvim

Undo. Redo. Time travel.
Take control of your edit history with an interactive timeline, diff previews, taggings and live reloading trees.

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
require("dotmd").setup({
  -- your configuration
})
```

### Requirements

- Neovim 0.11+ with Lua support
- The following diff CLI is optional to be installed in your $PATH:
  - `difft`
  - `diff`

## ⚙️ Configuration

> [!important]
> Make sure to run `:checkhealth time-machine` if something isn't working properly.

**dotmd.nvim** is highly configurable. And the default configurations are as below.

### Default Options

```lua
---@class TimeMachine.Config
---@field diff_tool? TimeMachine.DiffTool The diff tool to use
---@field native_diff_opts? vim.diff.Opts The options for vim.diff
---@field ignore_filesize? integer|nil The file size to ignore undo saved to disk
---@field ignored_filetypes? string[] The file types to ignore undo saved to disk
---@field split_opts? TimeMachine.SplitOpts The split options

---@alias TimeMachine.DiffTool "native"|"difft"|"diff"
---@alias TimeMachine.SplitDirection 'left'|'right'

---@type TimeMachine.Config
{
 split_opts = {
  split = "left",
  width = 50,
 },
 diff_tool = "native",
 native_diff_opts = {
  result_type = "unified",
  ctxlen = 3,
  algorithm = "histogram",
 },
 ignore_filesize = nil,
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

`<CR>` **Restore** - Restore to the selected sequence
`r` **Refresh** - Refresh the data
`p` **Preview** - Show the diff of the selected sequence
`t` **Tag** - Tag the selected sequence
`q` **Close** - Close the window

## 🎨 Hlgroups

- `TimeMachineCurrent` - Current sequence
- `TimeMachineKeymap` - Keymap
- `TimeMachineInfo` - Info
- `TimeMachineSeq` - Sequence
- `TimeMachineTag` - Tag

## 🤝 Contributing

Read the documentation carefully before submitting any issue.

Feature and pull requests are welcome.
