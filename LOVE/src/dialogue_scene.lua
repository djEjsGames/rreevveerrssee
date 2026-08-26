local dialogue = require("src.dialogue")

local M = {}
local env = {}
local backlogOpen = false
local focus = {}

function M.configure(options)
  env = options or {}
end

local function api()
  return {
    playSfx = env.playSfx,
    bgm = env.bgm,
    skipDown = env.skipDown,
  }
end

function M.loadPortraitPcg()
  if not (love.graphics.newImage and love.filesystem and love.filesystem.getDirectoryItems and env.portraits) then return end
  local base = "assets/Images/PCG"
  for _, file in ipairs(love.filesystem.getDirectoryItems(base)) do
    local stem = file:match("^(.-)%.png$")
    if stem then
      local key = stem:gsub("([a-z])([A-Z])", "%1_%2"):gsub("%W+", "_"):lower()
      pcall(function() env.portraits[key] = love.graphics.newImage(base .. "/" .. file) end)
    end
  end
end

function M.start(script)
  backlogOpen = false
  focus = {}
  dialogue.start(script, api())
end

function M.active()
  return dialogue.active()
end

function M.finish()
  backlogOpen = false
  focus = {}
  dialogue.finish()
end

function M.update(dt)
  dialogue.update(dt, api())
  local line = dialogue.current()
  local speakingActor = line and line.actor
  for _, actor in ipairs(dialogue.actors()) do
    local target = (not speakingActor or actor.id == speakingActor) and 1 or 0
    local value = focus[actor.id]
    if value == nil then value = target end
    local step = math.min(1, dt / 0.1)
    focus[actor.id] = value + (target - value) * step
  end
  if not dialogue.active() then
    M.finish()
    if env.close then env.close() end
  end
end

function M.keypressed(k)
  if k == "return" or k == "kpenter" or k == "space" then
    dialogue.next(api())
  elseif k == "b" then
    backlogOpen = not backlogOpen
  elseif k == "escape" then
    M.finish()
    if env.close then env.close() end
  end
end

local function colors()
  return env.colors or {
    text = { 0.9, 0.92, 0.88 },
    panel = { 0.16, 0.18, 0.19 },
    grid = { 0.22, 0.24, 0.25 },
  }
end

local function actorPosition(actor, screenW, screenH)
  local size = screenH * 0.8
  local y = screenH - size - 18
  if type(actor.pos) == "table" then return actor.pos.x, actor.pos.y, size end
  if actor.pos == "right" then return screenW - size - 88, y, size end
  if actor.pos == "center" then return (screenW - size) * 0.5, y, size end
  return 88, y, size
end

local function actorImage(actor, emotion)
  if not (actor.portrait and env.portraits) then return nil end
  local key = actor.portrait .. "_" .. tostring(emotion or actor.emotion or "normal")
  return env.portraits[key] or env.portraits[actor.portrait]
end

local function motionOffset(actor, t)
  local m = actor.motion or {}
  if m.type == "shake" then return math.sin(t * 46) * (m.power or 7), 0 end
  if m.type == "sway" then return math.sin(t * (m.speed or 5)) * (m.power or 8), 0 end
  if m.type == "totter" then return math.sin(t * (m.speed or 11)) * (m.power or 5), math.abs(math.sin(t * 16)) * -4 end
  return 0, 0
end

local function currentEmotion(actor)
  if actor.anim and actor.anim.time < actor.anim.duration * 0.5 then return actor.anim.from end
  return actor.emotion
end

local function portraitRect(actor, screenW, screenH, t, includeMotion)
  local x, y, size = actorPosition(actor, screenW, screenH)
  local ox, oy = 0, 0
  if includeMotion then ox, oy = motionOffset(actor, t) end
  ox = ox + (actor.offsetX or 0)
  local img = actorImage(actor, currentEmotion(actor))
  if not img then return x + ox, y + oy, size, size, nil end
  local scale = size / math.max(img:getWidth(), img:getHeight())
  local w, h = img:getWidth() * scale, img:getHeight() * scale
  return x + ox + (size - w) * 0.5, y + oy + (size - h) * 0.5, w, h, img
end

local function drawBackground(screenW, screenH)
  local img = env.backgrounds and env.backgrounds.youkaiMountain
  love.graphics.clear(0.06, 0.07, 0.08)
  if img then
    local scale = math.max(screenW / img:getWidth(), screenH / img:getHeight())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, screenW * 0.5, screenH * 0.5, 0, scale, scale, img:getWidth() * 0.5, img:getHeight() * 0.5)
    love.graphics.setColor(0, 0, 0, 0.22)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end
