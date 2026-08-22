local tileRules = require("src.tile_rules")

local M = {}

local function claimLane(flows, lane, key, laneKey)
  local k = laneKey(lane.x, lane.y, lane.entry, lane.exit)
  local reverse = laneKey(lane.x, lane.y, lane.exit, lane.entry)
  if flows.lanes[reverse] then
    local other = flows.lanes[reverse]
    other.blocked, lane.blocked = true, true
    flows.blocks[key(lane.x, lane.y)] = true
    flows.lanes[k] = lane
    return false
  end
  local old = flows.lanes[k]
  if not old or lane.strength >= old.strength then flows.lanes[k] = lane end
  return true
end

local function exitConnects(api, flows, x, y, exit)
  local nx, ny = x + api.dx[exit], y + api.dy[exit]
  if not api.inBounds(nx, ny) then return false end
  local nextCell = api.board[ny][nx]
  if api.rules and api.rules.reverseFlow and nextCell.kind == "source" then return true end
  if nextCell.kind == "dest" then return true end
  if nextCell.kind ~= "tile" then return false end
  return #tileRules.exitsFor(nextCell, api.opposite[exit], api.schemaPairComplete, api.rules) > 0
end

function M.recalc(api)
  local flows = { lanes = {}, from = {}, sourceLanes = {}, blocks = {} }
  local queue = {}
  if api.rules and api.rules.reverseFlow then
    for _, d in ipairs(api.dests) do
      for _, input in ipairs(d.inputs or api.dirs) do
        queue[#queue + 1] = { x = d.x + api.dx[input], y = d.y + api.dy[input], entry = api.opposite[input], source = d.id, strength = 1, dist = 0 }
      end
    end
  else
    for _, s in ipairs(api.sources) do
      queue[#queue + 1] = { x = s.x + api.dx[s.output], y = s.y + api.dy[s.output], entry = api.opposite[s.output], source = s.id, strength = s.strength, dist = 0 }
    end
  end
  local guard = 0
  while #queue > 0 and guard < 2000 do
    guard = guard + 1
    local f = table.remove(queue, 1)
    if api.inBounds(f.x, f.y) then
      local cell = api.board[f.y][f.x]
      if cell.kind == "tile" then
        for _, exit in ipairs(tileRules.exitsFor(cell, f.entry, api.schemaPairComplete, api.rules)) do
          if (cell.type ~= "splitter" and cell.type ~= "merger") or exitConnects(api, flows, f.x, f.y, exit) then
            local lane = { x = f.x, y = f.y, entry = f.entry, exit = exit, type = cell.type, pair = cell.pair, source = f.source, strength = f.strength, dist = f.dist + 1 }
            claimLane(flows, lane, api.key, api.laneKey)
            local lk = api.laneKey(f.x, f.y, f.entry, exit)
            flows.from[f.x .. "," .. f.y .. "," .. f.entry] = flows.from[f.x .. "," .. f.y .. "," .. f.entry] or {}
            table.insert(flows.from[f.x .. "," .. f.y .. "," .. f.entry], lk)
            if f.dist == 0 then
              flows.sourceLanes[f.source] = flows.sourceLanes[f.source] or {}
              table.insert(flows.sourceLanes[f.source], lk)
            end
            if not lane.blocked and cell.type == "schema_in" and exit == "C" then
              local ox, oy = api.findSchemaPart(cell.pair, "out")
              if ox then queue[#queue + 1] = { x = ox, y = oy, entry = "C", source = f.source, strength = f.strength, dist = f.dist + 1 } end
            elseif not lane.blocked then
              queue[#queue + 1] = { x = f.x + api.dx[exit], y = f.y + api.dy[exit], entry = api.opposite[exit], source = f.source, strength = f.strength, dist = f.dist + 1 }
            end
          end
        end
      end
    end
  end
  return flows
end

function M.laneAfter(api, lane)
  if lane.type == "backdoor" and lane.exit == "C" then return nil, "stock" end
  if lane.type == "schema_in" and lane.exit == "C" then
    local ox, oy, out = api.findSchemaPart(lane.pair, "out")
    if not out then return nil, "blocked" end
    local outDir = api.dirs[(out.rotation % 4) + 1]
    local lk = api.laneKey(ox, oy, "C", outDir)
    local outLane = api.flows.lanes[lk]
    return outLane and not outLane.blocked and lk or nil, outLane and not outLane.blocked and "lane" or "blocked"
  end
  local nx, ny = lane.x + api.dx[lane.exit], lane.y + api.dy[lane.exit]
  if not api.inBounds(nx, ny) then return nil, "void" end
  local cell = api.board[ny][nx]
  if api.rules and api.rules.reverseFlow and cell.kind == "source" then return nil, "source", cell.id end
  if cell.kind == "dest" then
    local entry = api.opposite[lane.exit]
    return nil, api.hasDir(cell.inputs, entry) and "dest" or "blocked", cell.id
  end
  if cell.kind ~= "tile" then return nil, "blocked" end
  local entry = api.opposite[lane.exit]
  local options = api.flows.from[nx .. "," .. ny .. "," .. entry] or {}
  if #options == 0 then return nil, "blocked" end
  if cell.type == "splitter" then
    local sk = api.key(nx, ny)
    api.splitState[sk] = api.splitState[sk] or 1
    local pick = options[((api.splitState[sk] - 1) % #options) + 1]
    return pick, "lane", nil, sk
  end
  return options[1], "lane"
end

return M
