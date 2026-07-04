vim.env.NVIM_TESTING = "1"

vim.opt.rtp:prepend(vim.fn.getcwd())

require("time-machine").setup()