end

local function drawPortrait(actor, screenW, screenH, t)
  if actor.visible == false and not actor.transition then return end
  local x, y, w, h, img = portraitRect(actor, screenW, screenH, t, true)
  local f = focus[actor.id]
  if f == nil then f = 1 end
  local alpha = (actor.alpha or 1) * (0.72 + 0.28 * f)
  local shade = 0.62 + 0.38 * f
  y = y + 30 * (1 - f)
  local sx = actor.flip and -1 or 1
  if actor.anim then
    local p = actor.anim.duration > 0 and actor.anim.time / actor.anim.duration or 1
    sx = sx * math.abs(math.cos(p * math.pi))
  end
  if img then
    local scale = w / img:getWidth()
    love.graphics.setColor(shade, shade, shade, alpha)
    love.graphics.draw(img, x + w * 0.5, y + h * 0.5, 0, sx * scale, scale, img:getWidth() * 0.5, img:getHeight() * 0.5)
  else
    local c = colors()
    love.graphics.setColor(c.panel[1], c.panel[2], c.panel[3], alpha)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(c.text[1], c.text[2], c.text[3], alpha)
    love.graphics.printf(actor.name or actor.id or "?", x, y + h * 0.45, w, "center")
  end
end

local function drawSpeechBubble(line, screenW, screenH)
  if not (line and line.actorData) then return end
  local c = colors()
  local actor = line.actorData
  if actor.visible == false then return end
  local px, py, pw, ph = portraitRect(actor, screenW, screenH, 0, false)
  local font = love.graphics.getFont()
  local w = math.floor(screenW / 3)
  local _, wrapped = font:getWrap(line.text, w - 32)
  local h = math.max(78, #wrapped * font:getHeight() + 48)
  local x = actor.pos == "right" and px - w or px + pw
  x = math.max(20, math.min(screenW - w - 20, x))
  local y = math.max(34, math.min(screenH - h - 44, py + ph * 0.14 - h))
  local border = line.bubble == "shout" and { 1, 0.28, 0.22 } or { 0.36, 0.82, 0.95 }
  local tailSize = 24
  local tailY = y + h
  love.graphics.setColor(0, 0, 0, 0.82)
  if actor.pos == "right" then
    love.graphics.polygon("fill", x + w - tailSize, tailY, x + w, tailY, x + w + tailSize * 0.65, tailY + tailSize)
  else
    love.graphics.polygon("fill", x, tailY, x + tailSize, tailY, x - tailSize * 0.65, tailY + tailSize)
  end
  love.graphics.rectangle("fill", x, y, w, h, 7, 7)
  love.graphics.setColor(border)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 7, 7)
  if actor.pos == "right" then
    love.graphics.line(x + w - tailSize, tailY, x + w + tailSize * 0.65, tailY + tailSize, x + w, tailY)
  else
    love.graphics.line(x, tailY, x - tailSize * 0.65, tailY + tailSize, x + tailSize, tailY)
  end
  love.graphics.setLineWidth(1)
  love.graphics.setColor(c.text)
  love.graphics.print(actor.name or "", x + 16, y + 12)
  love.graphics.printf(line.text, x + 16, y + 34, w - 32, "left")
end

local function drawBacklog(screenW)
  if not backlogOpen then return end
  local c = colors()
  local log = dialogue.backlog()
  local h = math.min(300, 38 + #log * 24)
  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.rectangle("fill", 40, 36, screenW - 80, h, 6, 6)
  love.graphics.setColor(c.grid)
  love.graphics.rectangle("line", 40, 36, screenW - 80, h, 6, 6)
  love.graphics.setColor(c.text)
  local y = 58
  for i = math.max(1, #log - 8), #log do
    local item = log[i]
    love.graphics.printf((item.name or "") .. ": " .. (item.text or ""), 60, y, screenW - 120, "left")
    y = y + 24
  end
end

function M.draw()
  local c = colors()
  local screenW, screenH = love.graphics.getDimensions()
  drawBackground(screenW, screenH)
  local oldFont = love.graphics.getFont()
  if env.font then love.graphics.setFont(env.font()) end
  for _, actor in ipairs(dialogue.actors()) do drawPortrait(actor, screenW, screenH, env.time and env.time() or 0) end
  drawSpeechBubble(dialogue.current(), screenW, screenH)
  drawBacklog(screenW)
  love.graphics.setColor(c.text)
  love.graphics.print("Enter/Space: next   Ctrl: skip   B: backlog   Esc: close", 24, screenH - 32)
  if oldFont then love.graphics.setFont(oldFont) end
end

return M
