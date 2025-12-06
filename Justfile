doc:
    vimcats -t -f -c -a \
    lua/time-machine/init.lua \
    lua/time-machine/config.lua \
    lua/time-machine/types.lua \
    > doc/time-machine.nvim.txt

set shell := ["bash", "-cu"]

fmt-check:
    stylua --config-path=.stylua.toml --check lua

fmt:
    stylua --config-path=.stylua.toml lua

test:
    @echo "Running tests in headless Neovim using test_init.lua..."
    nvim -l tests/minit.lua --minitest
