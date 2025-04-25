doc:
    panvimdoc --project-name time-machine.nvim --input-file ./README.md --demojify true --vim-version "Neovim >= 0.11.0"

set shell := ["bash", "-cu"]

test:
    @echo "Running tests in headless Neovim using test_init.lua..."
    nvim -l tests/minit.lua --minitest
