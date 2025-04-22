# time-machine.nvim (WIP)

Time Machine is a lightweight Neovim plugin that provides persistent, per‑buffer version history with diff‑based snapshots, branch awareness, and an intuitive UI. Unlike the native undo system or popular undo‑tree plugins, Time Machine stores every change in an on‑disk SQLite database, enabling you to browse and restore snapshots even after restarting Neovim.

- [ ] Problem now is with how we create the snapshot that has '\n' in the source code
- [ ] Another problem is that when applying the diff during restore, we need to make sure it get applies from the root to the end of the chain
