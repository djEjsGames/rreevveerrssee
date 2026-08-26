local config = require("src.config")
local common = require("src.common")
local editor = require("src.editor")
local scenarios = require("src.scenarios")
storyDialogueScene = require("src.dialogue_scene")
dialogueScripts = require("src.dialogue_scripts")
local tileRules = require("src.tile_rules")
local flowRules = require("src.flow")

local W, H, CELL = config.board.w, config.board.h, config.board.cell
local PORT_RADIUS = CELL * 0.5
local OX, OY = config.board.ox, config.board.oy
local EDITOR_BOARD_SIZES = config.editorBoardSizes
local dirs, dx, dy, opposite = config.dirs, config.dx, config.dy, config.opposite
local names, editorNames = config.names, config.editorNames
local colors = config.colors

local board, sources, dests, flows, cargo, selected, editorSelected, placementRotation, paused, debug, status, unlimitedStock
local nextCargoId = 1
local nextSchemaId, schemaStock, pendingSchema = 1, 2, nil
local editorMode, editorSizing, editorMessage = false, false, ""
local topTab = "build"
local dirty = true
local splitState = {}
local scenario = 1
local scenarioTitle = ""
local cargoSpacing = config.cargoSpacing
local rotateTweenDuration = config.rotateTweenDuration
local cameraX, cameraY, zoom = 0, 0, 1
local cameraSpeed = config.cameraSpeed
local simTime = 0
local replayEvents = {}
local pendingDisturbance = nil
local disturbanceTweenDuration = config.disturbanceTweenDuration
local deniedShakes = {}
recallCargo = {}
lostCargo = 0
dragStart = nil
consumableOrder = { "none", "cirno_wing", "momoyo_pickaxe" }
consumableCounts = { cirno_wing = 3, momoyo_pickaxe = 3 }
equippedConsumable = 1
consumableTween = nil
ruleInversions = { reverseFlow = false, swapSplitMerge = false }
portraits = {}
icons = {}
backgrounds = {}
characterCue = nil
bgm = nil
uiFont, dialogFont = nil, nil
sfxSources, activeSfx = {}, {}
local bgmIndex = 0
local bgmTracks = { "assets/audio/bgm1.mp3", "assets/audio/bgm2.mp3" }
bgmFade = nil
dialogueTestPanelOpen = false
disturbanceTimer = config.firstDisturbanceDelay
disturbanceAutoEnabled = true
disturbancesBlocked = true
rumiaOrb = nil
rumiaTrail = {}
cooldownSliderDrag = false
gameScene = "map"
mapAreas = {
  { name = "Youkai Mountain", jp = "요괴의 산", enabled = true, areaId = "youkai_mountain", scenario = 3, x = 80, y = 70, w = 420, h = 300, tiles = "cliff path, waterfall pipe, kappa gear", obstacles = "cliff, rapid, patrol post" },
  { name = "Moriya Shrine", jp = "모리야 신사", scenario = 4, x = 250, y = 47, w = 190, h = 95, tiles = "shrine path, faith conduit, lake bridge", obstacles = "sacred tree, shrine rope, wind lake" },
  { name = "Tengu Base", jp = "텐구 기지", scenario = 3, x = 370, y = 190, w = 150, h = 95, tiles = "watch route, wind post, report lane", obstacles = "watchtower, barricade, cliff edge" },
  { name = "Geyser", jp = "간헐천", scenario = 2, x = -32, y = 142, w = 180, h = 100, tiles = "steam pipe, heat valve, pressure bend", obstacles = "geyser vent, hot spring, steam wall" },
  { name = "Former Hell", jp = "지령전", scenario = 1, x = 80, y = 440, w = 360, h = 210, tiles = "underground rail, furnace duct, mind corridor", obstacles = "lava crack, old hell wall, vengeful spirit" },
  { name = "Misty Lake", jp = "안개 호수", scenario = 4, x = 590, y = 100, w = 330, h = 210, tiles = "pier route, ice channel, fog lane", obstacles = "lake water, thin ice, thick fog" },
  { name = "Scarlet Devil Mansion", jp = "홍마관", scenario = 5, x = 705, y = 170, w = 170, h = 95, tiles = "red hall, library rail, servant passage", obstacles = "wall, bookshelf, locked door" },
  { name = "Hakurei Shrine", jp = "하쿠레이 신사", scenario = 1, x = 1180, y = 120, w = 230, h = 120, tiles = "approach path, torii turn, border line", obstacles = "forest, stairs, barrier stone" },
  { name = "Human Village", jp = "인간 마을", scenario = 2, x = 700, y = 420, w = 300, h = 190, tiles = "street, shop alley, storehouse lane", obstacles = "house, fence, well" },
  { name = "Palanquin Ship", jp = "성련선", scenario = 6, x = 1060, y = 415, w = 240, h = 115, tiles = "deck route, cargo hold, cloud wake", obstacles = "mast, railing, sail" },
  { name = "Divine Spirit Mausoleum", jp = "신령묘", scenario = 7, x = 1110, y = 560, w = 220, h = 110, tiles = "stone chamber, talisman path, tao conduit", obstacles = "tombstone, sealed door, stone wall" },
  { name = "Bamboo Forest", jp = "미혹의 죽림", scenario = 3, x = 1230, y = 720, w = 360, h = 230, tiles = "bamboo trail, moonlit bend, hidden track", obstacles = "bamboo thicket, blind path, rabbit trap" },
  { name = "Eientei", jp = "영원정", scenario = 8, x = 1365, y = 805, w = 170, h = 95, tiles = "mansion hall, medicine line, moon corridor", obstacles = "sliding door, medicine shelf, illusion screen" },
  { name = "Sunflower Field", jp = "해바라기 밭", scenario = 6, x = 560, y = 760, w = 360, h = 180, tiles = "flower row, sunny path, fairy loop", obstacles = "sunflower wall, tall grass, fairy crowd" },
  { name = "Hakugyokurou", jp = "백옥루", scenario = 7, x = 1000, y = -120, w = 260, h = 120, tiles = "cherry path, ghost stair, nether bridge", obstacles = "cherry tree, spirit wall, garden gate" },
  { name = "Beast Realm", jp = "축생계", scenario = 5, x = 1480, y = 430, w = 240, h = 150, tiles = "beast road, faction track, arena route", obstacles = "mud, bone fence, territory wall" },
}
currentArea = nil
local disturbanceEffects = config.disturbanceEffects
local key, laneKey = common.key, common.laneKey
local function inBounds(x, y) return common.inBounds(x, y, W, H) end
local cellHasCargo, cellAt, denyCellAction
local rotationLabel
local fitBoardToView, resetScenario
local function hasDir(list, dir) return common.hasDir(list, dir, dirs) end
local function dirIndex(d) return common.dirIndex(dirs, d) end
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

local function canModifyCell(cell, layer)
  if cell.occupiedBy and layer ~= "editor" then return false end
  if layer == "disturbance" then return cell.kind ~= "source" and cell.kind ~= "dest" end
  if layer == "editor" then return true end
  return not cell.immutable
end

local function removeFrom(list, x, y)
  for i = #list, 1, -1 do
    if list[i].x == x and list[i].y == y then table.remove(list, i) end
  end
end

local function setTile(x, y, typeName, rot, layer)
  if not canModifyCell(board[y][x], layer or "player") then return false end
  if board[y][x].type == "schema_in" or board[y][x].type == "schema_out" then return false end
  if recallCargoInCell then recallCargoInCell(x, y) end
  board[y][x] = { kind = "tile", type = typeName, rotation = rot or 0 }
  dirty = true
  return true
end

local function setSchemaTile(x, y, part, pair, rot, layer)
  if not canModifyCell(board[y][x], layer or "player") then return false end
  if recallCargoInCell then recallCargoInCell(x, y) end
  board[y][x] = { kind = "tile", type = part == "in" and "schema_in" or "schema_out", pair = pair, rotation = rot or 0 }
  dirty = true
  return true
end

local function findSchemaPart(pair, part)
  local typeName = part == "in" and "schema_in" or "schema_out"
  for y = 1, H do
    for x = 1, W do
      local cell = board[y][x]
      if cell.kind == "tile" and cell.type == typeName and cell.pair == pair then return x, y, cell end
    end
  end
end

local function schemaPairComplete(pair)
  return findSchemaPart(pair, "in") and findSchemaPart(pair, "out")
end

local function removeTileAt(x, y)
  local cell = board[y][x]
  if cell.kind ~= "tile" then return false end
  if cell.type == "schema_in" or cell.type == "schema_out" then
    local complete = schemaPairComplete(cell.pair)
    for yy = 1, H do
      for xx = 1, W do
        local other = board[yy][xx]
        if other.kind == "tile" and other.pair == cell.pair then
          if recallCargoInCell then recallCargoInCell(xx, yy) end
          board[yy][xx] = { kind = "empty" }
        end
      end
    end
    if pendingSchema and pendingSchema.pair == cell.pair then pendingSchema = nil end
    if complete then schemaStock = schemaStock + 1 end
  else
    if recallCargoInCell then recallCargoInCell(x, y) end
    board[y][x] = { kind = "empty" }
  end
  dirty = true
  return true
end

local function clearCellAt(x, y)
  local cell = board[y][x]
  if cell.kind == "tile" then removeTileAt(x, y); return end
  if cell.kind == "source" then removeFrom(sources, x, y) end
  if cell.kind == "dest" then removeFrom(dests, x, y) end
  board[y][x] = { kind = "empty" }
  dirty = true
end

function swapTiles(ax, ay, bx, by, layer)
  if ax == bx and ay == by then return false end
  if not inBounds(ax, ay) or not inBounds(bx, by) then return false end
  local a, b = board[ay][ax], board[by][bx]
  if not canModifyCell(a, layer or "player") or not canModifyCell(b, layer or "player") then return false end
  if not ((a.kind == "tile" or a.kind == "empty") and (b.kind == "tile" or b.kind == "empty")) then return false end
  if a.kind == "empty" and b.kind == "empty" then return false end
  if recallCargoInCell then recallCargoInCell(ax, ay); recallCargoInCell(bx, by) end
  board[ay][ax], board[by][bx] = b, a
  dirty = true
  return true
end

local function setObstacle(x, y, typeName, immutable)
  board[y][x] = { kind = "obstacle", type = typeName, immutable = immutable ~= false }
end

