local M = {}

function M.key(x, y) return x .. "," .. y end

function M.laneKey(x, y, entry, exit)
  return x .. "," .. y .. "," .. entry .. "," .. exit
end

function M.inBounds(x, y, w, h)
  return x >= 1 and y >= 1 and x <= w and y <= h
end

function M.hasDir(list, dir, fallback)
  for _, d in ipairs(list or fallback) do
    if d == dir then return true end
  end
  return false
end

function M.dirIndex(dirs, d)
  for i, name in ipairs(dirs) do if name == d then return i - 1 end end
  return 0
end

function M.rotationLabel(dirs, r)
  return dirs[(r % 4) + 1]
end

function M.clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

function M.easeOutQuint(t)
  return 1 - (1 - t) ^ 5
end

function M.rotateLocal(lx, ly, turns)
  local a = turns * math.pi * 0.5
  return lx * math.cos(a) - ly * math.sin(a), lx * math.sin(a) + ly * math.cos(a)
end

function M.transformDir(d, effect)
  if effect == "rotate_cw" then return ({ N = "E", E = "S", S = "W", W = "N", C = "C" })[d] end
  if effect == "rotate_ccw" then return ({ N = "W", W = "S", S = "E", E = "N", C = "C" })[d] end
  if effect == "flip_h" then return ({ N = "N", E = "W", S = "S", W = "E", C = "C" })[d] end
  if effect == "flip_v" then return ({ N = "S", E = "E", S = "N", W = "W", C = "C" })[d] end
  if effect == "flip_diag_main" then return ({ N = "W", E = "S", S = "E", W = "N", C = "C" })[d] end
  if effect == "flip_diag_anti" then return ({ N = "E", E = "N", S = "W", W = "S", C = "C" })[d] end
  return d
end

function M.transformLocal(lx, ly, effect)
  if effect == "rotate_cw" then return M.rotateLocal(lx, ly, 1) end
  if effect == "rotate_ccw" then return M.rotateLocal(lx, ly, -1) end
  if effect == "flip_h" then return -lx, ly end
  if effect == "flip_v" then return lx, -ly end
  if effect == "flip_diag_main" then return ly, lx end
  if effect == "flip_diag_anti" then return -ly, -lx end
  return lx, ly
end

function M.effectMatrix(effect)
  if effect == "rotate_cw" then return { 0, -1, 1, 0 } end
  if effect == "rotate_ccw" then return { 0, 1, -1, 0 } end
  if effect == "flip_h" then return { -1, 0, 0, 1 } end
  if effect == "flip_v" then return { 1, 0, 0, -1 } end
  if effect == "flip_diag_main" then return { 0, 1, 1, 0 } end
  if effect == "flip_diag_anti" then return { 0, -1, -1, 0 } end
  return { 1, 0, 0, 1 }
end

function M.matrixPoint(m, x, y)
  m = m or { 1, 0, 0, 1 }
  return m[1] * x + m[2] * y, m[3] * x + m[4] * y
end

function M.composeMatrix(a, b)
  b = b or { 1, 0, 0, 1 }
  return {
    a[1] * b[1] + a[2] * b[3],
    a[1] * b[2] + a[2] * b[4],
    a[3] * b[1] + a[4] * b[3],
    a[3] * b[2] + a[4] * b[4],
  }
end

function M.transformRegionLocal(gx, gy, size, effect)
  if effect == "rotate_cw" then return size - gy, gx end
  if effect == "rotate_ccw" then return gy, size - gx end
  if effect == "flip_h" then return size - gx, gy end
  if effect == "flip_v" then return gx, size - gy end
  if effect == "flip_diag_main" then return gy, gx end
  if effect == "flip_diag_anti" then return size - gy, size - gx end
  return gx, gy
end

function M.regionPointToCell(x, y, size, gx, gy)
  local ix = math.max(0, math.min(size - 1, math.floor(gx)))
  local iy = math.max(0, math.min(size - 1, math.floor(gy)))
  return x + ix, y + iy, gx - ix - 0.5, gy - iy - 0.5
end

function M.samePortSet(a, b, c, d)
  return (a == c and b == d) or (a == d and b == c)
end

function M.q(s)
  return string.format("%q", tostring(s))
end

function M.isArray(t)
  local n = 0
  for k in pairs(t) do
    if type(k) ~= "number" then return false end
    n = math.max(n, k)
  end
  for i = 1, n do if t[i] == nil then return false end end
  return true
end

function M.luaValue(v, indent)
  indent = indent or ""
  if type(v) == "string" then return M.q(v) end
  if type(v) == "number" or type(v) == "boolean" then return tostring(v) end
  if type(v) ~= "table" then return "nil" end
  local childIndent = indent .. "  "
  local lines = { "{" }
  if M.isArray(v) then
    for _, item in ipairs(v) do
      lines[#lines + 1] = childIndent .. M.luaValue(item, childIndent) .. ","
    end
  else
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      local keyText = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or ("[" .. M.luaValue(k) .. "]")
      lines[#lines + 1] = childIndent .. keyText .. " = " .. M.luaValue(v[k], childIndent) .. ","
    end
  end
  lines[#lines + 1] = indent .. "}"
  return table.concat(lines, "\n")
end

function M.copyReq(req)
  local out = {}
  for k, v in pairs(req or {}) do out[k] = v end
  return out
end

return M
