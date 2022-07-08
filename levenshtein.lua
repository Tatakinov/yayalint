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

local function init_cache(s1, s2)
  _cache  = {}
  _cache["/"]  = 0
  for i = 1, #s1 do
    _cache[id(string.sub(s1, 1, i), "")] = i
  end
  for i = 1, #s2 do
    _cache[id("", string.sub(s2, 1, i))] = i
  end
end

local function cache(s1, s2)
  if _cache[id(s1, s2)] then
    return _cache[id(s1, s2)]
  end
  local cost = string.sub(s1, -1, -1) == string.sub(s2, -1, -1) and 0 or 1
  _cache[id(s1, s2)] = min(
    cache(string.sub(s1, 1, -2), s2) + 1,
    cache(s1, string.sub(s2, 1, -2)) + 1,
    cache(string.sub(s1, 1, -2), string.sub(s2, 1, -2)) + cost
  )
  return _cache[id(s1, s2)]
end

local function getLevenshteinDistance(s1, s2)
  init_cache(s1, s2)
  return cache(s1, s2)
end

local function M(s, ...)
  local t = {...}
  local key
  for _, v in ipairs(t) do
    for k, v in pairs(v) do
      if s ~= k then
        if getLevenshteinDistance(s, k) <= 2 then
          key = k
        end
      end
    end
  end
  return key
end

return M