local function setSource(s)
  s.strength = 1
  s.rotation = dirIndex(s.output)
  board[s.y][s.x] = { kind = "source", id = s.id, output = s.output, rotation = s.rotation, immutable = true }
  sources[#sources + 1] = s
end

local function setDest(d)
  d.inputs = d.inputs or dirs
  d.rotation = d.rotation or dirIndex(d.inputs[1])
  board[d.y][d.x] = { kind = "dest", id = d.id, inputs = d.inputs, rotation = d.rotation, immutable = true }
  dests[#dests + 1] = d
end

local function nextNodeId(prefix, list)
  local maxId = 0
  for _, item in ipairs(list) do
    local n = tostring(item.id):match("^" .. prefix .. "(%d+)$")
    if n then maxId = math.max(maxId, tonumber(n)) end
  end
  return prefix .. (maxId + 1)
end

local function sourceAt(x, y)
  for _, s in ipairs(sources) do if s.x == x and s.y == y then return s end end
end

local function destAt(x, y)
  for _, d in ipairs(dests) do if d.x == x and d.y == y then return d end end
end

local function firstReqType(d)
  for t in pairs(d.req or {}) do return t end
  return "box"
end

local function cycleCargoType(t)
  for i, name in ipairs(config.cargoTypes) do
    if name == t then return config.cargoTypes[i % #config.cargoTypes + 1] end
  end
  return config.cargoTypes[1]
end

local function editorApi()
  return {
    board = function() return board end,
    sources = function() return sources end,
    dests = function() return dests end,
    editorMode = function() return editorMode end,
    editorBoardSizes = function() return EDITOR_BOARD_SIZES end,
    placementRotation = function() return placementRotation end,
    pendingSchema = function() return pendingSchema end,
    key = key,
    inBounds = inBounds,
    cell = function(x, y) return board[y][x] end,
    hoverCell = function() return cellAt(love.mouse.getPosition()) end,
    sourceAt = sourceAt,
    destAt = destAt,
    firstReqType = firstReqType,
    cycleCargoType = cycleCargoType,
    cellHasCargo = cellHasCargo,
    denyCellAction = denyCellAction,
    clearCellAt = clearCellAt,
    setSource = setSource,
    setDest = setDest,
    setObstacle = setObstacle,
    setSchemaTile = setSchemaTile,
    setTile = setTile,
    nextNodeId = nextNodeId,
    rotationLabel = rotationLabel,
    resetScenario = resetScenario,
    setMessage = function(message) editorMessage = message end,
    markDirty = function() dirty = true end,
    setPendingSchema = function(value) pendingSchema = value end,
    takeNextSchemaId = function()
      local pair = nextSchemaId
      nextSchemaId = nextSchemaId + 1
      return pair
    end,
    setEditorState = function(mode, sizing, _, pending, pause)
      editorMode, editorSizing, pendingSchema, paused = mode, sizing, pending, pause
    end,
  }
end

local function editHoveredResource(action)
  return editor.editHoveredResource(action, editorApi())
end

local function placeEditorItem(x, y, name)
  return editor.placeItem(x, y, name, editorApi())
end

resetScenario = function(n, w, h, title)
  scenario, W, H, scenarioTitle = n, w, h, title
  currentArea = nil
  board, sources, dests, cargo, flows, splitState = newBoard(), {}, {}, {}, {}, {}
  nextSchemaId, schemaStock, pendingSchema = 1, 2, nil
  simTime = 0
  replayEvents = { { t = 0, action = "scenario", scenario = n } }
  nextCargoId, status, dirty = 1, "running", true
  lostCargo = 0
  disturbanceTimer, rumiaOrb, rumiaTrail = config.firstDisturbanceDelay, nil, {}
  cameraX, cameraY, zoom = 0, 0, 1
  if fitBoardToView then fitBoardToView() end
end

local function loadScenario(n)
  scenarios.load(n, {
    resetScenario = resetScenario,
    setSource = setSource,
    setDest = setDest,
    setTile = setTile,
    setObstacle = setObstacle,
  })
end

function loadYoukaiMountainArea()
  resetScenario(101, 20, 30, "요괴의 산")
  unlimitedStock = true

  local reserved = {}
  local function reserve(x, y) if x >= 1 and x <= W and y >= 1 and y <= H then reserved[key(x, y)] = true end end
  local function reserveLine(x1, y1, x2, y2)
    local sx, sy = x1 == x2 and 0 or (x1 < x2 and 1 or -1), y1 == y2 and 0 or (y1 < y2 and 1 or -1)
    local x, y = x1, y1
    while true do
      reserve(x, y)
      if x == x2 and y == y2 then break end
      x, y = x + sx, y + sy
    end
  end
  for y = 14, 16 do for x = 9, 13 do reserve(x, y) end end
  reserveLine(12, 15, 19, 15); reserveLine(19, 15, 19, 5)
  reserveLine(10, 15, 2, 15); reserveLine(2, 15, 2, 18)
  reserveLine(12, 15, 12, 1)
  reserve(20, 5); reserve(1, 18)
  local function fillRect(typeName, target, x1, y1, x2, y2)
    for y = y1, y2 do
      for x = x1, x2 do
        if target <= 0 then return 0 end
        if not reserved[key(x, y)] and board[y][x].kind == "empty" then
          setObstacle(x, y, typeName)
          target = target - 1
        end
      end
    end
    return target
  end

  fillRect("water", 60, 5, 1, 6, 30)
  local rocks = 390
  rocks = fillRect("rock", rocks, 1, 1, 8, 30)
  rocks = fillRect("rock", rocks, 14, 1, 20, 30)
  rocks = fillRect("rock", rocks, 9, 1, 13, 6)
  fillRect("rock", rocks, 9, 25, 13, 30)

  setSource({ id = "A1", x = 10, y = 15, output = "E", strength = 1, cargoType = "오이", remaining = -1, timer = 0, interval = 0.8 })
  setSource({ id = "A2", x = 12, y = 15, output = "W", strength = 1, cargoType = "오이", remaining = -1, timer = 0, interval = 0.8 })
  board[15][10].rotatable = true
  board[15][12].rotatable = true
  setDest({ id = "B1", label = "텐구", x = 20, y = 5, inputs = { "W" }, req = { ["오이"] = 30 }, got = {}, wrong = 0 })
  setDest({ id = "B2", label = "캇파", x = 1, y = 18, inputs = { "E" }, req = { ["오이"] = 30 }, got = {}, wrong = 0 })
  setDest({ id = "B3", label = "모리야", x = 12, y = 1, inputs = { "S" }, req = { ["오이"] = 30 }, got = {}, wrong = 0 })
end

function loadAreaScenario(area)
  if area.areaId == "youkai_mountain" then loadYoukaiMountainArea(); return end
  loadScenario(area.scenario)
end

function mapAreaById(areaId)
  for _, area in ipairs(mapAreas) do if area.areaId == areaId then return area end end
end

local function startEditorSizing()
  editor.startSizing(editorApi())
end

local function createEditorStage(sizeIndex)
  return editor.createStage(sizeIndex, editorApi())
end

local function tileColor(tile)
  return tileRules.color(tile, colors)
end

local function tileLabel(tile)
  return tileRules.label(tile)
end

local function boardToken(cell)
  if cell.kind == "tile" then return tileLabel(cell) .. (cell.pair and (cell.pair .. ":") or "") .. cell.rotation end
  if cell.kind == "obstacle" then return cell.type:sub(1, 1):upper() end
  if cell.kind == "source" then return "A:" .. cell.output end
  if cell.kind == "dest" then return "B:" .. table.concat(cell.inputs or dirs, "") end
  return ({ empty = ".", source = "A", dest = "B" })[cell.kind]
end

function cellData(x, y, cell)
  if cell.kind == "tile" then return { x = x, y = y, kind = "tile", type = cell.type, rotation = cell.rotation, pair = cell.pair, occupiedBy = cell.occupiedBy } end
  if cell.kind == "obstacle" then return { x = x, y = y, kind = "obstacle", type = cell.type, transform = cell.transform, occupiedBy = cell.occupiedBy } end
  if cell.occupiedBy then return { x = x, y = y, kind = cell.kind, occupiedBy = cell.occupiedBy } end
end

function sourceData(s)
  return { id = s.id, x = s.x, y = s.y, output = s.output, rotation = s.rotation, strength = s.strength, cargoType = s.cargoType, remaining = s.remaining, timer = s.timer, interval = s.interval, received = common.copyReq(s.received) }
end

function destinationData(d)
  return { id = d.id, x = d.x, y = d.y, inputs = d.inputs, rotation = d.rotation, req = common.copyReq(d.req), got = common.copyReq(d.got), wrong = d.wrong, timer = d.timer, reverseSent = d.reverseSent }
end

function tileSegments(tile) return tileRules.segments(tile, ruleInversions) end
function tilePorts(tile) return tileRules.ports(tile, ruleInversions) end
function baseTileSegments(typeName) return tileRules.baseSegments(typeName, ruleInversions) end
function baseTilePorts(typeName) return tileRules.basePorts(typeName, ruleInversions) end

local easeOutQuint, rotateLocal = common.easeOutQuint, common.rotateLocal

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

local transformDir, transformLocal = common.transformDir, common.transformLocal
local effectMatrix, matrixPoint = common.effectMatrix, common.matrixPoint
local composeMatrix, transformRegionLocal = common.composeMatrix, common.transformRegionLocal

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

local regionPointToCell, samePortSet = common.regionPointToCell, common.samePortSet

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
      if (tile.kind == "tile" or tile.kind == "obstacle") and tile.regionTween then
        tile.regionTween.time = tile.regionTween.time + dt
        if tile.regionTween.time >= tile.regionTween.duration then
          if tile.kind == "obstacle" and tile.regionTween.toTransform then
            tile.transform = tile.regionTween.toTransform
          end
          tile.regionTween = nil
        end
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

function bezierPoint(a, b, c, d, t)
  local u = 1 - t
  return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d
end

function updateRecallCargo(dt)
  for i = #recallCargo, 1, -1 do
    local r = recallCargo[i]
    r.time = r.time + dt
    local t = math.min(1, r.time / r.duration)
    if t >= 1 then
      table.remove(recallCargo, i)
    else
      local q = t * t
      r.x = bezierPoint(r.sx, r.c1x, r.c2x, r.tx, q)
      r.y = bezierPoint(r.sy, r.c1y, r.c2y, r.ty, q)
      r.trail[#r.trail + 1] = { x = r.x, y = r.y, time = 0, duration = 0.2 + math.random() * 0.1 }
      for j = #r.trail, 1, -1 do
        r.trail[j].time = r.trail[j].time + dt
        if r.trail[j].time >= r.trail[j].duration then table.remove(r.trail, j) end
      end
    end
  end
end

local function updateDeniedShakes(dt)
  for k, t in pairs(deniedShakes) do
    t = t - dt
    if t <= 0 then deniedShakes[k] = nil else deniedShakes[k] = t end
  end
end

local function deniedShakeOffset(x, y)
  local shake = deniedShakes[key(x, y)]
  if not shake then return 0, 0 end
  local f = shake / 0.18
  return math.sin(shake * 95) * 8 * f, 0
end

function flowApi()
  return {
    board = board,
    sources = sources,
    dests = dests,
    flows = flows,
    splitState = splitState,
    rules = ruleInversions,
    dirs = dirs,
    dx = dx,
    dy = dy,
    opposite = opposite,
    key = key,
    laneKey = laneKey,
    inBounds = inBounds,
    hasDir = hasDir,
    findSchemaPart = findSchemaPart,
    schemaPairComplete = schemaPairComplete,
  }
end

local function recalcFlow()
  flows = flowRules.recalc(flowApi())
  dirty = false
end

local function laneHasSpace(lk, progress, ignoreId, fromProgress)
  for _, c in ipairs(cargo) do
    if c.id ~= ignoreId and c.state ~= "removed" and c.lane == lk then
      if not fromProgress and math.abs(c.progress - progress) < cargoSpacing then return false end
      if fromProgress and c.progress > fromProgress and c.progress - progress < cargoSpacing then return false end
    end
  end
  return true
end

local function laneSnapshot(lane)
  return lane and { x = lane.x, y = lane.y, entry = lane.entry, exit = lane.exit, type = lane.type, pair = lane.pair }
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

function cargoWorldPoint(c)
  local lane = flows.lanes[c.lane] or c.visualLane
  if lane then return laneWorldPoint(lane, c.progress or 0) end
  if c.visualPoint then
    local cx, cy = center(c.visualPoint.x, c.visualPoint.y)
    return cx + (c.visualPoint.lx or 0) * CELL, cy + (c.visualPoint.ly or 0) * CELL
  end
  local cx, cy = center(c.cellX or 1, c.cellY or 1)
  return cx + (c.localX or 0) * CELL, cy + (c.localY or 0) * CELL
end

function sourcePortPoint(id)
  for _, s in ipairs(sources) do
    if s.id == id then
      local x, y = portPoint(s.x, s.y, s.output)
      return x, y, s
    end
  end
end

function stockBack(c)
  local _, _, s = sourcePortPoint(c.source)
  if s and not unlimitedStock and s.remaining ~= -1 then s.remaining = s.remaining + 1 end
end

function recallCargoInCell(x, y)
  local played = false
  for _, c in ipairs(cargo) do
    if cargoInCell(c, x, y) then
      local sx, sy = cargoWorldPoint(c)
      local tx, ty = sourcePortPoint(c.source)
      if tx and ty then
        local a, speed = math.random() * math.pi * 2, 240 + math.random() * 260
        local duration = 0.55 + math.random() * 0.3
        recallCargo[#recallCargo + 1] = { type = c.type, x = sx, y = sy, sx = sx, sy = sy, c1x = sx + math.cos(a) * speed * 0.45, c1y = sy + math.sin(a) * speed * 0.45, c2x = tx + (math.random() - 0.5) * CELL * 3, c2y = ty + (math.random() - 0.5) * CELL * 3, tx = tx, ty = ty, time = 0, duration = duration, trail = {} }
      end
      if not played then playSfx("cargoReturn", 0.75); played = true end
      stockBack(c)
      c.state = "removed"
    end
  end
end

local function rememberCargoPoint(c, x, y, lx, ly)
  c.cellX, c.cellY, c.localX, c.localY = x, y, lx, ly
  c.visualLane = nil
  c.visualPoint = { x = x, y = y, lx = lx, ly = ly }
end

function cargoInCell(c, x, y)
  if c.state == "removed" then return false end
  local lane = flows.lanes[c.lane] or c.visualLane
  if lane then return lane.x == x and lane.y == y end
  return c.cellX == x and c.cellY == y
end

function cargoInYuyukoCell(c)
  if c.state == "removed" then return false end
  local lane = flows.lanes[c.lane] or c.visualLane
  local x, y = lane and lane.x or c.cellX, lane and lane.y or c.cellY
  return x and y and board[y] and board[y][x] and board[y][x].occupiedBy == "yuyuko"
end

function cellHasCargo(x, y)
  for _, c in ipairs(cargo) do
    if cargoInCell(c, x, y) then return true end
  end
  return false
end

denyCellAction = function(x, y)
  deniedShakes[key(x, y)] = 0.18
  playSfx("tileDeny", 0.75)
end

function nearestProgressOnLane(lane, lx, ly)
  local bestProgress, bestDist
  for i = 0, 24 do
    local p = i / 24
    local x, y = laneLocalPoint(lane, p)
    local dist = (lx - x) * (lx - x) + (ly - y) * (ly - y)
    if not bestDist or dist < bestDist then bestProgress, bestDist = p, dist end
  end
  return bestProgress, bestDist
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
      local bestLane, bestProgress, fallbackLane, fallbackProgress, fallbackDist
      for lk, lane in pairs(flows.lanes) do
        if lane.x == x and lane.y == y and not lane.blocked then
          local p = progressOnLane(lane, c.localX or 0, c.localY or 0)
          if p and (not bestProgress or math.abs(p - c.progress) < math.abs(bestProgress - c.progress)) then
            bestLane, bestProgress = lk, p
          elseif not p then
            local np, dist = nearestProgressOnLane(lane, c.localX or 0, c.localY or 0)
            if np and (not fallbackDist or dist < fallbackDist) then
              fallbackLane, fallbackProgress, fallbackDist = lk, np, dist
            end
          end
        end
      end
      if not bestLane then bestLane, bestProgress = fallbackLane, fallbackProgress end
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
  return flowRules.laneAfter(flowApi(), lane)
end

local function returnToStock(c)
  for _, s in ipairs(sources) do
    if s.id == c.source then
      if not unlimitedStock and s.remaining ~= -1 then s.remaining = s.remaining + 1 end
      break
    end
  end
  c.state = "removed"
end

function loseCargo(c)
  if c.state == "removed" then return end
  lostCargo = lostCargo + 1
  c.state = "removed"
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

local function deliverToSource(sourceId, c)
  for _, s in ipairs(sources) do
    if s.id == sourceId then
      s.received = s.received or {}
      s.received[c.type] = (s.received[c.type] or 0) + 1
      for _, d in ipairs(dests) do
        if d.id == c.source and d.req[c.type] and (d.got[c.type] or 0) < d.req[c.type] then
          d.got[c.type] = (d.got[c.type] or 0) + 1
          break
        end
      end
      c.state = "removed"
      return
    end
  end
end

local function spawnFromDestinations(dt)
  for _, d in ipairs(dests) do
    d.timer = (d.timer or 0) + dt
    local t = firstReqType(d)
    local limit = d.req[t] or 0
    d.reverseSent = d.reverseSent or 0
    if d.timer >= (d.interval or 1) and d.reverseSent < limit then
      local sourceLanes = flows.sourceLanes[d.id]
      local lk = sourceLanes and sourceLanes[1]
      if lk and laneHasSpace(lk, 0) then
        local lane = flows.lanes[lk]
        cargo[#cargo + 1] = { id = nextCargoId, type = t, source = d.id, lane = lk, visualLane = laneSnapshot(lane), cellX = lane.x, cellY = lane.y, progress = 0, speed = 1.5, state = "moving" }
        nextCargoId, d.reverseSent, d.timer = nextCargoId + 1, d.reverseSent + 1, 0
      end
    end
  end
end

local function spawn(dt)
  if ruleInversions.reverseFlow then return spawnFromDestinations(dt) end
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
    if a.lane == b.lane then
      if a.progress == b.progress then return a.id < b.id end
      return a.progress > b.progress
    end
    return a.id < b.id
  end)
end

local function moveCargo(dt)
  sortCargo()
  for _, c in ipairs(cargo) do
    if c.state ~= "removed" then
      if cargoInYuyukoCell(c) then
        loseCargo(c)
      else
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
            elseif why == "source" then
              deliverToSource(destId, c)
            elseif why == "stock" then
              returnToStock(c)
          elseif why == "lost" then
            loseCargo(c)
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
end

local function checkStatus()
  if ruleInversions.reverseFlow then
    local need, got = 0, 0
    for _, d in ipairs(dests) do
      for _, n in pairs(d.req) do need = need + n end
    end
    for _, s in ipairs(sources) do
      for _, n in pairs(s.received or {}) do got = got + n end
    end
    status = need > 0 and got >= need and "success" or "running"
    return
  end
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

cellAt = function(mx, my)
  mx, my = (mx - cameraX) / zoom, (my - cameraY) / zoom
  return math.floor((mx - OX) / CELL) + 1, math.floor((my - OY) / CELL) + 1
end

local clamp = common.clamp

function rotationLabel(r)
  return common.rotationLabel(dirs, r)
end

local function currentPalette()
  return editorMode and editorNames or names
end

local function currentSelection()
  return editorMode and editorSelected or selected
end

local function screenSize()
  local w = love.graphics.getWidth and love.graphics.getWidth() or 1280
  local h = love.graphics.getHeight and love.graphics.getHeight() or 820
  return w, h
end

local function placementPanelRect()
  local screenW, screenH = screenSize()
  local palette = currentPalette()
  local w = math.max(420, #palette * 88 + 18)
  return math.max(20, (screenW - w) * 0.5), screenH - 82, w, 74
end

fitBoardToView = function()
  local screenW, screenH = screenSize()
  local left, top, rightPanelW, bottomPanelH = 24, 112, 316, 96
  local viewW = math.max(CELL, screenW - left - rightPanelW)
  local viewH = math.max(CELL, screenH - top - bottomPanelH)
  local boardW, boardH = W * CELL, H * CELL
  zoom = math.min(2.5, math.max(0.45, math.min(viewW / boardW, viewH / boardH)))
  cameraX = left + (viewW - boardW * zoom) * 0.5 - OX * zoom
  cameraY = top + (viewH - boardH * zoom) * 0.5 - OY * zoom
end

local function panelHit(mx, my)
  local px, py = placementPanelRect()
  if my < py + 8 or my > py + 66 then return nil end
  local palette = currentPalette()
  for i = 1, #palette do
    local x = px + 12 + (i - 1) * 88
    if mx >= x and mx <= x + 82 then return i end
  end
  return nil
end

local function topTabHit(mx, my)
  local x, y = 24, 18
  for _, tab in ipairs(config.topTabs) do
    if mx >= x and mx <= x + 86 and my >= y and my <= y + 24 then return tab.id end
    x = x + 94
  end
  return nil
end

function cooldownSliderRect()
  return 24, 103, 260, 18
end

function setDisturbanceCooldown(seconds)
  config.disturbanceInterval = math.floor(math.max(20, math.min(90, seconds)) + 0.5)
  disturbanceTimer = math.min(disturbanceTimer, config.disturbanceInterval)
  if rumiaOrb then rumiaOrb.wanderDuration = math.max(1, config.disturbanceInterval - 5) end
end

function setDisturbanceCooldownFromMouse(mx)
  local x, _, w = cooldownSliderRect()
  local t = math.max(0, math.min(1, (mx - x) / w))
  setDisturbanceCooldown(20 + t * 70)
end

function cooldownSliderHit(mx, my)
  if topTab ~= "debug" then return false end
  local x, y, w, h = cooldownSliderRect()
  return mx >= x and mx <= x + w and my >= y - 10 and my <= y + h + 10
end

function topPanelHeight()
  return topTab == "debug" and 130 or 88
end

function characterCueTop(t)
  return 10 + topPanelHeight() + 14 + 18 * (1 - t)
end

function drawCooldownSlider()
  if topTab ~= "debug" then return end
  local x, y, w, h = cooldownSliderRect()
  local t = (config.disturbanceInterval - 20) / 70
  love.graphics.setColor(colors.text)
  love.graphics.print("Cooldown: " .. config.disturbanceInterval .. "s", x, y - 18)
  love.graphics.setColor(colors.grid)
  love.graphics.rectangle("fill", x, y + h * 0.5 - 2, w, 4, 2, 2)
  love.graphics.setColor(colors.selected)
  love.graphics.rectangle("fill", x, y + h * 0.5 - 2, w * t, 4, 2, 2)
  love.graphics.setColor(colors.hover)
  love.graphics.circle("fill", x + w * t, y + h * 0.5, 8)
  love.graphics.setColor(colors.text)
  love.graphics.print("20", x, y + 14)
  love.graphics.print("90", x + w - 16, y + 14)
end

local function drawTopPanel()
  local screenW = screenSize()
  love.graphics.setColor(colors.panel)
  love.graphics.rectangle("fill", 14, 10, math.max(360, screenW - 28), topPanelHeight(), 5, 5)

  local x = 24
  for _, tab in ipairs(config.topTabs) do
    love.graphics.setColor(tab.id == topTab and colors.selected or colors.tile)
    love.graphics.rectangle("fill", x, 18, 86, 24, 4, 4)
    love.graphics.setColor(tab.id == topTab and colors.hover or colors.grid)
    love.graphics.rectangle("line", x, 18, 86, 24, 4, 4)
    love.graphics.setColor(colors.text)
    love.graphics.print(tab.label, x + 12, 24)
    x = x + 94
  end

  local line1, line2 = "", ""
  if topTab == "build" then
    local schemaText = pendingSchema and ("place exit #" .. pendingSchema.pair) or ("stock " .. schemaStock)
    line1 = "Selected: " .. names[selected] .. "   Rotation: " .. placementRotation .. " " .. rotationLabel(placementRotation) .. "   Schema: " .. schemaText
    line2 = "Left: place/replace   Right: remove   R: rotate   Wheel: zoom   WASD: camera   Esc: map"
  elseif topTab == "editor" then
    if editorSizing then
      line1 = "Editor setup: choose board size with 1, 2, or 3"
      line2 = "G/Esc: cancel"
    elseif editorMode then
      line1 = "Editor: on   Brush: " .. editorNames[editorSelected] .. "   Rotation: " .. placementRotation .. " " .. rotationLabel(placementRotation)
      line2 = "G: exit editor   L: lock   T: cargo type   +/-: amount   Q: source infinite   X/I: export/import"
      local hx, hy = cellAt(love.mouse.getPosition())
      if inBounds(hx, hy) and board[hy][hx].kind == "source" then
        local s = sourceAt(hx, hy)
        if s then line1 = line1 .. "   " .. s.id .. " cargo:" .. s.cargoType .. " stock:" .. (s.remaining == -1 and "infinite" or s.remaining) end
      elseif inBounds(hx, hy) and board[hy][hx].kind == "dest" then
        local d = destAt(hx, hy)
        local t = d and firstReqType(d)
        if d then line1 = line1 .. "   " .. d.id .. " need:" .. t .. " x" .. d.req[t] end
      end
    else
      line1 = "Editor: off"
      line2 = "G: start editor setup"
    end
  elseif topTab == "debug" then
    line1 = "Debug: " .. (debug and "flow overlay on" or "flow overlay off") .. "   Disturbance: B   Auto: M " .. (disturbanceAutoEnabled and "on" or "off") .. "   Recalc flow: F   Rule invert: N"
    line2 = "`: debug overlay   C: debug dump   V: replay dump   Shift+V: import replay snapshot   " .. ruleInversionText()
  else
    line1 = "Stage: " .. scenario .. "/" .. scenarios.count .. " " .. scenarioTitle .. "   Board: " .. W .. "x" .. H .. "   Zoom: " .. string.format("%.2f", zoom)
    line2 = "State: " .. status .. (paused and " paused" or "") .. "   Stock: " .. (unlimitedStock and "unlimited" or "scenario") .. "   Space: pause   Esc: map"
  end

  love.graphics.setColor(colors.text)
  love.graphics.print(line1, 24, 50)
  love.graphics.print(editorMessage ~= "" and editorMessage or line2, 24, 74)
  drawCooldownSlider()
end

function mapAreaAt(mx, my)
  mx, my = (mx - cameraX) / zoom, (my - cameraY) / zoom
  for i = #mapAreas, 1, -1 do
    local area = mapAreas[i]
    if mx >= area.x and mx <= area.x + area.w and my >= area.y and my <= area.y + area.h then return i, area end
  end
end

function mapCellAt(mx, my)
  local wx, wy = (mx - cameraX) / zoom, (my - cameraY) / zoom
  return math.floor(wx / CELL), math.floor(wy / CELL)
end

function selectMapArea(area)
  if area.enabled == false then return end
  loadAreaScenario(area)
  currentArea = area
  gameScene = "play"
  scenarioTitle = area.jp
  editorMessage = area.jp .. " selected"
end

function startDialogueTest(index)
  local item = dialogueScripts.tests[index]
  if not item then return false end
  storyDialogueScene.start(item.script)
  dialogueTestPanelOpen = false
  gameScene = "dialogue"
  return true
end

function dialogueTestButtonRect()
  local _, screenH = love.graphics.getDimensions()
  return 18, screenH - 58, 178, 40
end

function dialogueTestPanelRect()
  local w = 360
  local h = 54 + #dialogueScripts.tests * 38
  local bx, by = dialogueTestButtonRect()
  return bx, by - h - 10, w, h
end

function dialogueTestButtonHit(mx, my)
  local x, y, w, h = dialogueTestButtonRect()
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function dialogueTestPanelHit(mx, my)
  if not dialogueTestPanelOpen then return nil end
  local x, y, w = dialogueTestPanelRect()
  for i = 1, #dialogueScripts.tests do
    local iy = y + 42 + (i - 1) * 38
    if mx >= x + 14 and mx <= x + w - 14 and my >= iy and my <= iy + 30 then return i end
  end
  return nil
end

function drawDialogueTestButton()
  local x, y, w, h = dialogueTestButtonRect()
  local mx, my = love.mouse.getPosition()
  local hot = dialogueTestButtonHit(mx, my)
  love.graphics.setColor(hot and colors.selected or colors.panel)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  love.graphics.setColor(dialogueTestPanelOpen and colors.hover or colors.grid)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(colors.text)
  love.graphics.print("Dialogue Tests", x + 16, y + 12)
end

function drawDialogueTestPanel()
  if not dialogueTestPanelOpen then return end
  local x, y, w, h = dialogueTestPanelRect()
  love.graphics.setColor(0, 0, 0, 0.88)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  love.graphics.setColor(colors.hover)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(colors.text)
  love.graphics.print("Dialogue Tests", x + 16, y + 14)
  local mx, my = love.mouse.getPosition()
  local hit = dialogueTestPanelHit(mx, my)
  for i, item in ipairs(dialogueScripts.tests) do
    local iy = y + 42 + (i - 1) * 38
    love.graphics.setColor(i == hit and colors.selected or colors.panel)
    love.graphics.rectangle("fill", x + 14, iy, w - 28, 30, 4, 4)
    love.graphics.setColor(colors.text)
    love.graphics.print(i .. ". " .. item.label, x + 26, iy + 7)
  end
end

function drawMapSelectScene()
  love.graphics.clear(colors.bg)
  local mx, my = love.mouse.getPosition()
  local hoverIndex = mapAreaAt(mx, my)

  love.graphics.push()
  love.graphics.translate(cameraX, cameraY)
  love.graphics.scale(zoom)

  love.graphics.setColor(colors.grid)
  love.graphics.setLineWidth(1)
  for x = -240, 1760, CELL do love.graphics.line(x, -160, x, 1000) end
  for y = -144, 1000, CELL do love.graphics.line(-240, y, 1760, y) end

  for i, area in ipairs(mapAreas) do
    if area.enabled ~= false then
      love.graphics.setColor(i == hoverIndex and colors.selected or colors.tile)
    else
      love.graphics.setColor(0.12, 0.13, 0.14, 0.72)
    end
    love.graphics.rectangle("fill", area.x, area.y, area.w, area.h, 6, 6)
    if area.enabled ~= false then
      love.graphics.setColor(i == hoverIndex and colors.hover or colors.grid)
    else
      love.graphics.setColor(0.24, 0.24, 0.24)
    end
    love.graphics.setLineWidth(i == hoverIndex and 3 or 1)
    love.graphics.rectangle("line", area.x, area.y, area.w, area.h, 6, 6)
    if area.enabled ~= false then love.graphics.setColor(colors.text) else love.graphics.setColor(0.48, 0.5, 0.48) end
    love.graphics.print(i .. ". " .. area.jp, area.x + 18, area.y + 22)
    love.graphics.print(area.enabled ~= false and area.name or "Locked", area.x + 18, area.y + 54)
  end
  love.graphics.setLineWidth(1)
  love.graphics.pop()

  love.graphics.setColor(colors.panel)
  love.graphics.rectangle("fill", 14, 10, math.max(360, screenSize() - 28), hoverIndex and 122 or 72, 5, 5)
  love.graphics.setColor(colors.text)
  love.graphics.print("Map Select", 24, 24)
  love.graphics.print("Left: choose area   Wheel: zoom   WASD: camera   O: dialogue tests", 24, 50)
  if hoverIndex then
    local area = mapAreas[hoverIndex]
    if area.enabled ~= false then
      love.graphics.print("Tiles: " .. area.tiles, 24, 78)
      love.graphics.print("Obstacles: " .. area.obstacles, 24, 102)
    else
      love.graphics.print("Locked area", 24, 78)
    end
  end
  drawDialogueTestPanel()
  drawDialogueTestButton()
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
  love.graphics.print(tileLabel(tile), cx - 4, cy - 7)
end

local drawArrowHead

local function drawNodeIcon(name, x, y, size)
  love.graphics.setColor(name == "source" and colors.source or colors.dest)
  love.graphics.rectangle("fill", x + 3, y + 3, size - 6, size - 6, 4, 4)
  love.graphics.setColor(colors.text)
  love.graphics.print(name == "source" and "A" or "B", x + size / 2 - 4, y + size / 2 - 7)
  local d = rotationLabel(placementRotation)
  local cx, cy = x + size / 2, y + size / 2
  local tx, ty = cx + dx[d] * size * 0.32, cy + dy[d] * size * 0.32
  drawArrowHead(tx, ty, name == "source" and d or opposite[d], colors.hover)
end

local function drawObstacleIcon(name, x, y, size)
  love.graphics.setColor(name == "water" and colors.water or colors.rock)
  love.graphics.rectangle("fill", x + 3, y + 3, size - 6, size - 6, 4, 4)
  love.graphics.setColor(colors.text)
  love.graphics.print(name == "water" and "W" or "R", x + size / 2 - 4, y + size / 2 - 7)
end

local function drawPlacementPanel()
  local palette = currentPalette()
  local active = currentSelection()
  local panelX, panelY, panelW = placementPanelRect()
  love.graphics.setColor(colors.panel)
  love.graphics.rectangle("fill", panelX, panelY, panelW, 74, 4, 4)
  for i, name in ipairs(palette) do
    local x, y = panelX + 12 + (i - 1) * 88, panelY + 8
    love.graphics.setColor(i == active and colors.selected or colors.tile)
    love.graphics.rectangle("fill", x, y, 82, 54, 4, 4)
    love.graphics.setColor(i == active and colors.hover or colors.grid)
    love.graphics.rectangle("line", x, y, 82, 54, 4, 4)
    if name == "source" or name == "dest" then
      drawNodeIcon(name, x + 5, y + 5, 34)
    elseif name == "rock" or name == "water" then
      drawObstacleIcon(name, x + 5, y + 5, 34)
    else
      drawTileIcon({ type = name, rotation = placementRotation }, x + 5, y + 5, 34)
    end
    love.graphics.setColor(colors.text)
    love.graphics.print(i .. " " .. name, x + 42, y + 8)
    if name == "schema" then love.graphics.print("x" .. schemaStock, x + 42, y + 28)
    elseif i == active then love.graphics.print("rot " .. placementRotation .. " " .. rotationLabel(placementRotation), x + 42, y + 28) end
  end
end

function consumableAt(i)
  return consumableOrder[((i - 1) % #consumableOrder) + 1]
end

function consumableName(id)
  if id == "cirno_wing" then return "C" end
  if id == "momoyo_pickaxe" then return "M" end
  return "X"
end

function consumableCount(id)
  return id == "none" and nil or (consumableCounts[id] or 0)
end

function consumableUsable(id)
  local n = consumableCount(id)
  return not n or n > 0
end

function cycleConsumable(dir)
  local from = equippedConsumable
  equippedConsumable = ((equippedConsumable + dir - 1) % #consumableOrder) + 1
  consumableTween = { from = from, to = equippedConsumable, dir = dir, time = 0, duration = 0.18 }
end

function randomizeRuleInversions()
  ruleInversions.reverseFlow = not ruleInversions.reverseFlow
  ruleInversions.swapSplitMerge = false
  splitState = {}
  dirty = true
  characterCue = { id = "sagume", text = "매일 오늘같이 순탄하게 흘러가는 하루였으면 좋겠네.", nitoriText = "아잇 싯팔 왜 뒤집어지는데", time = 0, duration = 3.4 }
end

function ruleInversionText()
  return "Reverse:" .. (ruleInversions.reverseFlow and "on" or "off") .. " Split/Merge:" .. (ruleInversions.swapSplitMerge and "on" or "off")
end

function updateConsumableTween(dt)
  if not consumableTween then return end
  consumableTween.time = consumableTween.time + dt
  if consumableTween.time >= consumableTween.duration then consumableTween = nil end
end

function updateCharacterCue(dt)
  if not characterCue then return end
  characterCue.time = characterCue.time + dt
  if characterCue.time >= characterCue.duration then characterCue = nil end
end

function placementConsumableId(cell)
  local id = consumableAt(equippedConsumable)
  if id == "cirno_wing" and cell.kind == "obstacle" and cell.type == "water" and consumableUsable(id) then return id end
  if id == "momoyo_pickaxe" and cell.kind == "obstacle" and cell.type == "rock" and consumableUsable(id) then return id end
end

function usePlacementConsumable(id)
  if id and consumableCounts[id] and consumableCounts[id] > 0 then consumableCounts[id] = consumableCounts[id] - 1 end
end

function drawConsumableItem(id, x, y, size, alpha)
  local usable = consumableUsable(id)
  alpha = alpha or 1
  love.graphics.setColor(usable and 0.2 or 0.09, usable and 0.34 or 0.1, usable and 0.42 or 0.12, alpha)
  if id == "momoyo_pickaxe" then love.graphics.setColor(usable and 0.46 or 0.14, usable and 0.3 or 0.1, usable and 0.18 or 0.08, alpha) end
  if id == "none" then love.graphics.setColor(0.12, 0.13, 0.14, alpha) end
  love.graphics.rectangle("fill", x - size / 2, y - size / 2, size, size, 5, 5)
  love.graphics.setColor(colors.grid[1], colors.grid[2], colors.grid[3], alpha)
  love.graphics.rectangle("line", x - size / 2, y - size / 2, size, size, 5, 5)
  love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], usable and alpha or alpha * 0.45)
  love.graphics.print(consumableName(id), x - 4, y - 8)
  local n = consumableCount(id)
  if n then love.graphics.print(tostring(n), x + size / 2 - 16, y + size / 2 - 18) end
end

function drawConsumableSlots()
  if editorMode or editorSizing then return end
  local screenW, screenH = screenSize()
  local _, panelY = placementPanelRect()
  local cx, y = screenW * 0.5, panelY - 44
  local leftX, rightX, side, centerSize = cx - 52, cx + 52, 52, 72
  love.graphics.setColor(0, 0, 0, 0.22)
  love.graphics.rectangle("fill", leftX - side / 2, y - side / 2, side, side, 5, 5)
  love.graphics.rectangle("fill", rightX - side / 2, y - side / 2, side, side, 5, 5)
  love.graphics.rectangle("fill", cx - centerSize / 2, y - centerSize / 2, centerSize, centerSize, 6, 6)
  if consumableTween then
    local tt = easeOutQuint(math.min(1, consumableTween.time / consumableTween.duration))
    local d = consumableTween.dir
    drawConsumableItem(consumableAt(consumableTween.from - d), cx - d * 104, y, side, 1 - tt)
    drawConsumableItem(consumableAt(consumableTween.from), cx - d * 52 * tt, y, centerSize + (side - centerSize) * tt, 1)
    drawConsumableItem(consumableAt(consumableTween.to), cx + d * 52 * (1 - tt), y, side + (centerSize - side) * tt, 1)
    drawConsumableItem(consumableAt(consumableTween.to + d), cx + d * 104, y, side, tt)
  else
    drawConsumableItem(consumableAt(equippedConsumable - 1), leftX, y, side, 0.78)
    drawConsumableItem(consumableAt(equippedConsumable + 1), rightX, y, side, 0.78)
    drawConsumableItem(consumableAt(equippedConsumable), cx, y, centerSize, 1)
  end
  love.graphics.setColor(colors.text)
  love.graphics.print("Q", leftX - 5, y + side / 2 + 4)
  love.graphics.print("E", rightX - 5, y + side / 2 + 4)
end

function drawImageBox(img, x, y, size, alpha)
  alpha = alpha or 1
  love.graphics.setColor(0.04, 0.05, 0.06, 0.72 * alpha)
  love.graphics.rectangle("fill", x, y, size, size, 6, 6)
  if img and love.graphics.draw then
    local scale = size / math.max(img:getWidth(), img:getHeight())
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(img, x + (size - img:getWidth() * scale) * 0.5, y + (size - img:getHeight() * scale) * 0.5, 0, scale, scale)
  end
  love.graphics.setColor(colors.grid[1], colors.grid[2], colors.grid[3], alpha)
  love.graphics.rectangle("line", x, y, size, size, 6, 6)
end

function drawPlayerPortrait()
  if editorSizing then return end
  local _, panelY = placementPanelRect()
  drawImageBox(portraits.nitori, 22, panelY - 122, 106, 1)
end

function drawSagumeLine(x, y, alpha)
  local a, b, c = "매일 오늘같이 ", "순탄하게 흘러가는", " 하루였으면 좋겠네."
  local font = love.graphics.getFont()
  love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], alpha)
  love.graphics.print(a, x, y)
  love.graphics.setColor(1, 0, 0, alpha)
  love.graphics.print(b, x + font:getWidth(a), y)
  love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], alpha)
  love.graphics.print(c, x + font:getWidth(a .. b), y)
end

function drawNitoriCue(text, alpha, t)
  local _, panelY = placementPanelRect()
  local x, y, w, h = 92, panelY - 184 - 10 * (1 - t), 300, 64
  love.graphics.setColor(0, 0, 0, 0.74 * alpha)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  love.graphics.setColor(0.36, 0.82, 0.95, alpha)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
  love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], alpha)
  love.graphics.printf(text, x + 14, y + 13, w - 28, "left")
end

function drawNitoriIconCue(img, alpha, t)
  local _, panelY = placementPanelRect()
  local x, y, w, h = 92, panelY - 204 - 10 * (1 - t), 128, 108
  love.graphics.setColor(0, 0, 0, 0.74 * alpha)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  love.graphics.setColor(0.36, 0.82, 0.95, alpha)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
  if img then
    local size = 80
    local scale = size / math.max(img:getWidth(), img:getHeight())
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(img, x + (w - img:getWidth() * scale) * 0.5, y + (h - img:getHeight() * scale) * 0.5, 0, scale, scale)
  end
end

function drawCharacterCue()
  if not characterCue then return end
  local oldFont = love.graphics.getFont()
  if dialogFont then love.graphics.setFont(dialogFont) end
  local t = math.min(1, characterCue.time / 0.28)
  local out = math.min(1, (characterCue.duration - characterCue.time) / 0.35)
  local alpha = easeOutQuint(math.min(t, out))
  if characterCue.id == "seija" then
    local x, y = 24, characterCueTop(t)
    drawImageBox(portraits.seija, x, y, 82, alpha)
    love.graphics.setColor(0, 0, 0, 0.78 * alpha)
    love.graphics.rectangle("fill", x + 92, y + 10, 380, 68, 6, 6)
    love.graphics.setColor(1, 0.25, 0.2, alpha)
    love.graphics.rectangle("line", x + 92, y + 10, 380, 68, 6, 6)
    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], alpha)
    love.graphics.printf(characterCue.text, x + 110, y + 26, 344, "left")
  elseif characterCue.id == "sagume" then
    local screenW = screenSize()
    local x, y = screenW - 438, characterCueTop(t) + 44
    drawImageBox(portraits.sagume, x, y, 74, alpha)
    love.graphics.setColor(0, 0, 0, 0.7 * alpha)
    love.graphics.rectangle("fill", x - 410, y + 8, 400, 66, 6, 6)
    love.graphics.setColor(0.72, 0.55, 0.9, alpha)
    love.graphics.rectangle("line", x - 410, y + 8, 400, 66, 6, 6)
    drawSagumeLine(x - 396, y + 32, alpha)
  elseif characterCue.id == "yuyuko" then
    local x, y = 24, characterCueTop(t)
    drawImageBox(portraits.yuyuko, x, y, 82, alpha)
    love.graphics.setColor(0, 0, 0, 0.78 * alpha)
    love.graphics.rectangle("fill", x + 92, y + 10, 320, 68, 6, 6)
    love.graphics.setColor(1, 0.38, 0.5, alpha)
    love.graphics.rectangle("line", x + 92, y + 10, 320, 68, 6, 6)
    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], alpha)
    love.graphics.printf(characterCue.text, x + 110, y + 26, 284, "left")
  elseif characterCue.id == "rumia" then
    local x, y = 24, characterCueTop(t)
    drawImageBox(portraits.rumia, x, y, 82, alpha)
    love.graphics.setColor(0, 0, 0, 0.78 * alpha)
    love.graphics.rectangle("fill", x + 92, y + 10, 270, 68, 6, 6)
    love.graphics.setColor(0.38, 0.22, 0.52, alpha)
    love.graphics.rectangle("line", x + 92, y + 10, 270, 68, 6, 6)
    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], alpha)
    love.graphics.printf(characterCue.text, x + 110, y + 26, 234, "left")
  end
  if characterCue.nitoriText then drawNitoriCue(characterCue.nitoriText, alpha, t) end
  if characterCue.nitoriIcon then drawNitoriIconCue(characterCue.nitoriIcon, alpha, t) end
  if oldFont then love.graphics.setFont(oldFont) end
