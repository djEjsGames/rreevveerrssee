local M = {}

function M.editHoveredResource(action, api)
  if not api.editorMode() then return false end
  local x, y = api.hoverCell()
  if not api.inBounds(x, y) then return false end
  local cell = api.cell(x, y)
  if cell.kind == "source" then
    local s = api.sourceAt(x, y)
    if not s then return false end
    if action == "type" then
      s.cargoType = api.cycleCargoType(s.cargoType)
    elseif action == "inc" then
      s.remaining = s.remaining == -1 and 1 or s.remaining + 1
    elseif action == "dec" then
      s.remaining = s.remaining == -1 and -1 or math.max(0, s.remaining - 1)
    elseif action == "infinite" then
      s.remaining = s.remaining == -1 and 5 or -1
    end
    api.setMessage(s.id .. " cargo:" .. s.cargoType .. " stock:" .. (s.remaining == -1 and "infinite" or s.remaining))
    api.markDirty()
    return true
  elseif cell.kind == "dest" then
    local d = api.destAt(x, y)
    if not d then return false end
    local t = api.firstReqType(d)
    local need = d.req[t] or 1
    if action == "type" then
      local nt = api.cycleCargoType(t)
      d.req = { [nt] = need }
      d.got = {}
    elseif action == "inc" then
      d.req[t] = need + 1
    elseif action == "dec" then
      d.req[t] = math.max(1, need - 1)
    else
      return false
    end
    t = api.firstReqType(d)
    api.setMessage(d.id .. " need:" .. t .. " x" .. d.req[t])
    api.markDirty()
    return true
  end
  return false
end

function M.placeItem(x, y, name, api)
  if api.cellHasCargo(x, y) then api.denyCellAction(x, y); return false end
  api.clearCellAt(x, y)
  if name == "source" then
    api.setSource({ id = api.nextNodeId("A", api.sources()), x = x, y = y, output = api.rotationLabel(api.placementRotation()), strength = 1, cargoType = "box", remaining = -1, timer = 0, interval = 1 })
  elseif name == "dest" then
    api.setDest({ id = api.nextNodeId("B", api.dests()), x = x, y = y, inputs = { api.rotationLabel(api.placementRotation()) }, req = { box = 1 }, got = {}, wrong = 0 })
  elseif name == "rock" or name == "water" then
    api.setObstacle(x, y, name, true)
  elseif name == "schema" then
    local pending = api.pendingSchema()
    if pending then
      if api.key(x, y) == api.key(pending.x, pending.y) then api.denyCellAction(x, y); return false end
      api.setSchemaTile(x, y, "out", pending.pair, api.placementRotation(), "editor")
      api.setPendingSchema(nil)
    else
      local pair = api.takeNextSchemaId()
      api.setSchemaTile(x, y, "in", pair, api.placementRotation(), "editor")
      api.setPendingSchema({ pair = pair, x = x, y = y })
    end
  else
    api.setTile(x, y, name, api.placementRotation(), "editor")
  end
  api.setMessage("Placed " .. name .. " at " .. x .. "," .. y)
  return true
end

function M.startSizing(api)
  api.setEditorState(true, true, nil, nil, true)
  api.setMessage("Choose editor board size: 1 small, 2 medium, 3 large")
end

function M.createStage(sizeIndex, api)
  local size = api.editorBoardSizes()[sizeIndex]
  if not size then return false end
  api.resetScenario(0, size.w, size.h, "Editor " .. size.w .. "x" .. size.h)
  api.setEditorState(true, false, nil, nil, true)
  api.setMessage("New editor board: " .. size.label)
  return true
end

return M
