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

lint:
    @if lua-language-server --configpath=.luarc.json --check=. --check_format=pretty --checklevel=Warning 2>&1 | grep -E 'Warning|Error'; then \
        echo "LSP lint failed"; \
        exit 1; \
    else \
        echo "LSP lint passed"; \
    fi

test:
    @echo "Running tests in headless Neovim using test_init.lua..."
    nvim -l tests/minit.lua --minitest