end

local function drawProgressPanel()
  local screenW, screenH = screenSize()
  local w, h = 284, 232
  local x, y = screenW - w - 16, (screenH - h) * 0.5
  love.graphics.setColor(colors.panel)
  love.graphics.rectangle("fill", x, y, w, h, 5, 5)
  love.graphics.setColor(colors.grid)
  love.graphics.rectangle("line", x, y, w, h, 5, 5)

  love.graphics.setColor(colors.text)
  love.graphics.print("Sources", x + 16, y + 14)
  local lineY = y + 38
  for _, s in ipairs(sources) do
    love.graphics.print(s.id .. "  " .. s.output .. "  " .. s.cargoType .. "  stock:" .. (unlimitedStock and "unlimited" or tostring(s.remaining)), x + 16, lineY)
    lineY = lineY + 20
  end
  lineY = lineY + 10
  love.graphics.print("Lost  " .. tostring(lostCargo), x + 16, lineY)
  lineY = lineY + 24
  love.graphics.print("Destinations", x + 16, lineY)
  lineY = lineY + 24
  for _, d in ipairs(dests) do
    for t, n in pairs(d.req) do
      love.graphics.print(d.id .. " " .. (d.label or "") .. "  in:" .. table.concat(d.inputs or dirs, "") .. "  " .. t .. " " .. tostring(d.got[t] or 0) .. "/" .. n .. "  wrong:" .. d.wrong, x + 16, lineY)
      lineY = lineY + 20
      if lineY > y + h - 22 then return end
    end
  end
