local W, H, CELL = 12, 8, 48
local PORT_RADIUS = CELL * 0.5
local OX, OY = 24, 72
local dirs = { "N", "E", "S", "W" }
local dx = { N = 0, E = 1, S = 0, W = -1 }
local dy = { N = -1, E = 0, S = 1, W = 0 }
local opposite = { N = "S", E = "W", S = "N", W = "E" }
local names = { "straight", "corner", "splitter", "merger", "bridge" }
local colors = {
  bg = { 0.08, 0.09, 0.1 },
  grid = { 0.22, 0.24, 0.25 },
  empty = { 0.13, 0.14, 0.15 },
  tile = { 0.23, 0.27, 0.29 },
  flow = { 0.33, 0.75, 1 },
  block = { 1, 0.25, 0.22 },
  cargo = { 1, 0.78, 0.25 },
  text = { 0.9, 0.92, 0.88 },
  source = { 0.22, 0.65, 0.33 },
  dest = { 0.65, 0.42, 0.85 },
  hover = { 1, 0.86, 0.28 },
  panel = { 0.16, 0.18, 0.19 },
  selected = { 0.32, 0.58, 0.78 },
  splitter = { 0.2, 0.45, 0.52 },
  merger = { 0.52, 0.34, 0.22 },
}

local board, sources, dests, flows, cargo, selected, placementRotation, paused, debug, status, unlimitedStock, dumpOverlay
local nextCargoId = 1
local dirty = true
local splitState = {}
local scenario = 1
local cargoSpacing = 0.55
local rotateTweenDuration = 0.1
local cameraX, cameraY, zoom = 0, 0, 1
local cameraSpeed = 360
local simTime = 0
local replayEvents = {}
local pendingDisturbance = nil
local disturbanceDelay = 3
local disturbanceTweenDuration = 1
local disturbanceEffects = {
  { id = "rotate_cw", label = "Rotate +90" },
  { id = "rotate_ccw", label = "Rotate -90" },
  { id = "flip_h", label = "Flip Horizontal" },
  { id = "flip_v", label = "Flip Vertical" },
  { id = "flip_diag_main", label = "Flip Diagonal \\" },
  { id = "flip_diag_anti", label = "Flip Diagonal /" },
}

local function key(x, y) return x .. "," .. y end
local function laneKey(x, y, entry, exit) return x .. "," .. y .. "," .. entry .. "," .. exit end
local function inBounds(x, y) return x >= 1 and y >= 1 and x <= W and y <= H end
local function center(x, y) return OX + (x - 0.5) * CELL, OY + (y - 0.5) * CELL end
local function portPoint(x, y, d)
  local cx, cy = center(x, y)
  return cx + dx[d] * PORT_RADIUS, cy + dy[d] * PORT_RADIUS
end

local function newBoard()
  local b = {}
  for y = 1, H do
    b[y] = {}
    for x = 1, W do b[y][x] = { kind = "empty" } end
  end
  return b
end

local function setTile(x, y, typeName, rot)
  if board[y][x].kind == "source" or board[y][x].kind == "dest" then return false end
  board[y][x] = { kind = "tile", type = typeName, rotation = rot or 0 }
  dirty = true
  return true
end

