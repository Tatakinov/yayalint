local Config  = require("config")
if type(Config) ~= "table" then
  Config  = {}
end
if not(Config.var) then
  Config.var  = {}
end
if not(Config.var.used) then
  Config.var.used = {}
end
if not(Config.var.predefined) then
  Config.var.predefined = {}
end
if not(Config.func) then
  Config.func = {}
end
if not(Config.func.used) then
  Config.func.used = {}
end
if not(Config.func.predefined) then
  Config.func.predefined = {}
end
if not(Config.func.builtin) then
  Config.func.builtin = {}
end

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