end

local function drawSchemaLinks()
  for y = 1, H do
    for x = 1, W do
      local cell = board[y][x]
      if cell.kind == "tile" and cell.type == "schema_in" then
        local ox, oy = findSchemaPart(cell.pair, "out")
        if ox then
          local ax, ay = center(x, y)
          local bx, by = center(ox, oy)
          local vx, vy = bx - ax, by - ay
          local len = math.max(1, math.sqrt(vx * vx + vy * vy))
          local nx, ny = vx / len, vy / len
          local px, py = -ny, nx
          love.graphics.setColor(0.72, 0.48, 1, 0.45)
          love.graphics.setLineWidth(2)
          love.graphics.line(ax, ay, bx, by)
          for i = 0, 2 do
            local t = (simTime * 1.6 + i / 3) % 1
            local mx, my = ax + vx * t, ay + vy * t
            love.graphics.setColor(0.82, 0.65, 1, 0.35 + 0.55 * t)
            love.graphics.circle("fill", mx, my, 3 + 2 * t)
          end
          love.graphics.setColor(0.82, 0.65, 1, 0.9)
          love.graphics.polygon("fill", bx, by, bx - nx * 14 + px * 6, by - ny * 14 + py * 6, bx - nx * 14 - px * 6, by - ny * 14 - py * 6)
          love.graphics.setColor(0.72, 0.48, 1, 0.9)
          love.graphics.print("#" .. cell.pair, (ax + bx) / 2 - 8, (ay + by) / 2 - 8)
        end
      end
    end
  end
  love.graphics.setLineWidth(1)
