local config = require("src.config")

local dirs = config.dirs

local M = {}

function M.exitsFor(tile, entry, schemaPairComplete, rules)
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
    if rules and rules.swapSplitMerge then
      if entry ~= input then return { input } end
    elseif entry == input then
      local outs = {}
      for _, d in ipairs(dirs) do if d ~= input then outs[#outs + 1] = d end end
      return outs
    end
  elseif tile.type == "merger" then
    local output = dirs[r + 1]
    if rules and rules.swapSplitMerge then
      if entry == output then
        local outs = {}
        for _, d in ipairs(dirs) do if d ~= output then outs[#outs + 1] = d end end
        return outs
      end
    elseif entry ~= output then return { output } end
  elseif tile.type == "bridge" then
    if entry == "N" then return { "S" } end
    if entry == "S" then return { "N" } end
    if entry == "W" then return { "E" } end
    if entry == "E" then return { "W" } end
  elseif tile.type == "schema_in" then
    if rules and rules.reverseFlow then
      if entry == "C" then return { dirs[r + 1] } end
      return {}
    end
    if entry == dirs[r + 1] and schemaPairComplete(tile.pair) then return { "C" } end
  elseif tile.type == "schema_out" then
    if rules and rules.reverseFlow then
      if entry == dirs[r + 1] and schemaPairComplete(tile.pair) then return { "C" } end
      return {}
    end
    if entry == "C" then return { dirs[r + 1] } end
  elseif tile.type == "backdoor" then
    if entry ~= "C" then return { "C" } end
  end
  return {}
end

function M.segments(tile, rules)
  local r = tile.rotation % 4
  if tile.type == "straight" then
    return r % 2 == 0 and { { "N", "S" } } or { { "E", "W" } }
  elseif tile.type == "corner" then
    return { { dirs[r + 1], dirs[(r + 1) % 4 + 1] } }
  elseif tile.type == "splitter" then
    local input, segments = dirs[r + 1], {}
    for _, d in ipairs(dirs) do if d ~= input then segments[#segments + 1] = rules and rules.swapSplitMerge and { d, input } or { input, d } end end
    return segments
  elseif tile.type == "merger" then
    local output, segments = dirs[r + 1], {}
    for _, d in ipairs(dirs) do if d ~= output then segments[#segments + 1] = rules and rules.swapSplitMerge and { output, d } or { d, output } end end
    return segments
  elseif tile.type == "bridge" then
    return { { "N", "S" }, { "W", "E" } }
  elseif tile.type == "schema" or tile.type == "schema_in" then
    return rules and rules.reverseFlow and { { "C", dirs[r + 1] } } or { { dirs[r + 1], "C" } }
  elseif tile.type == "schema_out" then
    return rules and rules.reverseFlow and { { dirs[r + 1], "C" } } or { { "C", dirs[r + 1] } }
  elseif tile.type == "backdoor" then
    return { { "N", "C" }, { "E", "C" }, { "S", "C" }, { "W", "C" } }
  end
  return {}
end

function M.ports(tile, rules)
  local r = tile.rotation % 4
  if tile.type == "splitter" then
    local input, outputs = dirs[r + 1], {}
    for _, d in ipairs(dirs) do if d ~= input then outputs[#outputs + 1] = d end end
    if rules and rules.swapSplitMerge then return outputs, { input } end
    return { input }, outputs
  elseif tile.type == "merger" then
    local output, inputs = dirs[r + 1], {}
    for _, d in ipairs(dirs) do if d ~= output then inputs[#inputs + 1] = d end end
    if rules and rules.swapSplitMerge then return { output }, inputs end
    return inputs, { output }
  elseif tile.type == "schema" or tile.type == "schema_in" then
    return rules and rules.reverseFlow and { "C" } or { dirs[r + 1] }, rules and rules.reverseFlow and { dirs[r + 1] } or { "C" }
  elseif tile.type == "schema_out" then
    return rules and rules.reverseFlow and { dirs[r + 1] } or { "C" }, rules and rules.reverseFlow and { "C" } or { dirs[r + 1] }
  elseif tile.type == "backdoor" then
    return dirs, { "C" }
  end
  return {}, {}
end

function M.baseSegments(typeName, rules)
  if typeName == "straight" then return { { "N", "S" } } end
  if typeName == "corner" then return { { "N", "E" } } end
  if typeName == "splitter" then return rules and rules.swapSplitMerge and { { "E", "N" }, { "S", "N" }, { "W", "N" } } or { { "N", "E" }, { "N", "S" }, { "N", "W" } } end
  if typeName == "merger" then return rules and rules.swapSplitMerge and { { "N", "E" }, { "N", "S" }, { "N", "W" } } or { { "E", "N" }, { "S", "N" }, { "W", "N" } } end
  if typeName == "bridge" then return { { "N", "S" }, { "W", "E" } } end
  if typeName == "schema" or typeName == "schema_in" then return rules and rules.reverseFlow and { { "C", "N" } } or { { "N", "C" } } end
  if typeName == "schema_out" then return rules and rules.reverseFlow and { { "N", "C" } } or { { "C", "N" } } end
  if typeName == "backdoor" then return { { "N", "C" }, { "E", "C" }, { "S", "C" }, { "W", "C" } } end
  return {}
end

function M.basePorts(typeName, rules)
  if typeName == "splitter" then return rules and rules.swapSplitMerge and { "E", "S", "W" } or { "N" }, rules and rules.swapSplitMerge and { "N" } or { "E", "S", "W" } end
  if typeName == "merger" then return rules and rules.swapSplitMerge and { "N" } or { "E", "S", "W" }, rules and rules.swapSplitMerge and { "E", "S", "W" } or { "N" } end
  if typeName == "schema" or typeName == "schema_in" then return rules and rules.reverseFlow and { "C" } or { "N" }, rules and rules.reverseFlow and { "N" } or { "C" } end
  if typeName == "schema_out" then return rules and rules.reverseFlow and { "N" } or { "C" }, rules and rules.reverseFlow and { "C" } or { "N" } end
  if typeName == "backdoor" then return dirs, { "C" } end
  return {}, {}
end

function M.label(tile)
  if tile.type == "schema_in" then return "I" end
  if tile.type == "schema_out" then return "O" end
  if tile.type == "schema" then return "Y" end
  if tile.type == "backdoor" then return "D" end
  return tile.type:sub(1, 1):upper()
end

function M.color(tile, colors)
  if tile.type == "splitter" then return colors.splitter end
  if tile.type == "merger" then return colors.merger end
  if tile.type == "schema_in" or tile.type == "schema_out" or tile.type == "schema" then return colors.schema end
  return colors.tile
end

return M
