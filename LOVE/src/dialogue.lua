local M = {}

local state = nil

local function clone(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, item in pairs(v) do out[k] = clone(item) end
  return out
end

local function textOf(script, value)
  if not value then return "" end
  return (script.text and script.text[value]) or value
end

local function motionOf(value)
  if type(value) == "table" then return value end
  return { type = value or "none" }
end

local function applyActorLine(actor, line)
  if line.pos then actor.pos = line.pos end
  if line.flip ~= nil then actor.flip = line.flip end
  if line.emotion and line.emotion ~= actor.emotion then
    actor.anim = { time = 0, duration = line.flipDuration or 0.28, from = actor.emotion, to = line.emotion }
    actor.emotion = line.emotion
  end
  actor.motion = motionOf(line.motion)
end

local function actorCue(cue, fallbackActor)
  if type(cue) == "table" then return cue end
  if cue == true then return { actor = fallbackActor } end
  return { actor = cue or fallbackActor }
end

local function startTransition(actor, kind, cue)
  cue = actorCue(cue)
  local side = cue.from or cue.to or "left"
  local distance = cue.distance or 260
  local offset = side == "right" and distance or -distance
  actor.visible = true
  actor.transition = {
    kind = kind,
    time = 0,
    duration = cue.duration or 0.35,
    fromX = kind == "enter" and offset or 0,
    toX = kind == "enter" and 0 or offset,
    fromAlpha = kind == "enter" and 0 or (actor.alpha or 1),
    toAlpha = kind == "enter" and 1 or (cue.toAlpha or 0),
    hideWhenDone = kind == "exit",
  }
end

local function enterLine(api)
  local script, line = state.script, state.line()
  if not line then state.done = true; return end
  state.lineTime, state.pendingSkip = 0, 0
  if line.enter then
    local cue = actorCue(line.enter, line.actor)
    if cue.actor and state.actors[cue.actor] then startTransition(state.actors[cue.actor], "enter", cue) end
  end
  if line.exit then
    local cue = actorCue(line.exit, line.actor)
    if cue.actor and state.actors[cue.actor] then startTransition(state.actors[cue.actor], "exit", cue) end
  end
  if line.fade then
    local cue = actorCue(line.fade, line.actor)
    if cue.actor and state.actors[cue.actor] then
      local actor = state.actors[cue.actor]
      actor.visible = true
      actor.transition = { kind = "fade", time = 0, duration = cue.duration or 0.35, fromX = 0, toX = 0, fromAlpha = actor.alpha or 1, toAlpha = cue.to or 1 }
    end
  end
  if line.actor and state.actors[line.actor] then
    local actor = state.actors[line.actor]
    state.z = state.z + 1
    actor.z = state.z
    applyActorLine(actor, line)
    state.backlog[#state.backlog + 1] = { name = actor.name, text = textOf(script, line.text) }
  end
  if line.sfx and api and api.playSfx then api.playSfx(line.sfx, line.sfxVolume or 0.8) end
  if line.bgm and api and api.bgm then api.bgm(line.bgm) end
end

function M.start(script, api)
  local actors = clone(script.actors or {})
  local z = 0
  for _, actor in pairs(actors) do
    z = z + 1
    actor.z = z
    actor.motion = motionOf(actor.motion)
    actor.alpha = actor.visible == false and 0 or 1
  end
  state = {
    script = script,
    actors = actors,
    index = 1,
    z = z,
    lineTime = 0,
    pendingSkip = 0,
    backlog = {},
    done = false,
  }
  function state.line() return state.script.lines[state.index] end
  if script.bgm and api and api.bgm then api.bgm(script.bgm) end
  enterLine(api)
end

function M.active()
  return state and not state.done
end

function M.current()
  if not M.active() then return nil end
  local line = state.line()
  return line and {
    actor = line.actor,
    actorData = state.actors[line.actor],
    text = textOf(state.script, line.text),
    bubble = line.bubble or "default",
  }
end

function M.actors()
  if not state then return {} end
  local list = {}
  for id, actor in pairs(state.actors) do
    local item = clone(actor)
    item.id = id
    list[#list + 1] = item
  end
  table.sort(list, function(a, b) return (a.z or 0) < (b.z or 0) end)
  return list
end

function M.backlog()
  return state and state.backlog or {}
end

function M.next(api)
  if not M.active() then return false end
  state.index = state.index + 1
  if state.index > #state.script.lines then state.done = true; return false end
  enterLine(api)
  return true
end

function M.update(dt, api)
  if not M.active() then return end
  state.lineTime = state.lineTime + dt
  for _, actor in pairs(state.actors) do
    if actor.transition then
      actor.transition.time = math.min(actor.transition.duration, actor.transition.time + dt)
      local tr = actor.transition
      local t = tr.duration > 0 and tr.time / tr.duration or 1
      actor.alpha = tr.fromAlpha + (tr.toAlpha - tr.fromAlpha) * t
      actor.offsetX = tr.fromX + (tr.toX - tr.fromX) * t
      if t >= 1 then
        actor.visible = not tr.hideWhenDone
        actor.alpha = tr.toAlpha
        actor.offsetX = tr.toX
        actor.transition = nil
      end
    end
    if actor.anim then
      actor.anim.time = math.min(actor.anim.duration, actor.anim.time + dt)
      if actor.anim.time >= actor.anim.duration then actor.anim = nil end
    end
  end
  local line = state.line()
  if line and line.wait and state.lineTime >= line.wait then M.next(api) end
  if api and api.skipDown and api.skipDown() then
    state.pendingSkip = state.pendingSkip + dt
    if state.pendingSkip >= 0.04 then
      state.pendingSkip = 0
      M.next(api)
    end
  end
end

function M.finish()
  state = nil
end

return M