end

local drawTile

local function drawSchemaExitPreview(hx, hy)
  if not pendingSchema or not inBounds(hx, hy) then return end
  local sx, sy = deniedShakeOffset(hx, hy)
  local bx, by = OX + (hx - 1) * CELL + sx, OY + (hy - 1) * CELL + sy
  love.graphics.setColor(colors.schema[1], colors.schema[2], colors.schema[3], 0.42)
  love.graphics.rectangle("fill", bx, by, CELL - 1, CELL - 1)
  drawTile(hx, hy, { kind = "tile", type = "schema_out", pair = pendingSchema.pair, rotation = placementRotation })
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
  local cx, cy = center(x, y)
  local sx, sy = deniedShakeOffset(x, y)
  cx, cy = cx + sx, cy + sy
  return cx, cy
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
  love.graphics.print(tileLabel(cell), cx - 4, cy - 8)
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

function drawTile(x, y, cell)
  if cell.regionTween then return drawRegionTile(cell) end
  local cx, cy = tileVisualCenter(x, y, cell)
  love.graphics.setColor(tileColor(cell))
  love.graphics.rectangle("fill", cx - CELL * 0.5, cy - CELL * 0.5, CELL - 1, CELL - 1)
  love.graphics.setColor(0.86, 0.88, 0.8)
  love.graphics.print(tileLabel(cell), cx - 4, cy - 8)
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

function drawDraggedTile()
  if not dragStart or not inBounds(dragStart.x, dragStart.y) then return end
  local cell = board[dragStart.y][dragStart.x]
  if cell.kind ~= "tile" then return end
  local mx, my = love.mouse.getPosition()
  local color = tileColor(cell)
  love.graphics.setColor(color[1], color[2], color[3], 0.46)
  love.graphics.rectangle("fill", mx - CELL * 0.5, my - CELL * 0.5, CELL - 1, CELL - 1, 4, 4)
  love.graphics.setColor(0.86, 0.88, 0.8, 0.72)
  love.graphics.print(tileLabel(cell), mx - 4, my - 8)
  for _, segment in ipairs(baseTileSegments(cell.type)) do
    local ax, ay = drawPoint(mx, my, segment[1], PORT_RADIUS, cell.rotation)
    local bx, by = drawPoint(mx, my, segment[2], PORT_RADIUS, cell.rotation)
    if cell.type == "corner" then
      love.graphics.line(ax, ay, mx, my)
      love.graphics.line(mx, my, bx, by)
    else
      love.graphics.line(ax, ay, bx, by)
    end
  end
  local inputs, outputs = baseTilePorts(cell.type)
  love.graphics.setColor(0.1, 0.12, 0.13, 0.72)
  for _, d in ipairs(inputs) do
    local px, py = drawPoint(mx, my, d, PORT_RADIUS, cell.rotation)
    love.graphics.rectangle("fill", px - 5, py - 5, 10, 10)
  end
  love.graphics.setColor(1, 0.86, 0.28, 0.72)
  for _, d in ipairs(outputs) do
    local px, py = drawPoint(mx, my, d, PORT_RADIUS, cell.rotation)
    love.graphics.circle("fill", px, py, 5)
  end
end

local function drawObstacle(_, _, cell, bx, by)
  local rt = cell.regionTween
  local function p(px, py)
    local lx, ly = matrixPoint(rt and rt.fromTransform or cell.transform, px / CELL - 0.5, py / CELL - 0.5)
    if rt then
      return regionTweenPoint(rt, lx, ly)
    end
    return bx + CELL * 0.5 + lx * CELL, by + CELL * 0.5 + ly * CELL
  end
  local x1, y1 = p(3, 3)
  local x2, y2 = p(CELL - 4, 3)
  local x3, y3 = p(CELL - 4, CELL - 4)
  local x4, y4 = p(3, CELL - 4)
  love.graphics.setColor(cell.type == "water" and colors.water or colors.rock)
  love.graphics.polygon("fill", x1, y1, x2, y2, x3, y3, x4, y4)
  love.graphics.setColor(0.82, 0.86, 0.82)
  if cell.type == "water" then
    local ax, ay = p(10, 22); local bx1, by1 = p(20, 18); local cx, cy = p(30, 22); local dx1, dy1 = p(40, 18)
    love.graphics.line(ax, ay, bx1, by1, cx, cy, dx1, dy1)
    ax, ay = p(10, 30); bx1, by1 = p(20, 26); cx, cy = p(30, 30); dx1, dy1 = p(40, 26)
    love.graphics.line(ax, ay, bx1, by1, cx, cy, dx1, dy1)
  else
    local ax, ay = p(14, 34); local bx1, by1 = p(22, 14); local cx, cy = p(36, 22); local dx1, dy1 = p(40, 36)
    love.graphics.polygon("fill", ax, ay, bx1, by1, cx, cy, dx1, dy1)
  end
end

function drawOccupation(cell, bx, by)
  if cell.occupiedBy ~= "yuyuko" then return end
  love.graphics.setColor(0.28, 0.04, 0.08, 0.42)
  love.graphics.rectangle("fill", bx + 3, by + 3, CELL - 7, CELL - 7, 5, 5)
  drawImageBox(portraits.yuyuko, bx + 7, by + 7, CELL - 15, 0.92)
end

function rumiaOutsidePoint()
  local side = math.random(1, 4)
  if side == 1 then return math.random() * W + 0.5, -4 end
  if side == 2 then return W + 5, math.random() * H + 0.5 end
  if side == 3 then return math.random() * W + 0.5, H + 5 end
  return -4, math.random() * H + 0.5
end

