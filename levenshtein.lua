local function min(...)
  local args  = {...}
  local n = 10000
  for _, v in ipairs(args) do
    if n > v then
      n = v
    end
  end
  return n
end

local function id(s1, s2)
  return s1 .. "/" .. s2
end

local _cache  = {}
local _d_max  = 10000

local function init_cache(d_max, s1, s2)
  _d_max  = d_max
  _cache["/"]  = 0
  for i = 1, #s1 do
    _cache[id(string.sub(s1, i), "")] = #s1 - i + 1
  end
  for i = 1, #s2 do
    _cache[id("", string.sub(s2, i))] = #s2 - i + 1
  end
end

local function cache(s1, s2)
  local i  = id(s1, s2)
  if _cache[i] then
    --print("cache:", s1, s2)
    return _cache[i]
  end
  if math.abs(#s1 - #s2) > _d_max then
    _cache[i]  = _d_max + 1
    return _d_max + 1
  end
  local cost = string.sub(s1, 1, 1) == string.sub(s2, 1, 1) and 0 or 1
  _cache[i] = min(
    cache(string.sub(s1, 2), s2) + 1,
    cache(s1, string.sub(s2, 2)) + 1,
    cache(string.sub(s1, 2), string.sub(s2, 2)) + cost
  )
  return _cache[id(s1, s2)]
end

local function M(d_max, s1, s2)
  if s1 == s2 then
    return 0
  end
  if s1 > s2 then
    s1, s2  = s2, s1
  end
  init_cache(d_max, s1, s2)
  return cache(s1, s2)
end

return M
