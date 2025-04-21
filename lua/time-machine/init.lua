---@module "time-machine"

local M = {}

M.setup = require("time-machine.config").setup

M.actions = require("time-machine.actions")

return M
