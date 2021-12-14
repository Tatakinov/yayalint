local Class = require("class")
local M = Class()

M.__index = M
M.__tostring  = function(self)
  return self:tostring()
end

function M:_init(str)
  self.data = {}
  self.length = 0
  self:append(str)
end

function M:insert(str, pos)
  if str ~= nil then
    local mt  = getmetatable(str)
    if mt and mt.__tostring then
      str = tostring(str)
    elseif type(str) == "number" or type(str) == "boolean" then
      str = tostring(str)
    end
    assert(type(str) == "string")
    if pos then
      table.insert(self.data, pos, str)
    else
      table.insert(self.data, str)
    end
    self.length  = self.length + #str
  end
  return self
end

function M:prepend(str)
  return self:insert(str, 1)
end

function M:append(str)
  return self:insert(str)
end

function M:tostring()
  return table.concat(self.data)
end

function M:clear()
  self:_init()
  return self
end

function M:strlen()
  return self.length
end

return M
