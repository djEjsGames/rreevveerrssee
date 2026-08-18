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

local board, sources, dests, flows, cargo, selected, placementRotation, paused, debug, status
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
    local t = math.min(1, tile.tweenTime / rotateTweenDuration)
    return tile.tweenFrom + (tile.tweenTo - tile.tweenFrom) * easeOutQuint(t)
  end
  return tile.rotation
end

local function rotateTile(tile)
  local from = visualRotation(tile)
  tile.rotation = (tile.rotation + 1) % 4
  tile.tweenFrom, tile.tweenTo, tile.tweenTime = from, from + 1, 0
end

local function updateTileTweens(dt)
  for y = 1, H do
    for x = 1, W do
      local tile = board[y][x]
      if tile.kind == "tile" and tile.tweenTime then
        tile.tweenTime = tile.tweenTime + dt
        if tile.tweenTime >= rotateTweenDuration then
          tile.tweenFrom, tile.tweenTo, tile.tweenTime = nil, nil, nil
        end
      end
    end
  end
end

local function updateCargoTweens(dt)
  for _, c in ipairs(cargo) do
    if c.rotateTween then
      c.rotateTween.time = c.rotateTween.time + dt
      if c.rotateTween.time >= rotateTweenDuration then c.rotateTween = nil end
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

local function rotateCargoInCell(x, y)
  for _, c in ipairs(cargo) do
    if cargoInCell(c, x, y) then
      local lx, ly = cargoLocal(c)
      local rx, ry = rotateLocal(lx, ly, 1)
      c.rotateTween = { x = x, y = y, lx = lx, ly = ly, time = 0 }
      rememberCargoPoint(c, x, y, rx, ry)
      c.state = "waiting"
    end
  end
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
    if s.timer >= s.interval and (s.remaining == -1 or s.remaining > 0) then
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
        if s.remaining > 0 then s.remaining = s.remaining - 1 end
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
    if s.remaining == -1 then need[s.cargoType] = -999999 else need[s.cargoType] = (need[s.cargoType] or 0) - s.remaining end
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

local function drawTile(x, y, cell)
  love.graphics.setColor(tileColor(cell))
  love.graphics.rectangle("fill", OX + (x - 1) * CELL, OY + (y - 1) * CELL, CELL - 1, CELL - 1)
  local cx, cy = center(x, y)
  love.graphics.setColor(0.86, 0.88, 0.8)
  love.graphics.print(cell.type:sub(1, 1):upper(), cx - 4, cy - 8)
  local rot = visualRotation(cell)
  for _, segment in ipairs(baseTileSegments(cell.type)) do
    local ax, ay = drawPoint(cx, cy, segment[1], PORT_RADIUS, rot)
    local bx, by = drawPoint(cx, cy, segment[2], PORT_RADIUS, rot)
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
    local px, py = drawPoint(cx, cy, d, PORT_RADIUS, rot)
    love.graphics.rectangle("fill", px - 5, py - 5, 10, 10)
  end
  love.graphics.setColor(1, 0.86, 0.28)
  for _, d in ipairs(outputs) do
    local px, py = drawPoint(cx, cy, d, PORT_RADIUS, rot)
    love.graphics.circle("fill", px, py, 5)
  end
end

local function drawFlow()
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
      if c.rotateTween then
        local t = math.min(1, c.rotateTween.time / rotateTweenDuration)
        local lx, ly = rotateLocal(c.rotateTween.lx, c.rotateTween.ly, easeOutQuint(t))
        local cx, cy = center(c.rotateTween.x, c.rotateTween.y)
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

local function exportDebugState()
  local lines = {
    "Nitori Factory Debug State",
    "scenario=" .. scenario .. " status=" .. status .. " paused=" .. tostring(paused),
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
  love.system.setClipboardText(table.concat(lines, "\n"))
end

local function q(s)
  return string.format("%q", tostring(s))
end

local function exportReplayDump()
  local lines = {
    "NitoriReplay = {",
    "  version = 1,",
    "  elapsed = " .. string.format("%.3f", simTime) .. ",",
    "  scenario = " .. scenario .. ",",
    "  status = " .. q(status) .. ",",
    "  events = {",
  }
  for _, e in ipairs(replayEvents) do
    if e.action == "scenario" then
      lines[#lines + 1] = string.format("    { t = %.3f, action = %s, scenario = %d },", e.t, q(e.action), e.scenario)
    elseif e.action == "place" then
      lines[#lines + 1] = string.format("    { t = %.3f, action = %s, x = %d, y = %d, tile = %s, rotation = %d },", e.t, q(e.action), e.x, e.y, q(e.tile), e.rotation)
    elseif e.action == "remove" or e.action == "rotate" then
      lines[#lines + 1] = string.format("    { t = %.3f, action = %s, x = %d, y = %d },", e.t, q(e.action), e.x, e.y)
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
  love.system.setClipboardText(table.concat(lines, "\n"))
end

function love.load()
  love.graphics.setFont(love.graphics.newFont(13))
  selected, placementRotation, paused, debug = 1, 0, false, true
  loadScenario(1)
end

function love.update(dt)
  simTime = simTime + dt
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
  if not paused then
    if status == "running" then spawn(dt) end
    moveCargo(dt)
    if status == "running" then checkStatus() end
  end
end

function love.draw()
  love.graphics.clear(colors.bg)
  love.graphics.setColor(colors.text)
  love.graphics.print("Wheel: zoom  WASD: camera  Left: place/replace  Right: remove  R: rotate  Space: pause  `: debug  C: copy state  V: replay  F: flow  Tab: scenario", 24, 18)
  love.graphics.print("Selected: " .. names[selected] .. "   Rotation: " .. placementRotation .. " " .. rotationLabel(placementRotation) .. "   Zoom: " .. string.format("%.2f", zoom) .. "   Scenario: " .. scenario .. "   State: " .. status .. (paused and " paused" or ""), 24, 42)

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
  if debug then drawFlow() end
  drawCargo()
  love.graphics.pop()
  drawPlacementPanel()

  local panelX = OX + W * CELL + 24
  love.graphics.setColor(colors.text)
  love.graphics.print("Sources", panelX, OY)
  local line = 1
  for _, s in ipairs(sources) do
    love.graphics.print(s.id .. " " .. s.cargoType .. " stock:" .. tostring(s.remaining), panelX, OY + line * 20)
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
  if k == "space" then paused = not paused end
  if k == "`" or k == "grave" then debug = not debug end
  if k == "c" then exportDebugState() end
  if k == "v" then exportReplayDump() end
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
