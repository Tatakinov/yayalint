local M = {}

setmetatable(M, {
  __call  = function(_, base)
    local class = setmetatable({}, {
      __index = base,
      __call  = function(c, ...)
        local self  = setmetatable({}, c)
        function self:super()
          return base
        end
        if type(self._init) == "function" then
          self:_init(...)
        end
        return self
      end,
    })
    return class
  end,
})

return M