local function setSource(s)
  board[s.y][s.x] = { kind = "source", id = s.id }
  sources[#sources + 1] = s
end

local function setDest(d)
  board[d.y][d.x] = { kind = "dest", id = d.id }
  dests[#dests + 1] = d
end

local function loadScenario(n)
  scenario = n
  board, sources, dests, cargo, flows, splitState = newBoard(), {}, {}, {}, {}, {}
  simTime = 0
  replayEvents = { { t = 0, action = "scenario", scenario = n } }
  nextCargoId, status, dirty = 1, "running", true
  if n == 1 then
    setSource({ id = "A1", x = 1, y = 4, output = "E", strength = 1, cargoType = "box", remaining = 8, timer = 0, interval = 1 })
    setDest({ id = "B1", x = 12, y = 4, req = { box = 5 }, got = {}, wrong = 0 })
    for x = 2, 11 do setTile(x, 4, "straight", 1) end
  elseif n == 2 then
    setSource({ id = "A1", x = 1, y = 4, output = "E", strength = 1, cargoType = "box", remaining = -1, timer = 0, interval = 0.8 })
    setDest({ id = "B1", x = 8, y = 2, req = { box = 2 }, got = {}, wrong = 0 })
    setDest({ id = "B2", x = 8, y = 4, req = { box = 2 }, got = {}, wrong = 0 })
    setDest({ id = "B3", x = 8, y = 6, req = { box = 2 }, got = {}, wrong = 0 })
    setTile(2, 4, "splitter", 3)
    for x = 3, 7 do setTile(x, 4, "straight", 1) end
    setTile(2, 3, "straight", 0); setTile(2, 2, "corner", 1)
    for x = 3, 7 do setTile(x, 2, "straight", 1) end
    setTile(2, 5, "straight", 0); setTile(2, 6, "corner", 0)
    for x = 3, 7 do setTile(x, 6, "straight", 1) end
  else
    setSource({ id = "A1", x = 1, y = 4, output = "E", strength = 1, cargoType = "box", remaining = 10, timer = 0, interval = 0.7 })
    setSource({ id = "A2", x = 12, y = 4, output = "W", strength = 3, cargoType = "box", remaining = 10, timer = 0, interval = 0.7 })
    for x = 2, 11 do setTile(x, 4, "straight", 1) end
    setDest({ id = "B1", x = 6, y = 1, req = { box = 4 }, got = {}, wrong = 0 })
  end
end

local function exitsFor(tile, entry)
  local r = tile.rotation % 4
  if tile.type == "straight" then
    local a, b = r % 2 == 0 and "N" or "E", r % 2 == 0 and "S" or "W"
    if entry == a then return { b } end
    if entry == b then return { a } end
  elseif tile.type == "corner" then
    local a, b = dirs[r + 1], dirs[(r + 1) % 4 + 1]
    if entry == a then return { b } end
    if entry == b then return { a } end
  elseif tile.type == "splitter" then
    local input = dirs[r + 1]
    if entry == input then
      local outs = {}
      for _, d in ipairs(dirs) do if d ~= input then outs[#outs + 1] = d end end
      return outs
    end
  elseif tile.type == "merger" then
    local output = dirs[r + 1]
    if entry ~= output then return { output } end
  elseif tile.type == "bridge" then
    if entry == "N" then return { "S" } end
    if entry == "S" then return { "N" } end
    if entry == "W" then return { "E" } end
    if entry == "E" then return { "W" } end
  end
  return {}
end

local function exitConnects(x, y, exit)
  local nx, ny = x + dx[exit], y + dy[exit]
  if not inBounds(nx, ny) then return false end
  local nextCell = board[ny][nx]
  if nextCell.kind == "dest" then return true end
  if nextCell.kind ~= "tile" then return false end
  return #exitsFor(nextCell, opposite[exit]) > 0
end

local function tileSegments(tile)
  local r = tile.rotation % 4
  if tile.type == "straight" then
    return r % 2 == 0 and { { "N", "S" } } or { { "E", "W" } }
  elseif tile.type == "corner" then
    return { { dirs[r + 1], dirs[(r + 1) % 4 + 1] } }
  elseif tile.type == "splitter" then
    local input = dirs[r + 1]
    local segments = {}
    for _, d in ipairs(dirs) do
      if d ~= input then segments[#segments + 1] = { input, d } end
    end
    return segments
  elseif tile.type == "merger" then
    local output = dirs[r + 1]
    local segments = {}
    for _, d in ipairs(dirs) do
      if d ~= output then segments[#segments + 1] = { d, output } end
    end
    return segments
  elseif tile.type == "bridge" then
    return { { "N", "S" }, { "W", "E" } }
  end
  return {}
end

local function tileColor(tile)
  if tile.type == "splitter" then return colors.splitter end
  if tile.type == "merger" then return colors.merger end
  return colors.tile
end

local function tilePorts(tile)
  local r = tile.rotation % 4
  if tile.type == "splitter" then
    local input, outputs = dirs[r + 1], {}
    for _, d in ipairs(dirs) do if d ~= input then outputs[#outputs + 1] = d end end
    return { input }, outputs
  elseif tile.type == "merger" then
    local output, inputs = dirs[r + 1], {}
    for _, d in ipairs(dirs) do if d ~= output then inputs[#inputs + 1] = d end end
    return inputs, { output }
  end
  return {}, {}
end

local function baseTileSegments(typeName)
  if typeName == "straight" then return { { "N", "S" } } end
  if typeName == "corner" then return { { "N", "E" } } end
  if typeName == "splitter" then return { { "N", "E" }, { "N", "S" }, { "N", "W" } } end
  if typeName == "merger" then return { { "E", "N" }, { "S", "N" }, { "W", "N" } } end
  if typeName == "bridge" then return { { "N", "S" }, { "W", "E" } } end
  return {}
end

local function baseTilePorts(typeName)
  if typeName == "splitter" then return { "N" }, { "E", "S", "W" } end
  if typeName == "merger" then return { "E", "S", "W" }, { "N" } end
  return {}, {}
end

local function easeOutQuint(t)
  return 1 - (1 - t) ^ 5
end

local function rotateLocal(lx, ly, turns)
  local a = turns * math.pi / 2
  return lx * math.cos(a) - ly * math.sin(a), lx * math.sin(a) + ly * math.cos(a)
end

local function drawPoint(cx, cy, d, radius, rot)
  local x, y = dx[d] * radius, dy[d] * radius
  local a = rot * math.pi / 2
  return cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)
end

local function visualRotation(tile)
  if tile.tweenTime then
    local t = math.min(1, tile.tweenTime / (tile.tweenDuration or rotateTweenDuration))
    return tile.tweenFrom + (tile.tweenTo - tile.tweenFrom) * easeOutQuint(t)
  end
  return tile.rotation
end

local function rotateTile(tile, turns, duration)
  turns = turns or 1
  local from = visualRotation(tile)
  tile.rotation = (tile.rotation + turns) % 4
  tile.tweenFrom, tile.tweenTo, tile.tweenTime, tile.tweenDuration = from, from + turns, 0, duration or rotateTweenDuration
end

local function dirIndex(d)
  for i, name in ipairs(dirs) do if name == d then return i - 1 end end
  return 0
end

local function transformDir(d, effect)
  if effect == "rotate_cw" then return ({ N = "E", E = "S", S = "W", W = "N" })[d] end
  if effect == "rotate_ccw" then return ({ N = "W", W = "S", S = "E", E = "N" })[d] end
  if effect == "flip_h" then return ({ N = "N", E = "W", S = "S", W = "E" })[d] end
  if effect == "flip_v" then return ({ N = "S", E = "E", S = "N", W = "W" })[d] end
  if effect == "flip_diag_main" then return ({ N = "W", E = "S", S = "E", W = "N" })[d] end
  if effect == "flip_diag_anti" then return ({ N = "E", E = "N", S = "W", W = "S" })[d] end
  return d
end

local function transformLocal(lx, ly, effect)
  if effect == "rotate_cw" then return rotateLocal(lx, ly, 1) end
  if effect == "rotate_ccw" then return rotateLocal(lx, ly, -1) end
  if effect == "flip_h" then return -lx, ly end
  if effect == "flip_v" then return lx, -ly end
  if effect == "flip_diag_main" then return ly, lx end
  if effect == "flip_diag_anti" then return -ly, -lx end
  return lx, ly
end

local function transformRegionLocal(gx, gy, size, effect)
  if effect == "rotate_cw" then return size - gy, gx end
  if effect == "rotate_ccw" then return gy, size - gx end
  if effect == "flip_h" then return size - gx, gy end
  if effect == "flip_v" then return gx, size - gy end
  if effect == "flip_diag_main" then return gy, gx end
  if effect == "flip_diag_anti" then return size - gy, size - gx end
  return gx, gy
end

local function tweenRegionLocal(gx, gy, size, effect, t)
  if effect == "rotate_cw" or effect == "rotate_ccw" then
    local a = (effect == "rotate_cw" and 1 or -1) * math.pi * 0.5 * t
    local cx, cy = size * 0.5, size * 0.5
    local lx, ly = gx - cx, gy - cy
    return cx + lx * math.cos(a) - ly * math.sin(a), cy + lx * math.sin(a) + ly * math.cos(a)
  end
  local tx, ty = transformRegionLocal(gx, gy, size, effect)
  return gx + (tx - gx) * t, gy + (ty - gy) * t
end

local function regionPointToCell(x, y, size, gx, gy)
  local ix = math.max(0, math.min(size - 1, math.floor(gx)))
  local iy = math.max(0, math.min(size - 1, math.floor(gy)))
  return x + ix, y + iy, gx - ix - 0.5, gy - iy - 0.5
end

local function samePortSet(a, b, c, d)
  return (a == c and b == d) or (a == d and b == c)
end

local function tileRotationAfterEffect(tile, effect)
  local r = tile.rotation % 4
  if tile.type == "corner" then
    local a, b = transformDir(dirs[r + 1], effect), transformDir(dirs[(r + 1) % 4 + 1], effect)
    for nr = 0, 3 do
      if samePortSet(a, b, dirs[nr + 1], dirs[(nr + 1) % 4 + 1]) then return nr end
    end
  elseif tile.type == "bridge" then
    return r
  end
  return dirIndex(transformDir(dirs[r + 1], effect))
end

local function transformTileRotation(tile, effect)
  if effect == "rotate_cw" then return rotateTile(tile, 1, disturbanceTweenDuration) end
  if effect == "rotate_ccw" then return rotateTile(tile, -1, disturbanceTweenDuration) end
  tile.effectTween = { effect = effect, fromRotation = visualRotation(tile), time = 0, duration = disturbanceTweenDuration }
  tile.rotation = tileRotationAfterEffect(tile, effect)
  tile.tweenFrom, tile.tweenTo, tile.tweenTime = nil, nil, nil
end

local function updateTileTweens(dt)
  for y = 1, H do
    for x = 1, W do
      local tile = board[y][x]
      if tile.kind == "tile" and tile.tweenTime then
        tile.tweenTime = tile.tweenTime + dt
        if tile.tweenTime >= (tile.tweenDuration or rotateTweenDuration) then
          tile.tweenFrom, tile.tweenTo, tile.tweenTime, tile.tweenDuration = nil, nil, nil, nil
        end
      end
      if tile.kind == "tile" and tile.effectTween then
        tile.effectTween.time = tile.effectTween.time + dt
        if tile.effectTween.time >= tile.effectTween.duration then tile.effectTween = nil end
      end
      if tile.kind == "tile" and tile.regionTween then
        tile.regionTween.time = tile.regionTween.time + dt
        if tile.regionTween.time >= tile.regionTween.duration then tile.regionTween = nil end
      end
    end
  end
end

local function updateCargoTweens(dt)
  for _, c in ipairs(cargo) do
    if c.rotateTween then
      c.rotateTween.time = c.rotateTween.time + dt
      if c.rotateTween.time >= (c.rotateTween.duration or rotateTweenDuration) then c.rotateTween = nil end
    end
    if c.effectTween then
      c.effectTween.time = c.effectTween.time + dt
      if c.effectTween.time >= c.effectTween.duration then c.effectTween = nil end
    end
    if c.regionTween then
      c.regionTween.time = c.regionTween.time + dt
      if c.regionTween.time >= c.regionTween.duration then c.regionTween = nil end
    end
  end
end

local function claimLane(lane)
  local k = laneKey(lane.x, lane.y, lane.entry, lane.exit)
  local reverse = laneKey(lane.x, lane.y, lane.exit, lane.entry)
  if flows.lanes[reverse] then
    local other = flows.lanes[reverse]
    if other.strength == lane.strength then
      other.blocked, lane.blocked = true, true
      flows.blocks[key(lane.x, lane.y)] = true
      flows.lanes[k] = lane
      return false
    end
    if other.strength > lane.strength then
      lane.blocked = true
      flows.blocks[key(lane.x, lane.y)] = true
      flows.lanes[k] = lane
      return false
    end
    other.blocked = true
    flows.blocks[key(lane.x, lane.y)] = true
  end
  local old = flows.lanes[k]
  if not old or lane.strength >= old.strength then flows.lanes[k] = lane end
  return true
end

local function recalcFlow()
  flows = { lanes = {}, from = {}, sourceLanes = {}, blocks = {} }
  local queue = {}
  for _, s in ipairs(sources) do
    queue[#queue + 1] = { x = s.x + dx[s.output], y = s.y + dy[s.output], entry = opposite[s.output], source = s.id, strength = s.strength, dist = 0 }
  end
  local guard = 0
  while #queue > 0 and guard < 2000 do
    guard = guard + 1
    local f = table.remove(queue, 1)
    if inBounds(f.x, f.y) then
      local cell = board[f.y][f.x]
      if cell.kind == "tile" then
        for _, exit in ipairs(exitsFor(cell, f.entry)) do
          if (cell.type ~= "splitter" and cell.type ~= "merger") or exitConnects(f.x, f.y, exit) then
          local lane = { x = f.x, y = f.y, entry = f.entry, exit = exit, type = cell.type, source = f.source, strength = f.strength, dist = f.dist + 1 }
          claimLane(lane)
          local lk = laneKey(f.x, f.y, f.entry, exit)
          flows.from[f.x .. "," .. f.y .. "," .. f.entry] = flows.from[f.x .. "," .. f.y .. "," .. f.entry] or {}
          table.insert(flows.from[f.x .. "," .. f.y .. "," .. f.entry], lk)
          if f.dist == 0 then
            flows.sourceLanes[f.source] = flows.sourceLanes[f.source] or {}
            table.insert(flows.sourceLanes[f.source], lk)
          end
          if not lane.blocked then
            queue[#queue + 1] = { x = f.x + dx[exit], y = f.y + dy[exit], entry = opposite[exit], source = f.source, strength = f.strength, dist = f.dist + 1 }
          end
          end
        end
      end
    end
  end
  dirty = false
end

local function laneHasSpace(lk, progress, ignoreId, fromProgress)
  for _, c in ipairs(cargo) do
    if c.id ~= ignoreId and c.state ~= "removed" and c.lane == lk then
      if not fromProgress and math.abs(c.progress - progress) < cargoSpacing then return false end
      if fromProgress and c.progress >= fromProgress and c.progress - progress < cargoSpacing then return false end
    end
  end
  return true
end

local function laneSnapshot(lane)
  return lane and { x = lane.x, y = lane.y, entry = lane.entry, exit = lane.exit, type = lane.type }
end

local function laneLocalPoint(lane, progress)
  local ax, ay = dx[lane.entry] * 0.5, dy[lane.entry] * 0.5
  local bx, by = dx[lane.exit] * 0.5, dy[lane.exit] * 0.5
  if lane.type == "corner" then
    if progress < 0.5 then
      local t = progress * 2
      return ax * (1 - t), ay * (1 - t)
    end
    local t = (progress - 0.5) * 2
    return bx * t, by * t
  end
  return ax + (bx - ax) * progress, ay + (by - ay) * progress
end

local function laneWorldPoint(lane, progress)
  local cx, cy = center(lane.x, lane.y)
  local lx, ly = laneLocalPoint(lane, progress)
  return cx + lx * CELL, cy + ly * CELL
end

local function cargoLocal(c)
  local lane = flows.lanes[c.lane] or c.visualLane
  if not lane then return c.localX or 0, c.localY or 0 end
  return laneLocalPoint(lane, c.progress)
end

local function rememberCargoPoint(c, x, y, lx, ly)
  c.cellX, c.cellY, c.localX, c.localY = x, y, lx, ly
  c.visualLane = nil
  c.visualPoint = { x = x, y = y, lx = lx, ly = ly }
end

local function cargoInCell(c, x, y)
  if c.state == "removed" then return false end
  local lane = flows.lanes[c.lane] or c.visualLane
  if lane then return lane.x == x and lane.y == y end
  return c.cellX == x and c.cellY == y
end

local function cellHasCargo(x, y)
  for _, c in ipairs(cargo) do
    if cargoInCell(c, x, y) then return true end
  end
  return false
end

local function progressOnSegment(lx, ly, ax, ay, bx, by)
  local vx, vy = bx - ax, by - ay
  local len2 = vx * vx + vy * vy
  if len2 == 0 then return nil end
  local t = ((lx - ax) * vx + (ly - ay) * vy) / len2
  if t < -0.05 or t > 1.05 then return nil end
  t = math.max(0, math.min(1, t))
  local px, py = ax + vx * t, ay + vy * t
  local dist2 = (lx - px) ^ 2 + (ly - py) ^ 2
  if dist2 > 0.08 then return nil end
  return t
end

local function progressOnLane(lane, lx, ly)
  local ax, ay = dx[lane.entry] * 0.5, dy[lane.entry] * 0.5
  local bx, by = dx[lane.exit] * 0.5, dy[lane.exit] * 0.5
  if lane.type == "corner" then
    local first = progressOnSegment(lx, ly, ax, ay, 0, 0)
    local second = progressOnSegment(lx, ly, 0, 0, bx, by)
    if first and (not second or first <= second) then return first * 0.5 end
    if second then return 0.5 + second * 0.5 end
    return nil
  end
  return progressOnSegment(lx, ly, ax, ay, bx, by)
end

local function remapCargoInCell(x, y)
  for _, c in ipairs(cargo) do
    if cargoInCell(c, x, y) then
      local bestLane, bestProgress
      for lk, lane in pairs(flows.lanes) do
        if lane.x == x and lane.y == y and not lane.blocked then
          local p = progressOnLane(lane, c.localX or 0, c.localY or 0)
          if p and (not bestProgress or math.abs(p - c.progress) < math.abs(bestProgress - c.progress)) then
            bestLane, bestProgress = lk, p
          end
        end
      end
      if bestLane then
        c.lane, c.progress, c.visualLane, c.visualPoint, c.state = bestLane, bestProgress, laneSnapshot(flows.lanes[bestLane]), nil, "moving"
      else
        c.lane, c.progress, c.state = nil, 0, "waiting"
      end
    end
  end
end

local function remapWaitingCargo()
  for _, c in ipairs(cargo) do
    if c.state ~= "removed" and c.state == "waiting" then
      if not c.visualPoint then
        local lx, ly = cargoLocal(c)
        rememberCargoPoint(c, c.cellX or 1, c.cellY or 1, lx, ly)
      end
      remapCargoInCell(c.visualPoint.x, c.visualPoint.y)
    end
  end
end

local function transformCargoInCell(x, y, effect, duration)
  for _, c in ipairs(cargo) do
    if cargoInCell(c, x, y) then
      local lx, ly = cargoLocal(c)
      local rx, ry = transformLocal(lx, ly, effect)
      if effect == "rotate_cw" or effect == "rotate_ccw" then
        c.rotateTween = { x = x, y = y, lx = lx, ly = ly, turns = effect == "rotate_cw" and 1 or -1, time = 0, duration = duration or rotateTweenDuration }
      else
        c.effectTween = { x = x, y = y, lx = lx, ly = ly, tx = rx, ty = ry, time = 0, duration = duration or disturbanceTweenDuration }
      end
      rememberCargoPoint(c, x, y, rx, ry)
      c.state = "waiting"
    end
  end
end

local function transformCargoInRegion(d)
  for _, c in ipairs(cargo) do
    if c.state ~= "removed" then
      local lane = flows.lanes[c.lane] or c.visualLane
      local x, y = lane and lane.x or c.cellX, lane and lane.y or c.cellY
      if x and y and x >= d.x and y >= d.y and x < d.x + d.size and y < d.y + d.size then
        local lx, ly = cargoLocal(c)
        local gx, gy = x - d.x + 0.5, y - d.y + 0.5
        local tx, ty = transformRegionLocal(gx, gy, d.size, d.effect)
        local nx, ny = regionPointToCell(d.x, d.y, d.size, tx, ty)
        local nlx, nly = transformLocal(lx, ly, d.effect)
        c.regionTween = { x = d.x, y = d.y, size = d.size, effect = d.effect, gx = gx, gy = gy, lx = lx, ly = ly, time = 0, duration = disturbanceTweenDuration }
        rememberCargoPoint(c, nx, ny, nlx, nly)
        c.state = "waiting"
      end
    end
  end
end

local function rotateCargoInCell(x, y)
  transformCargoInCell(x, y, "rotate_cw")
end

local function laneAfter(lane)
  local nx, ny = lane.x + dx[lane.exit], lane.y + dy[lane.exit]
  if not inBounds(nx, ny) then return nil, "void" end
  local cell = board[ny][nx]
  if cell.kind == "dest" then return nil, "dest", cell.id end
  if cell.kind ~= "tile" then return nil, "blocked" end
  local entry = opposite[lane.exit]
  local options = flows.from[nx .. "," .. ny .. "," .. entry] or {}
  if #options == 0 then return nil, "blocked" end
  if cell.kind == "tile" and cell.type == "splitter" then
    local sk = key(nx, ny)
    splitState[sk] = splitState[sk] or 1
    local pick = options[((splitState[sk] - 1) % #options) + 1]
    return pick, "lane", nil, sk
  end
  return options[1], "lane"
end

local function deliver(destId, c)
  for _, d in ipairs(dests) do
    if d.id == destId then
      if d.req[c.type] and (d.got[c.type] or 0) < d.req[c.type] then
        d.got[c.type] = (d.got[c.type] or 0) + 1
      else
        d.wrong = d.wrong + 1
      end
      c.state = "removed"
      return
    end
  end
end

local function spawn(dt)
  for _, s in ipairs(sources) do
    s.timer = s.timer + dt
    if s.timer >= s.interval and (unlimitedStock or s.remaining == -1 or s.remaining > 0) then
      local sourceLanes = flows.sourceLanes[s.id]
      local lk = sourceLanes and sourceLanes[1]
      if sourceLanes and #sourceLanes > 1 then
        local lane = flows.lanes[sourceLanes[1]]
        local sk = lane and key(lane.x, lane.y)
        splitState[sk] = splitState[sk] or 1
        lk = sourceLanes[((splitState[sk] - 1) % #sourceLanes) + 1]
        if lk and laneHasSpace(lk, 0) then splitState[sk] = splitState[sk] + 1 end
      end
      if lk and laneHasSpace(lk, 0) then
        local lane = flows.lanes[lk]
        cargo[#cargo + 1] = { id = nextCargoId, type = s.cargoType, source = s.id, lane = lk, visualLane = laneSnapshot(lane), cellX = lane.x, cellY = lane.y, progress = 0, speed = 1.5, state = "moving" }
        nextCargoId = nextCargoId + 1
        if not unlimitedStock and s.remaining > 0 then s.remaining = s.remaining - 1 end
        s.timer = 0
      end
    end
  end
end

local function sortCargo()
  table.sort(cargo, function(a, b)
    if a.lane == b.lane then return a.progress > b.progress end
    return a.id < b.id
  end)
end

local function moveCargo(dt)
  sortCargo()
  for _, c in ipairs(cargo) do
    if c.state ~= "removed" then
      local lane = flows.lanes[c.lane]
      if not lane or lane.blocked then
        c.state = "waiting"
      else
        c.visualLane = laneSnapshot(lane)
        c.visualPoint = nil
        c.cellX, c.cellY = lane.x, lane.y
        c.localX, c.localY = cargoLocal(c)
        local target = math.min(1, c.progress + c.speed * dt)
        if laneHasSpace(c.lane, target, c.id, c.progress) or target <= c.progress then
          c.progress, c.state = target, "moving"
          c.localX, c.localY = cargoLocal(c)
        else
          c.state = "waiting"
        end
        if c.progress >= 1 then
          local nextLane, why, destId, splitterKey = laneAfter(lane)
          if why == "dest" then
            deliver(destId, c)
          elseif nextLane and laneHasSpace(nextLane, 0) then
            c.lane, c.progress, c.state = nextLane, 0, "moving"
            c.visualLane = laneSnapshot(flows.lanes[nextLane])
            c.visualPoint = nil
            c.cellX, c.cellY = c.visualLane.x, c.visualLane.y
            c.localX, c.localY = cargoLocal(c)
            if splitterKey then splitState[splitterKey] = (splitState[splitterKey] or 1) + 1 end
          else
            c.progress, c.state = 1, "waiting"
            c.localX, c.localY = cargoLocal(c)
          end
        end
      end
    end
  end
end

local function checkStatus()
  local ok = true
  for _, d in ipairs(dests) do
    for t, need in pairs(d.req) do
      if (d.got[t] or 0) < need then ok = false end
    end
  end
  if ok then status = "success"; return end
  local need = {}
  for _, d in ipairs(dests) do
    for t, n in pairs(d.req) do need[t] = (need[t] or 0) + math.max(0, n - (d.got[t] or 0)) end
  end
  for _, c in ipairs(cargo) do if c.state ~= "removed" then need[c.type] = (need[c.type] or 0) - 1 end end
  for _, s in ipairs(sources) do
    if unlimitedStock or s.remaining == -1 then need[s.cargoType] = -999999 else need[s.cargoType] = (need[s.cargoType] or 0) - s.remaining end
  end
  for _, n in pairs(need) do if n > 0 then status = "failure"; return end end
  status = "running"
end

local function cellAt(mx, my)
  mx, my = (mx - cameraX) / zoom, (my - cameraY) / zoom
  return math.floor((mx - OX) / CELL) + 1, math.floor((my - OY) / CELL) + 1
end

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

local function rotationLabel(r)
  return dirs[(r % 4) + 1]
end

local function panelHit(mx, my)
  local y = OY + H * CELL + 14
  if my < y or my > y + 58 then return nil end
  for i = 1, #names do
    local x = OX + (i - 1) * 112
    if mx >= x and mx <= x + 104 then return i end
  end
  return nil
end

local function drawTileIcon(tile, x, y, size)
  local cx, cy = x + size / 2, y + size / 2
  local function iconPoint(d)
    return cx + dx[d] * size * 0.32, cy + dy[d] * size * 0.32
  end
  love.graphics.setColor(0.84, 0.87, 0.82)
  love.graphics.setLineWidth(2)
  for _, segment in ipairs(tileSegments(tile)) do
    local ax, ay = iconPoint(segment[1])
    local bx, by = iconPoint(segment[2])
    if tile.type == "corner" then
      love.graphics.line(ax, ay, cx, cy)
      love.graphics.line(cx, cy, bx, by)
    else
      love.graphics.line(ax, ay, bx, by)
    end
  end
  local inputs, outputs = tilePorts(tile)
  love.graphics.setColor(0.1, 0.12, 0.13)
  for _, d in ipairs(inputs) do
    local px, py = iconPoint(d)
    love.graphics.rectangle("fill", px - 3, py - 3, 6, 6)
  end
  love.graphics.setColor(1, 0.86, 0.28)
  for _, d in ipairs(outputs) do
    local px, py = iconPoint(d)
    love.graphics.circle("fill", px, py, 3)
  end
  love.graphics.setLineWidth(1)
  love.graphics.print(tile.type:sub(1, 1):upper(), cx - 4, cy - 7)
end

local function drawPlacementPanel()
  local y = OY + H * CELL + 14
  love.graphics.setColor(colors.panel)
  love.graphics.rectangle("fill", OX - 6, y - 8, W * CELL + 12, 74, 4, 4)
  for i, name in ipairs(names) do
    local x = OX + (i - 1) * 112
    love.graphics.setColor(i == selected and colors.selected or colors.tile)
    love.graphics.rectangle("fill", x, y, 104, 54, 4, 4)
    love.graphics.setColor(i == selected and colors.hover or colors.grid)
    love.graphics.rectangle("line", x, y, 104, 54, 4, 4)
    drawTileIcon({ type = name, rotation = placementRotation }, x + 5, y + 5, 34)
    love.graphics.setColor(colors.text)
    love.graphics.print(i .. " " .. name, x + 42, y + 8)
    if i == selected then love.graphics.print("rot " .. placementRotation .. " " .. rotationLabel(placementRotation), x + 42, y + 28) end
  end
end

local function transformedDrawPoint(cx, cy, d, radius, tween)
  local lx, ly = rotateLocal(dx[d] * radius / CELL, dy[d] * radius / CELL, tween.fromRotation)
  local tx, ty = transformLocal(lx, ly, tween.effect)
  local t = easeOutQuint(math.min(1, tween.time / tween.duration))
  return cx + (lx + (tx - lx) * t) * CELL, cy + (ly + (ty - ly) * t) * CELL
end

local function tileDrawPoint(cx, cy, d, rot, tween)
  if tween then return transformedDrawPoint(cx, cy, d, PORT_RADIUS, tween) end
  return drawPoint(cx, cy, d, PORT_RADIUS, rot)
end

local function tileVisualCenter(x, y, cell)
  if cell.regionTween then
    local rt = cell.regionTween
    local t = easeOutQuint(math.min(1, rt.time / rt.duration))
    local gx, gy = tweenRegionLocal(rt.gx, rt.gy, rt.size, rt.effect, t)
    return OX + (rt.x + gx - 1) * CELL, OY + (rt.y + gy - 1) * CELL
  end
  return center(x, y)
end

local function regionTweenPoint(rt, lx, ly)
  local t = easeOutQuint(math.min(1, rt.time / rt.duration))
  local gx, gy = tweenRegionLocal(rt.gx + lx, rt.gy + ly, rt.size, rt.effect, t)
  return OX + (rt.x + gx - 1) * CELL, OY + (rt.y + gy - 1) * CELL
end

local function dirLocalPoint(d, rot)
  return rotateLocal(dx[d] * 0.5, dy[d] * 0.5, rot)
end

local function regionBaseRotation(cell)
  if cell.tweenFrom then return cell.tweenFrom end
  if cell.effectTween then return cell.effectTween.fromRotation end
  return cell.rotation
end

local function drawRegionTile(cell)
  local rt = cell.regionTween
  local x1, y1 = regionTweenPoint(rt, -0.5, -0.5)
  local x2, y2 = regionTweenPoint(rt, 0.5, -0.5)
  local x3, y3 = regionTweenPoint(rt, 0.5, 0.5)
  local x4, y4 = regionTweenPoint(rt, -0.5, 0.5)
  love.graphics.setColor(tileColor(cell))
  love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3, x4, y4)

  local cx, cy = regionTweenPoint(rt, 0, 0)
  love.graphics.setColor(0.86, 0.88, 0.8)
  love.graphics.print(cell.type:sub(1, 1):upper(), cx - 4, cy - 8)
  local rot = regionBaseRotation(cell)
  for _, segment in ipairs(baseTileSegments(cell.type)) do
    local axl, ayl = dirLocalPoint(segment[1], rot)
    local bxl, byl = dirLocalPoint(segment[2], rot)
    local ax, ay = regionTweenPoint(rt, axl, ayl)
    local bx, by = regionTweenPoint(rt, bxl, byl)
    if cell.type == "corner" then
      love.graphics.line(ax, ay, cx, cy)
      love.graphics.line(cx, cy, bx, by)
    else
      love.graphics.line(ax, ay, bx, by)
    end
  end
  local inputs, outputs = baseTilePorts(cell.type)
  love.graphics.setColor(0.1, 0.12, 0.13)
  for _, d in ipairs(inputs) do
    local pxl, pyl = dirLocalPoint(d, rot)
    local px, py = regionTweenPoint(rt, pxl, pyl)
    love.graphics.rectangle("fill", px - 5, py - 5, 10, 10)
  end
  love.graphics.setColor(1, 0.86, 0.28)
  for _, d in ipairs(outputs) do
    local pxl, pyl = dirLocalPoint(d, rot)
    local px, py = regionTweenPoint(rt, pxl, pyl)
    love.graphics.circle("fill", px, py, 5)
  end
end

local function drawTile(x, y, cell)
  if cell.regionTween then return drawRegionTile(cell) end
  local cx, cy = tileVisualCenter(x, y, cell)
  love.graphics.setColor(tileColor(cell))
  love.graphics.rectangle("fill", cx - CELL * 0.5, cy - CELL * 0.5, CELL - 1, CELL - 1)
  love.graphics.setColor(0.86, 0.88, 0.8)
  love.graphics.print(cell.type:sub(1, 1):upper(), cx - 4, cy - 8)
  local rot = visualRotation(cell)
  for _, segment in ipairs(baseTileSegments(cell.type)) do
    local ax, ay = tileDrawPoint(cx, cy, segment[1], rot, cell.effectTween)
    local bx, by = tileDrawPoint(cx, cy, segment[2], rot, cell.effectTween)
    if cell.type == "corner" then
      love.graphics.line(ax, ay, cx, cy)
      love.graphics.line(cx, cy, bx, by)
    else
      love.graphics.line(ax, ay, bx, by)
    end
  end
  local inputs, outputs = baseTilePorts(cell.type)
  love.graphics.setColor(0.1, 0.12, 0.13)
  for _, d in ipairs(inputs) do
    local px, py = tileDrawPoint(cx, cy, d, rot, cell.effectTween)
    love.graphics.rectangle("fill", px - 5, py - 5, 10, 10)
  end
  love.graphics.setColor(1, 0.86, 0.28)
  for _, d in ipairs(outputs) do
    local px, py = tileDrawPoint(cx, cy, d, rot, cell.effectTween)
    love.graphics.circle("fill", px, py, 5)
  end
end

local function drawFlow()
  if not flows or not flows.lanes then return end
  for _, lane in pairs(flows.lanes) do
    love.graphics.setColor(lane.blocked and colors.block or colors.flow)
    love.graphics.setLineWidth(3)
    local ax, ay = laneWorldPoint(lane, 0)
    local bx, by = laneWorldPoint(lane, 1)
    if lane.type == "corner" then
      local mx, my = laneWorldPoint(lane, 0.5)
      love.graphics.line(ax, ay, mx, my)
      love.graphics.line(mx, my, bx, by)
    else
      love.graphics.line(ax, ay, bx, by)
    end
    love.graphics.circle("fill", bx, by, 4)
    if debug then
      love.graphics.setColor(colors.text)
      love.graphics.print(tostring(lane.strength), (ax + bx) / 2, (ay + by) / 2)
    end
  end
  love.graphics.setLineWidth(1)
end

local function drawCargo()
  for _, c in ipairs(cargo) do
    if c.state ~= "removed" then
      if c.regionTween then
        local rt = c.regionTween
        local t = easeOutQuint(math.min(1, rt.time / rt.duration))
        local gx, gy = tweenRegionLocal(rt.gx + (rt.lx or 0), rt.gy + (rt.ly or 0), rt.size, rt.effect, t)
        love.graphics.setColor(c.state == "waiting" and colors.block or colors.cargo)
        love.graphics.circle("fill", OX + (rt.x + gx - 1) * CELL, OY + (rt.y + gy - 1) * CELL, 8)
      elseif c.rotateTween then
        local t = math.min(1, c.rotateTween.time / (c.rotateTween.duration or rotateTweenDuration))
        local lx, ly = rotateLocal(c.rotateTween.lx, c.rotateTween.ly, (c.rotateTween.turns or 1) * easeOutQuint(t))
        local cx, cy = center(c.rotateTween.x, c.rotateTween.y)
        love.graphics.setColor(c.state == "waiting" and colors.block or colors.cargo)
        love.graphics.circle("fill", cx + lx * CELL, cy + ly * CELL, 8)
      elseif c.effectTween then
        local t = easeOutQuint(math.min(1, c.effectTween.time / c.effectTween.duration))
        local cx, cy = center(c.effectTween.x, c.effectTween.y)
        local lx = c.effectTween.lx + (c.effectTween.tx - c.effectTween.lx) * t
        local ly = c.effectTween.ly + (c.effectTween.ty - c.effectTween.ly) * t
        love.graphics.setColor(c.state == "waiting" and colors.block or colors.cargo)
        love.graphics.circle("fill", cx + lx * CELL, cy + ly * CELL, 8)
      else
        local lane = flows.lanes[c.lane] or c.visualLane
        if lane then
        local x, y = laneWorldPoint(lane, c.progress)
        love.graphics.setColor(c.state == "waiting" and colors.block or colors.cargo)
        love.graphics.circle("fill", x, y, 8)
        elseif c.visualPoint then
        local cx, cy = center(c.visualPoint.x, c.visualPoint.y)
        love.graphics.setColor(colors.block)
        love.graphics.circle("fill", cx + c.visualPoint.lx * CELL, cy + c.visualPoint.ly * CELL, 8)
        end
      end
    end
  end
end

local function regionHasActiveLane(x, y, size)
  for yy = y, y + size - 1 do
    for xx = x, x + size - 1 do
      if board[yy][xx].kind == "source" or board[yy][xx].kind == "dest" then return false end
    end
  end
  for _, lane in pairs(flows.lanes) do
    if not lane.blocked and lane.x >= x and lane.y >= y and lane.x < x + size and lane.y < y + size then
      return true
    end
  end
  return false
end

local function randomDisturbanceRegion()
  local size = math.random(2, 3)
  for _ = 1, 80 do
    local x, y = math.random(1, W - size + 1), math.random(1, H - size + 1)
    if regionHasActiveLane(x, y, size) then return x, y, size end
  end
  return nil
end

local function startDisturbance()
  if dirty then recalcFlow() end
  local x, y, size = randomDisturbanceRegion()
  if not x then return end
  local effect = disturbanceEffects[math.random(1, #disturbanceEffects)]
  pendingDisturbance = { x = x, y = y, size = size, effect = effect.id, label = effect.label, timer = disturbanceDelay, phase = "alert" }
  replayEvents[#replayEvents + 1] = { t = simTime, action = "disturbance_alert", x = x, y = y, size = size, effect = effect.id }
end

local function applyDisturbance(d)
  transformCargoInRegion(d)
  local moved = {}
  for y = d.y, d.y + d.size - 1 do
    for x = d.x, d.x + d.size - 1 do
      local cell = board[y][x]
      local gx, gy = x - d.x + 0.5, y - d.y + 0.5
      local tx, ty = transformRegionLocal(gx, gy, d.size, d.effect)
      local nx, ny = regionPointToCell(d.x, d.y, d.size, tx, ty)
      moved[key(nx, ny)] = cell
      if cell.kind == "tile" then
        cell.regionTween = { x = d.x, y = d.y, size = d.size, effect = d.effect, gx = gx, gy = gy, time = 0, duration = disturbanceTweenDuration }
        transformTileRotation(cell, d.effect)
      end
    end
  end
  for y = d.y, d.y + d.size - 1 do
    for x = d.x, d.x + d.size - 1 do board[y][x] = moved[key(x, y)] or { kind = "empty" } end
  end
  dirty = true
  recalcFlow()
  for y = d.y, d.y + d.size - 1 do
    for x = d.x, d.x + d.size - 1 do remapCargoInCell(x, y) end
  end
  replayEvents[#replayEvents + 1] = { t = simTime, action = "disturbance_apply", x = d.x, y = d.y, size = d.size, effect = d.effect }
end

local function updateDisturbance(dt)
  if not pendingDisturbance then return end
  pendingDisturbance.timer = pendingDisturbance.timer - dt
  if pendingDisturbance.phase == "alert" and pendingDisturbance.timer <= 0 then
    applyDisturbance(pendingDisturbance)
    pendingDisturbance.phase = "animating"
    pendingDisturbance.timer = disturbanceTweenDuration
  elseif pendingDisturbance.phase == "animating" and pendingDisturbance.timer <= 0 then
    pendingDisturbance = nil
  end
end

local function disturbanceLocksSimulation()
  return pendingDisturbance and pendingDisturbance.phase == "animating"
end

local function disturbanceGlyph(effect)
  if effect == "rotate_cw" then return "+90" end
  if effect == "rotate_ccw" then return "-90" end
  if effect == "flip_h" then return "<>" end
  if effect == "flip_v" then return "^v" end
  if effect == "flip_diag_main" then return "\\" end
  if effect == "flip_diag_anti" then return "/" end
  return "?"
end

local function previewLocalPoint(lx, ly, effect, t)
  if effect == "rotate_cw" then return rotateLocal(lx, ly, t) end
  if effect == "rotate_ccw" then return rotateLocal(lx, ly, -t) end
  local tx, ty = transformLocal(lx, ly, effect)
  return lx + (tx - lx) * t, ly + (ty - ly) * t
end

local function drawDisturbancePreviewQuad(d)
  if d.phase ~= "alert" then return end
  local t = easeOutQuint(simTime % 1)
  local cx = OX + (d.x + d.size * 0.5 - 1) * CELL
  local cy = OY + (d.y - 1) * CELL - CELL * 0.62
  local s = CELL * 0.78
  local function p(lx, ly)
    local x, y = previewLocalPoint(lx, ly, d.effect, t)
    return cx + x * s, cy + y * s
  end
  local x1, y1 = p(-0.5, -0.5)
  local x2, y2 = p(0.5, -0.5)
  local x3, y3 = p(0.5, 0.5)
  local x4, y4 = p(-0.5, 0.5)
  love.graphics.setColor(1, 0.86, 0.28, 0.18)
  love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3, x4, y4)
  love.graphics.setColor(1, 0.86, 0.28, 0.95)
  love.graphics.setLineWidth(2)
  love.graphics.polygon("line", x1, y1, x2, y2, x3, y3, x4, y4)
  local ax, ay = p(-0.5, 0)
  local mx, my = p(0, 0)
  local bx, by = p(0, -0.5)
  love.graphics.line(ax, ay, mx, my)
  love.graphics.line(mx, my, bx, by)
  love.graphics.print(disturbanceGlyph(d.effect), cx - 10, cy - 8)
end

local function drawDisturbanceAlertWorld()
  if not pendingDisturbance then return end
  local d = pendingDisturbance
  love.graphics.setColor(1, 0.16, 0.12, 0.22)
  love.graphics.rectangle("fill", OX + (d.x - 1) * CELL, OY + (d.y - 1) * CELL, d.size * CELL, d.size * CELL)
  love.graphics.setColor(1, 0.16, 0.12)
  love.graphics.setLineWidth(4)
  love.graphics.rectangle("line", OX + (d.x - 1) * CELL, OY + (d.y - 1) * CELL, d.size * CELL, d.size * CELL)
  if d.phase == "alert" then
    drawDisturbancePreviewQuad(d)
  end
  love.graphics.setLineWidth(1)
end

local function drawDisturbanceAlertUi()
  if not pendingDisturbance then return end
  love.graphics.setColor(1, 0.25, 0.18)
  local prefix = pendingDisturbance.phase == "animating" and "EFFECT " or "ALERT "
  love.graphics.print(prefix .. pendingDisturbance.label .. " " .. pendingDisturbance.size .. "x" .. pendingDisturbance.size .. " in " .. string.format("%.1f", pendingDisturbance.timer), 620, 18)
end

local function drawDumpOverlay()
  if not dumpOverlay then return end
  local x, y, w, h = 40, 96, 840, 390
  love.graphics.setColor(0.04, 0.045, 0.05, 0.94)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  love.graphics.setColor(1, 0.86, 0.28)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
  love.graphics.setColor(colors.text)
  love.graphics.print(dumpOverlay.title, x + 16, y + 14)
  love.graphics.print(dumpOverlay.message .. "  Esc: close", x + 16, y + 36)
  local shown = 0
  for line in (dumpOverlay.text .. "\n"):gmatch("(.-)\n") do
    love.graphics.print(line:sub(1, 118), x + 16, y + 66 + shown * 16)
    shown = shown + 1
    if shown >= 19 then
      love.graphics.print("... full dump is in the opened text tab / clipboard attempt", x + 16, y + 66 + shown * 16)
      break
    end
  end
end

local function exportDebugState()
  local lines = {
    "Nitori Factory Debug State",
    "scenario=" .. scenario .. " status=" .. status .. " paused=" .. tostring(paused) .. " unlimitedStock=" .. tostring(unlimitedStock),
    "selected=" .. names[selected] .. " placementRotation=" .. placementRotation .. " zoom=" .. string.format("%.2f", zoom),
    "",
    "Board:",
  }
  local mark = { empty = ".", source = "A", dest = "B" }
  for y = 1, H do
    local row = {}
    for x = 1, W do
      local cell = board[y][x]
      row[#row + 1] = cell.kind == "tile" and (cell.type:sub(1, 1):upper() .. cell.rotation) or mark[cell.kind]
    end
    lines[#lines + 1] = table.concat(row, " ")
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Sources:"
  for _, s in ipairs(sources) do
    lines[#lines + 1] = string.format("%s pos=%d,%d out=%s strength=%s cargo=%s remaining=%s", s.id, s.x, s.y, s.output, s.strength, s.cargoType, s.remaining)
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Destinations:"
  for _, d in ipairs(dests) do
    for t, need in pairs(d.req) do
      lines[#lines + 1] = string.format("%s pos=%d,%d %s=%d/%d wrong=%d", d.id, d.x, d.y, t, d.got[t] or 0, need, d.wrong)
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Cargo:"
  for _, c in ipairs(cargo) do
    if c.state ~= "removed" then
      lines[#lines + 1] = string.format("#%d type=%s state=%s lane=%s progress=%.3f cell=%s,%s local=%.3f,%.3f visual=%s",
        c.id, c.type, c.state, c.lane or "nil", c.progress or 0, c.cellX or "?", c.cellY or "?",
        c.localX or 0, c.localY or 0, c.visualPoint and (c.visualPoint.x .. "," .. c.visualPoint.y) or "none")
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Flow lanes:"
  for lk, lane in pairs(flows.lanes) do
    lines[#lines + 1] = string.format("%s source=%s strength=%s blocked=%s", lk, lane.source, lane.strength, tostring(lane.blocked or false))
  end
  return table.concat(lines, "\n")
end

local function q(s)
  return string.format("%q", tostring(s))
end

local function replayDumpText()
  local lines = {
    "NitoriReplay = {",
    "  version = 1,",
    "  elapsed = " .. string.format("%.3f", simTime) .. ",",
    "  scenario = " .. scenario .. ",",
    "  status = " .. q(status) .. ",",
    "  unlimitedStock = " .. tostring(unlimitedStock) .. ",",
    "  events = {",
  }
  for _, e in ipairs(replayEvents) do
    if e.action == "scenario" then
      lines[#lines + 1] = string.format("    { t = %.3f, action = %s, scenario = %d },", e.t, q(e.action), e.scenario)
    elseif e.action == "place" then
      lines[#lines + 1] = string.format("    { t = %.3f, action = %s, x = %d, y = %d, tile = %s, rotation = %d },", e.t, q(e.action), e.x, e.y, q(e.tile), e.rotation)
    elseif e.action == "remove" or e.action == "rotate" then
      lines[#lines + 1] = string.format("    { t = %.3f, action = %s, x = %d, y = %d },", e.t, q(e.action), e.x, e.y)
    elseif e.action == "disturbance_alert" or e.action == "disturbance_apply" then
      lines[#lines + 1] = string.format("    { t = %.3f, action = %s, x = %d, y = %d, size = %d, effect = %s },", e.t, q(e.action), e.x, e.y, e.size, q(e.effect))
    elseif e.action == "unlimited_stock" then
      lines[#lines + 1] = string.format("    { t = %.3f, action = %s, enabled = %s },", e.t, q(e.action), tostring(e.enabled))
    end
  end
  lines[#lines + 1] = "  },"
  lines[#lines + 1] = "  snapshot = {"
  lines[#lines + 1] = "    board = {"
  local mark = { empty = ".", source = "A", dest = "B" }
  for y = 1, H do
    local row = {}
    for x = 1, W do
      local cell = board[y][x]
      row[#row + 1] = cell.kind == "tile" and (cell.type:sub(1, 1):upper() .. cell.rotation) or mark[cell.kind]
    end
    lines[#lines + 1] = "      " .. q(table.concat(row, " ")) .. ","
  end
  lines[#lines + 1] = "    },"
  lines[#lines + 1] = "    cargo = {"
  for _, c in ipairs(cargo) do
    if c.state ~= "removed" then
      local visual = c.visualPoint and string.format(", visualPoint = { x = %d, y = %d, lx = %.3f, ly = %.3f }", c.visualPoint.x, c.visualPoint.y, c.visualPoint.lx, c.visualPoint.ly) or ""
      lines[#lines + 1] = string.format("      { id = %d, type = %s, state = %s, lane = %s, progress = %.3f, cellX = %s, cellY = %s, localX = %.3f, localY = %.3f%s },",
        c.id, q(c.type), q(c.state), c.lane and q(c.lane) or "nil", c.progress or 0, tostring(c.cellX or "nil"), tostring(c.cellY or "nil"), c.localX or 0, c.localY or 0, visual)
    end
  end
  lines[#lines + 1] = "    },"
  lines[#lines + 1] = "  },"
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n")
end

local function urlEncode(s)
  return (s:gsub("\n", "\r\n"):gsub("([^%w%-_%.~ ])", function(c)
    return string.format("%%%02X", c:byte())
  end):gsub(" ", "%%20"))
end

local function showDump(title, text)
  local copied = pcall(function() love.system.setClipboardText(text) end)
  local opened = love.system.openURL and pcall(function()
    love.system.openURL("nitori-dump:" .. urlEncode(title) .. ":" .. urlEncode(text))
  end)
  dumpOverlay = {
    title = title,
    text = text,
    message = (copied and "Clipboard attempted. " or "Clipboard blocked. ") .. (opened and "Editable web textbox requested." or "Web textbox unavailable."),
  }
end

function love.load()
  math.randomseed(os.time())
  love.graphics.setFont(love.graphics.newFont(13))
  selected, placementRotation, paused, debug, unlimitedStock = 1, 0, false, true, false
  loadScenario(1)
end

function love.update(dt)
  simTime = simTime + dt
  updateDisturbance(dt)
  if dirty then
    recalcFlow()
  end
  remapWaitingCargo()
  updateTileTweens(dt)
  updateCargoTweens(dt)
  local move = cameraSpeed * dt
  if love.keyboard.isDown("a") then cameraX = cameraX + move end
  if love.keyboard.isDown("d") then cameraX = cameraX - move end
  if love.keyboard.isDown("w") then cameraY = cameraY + move end
  if love.keyboard.isDown("s") then cameraY = cameraY - move end
  if not paused and not disturbanceLocksSimulation() then
    if status == "running" then spawn(dt) end
    moveCargo(dt)
    if status == "running" then checkStatus() end
  end
end

function love.draw()
  love.graphics.clear(colors.bg)
  love.graphics.setColor(colors.text)
  love.graphics.print("Wheel: zoom  WASD: camera  Left: place/replace  Right: remove  R: rotate  B: disturbance  U: unlimited stock  Space: pause  `: debug  C: copy state  V: replay  F: flow  Tab: scenario", 24, 18)
  love.graphics.print("Selected: " .. names[selected] .. "   Rotation: " .. placementRotation .. " " .. rotationLabel(placementRotation) .. "   Zoom: " .. string.format("%.2f", zoom) .. "   Scenario: " .. scenario .. "   State: " .. status .. (paused and " paused" or "") .. "   Stock: " .. (unlimitedStock and "unlimited" or "scenario"), 24, 42)

  local hx, hy = cellAt(love.mouse.getPosition())
  love.graphics.push()
  love.graphics.translate(cameraX, cameraY)
  love.graphics.scale(zoom)
  for y = 1, H do
    for x = 1, W do
      love.graphics.setColor(colors.empty)
      love.graphics.rectangle("fill", OX + (x - 1) * CELL, OY + (y - 1) * CELL, CELL - 1, CELL - 1)
      local cell = board[y][x]
      if cell.kind == "tile" then drawTile(x, y, cell) end
      if cell.kind == "source" then
        love.graphics.setColor(colors.source)
        love.graphics.rectangle("fill", OX + (x - 1) * CELL + 4, OY + (y - 1) * CELL + 4, CELL - 8, CELL - 8, 4, 4)
        love.graphics.setColor(colors.text); love.graphics.print(cell.id, OX + (x - 1) * CELL + 13, OY + (y - 1) * CELL + 15)
      elseif cell.kind == "dest" then
        love.graphics.setColor(colors.dest)
        love.graphics.rectangle("fill", OX + (x - 1) * CELL + 4, OY + (y - 1) * CELL + 4, CELL - 8, CELL - 8, 4, 4)
        love.graphics.setColor(colors.text); love.graphics.print(cell.id, OX + (x - 1) * CELL + 13, OY + (y - 1) * CELL + 15)
      end
      love.graphics.setColor(colors.grid)
      love.graphics.rectangle("line", OX + (x - 1) * CELL, OY + (y - 1) * CELL, CELL, CELL)
    end
  end
  if inBounds(hx, hy) then
    love.graphics.setColor(colors.hover)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", OX + (hx - 1) * CELL + 2, OY + (hy - 1) * CELL + 2, CELL - 4, CELL - 4, 4, 4)
    love.graphics.setLineWidth(1)
  end
  drawDisturbanceAlertWorld()
  if debug then drawFlow() end
  drawCargo()
  love.graphics.pop()
  drawPlacementPanel()
  drawDisturbanceAlertUi()

  local panelX = OX + W * CELL + 24
  love.graphics.setColor(colors.text)
  love.graphics.print("Sources", panelX, OY)
  local line = 1
  for _, s in ipairs(sources) do
    love.graphics.print(s.id .. " " .. s.cargoType .. " stock:" .. (unlimitedStock and "unlimited" or tostring(s.remaining)), panelX, OY + line * 20)
    line = line + 1
  end
  line = line + 1
  love.graphics.print("Destinations", panelX, OY + line * 20)
  line = line + 1
  for _, d in ipairs(dests) do
    for t, n in pairs(d.req) do
      love.graphics.print(d.id .. " " .. t .. " " .. tostring(d.got[t] or 0) .. "/" .. n .. " wrong:" .. d.wrong, panelX, OY + line * 20)
      line = line + 1
    end
  end
  drawDumpOverlay()
end

function love.mousepressed(mx, my, button)
  local hit = panelHit(mx, my)
  if hit and button == 1 then
    selected = hit
    return
  end
  local x, y = cellAt(mx, my)
  if not inBounds(x, y) then return end
  if button == 1 then
    if cellHasCargo(x, y) then return end
    if setTile(x, y, names[selected], placementRotation) then
      replayEvents[#replayEvents + 1] = { t = simTime, action = "place", x = x, y = y, tile = names[selected], rotation = placementRotation }
    end
  elseif button == 2 and board[y][x].kind == "tile" then
    if cellHasCargo(x, y) then return end
    board[y][x] = { kind = "empty" }
    dirty = true
    replayEvents[#replayEvents + 1] = { t = simTime, action = "remove", x = x, y = y }
  end
end

function love.keypressed(k)
  if k >= "1" and k <= "5" then selected = tonumber(k) end
  if k == "escape" then dumpOverlay = nil end
  if k == "space" then paused = not paused end
  if k == "`" or k == "grave" then debug = not debug end
  if k == "c" then showDump("Nitori Debug State", exportDebugState()) end
  if k == "v" then showDump("Nitori Replay Dump", replayDumpText()) end
  if k == "b" then startDisturbance() end
  if k == "u" then
    unlimitedStock = not unlimitedStock
    replayEvents[#replayEvents + 1] = { t = simTime, action = "unlimited_stock", enabled = unlimitedStock }
  end
  if k == "f" then dirty = true end
  if k == "tab" then loadScenario(scenario % 3 + 1) end
  if k == "r" then
    local x, y = cellAt(love.mouse.getPosition())
    if inBounds(x, y) and board[y][x].kind == "tile" then
      rotateCargoInCell(x, y)
      rotateTile(board[y][x])
      placementRotation = board[y][x].rotation
      dirty = true
      recalcFlow()
      remapCargoInCell(x, y)
      replayEvents[#replayEvents + 1] = { t = simTime, action = "rotate", x = x, y = y }
    else
      placementRotation = (placementRotation + 1) % 4
    end
  end
end

function love.wheelmoved(_, y)
  if y == 0 then return end
  local mx, my = love.mouse.getPosition()
  local beforeX, beforeY = (mx - cameraX) / zoom, (my - cameraY) / zoom
  zoom = clamp(zoom * (y > 0 and 1.12 or 1 / 1.12), 0.5, 2.5)
  cameraX, cameraY = mx - beforeX * zoom, my - beforeY * zoom
end
