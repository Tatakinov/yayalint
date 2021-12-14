local Iconv = require("iconv")
local M = {}

function M.conv(str, to, from)
  local cd  = Iconv.new(to, from)
  if type(str) ~= "string" or cd == nil then
    -- TODO error
    return nil
  end
  local nstr, err = cd:iconv(str)
  if err ~= nil then
    -- TODO error
    return nil
  end
  return nstr
end

return M