function startRumiaDisturbance()
  disturbanceTimer = config.disturbanceInterval
  playSfx("rumiaEncounter", 0.85)
  local x, y = rumiaOutsidePoint()
  local tx, ty = math.random() * W + 0.5, math.random() * H + 0.5
  local ex, ey = rumiaOutsidePoint()
  rumiaOrb = {
    x = x, y = y, sx = x, sy = y, tx = tx, ty = ty, ex = ex, ey = ey,
    angle = math.atan2(ty - y, tx - x), time = 0, turn = 0, particleTimer = 0,
    phase = "enter", entryDuration = 2.5, exitDuration = 2.5,
    wanderDuration = math.max(1, config.disturbanceInterval - 5)
  }
  rumiaTrail = {}
  characterCue = { id = "rumia", text = "그-런건-가~", nitoriIcon = portraits.blind, time = 0, duration = 3.4 }
  replayEvents[#replayEvents + 1] = { t = simTime, action = "disturbance_alert", effect = "rumia" }
end

function updateRumia(dt)
  if not rumiaOrb then return end
  rumiaOrb.time = rumiaOrb.time + dt
  if rumiaOrb.phase == "enter" then
    local t = easeOutQuint(math.min(1, rumiaOrb.time / rumiaOrb.entryDuration))
    rumiaOrb.x = rumiaOrb.sx + (rumiaOrb.tx - rumiaOrb.sx) * t
    rumiaOrb.y = rumiaOrb.sy + (rumiaOrb.ty - rumiaOrb.sy) * t
    if t >= 1 then rumiaOrb.phase, rumiaOrb.time, rumiaOrb.turn = "wander", 0, 0 end
  elseif rumiaOrb.phase == "exit" then
    local t = easeOutQuint(math.min(1, rumiaOrb.time / rumiaOrb.exitDuration))
    rumiaOrb.x = rumiaOrb.sx + (rumiaOrb.tx - rumiaOrb.sx) * t
    rumiaOrb.y = rumiaOrb.sy + (rumiaOrb.ty - rumiaOrb.sy) * t
    if t >= 1 then rumiaOrb = nil; return end
  else
    local speed = 0.72
    rumiaOrb.turn = rumiaOrb.turn - dt
    if rumiaOrb.turn <= 0 then
      rumiaOrb.angle = rumiaOrb.angle + (math.random() - 0.5) * 1.6
      rumiaOrb.turn = 0.7 + math.random() * 0.8
    end
    rumiaOrb.x = rumiaOrb.x + math.cos(rumiaOrb.angle) * speed * dt
    rumiaOrb.y = rumiaOrb.y + math.sin(rumiaOrb.angle) * speed * dt
    if rumiaOrb.x < 1 or rumiaOrb.x > W then rumiaOrb.angle = math.pi - rumiaOrb.angle end
    if rumiaOrb.y < 1 or rumiaOrb.y > H then rumiaOrb.angle = -rumiaOrb.angle end
    rumiaOrb.x, rumiaOrb.y = math.max(1, math.min(W, rumiaOrb.x)), math.max(1, math.min(H, rumiaOrb.y))
    if rumiaOrb.time >= rumiaOrb.wanderDuration then
      rumiaOrb.phase, rumiaOrb.time = "exit", 0
      rumiaOrb.sx, rumiaOrb.sy, rumiaOrb.tx, rumiaOrb.ty = rumiaOrb.x, rumiaOrb.y, rumiaOrb.ex, rumiaOrb.ey
    end
  end
  rumiaOrb.particleTimer = rumiaOrb.particleTimer + dt
  while rumiaOrb.particleTimer >= 0.1 do
    rumiaOrb.particleTimer = rumiaOrb.particleTimer - 0.1
    local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * 5
    rumiaTrail[#rumiaTrail + 1] = { x = rumiaOrb.x + math.cos(a) * r, y = rumiaOrb.y + math.sin(a) * r, size = 1 + math.random() * 2, time = 0 }
  end
  for i = #rumiaTrail, 1, -1 do
    rumiaTrail[i].time = rumiaTrail[i].time + dt
    if rumiaTrail[i].time >= 1 then table.remove(rumiaTrail, i) end
  end
end

function drawRumiaOrb()
  if not rumiaOrb then return end
  for _, p in ipairs(rumiaTrail) do
    local a = 1 - p.time
    local x, y = center(p.x, p.y)
    for i = 8, 1, -1 do
      local t = i / 8
      local center = easeOutQuint(1 - t)
      love.graphics.setColor(0.005, 0, 0.018, (0.02 + center * 0.13) * a)
      love.graphics.circle("fill", x, y, CELL * p.size * t)
    end
  end
  local x, y = center(rumiaOrb.x, rumiaOrb.y)
  for i = 18, 1, -1 do
    local t = i / 18
    local center = easeOutQuint(1 - t)
    love.graphics.setColor(0.005, 0, 0.018, 0.025 + center * 0.2)
    love.graphics.circle("fill", x, y, CELL * 4 * t)
  end
  drawImageBox(portraits.rumia, x - 28, y - 28, 56, 0.88)
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
    if not lane.blocked then
      local p = (simTime * 1.7 + (lane.dist or 0) * 0.19) % 1
      local px, py = laneWorldPoint(lane, p)
      local qx, qy = laneWorldPoint(lane, math.min(1, p + 0.05))
      local vx, vy = qx - px, qy - py
      local len = math.max(1, math.sqrt(vx * vx + vy * vy))
      vx, vy = vx / len, vy / len
      local sx, sy = -vy, vx
      love.graphics.setColor(1, 0.95, 0.45)
      love.graphics.circle("fill", px, py, 3)
      love.graphics.polygon("fill", px + vx * 8, py + vy * 8, px - vx * 5 + sx * 4, py - vy * 5 + sy * 4, px - vx * 5 - sx * 4, py - vy * 5 - sy * 4)
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

function drawRecallCargo()
  for _, r in ipairs(recallCargo) do
    for _, p in ipairs(r.trail) do
      local a = 1 - p.time / p.duration
      love.graphics.setColor(colors.cargo[1], colors.cargo[2], colors.cargo[3], 0.28 * a)
      love.graphics.circle("fill", p.x, p.y, 6 * a)
    end
    local a = math.max(0, 1 - r.time / r.duration)
    love.graphics.setColor(colors.cargo[1], colors.cargo[2], colors.cargo[3], 0.45 + 0.55 * a)
    love.graphics.circle("fill", r.x, r.y, 8)
  end
end

local function regionHasActiveLane(x, y, size)
  for yy = y, y + size - 1 do
    for xx = x, x + size - 1 do
      if not canModifyCell(board[yy][xx], "disturbance") then return false end
    end
  end
  for _, lane in pairs(flows.lanes) do
    if not lane.blocked and lane.x >= x and lane.y >= y and lane.x < x + size and lane.y < y + size then
      return true
    end
  end
  return false
end

local function randomDisturbanceRegion(size)
  size = size or math.random(2, 3)
  for _ = 1, 80 do
    local x, y = math.random(1, W - size + 1), math.random(1, H - size + 1)
    if regionHasActiveLane(x, y, size) then return x, y, size end
  end
  return nil
end

local function nearPort(x, y)
  for _, s in ipairs(sources) do
    if x == s.x + dx[s.output] and y == s.y + dy[s.output] then return true end
  end
  for _, d in ipairs(dests) do
    for _, input in ipairs(d.inputs or dirs) do
      if x == d.x + dx[input] and y == d.y + dy[input] then return true end
    end
  end
  return false
end

local function randomYuyukoRegion()
  for _ = 1, 80 do
    local x, y = math.random(1, W), math.random(1, H)
    if regionHasActiveLane(x, y, 1) and not nearPort(x, y) then return x, y, 1 end
  end
end

local function startDisturbance(manual)
  if disturbancesBlocked and not manual then return end
  if dirty then recalcFlow() end
  local pick = math.random(1, 3)
  if pick == 1 then return startRumiaDisturbance() end
  if pick == 2 then
    local x, y, size = randomYuyukoRegion()
    if not x then return end
    disturbanceTimer = config.disturbanceInterval
    playSfx("alert", 0.85, 0.45)
    pendingDisturbance = { x = x, y = y, size = size, effect = "occupy", label = "Yuyuko Occupy", timer = config.disturbanceDelay, phase = "alert" }
    characterCue = { id = "yuyuko", text = "여기있네 빵 통조림~", nitoriText = "아아악!! 공습경보 공습경보!!", time = 0, duration = config.disturbanceDelay + disturbanceTweenDuration }
    replayEvents[#replayEvents + 1] = { t = simTime, action = "disturbance_alert", x = x, y = y, size = size, effect = "occupy" }
    return
  end
  local x, y, size = randomDisturbanceRegion()
  if not x then return end
  local effect = disturbanceEffects[math.random(1, #disturbanceEffects)]
  disturbanceTimer = config.disturbanceInterval
  playSfx("alert", 0.85, 0.45)
  pendingDisturbance = { x = x, y = y, size = size, effect = effect.id, label = effect.label, timer = config.disturbanceDelay, phase = "alert" }
  characterCue = { id = "seija", text = ({ "정말 망가트리기 좋게 생긴 공장이네", "내가 더 재밌게 해줄게" })[math.random(1, 2)], nitoriText = "세이자년 다음에 잡으면 죽인다", time = 0, duration = config.disturbanceDelay + disturbanceTweenDuration }
  replayEvents[#replayEvents + 1] = { t = simTime, action = "disturbance_alert", x = x, y = y, size = size, effect = effect.id }
end

function removeCargoInRegion(d)
  for _, c in ipairs(cargo) do
    if c.state ~= "removed" then
      local lane = flows.lanes[c.lane] or c.visualLane
      local x, y = lane and lane.x or c.cellX, lane and lane.y or c.cellY
      if x and y and x >= d.x and y >= d.y and x < d.x + d.size and y < d.y + d.size then loseCargo(c) end
    end
  end
end

function applyYuyukoDisturbance(d)
  removeCargoInRegion(d)
  for y = d.y, d.y + d.size - 1 do
    for x = d.x, d.x + d.size - 1 do
      if canModifyCell(board[y][x], "disturbance") then board[y][x].occupiedBy = "yuyuko" end
    end
  end
  dirty = true
  recalcFlow()
  replayEvents[#replayEvents + 1] = { t = simTime, action = "disturbance_apply", x = d.x, y = d.y, size = d.size, effect = d.effect }
end

local function applyDisturbance(d)
  if d.effect == "occupy" then return applyYuyukoDisturbance(d) end
  for y = d.y, d.y + d.size - 1 do
    for x = d.x, d.x + d.size - 1 do
      if not canModifyCell(board[y][x], "disturbance") then return end
    end
  end
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
      elseif cell.kind == "obstacle" then
        local fromTransform = cell.transform
        cell.regionTween = { x = d.x, y = d.y, size = d.size, effect = d.effect, gx = gx, gy = gy, time = 0, duration = disturbanceTweenDuration, fromTransform = fromTransform, toTransform = composeMatrix(effectMatrix(d.effect), fromTransform) }
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
  if effect == "occupy" then return "Y" end
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
  if d.effect == "occupy" then
    local cx = OX + (d.x + d.size * 0.5 - 1) * CELL
    local cy = OY + (d.y - 1) * CELL - CELL * 0.96
    drawImageBox(portraits.yuyuko, cx - 24, cy - 24, 48, 0.92)
    return
  end
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

local function exportDebugState()
  local lines = {
    "Nitori Factory Debug State",
    "scenario=" .. scenario .. " status=" .. status .. " paused=" .. tostring(paused) .. " unlimitedStock=" .. tostring(unlimitedStock) .. " " .. ruleInversionText(),
    "selected=" .. names[selected] .. " placementRotation=" .. placementRotation .. " zoom=" .. string.format("%.2f", zoom),
    "",
    "Board:",
  }
  local mark = { empty = ".", source = "A", dest = "B" }
  for y = 1, H do
    local row = {}
    for x = 1, W do
      local cell = board[y][x]
      row[#row + 1] = boardToken(cell)
    end
    lines[#lines + 1] = table.concat(row, " ")
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Sources:"
  for _, s in ipairs(sources) do
    local received = "{}"
    if s.received then
      local parts = {}
      for t, n in pairs(s.received) do parts[#parts + 1] = t .. "=" .. n end
      received = table.concat(parts, ",")
    end
    lines[#lines + 1] = string.format("%s pos=%d,%d out=%s rotation=%s strength=%s cargo=%s remaining=%s received=%s", s.id, s.x, s.y, s.output, s.rotation, s.strength, s.cargoType, s.remaining, received)
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Destinations:"
  for _, d in ipairs(dests) do
    for t, need in pairs(d.req) do
      lines[#lines + 1] = string.format("%s pos=%d,%d inputs=%s rotation=%s %s=%d/%d wrong=%d", d.id, d.x, d.y, table.concat(d.inputs or dirs, ","), d.rotation, t, d.got[t] or 0, need, d.wrong)
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

local q, luaValue, copyReq = common.q, common.luaValue, common.copyReq

local function exportStageData()
  local data = {
    version = 1,
    name = scenarioTitle ~= "" and scenarioTitle or ("Stage " .. scenario),
    size = { w = W, h = H },
    schemaStock = schemaStock,
    tileStock = { straight = "infinite", corner = "infinite", splitter = "infinite", merger = "infinite", bridge = "infinite", schema = schemaStock, backdoor = "infinite" },
    sources = {},
    destinations = {},
    cells = {},
  }
  for _, s in ipairs(sources) do
    data.sources[#data.sources + 1] = { id = s.id, x = s.x, y = s.y, output = s.output, cargoType = s.cargoType, stock = s.remaining == -1 and "infinite" or s.remaining, interval = s.interval }
  end
  for _, d in ipairs(dests) do
    data.destinations[#data.destinations + 1] = { id = d.id, x = d.x, y = d.y, inputs = d.inputs or dirs, req = copyReq(d.req), locked = true }
  end
  for y = 1, H do
    for x = 1, W do
      local cell = board[y][x]
      if cell.kind == "tile" then
        data.cells[#data.cells + 1] = { x = x, y = y, kind = "tile", type = cell.type, rotation = cell.rotation, pair = cell.pair, locked = cell.immutable or false }
      elseif cell.kind == "obstacle" then
        data.cells[#data.cells + 1] = { x = x, y = y, kind = "obstacle", type = cell.type, locked = cell.immutable or false, transform = cell.transform }
      end
    end
  end
  return data
end

local function stageDumpText()
  return "NitoriStage = " .. luaValue(exportStageData())
end

local function applyStageData(data)
  if type(data) ~= "table" or type(data.size) ~= "table" then return false, "invalid stage data" end
  resetScenario(0, data.size.w or W, data.size.h or H, data.name or "Imported Stage")
  schemaStock = data.schemaStock or (data.tileStock and data.tileStock.schema) or schemaStock
  if schemaStock == "infinite" then schemaStock = 99 end
  for _, s in ipairs(data.sources or {}) do
    setSource({ id = s.id or "A", x = s.x, y = s.y, output = s.output or "E", strength = 1, cargoType = s.cargoType or "box", remaining = s.stock == "infinite" and -1 or (s.stock or 0), timer = 0, interval = s.interval or 1 })
  end
  for _, d in ipairs(data.destinations or {}) do
    setDest({ id = d.id or "B", x = d.x, y = d.y, inputs = d.inputs or dirs, req = d.req or { box = 1 }, got = {}, wrong = 0 })
  end
  local maxPair = 0
  for _, c in ipairs(data.cells or {}) do
    if inBounds(c.x, c.y) and canModifyCell(board[c.y][c.x], "editor") then
      if c.kind == "tile" then
        board[c.y][c.x] = { kind = "tile", type = c.type, rotation = c.rotation or 0, pair = c.pair, immutable = c.locked or false }
        if c.pair then maxPair = math.max(maxPair, c.pair) end
      elseif c.kind == "obstacle" then
        board[c.y][c.x] = { kind = "obstacle", type = c.type or "rock", immutable = c.locked ~= false, transform = c.transform }
      end
    end
  end
  nextSchemaId, pendingSchema = maxPair + 1, nil
  editorMode, editorSizing = true, false
  dirty = true
  recalcFlow()
  editorMessage = "Imported stage: " .. scenarioTitle
  return true
end

local function parseStageText(text)
  local fn = load("return " .. text, "stage", "t", {})
  if fn then
    local ok, data = pcall(fn)
    if ok then return data end
  end
  local env = {}
  fn = load(text .. "\nreturn NitoriStage", "stage", "t", env)
  if not fn then return nil end
  local ok, data = pcall(fn)
  return ok and data or nil
end

function parseReplayText(text)
  local env = {}
  local fn = load(text .. "\nreturn NitoriReplay", "replay", "t", env)
  if not fn then return nil end
  local ok, data = pcall(fn)
  return ok and data or nil
end

function tokenCell(token)
  if token == "." then return { kind = "empty" } end
  local out = token:match("^A:(%u)$")
  if out then return { kind = "source", output = out } end
  local inputs = token:match("^B:([NESW]+)$")
  if inputs then
    local list = {}
    for i = 1, #inputs do list[#list + 1] = inputs:sub(i, i) end
    return { kind = "dest", inputs = list }
  end
  if token == "R" or token == "W" then return { kind = "obstacle", type = token == "R" and "rock" or "water", immutable = true } end
  local label, pair, rot = token:match("^(%u)(%d+):(%d+)$")
  if not label then label, rot = token:match("^(%u)(%d+)$") end
  if label then
    local types = { C = "corner", S = "straight", M = "merger", B = "bridge", D = "backdoor", I = "schema_in", O = "schema_out" }
    return { kind = "tile", type = types[label] or "straight", pair = pair and tonumber(pair), rotation = tonumber(rot) or 0 }
  end
  return { kind = "empty" }
end

function applyReplaySnapshot(data)
  local snap = data and data.snapshot
  if type(snap) ~= "table" then return false, "missing snapshot" end
  if snap.size then
    resetScenario(data.scenario or 0, snap.size.w or W, snap.size.h or H, snap.title or "Replay Snapshot")
  else
    loadScenario(data.scenario or scenario)
  end
  if snap.sources then
    sources = {}
    for _, s in ipairs(snap.sources) do
      setSource({ id = s.id or "A", x = s.x, y = s.y, output = s.output or "E", rotation = s.rotation, strength = s.strength or 1, cargoType = s.cargoType or "box", remaining = s.remaining or 0, timer = s.timer or 0, interval = s.interval or 1, received = s.received })
    end
  end
  if snap.destinations then
    dests = {}
    for _, d in ipairs(snap.destinations) do
      setDest({ id = d.id or "B", x = d.x, y = d.y, inputs = d.inputs or dirs, rotation = d.rotation, req = d.req or { box = 1 }, got = d.got or {}, wrong = d.wrong or 0, timer = d.timer or 0, reverseSent = d.reverseSent })
    end
  end
  paused, characterCue = true, nil
  cargo, recallCargo, rumiaOrb, rumiaTrail = {}, {}, nil, {}
  local maxPair = 0
  if snap.cells then
    for _, c in ipairs(snap.cells) do
      if inBounds(c.x, c.y) and (c.kind == "tile" or c.kind == "obstacle" or c.occupiedBy) then
        if c.kind == "tile" then board[c.y][c.x] = { kind = "tile", type = c.type, rotation = c.rotation or 0, pair = c.pair, occupiedBy = c.occupiedBy }
        elseif c.kind == "obstacle" then board[c.y][c.x] = { kind = "obstacle", type = c.type or "rock", immutable = true, transform = c.transform, occupiedBy = c.occupiedBy }
        elseif board[c.y] and board[c.y][c.x] then board[c.y][c.x].occupiedBy = c.occupiedBy end
        if c.pair then maxPair = math.max(maxPair, c.pair) end
      end
    end
  elseif snap.board then
    for y, row in ipairs(snap.board) do
      local x = 1
      for token in tostring(row):gmatch("%S+") do
        if inBounds(x, y) then
          local cell = tokenCell(token)
          if cell.kind == "tile" or cell.kind == "obstacle" then board[y][x] = cell end
        end
        x = x + 1
      end
    end
  end
  for _, c in ipairs(snap.cargo or {}) do
    cargo[#cargo + 1] = { id = c.id, type = c.type or "box", state = c.state or "waiting", lane = c.lane, progress = c.progress or 0, cellX = c.cellX, cellY = c.cellY, localX = c.localX or 0, localY = c.localY or 0, visualPoint = c.visualPoint, speed = c.speed or 1.5 }
    nextCargoId = math.max(nextCargoId, (c.id or 0) + 1)
  end
  ruleInversions.reverseFlow = snap.rules and snap.rules.reverseFlow or false
  ruleInversions.swapSplitMerge = snap.rules and snap.rules.swapSplitMerge or false
  status = snap.status or data.status or status
  unlimitedStock = data.unlimitedStock or false
  lostCargo = snap.lostCargo or lostCargo
  schemaStock = snap.schemaStock or schemaStock
  simTime = data.elapsed or simTime
  disturbanceTimer = snap.disturbanceTimer or disturbanceTimer
  disturbanceAutoEnabled = snap.disturbanceAutoEnabled ~= false
  pendingDisturbance = snap.pendingDisturbance
  rumiaOrb = snap.rumiaOrb
  nextSchemaId = math.max(nextSchemaId, maxPair + 1)
  dirty = true
  recalcFlow()
  remapWaitingCargo()
  editorMessage = "Imported replay snapshot"
  return true
end

function importReplaySnapshotFromClipboard()
  local ok, text = pcall(function() return love.system.getClipboardText() end)
  if not ok or not text or text == "" then editorMessage = "Replay import failed: clipboard is empty"; return end
  local data = parseReplayText(text)
  if not data then editorMessage = "Replay import failed: expected NitoriReplay"; return end
  local applied, err = applyReplaySnapshot(data)
  if not applied then editorMessage = "Replay import failed: " .. tostring(err) end
end

local function importStageFromClipboard()
  local ok, text = pcall(function() return love.system.getClipboardText() end)
  if not ok or not text or text == "" then editorMessage = "Import failed: clipboard is empty"; return end
  local data = parseStageText(text)
  if not data then editorMessage = "Import failed: expected NitoriStage table"; return end
  local applied, err = applyStageData(data)
  if not applied then editorMessage = "Import failed: " .. tostring(err) end
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
      local pair = e.pair and (", pair = " .. e.pair) or ""
      lines[#lines + 1] = string.format("    { t = %.3f, action = %s, x = %d, y = %d, tile = %s, rotation = %d%s },", e.t, q(e.action), e.x, e.y, q(e.tile), e.rotation, pair)
    elseif e.action == "remove" or e.action == "rotate" then
      lines[#lines + 1] = string.format("    { t = %.3f, action = %s, x = %d, y = %d },", e.t, q(e.action), e.x, e.y)
    elseif e.action == "swap" then
      lines[#lines + 1] = string.format("    { t = %.3f, action = %s, ax = %d, ay = %d, bx = %d, by = %d },", e.t, q(e.action), e.ax, e.ay, e.bx, e.by)
    elseif e.action == "disturbance_alert" or e.action == "disturbance_apply" then
      if e.x then
        lines[#lines + 1] = string.format("    { t = %.3f, action = %s, x = %d, y = %d, size = %d, effect = %s },", e.t, q(e.action), e.x, e.y, e.size, q(e.effect))
      else
        lines[#lines + 1] = string.format("    { t = %.3f, action = %s, effect = %s },", e.t, q(e.action), q(e.effect))
      end
    elseif e.action == "unlimited_stock" then
      lines[#lines + 1] = string.format("    { t = %.3f, action = %s, enabled = %s },", e.t, q(e.action), tostring(e.enabled))
    end
  end
  lines[#lines + 1] = "  },"
  lines[#lines + 1] = "  snapshot = {"
  lines[#lines + 1] = "    size = " .. luaValue({ w = W, h = H }, "    ") .. ","
  lines[#lines + 1] = "    title = " .. q(scenarioTitle) .. ","
  lines[#lines + 1] = "    status = " .. q(status) .. ","
  lines[#lines + 1] = "    rules = " .. luaValue(ruleInversions, "    ") .. ","
  lines[#lines + 1] = "    schemaStock = " .. tostring(schemaStock) .. ","
  lines[#lines + 1] = "    lostCargo = " .. tostring(lostCargo) .. ","
  lines[#lines + 1] = "    disturbanceTimer = " .. string.format("%.3f", disturbanceTimer or 0) .. ","
  lines[#lines + 1] = "    disturbanceAutoEnabled = " .. tostring(disturbanceAutoEnabled) .. ","
  lines[#lines + 1] = "    pendingDisturbance = " .. luaValue(pendingDisturbance, "    ") .. ","
  lines[#lines + 1] = "    rumiaOrb = " .. luaValue(rumiaOrb, "    ") .. ","
  lines[#lines + 1] = "    sources = {"
  for _, s in ipairs(sources) do lines[#lines + 1] = "      " .. luaValue(sourceData(s), "      ") .. "," end
  lines[#lines + 1] = "    },"
  lines[#lines + 1] = "    destinations = {"
  for _, d in ipairs(dests) do lines[#lines + 1] = "      " .. luaValue(destinationData(d), "      ") .. "," end
  lines[#lines + 1] = "    },"
  lines[#lines + 1] = "    board = {"
  local mark = { empty = ".", source = "A", dest = "B" }
  for y = 1, H do
    local row = {}
    for x = 1, W do
      local cell = board[y][x]
      row[#row + 1] = boardToken(cell)
    end
    lines[#lines + 1] = "      " .. q(table.concat(row, " ")) .. ","
  end
  lines[#lines + 1] = "    },"
  lines[#lines + 1] = "    cells = {"
  for y = 1, H do
    for x = 1, W do
      local data = cellData(x, y, board[y][x])
      if data then lines[#lines + 1] = "      " .. luaValue(data, "      ") .. "," end
    end
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
  local isWeb = love.system.getOS and love.system.getOS() == "Web"
  local opened = isWeb and love.system.openURL and pcall(function()
    love.system.openURL("https://djejsgames.github.io/rreevveerrssee/#nitori_dump=" .. urlEncode(title) .. ":" .. urlEncode(text))
  end)
  if not opened and not copied then print(title .. "\n" .. text) end
end

local function playNextBgm()
  if not (love.audio and love.audio.newSource) then return end
  pcall(function()
    bgmFade = nil
    bgmIndex = bgmIndex % #bgmTracks + 1
    bgm = love.audio.newSource(bgmTracks[bgmIndex], "stream")
    bgm:setLooping(false)
    bgm:setVolume(0.45)
    bgm:play()
  end)
end

function playBgm(path, volume, loop)
  if not (love.audio and love.audio.newSource) then return end
  pcall(function()
    if bgm then bgm:stop() end
    bgmFade = nil
    bgm = love.audio.newSource(path, "stream")
    bgm:setLooping(loop == true)
    bgm:setVolume(volume or 0.45)
    bgm:play()
  end)
end

function applyBgmCue(cue)
  if not cue then return end
  if cue.action == "play" and cue.path then playBgm(cue.path, cue.volume, cue.loop); return end
  if cue.action == "stop" and bgm then bgm:stop(); bgmFade = nil; return end
  if cue.action == "fade" and bgm then
    bgmFade = { time = 0, duration = cue.duration or 1, from = bgm:getVolume(), to = cue.to or 0, stop = cue.stop }
  end
end

function updateBgmFade(dt)
  if not (bgm and bgmFade) then return end
  bgmFade.time = math.min(bgmFade.duration, bgmFade.time + dt)
  local t = bgmFade.duration > 0 and bgmFade.time / bgmFade.duration or 1
  bgm:setVolume(bgmFade.from + (bgmFade.to - bgmFade.from) * t)
  if t >= 1 then
    if bgmFade.stop then bgm:stop() end
    bgmFade = nil
  end
end

local function loadSfx()
  if not (love.audio and love.audio.newSource) then return end
  local files = {
    alert = "assets/audio/SE/Alert.mp3",
    cargoReturn = "assets/audio/SE/Cargo_return.mp3",
    rumiaEncounter = "assets/audio/SE/Rumia_encounter.mp3",
    tileBatch = "assets/audio/SE/Tile_batch.mp3",
    tileDeny = "assets/audio/SE/Tile_Deny.mp3",
    tileSpin = "assets/audio/SE/Tile_spin.mp3",
  }
  for id, path in pairs(files) do pcall(function() sfxSources[id] = love.audio.newSource(path, "static") end) end
end

function playSfx(id, volume, fadeTail)
  local base = sfxSources[id]
  if not base then return end
  pcall(function()
    local s = base:clone()
    s:setVolume(volume or 0.8)
    s:play()
    if fadeTail then activeSfx[#activeSfx + 1] = { source = s, volume = volume or 0.8, fadeTail = fadeTail } end
  end)
end

function updateSfx()
  for i = #activeSfx, 1, -1 do
    local item = activeSfx[i]
    local s = item.source
    if not s:isPlaying() then
      table.remove(activeSfx, i)
    else
      local okDur, dur = pcall(function() return s:getDuration("seconds") end)
      local okTell, pos = pcall(function() return s:tell("seconds") end)
      if okDur and okTell and dur and pos then
        local remain = dur - pos
        if remain < item.fadeTail then s:setVolume(item.volume * math.max(0, remain / item.fadeTail)) end
      end
    end
  end
end

function love.load()
  math.randomseed(os.time())
  uiFont = love.graphics.newFont("assets/fonts/SeoulCyberUnivercity_EB.ttf", 13)
  dialogFont = love.graphics.newFont("assets/fonts/SeoulCyberUnivercity_EB.ttf", 21)
  love.graphics.setFont(uiFont)
  if love.graphics.newImage then
    portraits.nitori = love.graphics.newImage("assets/Images/Nitori.png")
    portraits.seija = love.graphics.newImage("assets/Images/Seija.png")
    portraits.sagume = love.graphics.newImage("assets/Images/Sagume.png")
    portraits.yuyuko = love.graphics.newImage("assets/Images/Yuyuko.png")
    portraits.rumia = love.graphics.newImage("assets/Images/Rumia.png")
    portraits.blind = love.graphics.newImage("assets/Images/Blind.png")
    icons.lock = love.graphics.newImage("assets/Images/Icon/Lock.png")
    backgrounds.youkaiMountain = love.graphics.newImage("assets/Images/Background/YoukaiMountain.jpg")
  end
  storyDialogueScene.configure({
    portraits = portraits,
    backgrounds = backgrounds,
    colors = colors,
    font = function() return dialogFont end,
    time = function() return simTime end,
    playSfx = playSfx,
    bgm = applyBgmCue,
    skipDown = function() return love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") end,
    close = function() gameScene = "map" end,
  })
  storyDialogueScene.loadPortraitPcg()
  loadSfx()
  playNextBgm()
  selected, editorSelected, placementRotation, paused, debug, unlimitedStock = 1, 1, 0, false, true, false
  loadScenario(1)
end

function love.update(dt)
  simTime = simTime + dt
  if bgm and not bgm:isPlaying() and gameScene ~= "dialogue" then playNextBgm() end
  updateBgmFade(dt)
  updateSfx()
  if gameScene == "dialogue" then
    storyDialogueScene.update(dt)
    return
  end
  local move = cameraSpeed * dt
  if love.keyboard.isDown("a") then cameraX = cameraX + move end
  if love.keyboard.isDown("d") then cameraX = cameraX - move end
  if love.keyboard.isDown("w") then cameraY = cameraY + move end
  if love.keyboard.isDown("s") then cameraY = cameraY - move end
  if gameScene == "map" then return end
  if not disturbancesBlocked or pendingDisturbance then updateDisturbance(dt) end
  updateRumia(dt)
  if dirty then
    recalcFlow()
  end
  remapWaitingCargo()
  updateTileTweens(dt)
  updateCargoTweens(dt)
  updateRecallCargo(dt)
  updateConsumableTween(dt)
  updateCharacterCue(dt)
  updateDeniedShakes(dt)
  if not disturbancesBlocked and not paused and status == "running" and disturbanceAutoEnabled then
    disturbanceTimer = disturbanceTimer - dt
    if disturbanceTimer <= 0 and not pendingDisturbance and not rumiaOrb then startDisturbance() end
  end
  if not paused and not disturbanceLocksSimulation() then
    if status == "running" then spawn(dt) end
    moveCargo(dt)
    if status == "running" then checkStatus() end
  end
end

local function drawHoverBorder(x, y, ox, oy, color)
  ox, oy = ox or 0, oy or 0
  love.graphics.setColor(color or colors.hover)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", OX + (x - 1) * CELL + 2 + ox, OY + (y - 1) * CELL + 2 + oy, CELL - 4, CELL - 4, 4, 4)
  love.graphics.setLineWidth(1)
end

local function drawDeniedBorders()
  for k in pairs(deniedShakes) do
    local x, y = k:match("^(%d+),(%d+)$")
    x, y = tonumber(x), tonumber(y)
    if x and y then
      local ox, oy = deniedShakeOffset(x, y)
      drawHoverBorder(x, y, ox, oy, colors.block)
    end
  end
end

function drawArrowHead(x, y, dir, color)
  local vx, vy = dx[dir], dy[dir]
  local px, py = -vy, vx
  love.graphics.setColor(color)
  love.graphics.polygon("fill", x, y, x - vx * 10 + px * 5, y - vy * 10 + py * 5, x - vx * 10 - px * 5, y - vy * 10 - py * 5)
end

local function drawSourceCell(cell, bx, by)
  love.graphics.setColor(colors.source)
  love.graphics.rectangle("fill", bx + 4, by + 4, CELL - 8, CELL - 8, 4, 4)
  love.graphics.setColor(colors.text)
  love.graphics.print(cell.id, bx + 10, by + 13)
  love.graphics.print(rotationLabel(cell.rotation), bx + 28, by + 28)
  local cx, cy = bx + CELL * 0.5, by + CELL * 0.5
  local tx, ty = cx + dx[cell.output] * 16, cy + dy[cell.output] * 16
  love.graphics.setColor(colors.cargo)
  love.graphics.setLineWidth(3)
  love.graphics.line(cx, cy, tx, ty)
  drawArrowHead(tx, ty, cell.output, colors.cargo)
  love.graphics.setLineWidth(1)
end

local function drawDestCell(cell, bx, by)
  love.graphics.setColor(colors.dest)
  love.graphics.rectangle("fill", bx + 4, by + 4, CELL - 8, CELL - 8, 4, 4)
  love.graphics.setColor(colors.text)
  love.graphics.print(cell.id, bx + 10, by + 13)
  love.graphics.print(rotationLabel(cell.rotation), bx + 28, by + 28)
  local cx, cy = bx + CELL * 0.5, by + CELL * 0.5
  love.graphics.setLineWidth(2)
  for _, input in ipairs(cell.inputs or dirs) do
    local sx, sy = cx + dx[input] * 19, cy + dy[input] * 19
    local tx, ty = cx + dx[input] * 8, cy + dy[input] * 8
    love.graphics.setColor(colors.hover)
    love.graphics.line(sx, sy, tx, ty)
    drawArrowHead(tx, ty, opposite[input], colors.hover)
  end
  love.graphics.setLineWidth(1)
end

local function drawEditorMarker(cell, bx, by, hovered)
  if (not editorMode and not hovered) or not cell.immutable or cell.kind == "source" or cell.kind == "dest" then return end
  if icons.lock then
    local size = 14
    local scale = size / math.max(icons.lock:getWidth(), icons.lock:getHeight())
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(icons.lock, bx + CELL - size - 4, by + 4, 0, scale, scale)
  else
    love.graphics.setColor(colors.block)
    love.graphics.rectangle("fill", bx + CELL - 12, by + 4, 8, 8, 2, 2)
  end
end

local function drawEditorSizingOverlay()
  if not editorSizing then return end
  local w, h = 460, 172
  local x, y = 360, 170
  love.graphics.setColor(0, 0, 0, 0.84)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  love.graphics.setColor(colors.hover)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(colors.text)
  love.graphics.print("New Stage Size", x + 28, y + 24)
  for i, size in ipairs(EDITOR_BOARD_SIZES) do
    love.graphics.print(i .. "  " .. size.label, x + 28, y + 24 + i * 30)
  end
  love.graphics.print("Esc/G: cancel", x + 28, y + h - 30)
end

function love.draw()
  if gameScene == "dialogue" then storyDialogueScene.draw(); return end
  if gameScene == "map" then drawMapSelectScene(); return end

  love.graphics.clear(colors.bg)

  local hx, hy = cellAt(love.mouse.getPosition())
  love.graphics.push()
  love.graphics.translate(cameraX, cameraY)
  love.graphics.scale(zoom)
  for y = 1, H do
    for x = 1, W do
      local sx, sy = deniedShakeOffset(x, y)
      local bx, by = OX + (x - 1) * CELL + sx, OY + (y - 1) * CELL + sy
      love.graphics.setColor(colors.empty)
      love.graphics.rectangle("fill", bx, by, CELL - 1, CELL - 1)
      local cell = board[y][x]
      if cell.kind == "tile" then drawTile(x, y, cell) end
      if cell.kind == "obstacle" then
        drawObstacle(x, y, cell, bx, by)
      elseif cell.kind == "source" then
        drawSourceCell(cell, bx, by)
      elseif cell.kind == "dest" then
        drawDestCell(cell, bx, by)
      end
      drawOccupation(cell, bx, by)
      drawEditorMarker(cell, bx, by, x == hx and y == hy)
      love.graphics.setColor(colors.grid)
      love.graphics.rectangle("line", bx, by, CELL, CELL)
    end
  end
  drawSchemaExitPreview(hx, hy)
  if inBounds(hx, hy) and not deniedShakes[key(hx, hy)] then
    local id = (not editorMode) and placementConsumableId(board[hy][hx])
    drawHoverBorder(hx, hy, nil, nil, id and { 0.25, 1, 0.38 } or nil)
  end
  drawSchemaLinks()
  drawDisturbanceAlertWorld()
  if debug then drawFlow() end
  drawCargo()
  drawRecallCargo()
  drawRumiaOrb()
  drawDeniedBorders()
  love.graphics.pop()
  drawDraggedTile()
  drawPlayerPortrait()
  drawConsumableSlots()
  drawPlacementPanel()
  drawProgressPanel()
  drawCharacterCue()
  drawTopPanel()
  drawDisturbanceAlertUi()
  drawEditorSizingOverlay()
end

function leftClickBoard(x, y)
  if editorMode then
    placeEditorItem(x, y, editorNames[editorSelected])
    return
  end
  local consumeId = placementConsumableId(board[y][x])
  if not consumeId and not canModifyCell(board[y][x], "player") then denyCellAction(x, y); return end
  if pendingSchema then
    if key(x, y) == key(pendingSchema.x, pendingSchema.y) then denyCellAction(x, y); return end
    if board[y][x].kind ~= "empty" and not consumeId then denyCellAction(x, y); return end
    if consumeId then board[y][x] = { kind = "empty" } end
    if setSchemaTile(x, y, "out", pendingSchema.pair, placementRotation) then
      usePlacementConsumable(consumeId)
      playSfx("tileBatch", 0.75)
      schemaStock = math.max(0, schemaStock - 1)
      replayEvents[#replayEvents + 1] = { t = simTime, action = "place", x = x, y = y, tile = "schema_out", rotation = placementRotation, pair = pendingSchema.pair }
      pendingSchema = nil
    end
  elseif names[selected] == "schema" then
    if schemaStock <= 0 then denyCellAction(x, y); return end
    if board[y][x].kind ~= "empty" and not consumeId then denyCellAction(x, y); return end
    local pair = nextSchemaId
    nextSchemaId = nextSchemaId + 1
    if consumeId then board[y][x] = { kind = "empty" } end
    if setSchemaTile(x, y, "in", pair, placementRotation) then
      usePlacementConsumable(consumeId)
      playSfx("tileBatch", 0.75)
      pendingSchema = { pair = pair, x = x, y = y }
      replayEvents[#replayEvents + 1] = { t = simTime, action = "place", x = x, y = y, tile = "schema_in", rotation = placementRotation, pair = pair }
    end
  else
    local cell = board[y][x]
    if not consumeId and cell.kind == "tile" and cell.type == names[selected] and cell.rotation == placementRotation then return end
    if consumeId then board[y][x] = { kind = "empty" } end
    if setTile(x, y, names[selected], placementRotation) then
      usePlacementConsumable(consumeId)
      playSfx("tileBatch", 0.75)
    replayEvents[#replayEvents + 1] = { t = simTime, action = "place", x = x, y = y, tile = names[selected], rotation = placementRotation }
  else
    denyCellAction(x, y)
  end
  end
end

function releaseBoardDrag(mx, my)
  if not dragStart then return false end
  local sx, sy = dragStart.x, dragStart.y
  local x, y = cellAt(mx, my)
  dragStart = nil
  if not inBounds(x, y) then return true end
  if sx == x and sy == y then leftClickBoard(x, y); return true end
  local layer = editorMode and "editor" or "player"
  if swapTiles(sx, sy, x, y, layer) then
    if not editorMode then replayEvents[#replayEvents + 1] = { t = simTime, action = "swap", ax = sx, ay = sy, bx = x, by = y } end
  else
    denyCellAction(sx, sy)
    denyCellAction(x, y)
  end
  return true
end

function love.mousepressed(mx, my, button)
  if gameScene == "dialogue" then storyDialogueScene.mousepressed(mx, my, button); return end
  if gameScene == "map" then
    if button == 1 then
      if dialogueTestButtonHit(mx, my) then dialogueTestPanelOpen = not dialogueTestPanelOpen; return end
      local dialogueTest = dialogueTestPanelHit(mx, my)
      if dialogueTest then startDialogueTest(dialogueTest); return end
      local _, area = mapAreaAt(mx, my)
      if area then selectMapArea(area) end
    end
    return
  end
  local tab = topTabHit(mx, my)
  if tab and button == 1 then topTab = tab; return end
  if button == 1 and cooldownSliderHit(mx, my) then
    cooldownSliderDrag = true
    setDisturbanceCooldownFromMouse(mx)
    return
  end
  if editorSizing then return end
  local hit = panelHit(mx, my)
  if hit and button == 1 then
    if editorMode then editorSelected = hit else selected = hit end
    return
  end
  local x, y = cellAt(mx, my)
  if not inBounds(x, y) then return end
  if button == 1 then
    dragStart = { x = x, y = y }
    return
  end
  if editorMode and button == 2 then
    clearCellAt(x, y)
    editorMessage = "Cleared " .. x .. "," .. y
  elseif button == 2 then
    if not canModifyCell(board[y][x], "player") then denyCellAction(x, y); return end
    if board[y][x].kind ~= "tile" then return end
    if removeTileAt(x, y) then replayEvents[#replayEvents + 1] = { t = simTime, action = "remove", x = x, y = y } end
  end
end

function love.mousereleased(mx, my, button)
  if button == 1 and cooldownSliderDrag then cooldownSliderDrag = false; return end
  if button == 1 then releaseBoardDrag(mx, my) end
end

function love.mousemoved(mx, my)
  if cooldownSliderDrag then setDisturbanceCooldownFromMouse(mx) end
end

function love.keypressed(k)
  if gameScene == "dialogue" then
    storyDialogueScene.keypressed(k)
    return
  end
  if gameScene == "map" then
    if k == "o" then dialogueTestPanelOpen = not dialogueTestPanelOpen; return end
    local numberKey = tonumber(k)
    if dialogueTestPanelOpen and numberKey then
      if startDialogueTest(numberKey) then return end
    end
    if numberKey and mapAreas[numberKey] then selectMapArea(mapAreas[numberKey]) end
    return
  end
  local numberKey = tonumber(k)
  if editorSizing then
    if numberKey and createEditorStage(numberKey) then return end
    if k == "escape" or k == "g" then editorMode, editorSizing = false, false; editorMessage = "Editor setup canceled"; return end
    return
  end
  if numberKey == 0 and editorMode then numberKey = 10 end
  if numberKey then
    if editorMode and numberKey >= 1 and numberKey <= #editorNames then editorSelected = numberKey
    elseif not editorMode and numberKey >= 1 and numberKey <= #names then selected = numberKey end
  end
  if k == "t" and editHoveredResource("type") then return end
  if (k == "=" or k == "+" or k == "kp+") and editHoveredResource("inc") then return end
  if (k == "-" or k == "kp-") and editHoveredResource("dec") then return end
  if k == "q" and editHoveredResource("infinite") then return end
  if not editorMode and k == "q" then cycleConsumable(-1); return end
  if not editorMode and k == "e" then cycleConsumable(1); return end
  if k == "space" then paused = not paused end
  if k == "`" or k == "grave" then debug = not debug end
  if k == "c" then showDump("Nitori Debug State", exportDebugState()) end
  if k == "v" and (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then importReplaySnapshotFromClipboard(); return end
  if k == "v" then showDump("Nitori Replay Dump", replayDumpText()) end
  if k == "g" then
    if editorMode then
      editorMode, editorSizing = false, false
      editorMessage = "Editor mode off"
    else
      startEditorSizing()
    end
  end
  if k == "x" then showDump("Nitori Stage Export", stageDumpText()); editorMessage = "Stage exported" end
  if k == "i" then importStageFromClipboard() end
  if k == "o" and editorMode then
    editorSelected = editorSelected == 10 and 11 or 10
    editorMessage = "Editor brush: " .. editorNames[editorSelected]
  end
  if k == "l" and editorMode then
    local x, y = cellAt(love.mouse.getPosition())
    if inBounds(x, y) and (board[y][x].kind == "tile" or board[y][x].kind == "obstacle") then
      board[y][x].immutable = not board[y][x].immutable
      editorMessage = "Lock " .. x .. "," .. y .. ": " .. tostring(board[y][x].immutable)
    end
  end
  if k == "b" then startDisturbance(true) end
  if k == "m" then disturbanceAutoEnabled = not disturbanceAutoEnabled end
  if k == "n" then randomizeRuleInversions(); return end
  if k == "u" then
    unlimitedStock = not unlimitedStock
    replayEvents[#replayEvents + 1] = { t = simTime, action = "unlimited_stock", enabled = unlimitedStock }
  end
  if k == "f" then dirty = true end
  if k == "tab" then loadScenario(scenario % scenarios.count + 1) end
  if k == "escape" then gameScene = "map"; cameraX, cameraY, zoom = 0, 0, 1; return end
  if k == "r" then
    local x, y = cellAt(love.mouse.getPosition())
    if editorMode and inBounds(x, y) and board[y][x].kind == "source" then
      local cell = board[y][x]
      cell.rotation = (cell.rotation + 1) % 4
      cell.output = rotationLabel(cell.rotation)
      for _, s in ipairs(sources) do if s.x == x and s.y == y then s.rotation, s.output = cell.rotation, cell.output end end
      dirty = true
      playSfx("tileSpin", 0.75)
    elseif editorMode and inBounds(x, y) and board[y][x].kind == "dest" then
      local cell = board[y][x]
      cell.rotation = (cell.rotation + 1) % 4
      cell.inputs = { rotationLabel(cell.rotation) }
      for _, d in ipairs(dests) do if d.x == x and d.y == y then d.rotation, d.inputs = cell.rotation, cell.inputs end end
      dirty = true
      playSfx("tileSpin", 0.75)
    elseif editorMode and inBounds(x, y) and board[y][x].kind == "tile" then
      rotateCargoInCell(x, y)
      rotateTile(board[y][x])
      placementRotation = board[y][x].rotation
      dirty = true
      recalcFlow()
      remapCargoInCell(x, y)
      playSfx("tileSpin", 0.75)
    elseif inBounds(x, y) and board[y][x].kind == "source" and board[y][x].rotatable then
      local cell = board[y][x]
      cell.rotation = (cell.rotation + 1) % 4
      cell.output = rotationLabel(cell.rotation)
      for _, s in ipairs(sources) do if s.x == x and s.y == y then s.rotation, s.output = cell.rotation, cell.output end end
      dirty = true
      playSfx("tileSpin", 0.75)
    elseif inBounds(x, y) and not canModifyCell(board[y][x], "player") then
      denyCellAction(x, y)
    elseif inBounds(x, y) and board[y][x].kind == "tile" then
      rotateCargoInCell(x, y)
      rotateTile(board[y][x])
      placementRotation = board[y][x].rotation
      dirty = true
      recalcFlow()
      remapCargoInCell(x, y)
      playSfx("tileSpin", 0.75)
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
