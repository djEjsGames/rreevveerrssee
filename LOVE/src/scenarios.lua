local M = {}

M.count = 8

function M.load(n, api)
  n = ((n - 1) % M.count) + 1
  if n == 1 then
    api.resetScenario(n, 8, 5, "Straight Gap")
    api.setSource({ id = "A1", x = 1, y = 3, output = "E", strength = 1, cargoType = "box", remaining = 50, timer = 0, interval = 1 })
    api.setDest({ id = "B1", x = 8, y = 3, inputs = { "W" }, req = { box = 30 }, got = {}, wrong = 0 })
    api.setTile(2, 3, "straight", 1)
    api.setTile(6, 3, "straight", 1)
    api.setTile(7, 3, "straight", 1)
  elseif n == 2 then
    api.resetScenario(n, 8, 6, "Corner Detour")
    api.setSource({ id = "A1", x = 1, y = 5, output = "E", strength = 1, cargoType = "box", remaining = 60, timer = 0, interval = 1 })
    api.setDest({ id = "B1", x = 8, y = 2, inputs = { "W" }, req = { box = 40 }, got = {}, wrong = 0 })
    api.setTile(2, 5, "straight", 1)
    api.setTile(3, 5, "corner", 3)
    api.setTile(7, 2, "straight", 1)
    api.setObstacle(4, 4, "rock")
    api.setObstacle(5, 4, "rock")
  elseif n == 3 then
    api.resetScenario(n, 9, 7, "Wall Route")
    api.setSource({ id = "A1", x = 1, y = 4, output = "E", strength = 1, cargoType = "box", remaining = 70, timer = 0, interval = 0.9 })
    api.setDest({ id = "B1", x = 9, y = 4, inputs = { "W" }, req = { box = 40 }, got = {}, wrong = 0 })
    api.setTile(2, 4, "straight", 1)
    api.setTile(8, 4, "straight", 1)
    for y = 2, 6 do if y ~= 2 then api.setObstacle(5, y, "rock") end end
  elseif n == 4 then
    api.resetScenario(n, 9, 7, "Splitter Three-Way")
    api.setSource({ id = "A1", x = 1, y = 4, output = "E", strength = 1, cargoType = "box", remaining = -1, timer = 0, interval = 0.8 })
    api.setDest({ id = "B1", x = 9, y = 2, inputs = { "W" }, req = { box = 20 }, got = {}, wrong = 0 })
    api.setDest({ id = "B2", x = 9, y = 4, inputs = { "W" }, req = { box = 20 }, got = {}, wrong = 0 })
    api.setDest({ id = "B3", x = 9, y = 6, inputs = { "W" }, req = { box = 20 }, got = {}, wrong = 0 })
    api.setTile(2, 4, "straight", 1)
    api.setTile(3, 4, "splitter", 3)
    api.setTile(8, 2, "straight", 1)
    api.setTile(8, 4, "straight", 1)
    api.setTile(8, 6, "straight", 1)
  elseif n == 5 then
    api.resetScenario(n, 10, 7, "Merger Join")
    api.setSource({ id = "A1", x = 1, y = 2, output = "E", strength = 1, cargoType = "box", remaining = 40, timer = 0, interval = 1 })
    api.setSource({ id = "A2", x = 1, y = 6, output = "E", strength = 1, cargoType = "box", remaining = 40, timer = 0, interval = 1 })
    api.setDest({ id = "B1", x = 10, y = 4, inputs = { "W" }, req = { box = 60 }, got = {}, wrong = 0 })
    api.setTile(2, 2, "straight", 1)
    api.setTile(2, 6, "straight", 1)
    api.setTile(7, 4, "merger", 1)
    api.setTile(8, 4, "straight", 1)
    api.setTile(9, 4, "straight", 1)
  elseif n == 6 then
    api.resetScenario(n, 10, 8, "Bridge Crossing")
    api.setSource({ id = "A1", x = 1, y = 4, output = "E", strength = 1, cargoType = "box", remaining = 40, timer = 0, interval = 0.9 })
    api.setSource({ id = "A2", x = 5, y = 8, output = "N", strength = 1, cargoType = "box", remaining = 40, timer = 0, interval = 0.9 })
    api.setDest({ id = "B1", x = 10, y = 4, inputs = { "W" }, req = { box = 30 }, got = {}, wrong = 0 })
    api.setDest({ id = "B2", x = 5, y = 1, inputs = { "S" }, req = { box = 30 }, got = {}, wrong = 0 })
    api.setTile(2, 4, "straight", 1)
    api.setTile(9, 4, "straight", 1)
    api.setTile(5, 7, "straight", 0)
    api.setTile(5, 2, "straight", 0)
  elseif n == 7 then
    api.resetScenario(n, 12, 8, "Schema Bypass")
    api.setSource({ id = "A1", x = 1, y = 4, output = "E", strength = 1, cargoType = "box", remaining = 60, timer = 0, interval = 0.9 })
    api.setDest({ id = "B1", x = 12, y = 4, inputs = { "W" }, req = { box = 40 }, got = {}, wrong = 0 })
    api.setTile(2, 4, "straight", 1)
    api.setTile(3, 4, "straight", 1)
    api.setTile(10, 4, "straight", 1)
    api.setTile(11, 4, "straight", 1)
    for y = 2, 7 do api.setObstacle(6, y, "water") end
  else
    api.resetScenario(n, 12, 8, "Factory Mix")
    api.setSource({ id = "A1", x = 1, y = 4, output = "E", strength = 1, cargoType = "box", remaining = -1, timer = 0, interval = 0.75 })
    api.setDest({ id = "B1", x = 12, y = 2, inputs = { "W" }, req = { box = 20 }, got = {}, wrong = 0 })
    api.setDest({ id = "B2", x = 12, y = 6, inputs = { "W" }, req = { box = 20 }, got = {}, wrong = 0 })
    api.setDest({ id = "B3", x = 8, y = 4, inputs = { "W" }, req = { box = 20 }, got = {}, wrong = 0 })
    api.setTile(2, 4, "straight", 1)
    api.setTile(4, 4, "splitter", 3)
    api.setTile(7, 4, "straight", 1)
    api.setTile(11, 2, "straight", 1)
    api.setTile(11, 6, "straight", 1)
    api.setObstacle(6, 3, "rock")
    api.setObstacle(6, 5, "water")
  end
end

return M
