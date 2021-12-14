local M = nil

if string.sub(package.config, 1, 1) == "\\" then
  M = require("conv.windows_wrap")
else
  M = require("conv.iconv")
end

return M
