local Class = require("class")
local LevenShtein = require("levenshtein")
local StringBuffer  = require("string_buffer")

local function initVarInfo()
  return {
    read  = false,
    write = false,
    is_func = false,
    pos = {},
  }
end

local cache = {}

local M = Class()
M.__index = M

function M:_init(k)
  assert(k)
  self._data  = {}
  self._k     = k
  self._index = {}
end

function M:add(key, pos, opt)
  if self._data[key] == nil then
    self._data[key] = initVarInfo()
  end
  for k, v in pairs(opt) do
    self._data[key][k]  = v
  end
  pos.write = opt.write
  pos.read  = opt.read
  table.insert(self._data[key].pos, pos)
  return self._data[key]
end

function M:addRead(key, pos, opt)
  opt.read  = true
  return self:add(key, pos, opt)
end

function M:addWrite(key, pos, opt)
  if not(self:get(key)) then
    self:generateIndex(key)
  end
  opt.write = true
  return self:add(key, pos, opt)
end

function M:get(key)
  return self._data[key]
end

function M:data()
  return self._data
end

-- https://qiita.com/daimonji-bucket/items/1f40bc3242a3d26133d0

function M:generateIndex(key)
  local t = {}
  if not(cache[key]) then
    self:_generateIndex(t, key, key)
    cache[key]  = t
  else
    t = cache[key]
  end
  for k, v in pairs(t) do
    for _, v in ipairs(v) do
      self._index[k]  = self._index[k] or {}
      table.insert(self._index[k], v)
    end
  end
end

function M:_generateIndex(out, word, key, k)
  k = k or 0
  out[key]  = out[key] or {}
  table.insert(out[key], {
    k = k,
    word  = word,
  })

  if k >= self._k or #key == 0 then
    return
  end

  local t = {}
  for i = 1, utf8.len(key) do
    local tmp = string.sub(key, 1, utf8.offset(key, i) - 1) .. string.sub(key, utf8.offset(key, i + 1))
    self:_generateIndex(out, word, tmp, k + 1)
  end
end

function M:search(query)
  local t = {}
  local result, distance  = nil, self._k + 1
  self:_generateIndex(t, query, query)
  for k, _ in pairs(t) do
    local v = self._index[k]
    if v then
      for _, v in ipairs(v) do
        local d = LevenShtein(self._k, query, v.word)
        if d > 0 and d < distance then
          distance  = d
          result  = v.word
        end
      end
    end
  end
  return result, distance
end

function M:clone()
  local clone = {
    _data = {},
    _k    = self._k,
    _index  = {},
  }
  for k, v in pairs(self._data) do
    clone._data[k]  = v
  end
  for k, v in pairs(self._index) do
    clone._index[k]  = v
  end
  return setmetatable(clone, getmetatable(self))
end

function M:index()
  return self._index
end

return M
