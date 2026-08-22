local M = {}

M.count = 8

local function rockLine(api, x, y1, y2)
  for y = y1, y2 do api.setObstacle(x, y, "rock") end
end

local function waterLine(api, x, y1, y2)
  for y = y1, y2 do api.setObstacle(x, y, "water") end
end

function M.load(n, api)
  n = ((n - 1) % M.count) + 1
  if n == 1 then
    api.resetScenario(n, 16, 10, "Straight Gap XL")
    api.setSource({ id = "A1", x = 1, y = 5, output = "E", strength = 1, cargoType = "box", remaining = 50, timer = 0, interval = 1 })
    api.setDest({ id = "B1", x = 16, y = 5, inputs = { "W" }, req = { box = 30 }, got = {}, wrong = 0 })
    api.setTile(2, 5, "straight", 1); api.setTile(13, 5, "straight", 1); api.setTile(14, 5, "straight", 1); api.setTile(15, 5, "straight", 1)
  elseif n == 2 then
    api.resetScenario(n, 16, 12, "Corner Detour XL")
    api.setSource({ id = "A1", x = 1, y = 10, output = "E", strength = 1, cargoType = "box", remaining = 60, timer = 0, interval = 1 })
    api.setDest({ id = "B1", x = 16, y = 3, inputs = { "W" }, req = { box = 40 }, got = {}, wrong = 0 })
    api.setTile(2, 10, "straight", 1); api.setTile(4, 10, "corner", 3); api.setTile(14, 3, "straight", 1); api.setTile(15, 3, "straight", 1)
    rockLine(api, 8, 5, 9); rockLine(api, 9, 5, 9)
  elseif n == 3 then
    api.resetScenario(n, 18, 14, "Wall Route XL")
    api.setSource({ id = "A1", x = 1, y = 7, output = "E", strength = 1, cargoType = "box", remaining = 70, timer = 0, interval = 0.9 })
    api.setDest({ id = "B1", x = 18, y = 7, inputs = { "W" }, req = { box = 40 }, got = {}, wrong = 0 })
    api.setTile(2, 7, "straight", 1); api.setTile(16, 7, "straight", 1); api.setTile(17, 7, "straight", 1)
    rockLine(api, 9, 4, 12); api.setObstacle(9, 3, "water")
  elseif n == 4 then
    api.resetScenario(n, 18, 14, "Splitter Three-Way XL")
    api.setSource({ id = "A1", x = 1, y = 7, output = "E", strength = 1, cargoType = "box", remaining = -1, timer = 0, interval = 0.8 })
    api.setDest({ id = "B1", x = 18, y = 3, inputs = { "W" }, req = { box = 20 }, got = {}, wrong = 0 })
    api.setDest({ id = "B2", x = 18, y = 7, inputs = { "W" }, req = { box = 20 }, got = {}, wrong = 0 })
    api.setDest({ id = "B3", x = 18, y = 11, inputs = { "W" }, req = { box = 20 }, got = {}, wrong = 0 })
    api.setTile(2, 7, "straight", 1); api.setTile(5, 7, "splitter", 3)
    api.setTile(16, 3, "straight", 1); api.setTile(17, 3, "straight", 1); api.setTile(16, 7, "straight", 1); api.setTile(17, 7, "straight", 1); api.setTile(16, 11, "straight", 1); api.setTile(17, 11, "straight", 1)
  elseif n == 5 then
    api.resetScenario(n, 20, 14, "Merger Join XL")
    api.setSource({ id = "A1", x = 1, y = 4, output = "E", strength = 1, cargoType = "box", remaining = 40, timer = 0, interval = 1 })
    api.setSource({ id = "A2", x = 1, y = 11, output = "E", strength = 1, cargoType = "box", remaining = 40, timer = 0, interval = 1 })
    api.setDest({ id = "B1", x = 20, y = 7, inputs = { "W" }, req = { box = 60 }, got = {}, wrong = 0 })
    api.setTile(2, 4, "straight", 1); api.setTile(2, 11, "straight", 1); api.setTile(13, 7, "merger", 1); api.setTile(18, 7, "straight", 1); api.setTile(19, 7, "straight", 1)
  elseif n == 6 then
    api.resetScenario(n, 20, 16, "Bridge Crossing XL")
    api.setSource({ id = "A1", x = 1, y = 8, output = "E", strength = 1, cargoType = "box", remaining = 40, timer = 0, interval = 0.9 })
    api.setSource({ id = "A2", x = 10, y = 16, output = "N", strength = 1, cargoType = "box", remaining = 40, timer = 0, interval = 0.9 })
    api.setDest({ id = "B1", x = 20, y = 8, inputs = { "W" }, req = { box = 30 }, got = {}, wrong = 0 })
    api.setDest({ id = "B2", x = 10, y = 1, inputs = { "S" }, req = { box = 30 }, got = {}, wrong = 0 })
    api.setTile(2, 8, "straight", 1); api.setTile(18, 8, "straight", 1); api.setTile(19, 8, "straight", 1); api.setTile(10, 15, "straight", 0); api.setTile(10, 2, "straight", 0)
  elseif n == 7 then
    api.resetScenario(n, 24, 16, "Schema Bypass XL")
    api.setSource({ id = "A1", x = 1, y = 8, output = "E", strength = 1, cargoType = "box", remaining = 60, timer = 0, interval = 0.9 })
    api.setDest({ id = "B1", x = 24, y = 8, inputs = { "W" }, req = { box = 40 }, got = {}, wrong = 0 })
    api.setTile(2, 8, "straight", 1); api.setTile(3, 8, "straight", 1); api.setTile(21, 8, "straight", 1); api.setTile(22, 8, "straight", 1); api.setTile(23, 8, "straight", 1)
    waterLine(api, 12, 3, 14); waterLine(api, 13, 3, 14)
  else
    api.resetScenario(n, 24, 16, "Factory Mix XL")
    api.setSource({ id = "A1", x = 1, y = 8, output = "E", strength = 1, cargoType = "box", remaining = -1, timer = 0, interval = 0.75 })
    api.setDest({ id = "B1", x = 24, y = 4, inputs = { "W" }, req = { box = 20 }, got = {}, wrong = 0 })
    api.setDest({ id = "B2", x = 24, y = 12, inputs = { "W" }, req = { box = 20 }, got = {}, wrong = 0 })
    api.setDest({ id = "B3", x = 16, y = 8, inputs = { "W" }, req = { box = 20 }, got = {}, wrong = 0 })
    api.setTile(2, 8, "straight", 1); api.setTile(7, 8, "splitter", 3); api.setTile(14, 8, "straight", 1); api.setTile(22, 4, "straight", 1); api.setTile(23, 4, "straight", 1); api.setTile(22, 12, "straight", 1); api.setTile(23, 12, "straight", 1)
    api.setObstacle(12, 6, "rock"); api.setObstacle(13, 6, "rock"); api.setObstacle(12, 10, "water"); api.setObstacle(13, 10, "water")
  end
end

return M
