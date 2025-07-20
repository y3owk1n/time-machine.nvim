doc:
    vimcats -t -f -c -a \
    lua/time-machine/init.lua \
    lua/time-machine/config.lua \
    lua/time-machine/types.lua \
    > doc/time-machine.nvim.txt

set shell := ["bash", "-cu"]

test:
    @echo "Running tests in headless Neovim using test_init.lua..."
    nvim -l tests/minit.lua --minitest
