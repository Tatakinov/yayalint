local Config  = require("config")

local M = {}

function M.isUserDefinedVariable(name)
  for _, v in ipairs(Config.var.predefined) do
    if string.match(name, v) then
      return true
    end
  end
  for _, v in ipairs(Config.func.builtin) do
    if string.match(name, v) then
      return true
    end
  end
  return false
end

function M.isUserUsedVariable(name)
  for _, v in ipairs(Config.var.used) do
    if string.match(name, v) then
      return true
    end
  end
  return false
end

function M.isUserDefinedFunction(name)
  for _, v in ipairs(Config.func.predefined) do
    if string.match(name, v) then
      return true
    end
  end
  for _, v in ipairs(Config.func.builtin) do
    if string.match(name, v) then
      return true
    end
  end
  return false
end

function M.isUserUsedFunction(name)
  for _, v in ipairs(Config.func.used) do
    if string.match(name, v) then
      return true
    end
  end
  return false
end

return M
