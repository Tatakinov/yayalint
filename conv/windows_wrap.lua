local Conv  = require("conv.windows")

local M = {}

function M.conv(input, to, from)
  local tbl = {
    from  = from,
    to  = to,
  }
  for k, v in pairs(tbl) do
    if v == "Shift_JIS" or v == "cp932" or v == "CP932" then
      tbl[k]  = 932
    elseif v == "UTF-8" then
      tbl[k]  = 65001
    end
  end

  local output  = Conv.conv(input, tbl.to, tbl.from)
  if output and #output > 0 then
    return output
  end
  return nil
end

return M
