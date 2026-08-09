local effects = require("effects")
local entities = require("entities")
local map = require("map")
local movement = require("movement")
local ui = require("ui")
local vision = require("vision")

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local TAU = math.pi * 2

local function angle_diff(from, to)
	return (to - from + math.pi) % TAU - math.pi
end

local ctx = {
	W = 1280,
	H = 720,
	TILE = 32,
	MAP_W = 270,
	MAP_H = 192,
	map = {},
	rooms = {},
	objectives = {},
	traps = {},
	mobs = {},
	cubes = {},
	supplies = {},
	objective_pings = {},
	ice_tiles = {},
	ice_by_key = {},
	seija = nil,
	afterimages = {},
	seed = 0,
	camera = { x = 0, y = 0 },
	screen_fx = { sx = 1, sy = 1, rot = 0, flash = 0, label = "" },
	view_basis = { sx = 1, sy = 1, rot = 0 },
	control_fx = { sx = 1, sy = 1, time = 0, duration = 0, label = "" },
	minimap_fx = { map = { rot = 0, sx = 1, sy = 1 } },
	minimap_interference_timer = 20,
	sagume_location_timer = 30,
	sagume_call_cd = 0,
	supply_interval = 60,
	supply_lifetime = 60,
	supply_ping_duration = 8,
	supply_timer = 60,
	time_limit = 180,
	time_left = 180,
	move_sound_timer = 0,
	help_popup = 0,
	full_map_open = false,
	debug_npc_map = false,
	briefing_menu = nil,
	status_popup = { text = "", time = 3, duration = 3 },
	last_status_text = "",
	drunk_fx = nil,
	suika_event = nil,
	fade_modes = {
		{ name = "slow", speed = 10 },
		{ name = "normal", speed = 20 },
		{ name = "fast", speed = 35 },
		{ name = "instant", speed = nil },
	},
	settings = { fade_mode = 2, distort_mode = "swirl" },
	profiles = {
		{ name = "Scout", speed = 460, sight = 300, near = 78, fov = math.rad(95), rays = 96 },
		{ name = "Operator", speed = 420, sight = 360, near = 68, fov = math.rad(70), rays = 84 },
		{ name = "Runner", speed = 540, sight = 230, near = 86, fov = math.rad(55), rays = 64 },
	},
	player = { x = 64, y = 64, r = 12, aim = 0, aim_turn = 12, profile = 1, dash_cd = 0, dash = nil, groggy = 0, sight_bonus = 0, fov_bonus = 0, speed_bonus = 0 },
	state = { done = false, result = "", prompt = "WASD: move  Mouse: aim  Space: step dash  R: new map" },
	briefing = nil,
	interference = nil,
	briefing_i = 0,
	interference_i = 0,
	question_i = 0,
	doremi_i = 0,
	briefing_lines = {
		{ speaker = "Sagume", text = "..." },
		{ speaker = "Sagume", text = "내 지시를 반대로 이해하고 움직여야 해" },
		{ speaker = "Sagume", text = "좀 더 서두르도록" },
		{ speaker = "Doremi", text = "사구메가 말한 내용은 반대로 받아들이면 돼." },
		{ speaker = "Doremi", text = "침착하게 위치를 다시 확인해." },
		{ speaker = "Doremi", text = "이건 꿈이 아니니까 조심해." },
	},
	interference_lines = {
		"방해하려고? 시시하네~",
		"이거나 먹어라!",
	},
}
ctx.VIEW_W = ctx.W * 0.8
ctx.PANEL_X = ctx.VIEW_W

local function reset_run()
	ctx.objectives, ctx.traps, ctx.mobs, ctx.cubes, ctx.supplies, ctx.afterimages = {}, {}, {}, {}, {}, {}
	ctx.objective_pings = {}
	ctx.ice_tiles, ctx.ice_by_key = {}, {}
	ctx.seija = nil
	ctx.screen_fx = { sx = 1, sy = 1, rot = 0, flash = 0, label = "" }
	ctx.view_basis = { sx = 1, sy = 1, rot = 0 }
	ctx.control_fx = { sx = 1, sy = 1, time = 0, duration = 0, label = "" }
	ctx.minimap_fx = { map = { rot = 0, sx = 1, sy = 1 } }
	ctx.minimap_interference_timer = 20
	ctx.sagume_location_timer = 30
	ctx.sagume_call_cd = 0
	ctx.supply_interval = 60
	ctx.supply_lifetime = 60
	ctx.supply_ping_duration = 8
	ctx.supply_timer = 1
	ctx.time_limit = 180
	ctx.time_left = ctx.time_limit
	ctx.move_sound_timer = 0
	ctx.help_popup = 0
	ctx.full_map_open = false
	ctx.debug_npc_map = false
	ctx.briefing_menu = nil
	ctx.status_popup = { text = "", time = 3, duration = 3 }
	ctx.last_status_text = ""
	ctx.suika_event = nil
	ctx.briefing = nil
	ctx.briefings = {}
	ctx.player.groggy = 0
	ctx.player.slide, ctx.player.last_move = nil, nil
	ctx.player.sight_bonus, ctx.player.fov_bonus, ctx.player.speed_bonus = 0, 0, 0
	ctx.player.kind = math.random(2) == 1 and "ringo" or "seiran"
	ctx.state = { done = false, result = "", prompt = "WASD: move  Mouse: aim  Space: step dash  R: new map" }
	map.generate(ctx)
	entities.populate(ctx)
end

local function sagume_say(text)
	ctx.sagume_location_timer = 30
	ui.start_briefing(ctx, ({ "left", "top", "corner" })[ctx.briefing_i % 3 + 1], text)
end

local function doremi_say(text)
	ctx.sagume_location_timer = 30
	ui.start_briefing(ctx, "top", text, "Doremi")
end

local function direction_from_player(x, y)
	local dx, dy = x - ctx.player.x, y - ctx.player.y
	local ax, ay = math.abs(dx), math.abs(dy)
	if ax > ay * 2 then return dx > 0 and "east" or "west" end
	if ay > ax * 2 then return dy > 0 and "south" or "north" end
	return (dy > 0 and "south" or "north") .. "_" .. (dx > 0 and "east" or "west")
end

local function opposite_direction(dir)
	return ({
		east = "west", west = "east", north = "south", south = "north",
		north_east = "south_west", north_west = "south_east",
		south_east = "north_west", south_west = "north_east",
	})[dir]
end

local function direction_name(dir)
	return ({
		east = "동쪽", west = "서쪽", north = "북쪽", south = "남쪽",
		north_east = "동북쪽", north_west = "서북쪽",
		south_east = "동남쪽", south_west = "서남쪽",
		center = "중앙",
	})[dir]
end

local function room_direction_at(x, y)
	for id, room in pairs(ctx.rooms) do
		if x >= room.x * ctx.TILE and x < (room.x + room.w) * ctx.TILE
			and y >= room.y * ctx.TILE and y < (room.y + room.h) * ctx.TILE then
			local dir = ({
				[1] = "north_west", [2] = "north", [3] = "north_east",
				[4] = "west", [5] = "center", [6] = "east",
				[7] = "south_west", [8] = "south", [9] = "south_east",
			})[id]
			return dir or direction_from_player(x, y)
		end
	end
	return direction_from_player(x, y)
end

local function spoken_player_direction(x, y)
	return direction_name(opposite_direction(direction_from_player(x, y)))
end

local function actual_player_direction(x, y)
	return direction_name(direction_from_player(x, y))
end

local function spoken_room_direction(x, y)
	local dir = room_direction_at(x, y)
	return direction_name(dir == "center" and dir or opposite_direction(dir))
end

local function actual_room_direction(x, y)
	return direction_name(room_direction_at(x, y))
end

local function seija_player_line()
	if not ctx.seija then return "..." end
	return ("세이자는 네 위치를 기준으로 %s에 있어"):format(spoken_player_direction(ctx.seija.x, ctx.seija.y))
end

local function seija_room_line()
	if not ctx.seija then return "..." end
	return ("세이자는 %s 방향의 방에 있어"):format(spoken_room_direction(ctx.seija.x, ctx.seija.y))
end

local function nearest_supply()
	local best, best_dist = nil, math.huge
	for _, supply in ipairs(ctx.supplies) do
		if not supply.fake then
			local dist = (supply.x - ctx.player.x) ^ 2 + (supply.y - ctx.player.y) ^ 2
			if dist < best_dist then best, best_dist = supply, dist end
		end
	end
	return best
end

local function reveal_supplies()
	for _, supply in ipairs(ctx.supplies) do
		supply.ping_time = ctx.supply_ping_duration
	end
end

local function supply_player_line()
	local supply = nearest_supply()
	if not supply then return "보급품은 없어" end
	reveal_supplies()
	return ("보급품은 네 위치를 기준으로 %s에 있어"):format(spoken_player_direction(supply.x, supply.y))
end

local function supply_room_line()
	local supply = nearest_supply()
	if not supply then return "보급품은 없어" end
	reveal_supplies()
	return ("보급품은 %s 방향의 방에 있어"):format(spoken_room_direction(supply.x, supply.y))
end

local function objective_line()
	local choices = {}
	for _, objective in ipairs(ctx.objectives) do
		if not objective.done then choices[#choices + 1] = objective end
	end
	if #choices == 0 then return "확인할 목표는 없어" end
	local objective = choices[math.random(#choices)]
	ctx.objective_pings[#ctx.objective_pings + 1] = { objective = objective, time = 8, duration = 8 }
	return ("%s 목표는 %s 방향의 방에 있어"):format(objective.name, spoken_room_direction(objective.x, objective.y))
end

local function trigger_sagume_default_briefing()
	ctx.briefing_i = ctx.briefing_i % #ctx.briefing_lines + 1
	local line = ctx.briefing_lines[ctx.briefing_i]
	if line.speaker == "Doremi" then
		doremi_say(line.text)
	else
		sagume_say(line.text)
	end
end

local function ask_sagume()
	ctx.question_i = ctx.question_i % 5 + 1
	local lines = { objective_line, seija_player_line, seija_room_line, supply_player_line, supply_room_line }
	sagume_say(lines[ctx.question_i]())
end

local function ask_doremi()
	if not ctx.seija then return end
	ctx.doremi_i = ctx.doremi_i % 6 + 1
	local target = "세이자"
	local lines = {
		function() return ("%s는 %s 방향의 방에 있어"):format(target, actual_room_direction(ctx.seija.x, ctx.seija.y)) end,
		function() return ("사구메가 %s는 %s 방향의 방에 있대"):format(target, spoken_room_direction(ctx.seija.x, ctx.seija.y)) end,
		function() return ("사구메가 말한걸 해석하면 %s는 %s 방향의 방에 있을거야"):format(target, actual_room_direction(ctx.seija.x, ctx.seija.y)) end,
		function() return ("%s는 네 위치를 기준으로 %s에 있어"):format(target, actual_player_direction(ctx.seija.x, ctx.seija.y)) end,
		function() return ("사구메가 %s는 네 위치를 기준으로 %s에 있대"):format(target, spoken_player_direction(ctx.seija.x, ctx.seija.y)) end,
		function() return ("사구메가 말한걸 해석하면 %s는 네 위치를 기준으로 %s에 있을거야"):format(target, actual_player_direction(ctx.seija.x, ctx.seija.y)) end,
	}
	doremi_say(lines[ctx.doremi_i]())
end

local function ask_briefing()
	if ctx.sagume_call_cd > 0 then
		ctx.state.prompt = ("Briefing cooldown %.1fs"):format(ctx.sagume_call_cd)
		return
	end
	ctx.sagume_call_cd = 3
	ask_sagume()
end

local function request_briefing(kind)
	if ctx.sagume_call_cd > 0 then
		ctx.state.prompt = ("Briefing cooldown %.1fs"):format(ctx.sagume_call_cd)
		return
	end
	ctx.sagume_call_cd = 3
	if kind == "objective" then
		sagume_say(objective_line())
	elseif kind == "supply" then
		sagume_say(supply_room_line())
	elseif kind == "seija" then
		sagume_say(seija_room_line())
	end
end

local function screen_to_world(x, y, basis)
	basis = basis or ctx.view_basis
	local cx, cy = ctx.VIEW_W / 2, ctx.H / 2
	x, y = x - cx, y - cy
	local c, s = math.cos(-(basis.rot or 0)), math.sin(-(basis.rot or 0))
	x, y = x * c - y * s, x * s + y * c
	x, y = x / basis.sx, y / basis.sy
	x, y = x + cx, y + cy
	return x + ctx.camera.x, y + ctx.camera.y
end

local function screen_input(dx, dy)
	local basis = ctx.view_basis
	dx, dy = dx * ctx.control_fx.sx, dy * ctx.control_fx.sy
	local c, s = math.cos(-(basis.rot or 0)), math.sin(-(basis.rot or 0))
	dx, dy = dx * c - dy * s, dx * s + dy * c
	return dx / basis.sx, dy / basis.sy
end

local function world_to_screen(x, y)
	local sx, sy = x - ctx.camera.x, y - ctx.camera.y
	local cx, cy = ctx.VIEW_W / 2, ctx.H / 2
	sx, sy = sx - cx, sy - cy
	sx, sy = sx * ctx.screen_fx.sx, sy * ctx.screen_fx.sy
	local c, s = math.cos(ctx.screen_fx.rot or 0), math.sin(ctx.screen_fx.rot or 0)
	sx, sy = sx * c - sy * s, sx * s + sy * c
	return sx + cx, sy + cy
end

local function draw_upright_at(x, y, draw)
	local fx = ctx.screen_fx
	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.scale(fx.sx < 0 and -1 or 1, fx.sy < 0 and -1 or 1)
	love.graphics.rotate(-(fx.rot or 0))
	love.graphics.translate(-x, -y)
	draw()
	love.graphics.pop()
end

local function draw_wall_tile(tx, ty)
	local x, y, t = (tx - 1) * ctx.TILE, (ty - 1) * ctx.TILE, ctx.TILE
	love.graphics.setColor(0.12, 0.12, 0.14)
	love.graphics.rectangle("fill", x, y, t, t)
	love.graphics.setColor(0.22, 0.22, 0.25)
	love.graphics.rectangle("fill", x, y + 2, t, t * 0.62)
	love.graphics.setColor(0.15, 0.15, 0.18)
	love.graphics.rectangle("fill", x, y + t * 0.62, t, t * 0.38)
	love.graphics.setColor(0.08, 0.08, 0.1, 0.7)
	love.graphics.line(x, y + t * 0.62, x + t, y + t * 0.62)
end

local function draw_standing_actor(actor, color, alpha, aim, accent)
	local x, y, r = actor.x, actor.y, actor.r or 12
	alpha = alpha or 1
	accent = accent or { 0.05, 0.055, 0.065 }
	love.graphics.setColor(0, 0, 0, 0.32 * alpha)
	love.graphics.ellipse("fill", x, y + r * 0.35, r * 1.05, r * 0.38)
	if actor.image then
		local scale = (r * 4.2) / actor.image:getHeight()
		love.graphics.setColor(1, 1, 1, alpha)
		love.graphics.draw(actor.image, x, y + r * 0.6, 0, scale, scale, actor.image:getWidth() / 2, actor.image:getHeight())
		if aim then
			love.graphics.setColor(1, 0.95, 0.55, 0.7 * alpha)
			love.graphics.line(x, y - r * 1.35, x + math.cos(aim) * 34, y - r * 1.35 + math.sin(aim) * 34)
		end
		return
	end
	love.graphics.setColor(color[1] * 0.58, color[2] * 0.58, color[3] * 0.58, alpha)
	love.graphics.rectangle("fill", x - r * 0.48, y - r * 0.28, r * 0.36, r * 0.95, 2, 2)
	love.graphics.rectangle("fill", x + r * 0.12, y - r * 0.28, r * 0.36, r * 0.95, 2, 2)
	love.graphics.setColor(color[1], color[2], color[3], alpha)
	love.graphics.ellipse("fill", x, y - r * 0.88, r * 0.78, r * 1.08)
	love.graphics.setColor(accent[1], accent[2], accent[3], alpha)
	love.graphics.ellipse("line", x, y - r * 0.88, r * 0.78, r * 1.08)
	love.graphics.setColor(color[1] * 1.08, color[2] * 1.08, color[3] * 1.08, alpha)
	love.graphics.circle("fill", x, y - r * 2.02, r * 0.62)
	love.graphics.setColor(accent[1], accent[2], accent[3], alpha)
	love.graphics.circle("line", x, y - r * 2.02, r * 0.62)
	love.graphics.circle("fill", x - r * 0.23, y - r * 2.08, 2)
	love.graphics.circle("fill", x + r * 0.23, y - r * 2.08, 2)
	if aim then
		love.graphics.setColor(1, 0.95, 0.55, 0.7 * alpha)
		love.graphics.line(x, y - r * 1.35, x + math.cos(aim) * 34, y - r * 1.35 + math.sin(aim) * 34)
	end
end

local function status_text()
	return ctx.state.result ~= "" and ctx.state.result or ctx.state.prompt
end

local function update_status_popup(dt)
	local text = status_text()
	if text ~= ctx.last_status_text then
		ctx.last_status_text = text
		ctx.status_popup = { text = text, time = 0, duration = 3 }
	else
		ctx.status_popup.time = math.min(ctx.status_popup.duration, ctx.status_popup.time + dt)
	end
end

local function draw_status_popup()
	local popup = ctx.status_popup
	if popup.time >= popup.duration or popup.text == "" then return end
	local t = popup.time / popup.duration
	local alpha = math.min(1, math.min(t / 0.18, (1 - t) / 0.28))
	local font = love.graphics.getFont()
	local w = font:getWidth(popup.text) + 34
	local x, y = (ctx.VIEW_W - w) / 2, ctx.H * 0.68
	love.graphics.setColor(0.04, 0.045, 0.05, 0.78 * alpha)
	love.graphics.rectangle("fill", x, y, w, 36, 6, 6)
	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.print(popup.text, x + 17, y + 10)
end

local function draw_timer()
	local time_left = math.ceil(ctx.time_left or 0)
	local text = ("TIME %02d:%02d"):format(math.floor(time_left / 60), time_left % 60)
	local font = love.graphics.getFont()
	local w = font:getWidth(text)
	love.graphics.setColor(0.04, 0.045, 0.05, 0.72)
	love.graphics.rectangle("fill", (ctx.VIEW_W - w) / 2 - 14, 14, w + 28, 32, 6, 6)
	love.graphics.setColor(time_left <= 30 and 1 or 0.95, time_left <= 30 and 0.35 or 0.95, time_left <= 30 and 0.28 or 0.9)
	love.graphics.print(text, (ctx.VIEW_W - w) / 2, 23)
end

local function draw_supply_trackers()
	local margin = 24
	local function draw_tracker(x, y, color, shape)
		local sx, sy = world_to_screen(x, y)
		if sx < 0 or sx > ctx.VIEW_W or sy < 0 or sy > ctx.H then
			local cx, cy = ctx.VIEW_W / 2, ctx.H / 2
			local dx, dy = sx - cx, sy - cy
			local scale = math.min(
				dx ~= 0 and (dx > 0 and (ctx.VIEW_W - margin - cx) / dx or (margin - cx) / dx) or math.huge,
				dy ~= 0 and (dy > 0 and (ctx.H - margin - cy) / dy or (margin - cy) / dy) or math.huge
			)
			local x, y = cx + dx * scale, cy + dy * scale
			local angle = math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)
			love.graphics.setColor(color[1], color[2], color[3], 0.9)
			if shape == "box" then love.graphics.rectangle("line", x - 9, y - 9, 18, 18) else love.graphics.circle("line", x, y, 11) end
			love.graphics.polygon("fill",
				x + math.cos(angle) * 14, y + math.sin(angle) * 14,
				x + math.cos(angle + 2.35) * 8, y + math.sin(angle + 2.35) * 8,
				x + math.cos(angle - 2.35) * 8, y + math.sin(angle - 2.35) * 8
			)
		end
	end
	for _, supply in ipairs(ctx.supplies) do
		if (supply.ping_time or 0) > 0 then
		draw_tracker(supply.x, supply.y, supply.color)
		end
	end
	for _, ping in ipairs(ctx.objective_pings) do
		local objective = ping.objective
		draw_tracker(objective.x, objective.y, objective.color, "box")
	end
end

function love.load()
	love.window.setMode(ctx.W, ctx.H)
	effects.load(ctx)
	ui.load(ctx)
	reset_run()
end

function love.update(dt)
	if not ctx.state.cleared and ctx.state.result == "" then
		ctx.time_left = math.max(0, ctx.time_left - dt)
		if ctx.time_left == 0 then
			ctx.state.result = "Time over. Press R for a new map."
		end
	end
	ctx.player.dash_cd = math.max(0, ctx.player.dash_cd - dt)
	ctx.move_sound_timer = math.max(0, ctx.move_sound_timer - dt)
	ctx.sagume_call_cd = math.max(0, ctx.sagume_call_cd - dt)
	ctx.help_popup = math.max(0, ctx.help_popup - dt)
	effects.update_control_fx(ctx, dt)
	local dx, dy = movement.input()
	dx, dy = screen_input(dx, dy)
	local input_len = math.sqrt(dx * dx + dy * dy)
	local tx, ty = map.tile_of(ctx, ctx.player.x, ctx.player.y)
	local on_ice = ctx.ice_by_key[tx .. "," .. ty] ~= nil
	if on_ice then
		if not ctx.player.slide then
			if ctx.player.last_move then
				ctx.player.slide = { x = ctx.player.last_move.x, y = ctx.player.last_move.y }
			elseif input_len > 0 then
				ctx.player.slide = { x = dx / input_len, y = dy / input_len }
			end
		end
	elseif input_len > 0 then
		ctx.player.last_move = { x = dx / input_len, y = dy / input_len }
		ctx.player.slide = nil
	else
		ctx.player.slide = nil
	end
	local moving = false
	if entities.update_suika_event(ctx, dt) then
		ctx.player.dash = nil
	elseif ctx.player.groggy > 0 then
		ctx.player.dash = nil
		ctx.player.groggy = math.max(0, ctx.player.groggy - dt)
		if ctx.player.groggy == 0 then effects.start_drunk_fx(ctx) end
	else
		if movement.update_dash(ctx, dt) then
			moving = true
		elseif on_ice and ctx.player.slide then
			moving = movement.move_player(ctx, ctx.player.slide.x, ctx.player.slide.y, (ctx.profiles[ctx.player.profile].speed + ctx.player.speed_bonus) * 0.75 * dt)
			if not moving then ctx.player.slide = nil end
		else
			moving = movement.move_player(ctx, dx, dy, (ctx.profiles[ctx.player.profile].speed + ctx.player.speed_bonus) * dt)
		end
	end
	if moving and ctx.move_sound_timer == 0 then
		effects.play_sound(ctx, "move")
		ctx.move_sound_timer = 0.3
	end

	effects.update_afterimages(ctx, dt)
	movement.update_cubes(ctx, dt)
	vision.update_alpha(ctx, ctx.objectives, dt)
	for i = #ctx.objective_pings, 1, -1 do
		ctx.objective_pings[i].time = ctx.objective_pings[i].time - dt
		if ctx.objective_pings[i].time <= 0 then table.remove(ctx.objective_pings, i) end
	end
	vision.update_alpha(ctx, ctx.mobs, dt)
	vision.update_alpha(ctx, ctx.cubes, dt)
	vision.update_alpha(ctx, ctx.supplies, dt)
	if ctx.seija then vision.update_alpha(ctx, { ctx.seija }, dt) end
	entities.update_traps(ctx, dt)
	entities.update_supplies(ctx, dt)
	entities.update_mobs(ctx, dt)
	entities.update_ice(ctx, dt)
	entities.update_seija(ctx, dt)
	effects.update_screen_fx(ctx, dt)
	effects.update_drunk_fx(ctx, dt)
	effects.update_dark_fx(ctx, dt)
	entities.update_objectives(ctx)
	ui.update_briefing(ctx, dt)
	ui.update_interference(ctx, dt)
	ui.update_minimap_fx(ctx, dt)
	ctx.minimap_interference_timer = ctx.minimap_interference_timer - dt
	if ctx.minimap_interference_timer <= 0 then
		ui.trigger_minimap_interference(ctx)
	end
	ctx.sagume_location_timer = ctx.sagume_location_timer - dt
	if ctx.sagume_location_timer <= 0 then
		ctx.sagume_location_timer = 30
		trigger_sagume_default_briefing()
	end
	update_status_popup(dt)

	ctx.camera.x = math.max(0, math.min(ctx.player.x - ctx.VIEW_W / 2, ctx.MAP_W * ctx.TILE - ctx.VIEW_W))
	ctx.camera.y = math.max(0, math.min(ctx.player.y - ctx.H / 2, ctx.MAP_H * ctx.TILE - ctx.H))
	local mx, my = love.mouse.getPosition()
	mx = math.min(mx, ctx.VIEW_W)
	mx, my = effects.diag_flip_to_canvas(ctx, mx, my)
	local wx, wy = screen_to_world(mx, my)
	local target_aim = atan2(wy - ctx.player.y, wx - ctx.player.x)
	ctx.player.aim = ctx.player.aim + angle_diff(ctx.player.aim, target_aim) * math.min(1, ctx.player.aim_turn * dt)
end

function love.keypressed(key)
	if key == "space" and not ctx.suika_event and ctx.player.groggy == 0 then movement.start_dash(ctx, screen_input(movement.input())) end
	if key == "b" then
		ask_briefing()
	end
	if key == "n" then
		ui.trigger_minimap_interference(ctx)
	end
	if key == "g" then ctx.settings.distort_mode = ctx.settings.distort_mode == "wave" and "swirl" or "wave" end
	if key == "v" then ctx.settings.fade_mode = ctx.settings.fade_mode % #ctx.fade_modes + 1 end
	if key == "r" then reset_run() end
	if key == "h" then ctx.help_popup = 5 end
	if key == "tab" then ctx.full_map_open = not ctx.full_map_open end
	if key == "z" then
		ctx.debug_npc_map = not ctx.debug_npc_map
		ctx.full_map_open = ctx.debug_npc_map or ctx.full_map_open
	end
end

function love.mousepressed(x, y, button)
	if button == 2 and x <= ctx.VIEW_W then
		ctx.briefing_menu = {
			x = math.max(190, math.min(ctx.VIEW_W - 190, x)),
			y = math.max(190, math.min(ctx.H - 190, y)),
		}
	end
end

function love.mousereleased(x, y, button)
	if button == 2 and ctx.briefing_menu then
		local choice = ui.briefing_menu_choice(ctx, x, y)
		ctx.briefing_menu = nil
		if choice then request_briefing(choice) end
	end
end

function love.draw()
	love.graphics.clear(0.06, 0.065, 0.07)
	effects.begin_world_canvas(ctx)
	love.graphics.setScissor(0, 0, ctx.VIEW_W, ctx.H)
	love.graphics.push()
	effects.apply_screen_fx(ctx)
	love.graphics.translate(-ctx.camera.x, -ctx.camera.y)

	local first_x = math.max(1, math.floor(ctx.camera.x / ctx.TILE) + 1)
	local last_x = math.min(ctx.MAP_W, math.floor((ctx.camera.x + ctx.VIEW_W) / ctx.TILE) + 2)
	local first_y = math.max(1, math.floor(ctx.camera.y / ctx.TILE) + 1)
	local last_y = math.min(ctx.MAP_H, math.floor((ctx.camera.y + ctx.H) / ctx.TILE) + 2)
	for y = first_y, last_y do
		for x = first_x, last_x do
			if ctx.map[y][x] == 1 then
				draw_wall_tile(x, y)
			end
		end
	end

	love.graphics.setColor(1, 0.95, 0.55, 0.22)
	love.graphics.polygon("fill", vision.sight_polygon(ctx))
	love.graphics.setColor(1, 0.95, 0.55, 0.12)
	love.graphics.polygon("fill", vision.near_sight_polygon(ctx))

	for _, ice in ipairs(ctx.ice_tiles) do
		local alpha = math.min(0.5, ice.time / 2 * 0.5) * math.min(1, (ice.age or 0) / 0.1)
		love.graphics.setColor(0.42, 0.86, 1.0, alpha)
		love.graphics.rectangle("fill", (ice.tx - 1) * ctx.TILE, (ice.ty - 1) * ctx.TILE, ctx.TILE, ctx.TILE)
		love.graphics.setColor(0.72, 0.95, 1.0, alpha)
		love.graphics.rectangle("line", (ice.tx - 1) * ctx.TILE + 2, (ice.ty - 1) * ctx.TILE + 2, ctx.TILE - 4, ctx.TILE - 4)
	end

	for _, objective in ipairs(ctx.objectives) do
		if objective.alpha > 0.02 then
			love.graphics.setColor(objective.color[1], objective.color[2], objective.color[3], objective.done and objective.alpha * 0.35 or objective.alpha)
			love.graphics.circle("line", objective.x, objective.y, 24)
			love.graphics.circle("fill", objective.x, objective.y, 7)
		end
	end

	for _, trap in ipairs(ctx.traps) do
		if trap.alpha > 0.02 then
			love.graphics.setColor(1, 0.35, 0.12, trap.alpha)
			love.graphics.circle("line", trap.x, trap.y, 18)
			love.graphics.line(trap.x - 12, trap.y - 12, trap.x + 12, trap.y + 12)
			love.graphics.line(trap.x + 12, trap.y - 12, trap.x - 12, trap.y + 12)
		end
	end

	for _, cube in ipairs(ctx.cubes) do
		if cube.alpha > 0.02 then
			love.graphics.setColor(0.62, 0.66, 0.7, cube.alpha)
			love.graphics.rectangle("fill", cube.x - cube.r, cube.y - cube.r, cube.r * 2, cube.r * 2)
			love.graphics.setColor(0.18, 0.2, 0.22, cube.alpha)
			love.graphics.rectangle("line", cube.x - cube.r, cube.y - cube.r, cube.r * 2, cube.r * 2)
		end
	end

	for _, supply in ipairs(ctx.supplies) do
		if supply.alpha > 0.02 then
			draw_upright_at(supply.x, supply.y, function()
				love.graphics.setColor(supply.color[1], supply.color[2], supply.color[3], supply.alpha)
				love.graphics.circle("fill", supply.x, supply.y, 10)
				love.graphics.setColor(0.05, 0.05, 0.06, supply.alpha)
				love.graphics.print(supply.icon, supply.x - 5, supply.y - 8)
			end)
		end
	end

	if ctx.seija and ctx.seija.alpha > 0.02 then
		love.graphics.setColor(0.95, 0.55, 1.0, ctx.seija.alpha * 0.14)
		love.graphics.polygon("fill", vision.body_sight_polygon(ctx, ctx.seija, ctx.seija.sight, ctx.seija.fov, 48))
	end

	for _, image in ipairs(ctx.afterimages) do
		love.graphics.setColor(0.35, 0.72, 0.95, image.t / 0.16 * 0.35)
		love.graphics.circle("fill", image.x, image.y, ctx.player.r)
	end

	local actors = {}
	for _, mob in ipairs(ctx.mobs) do
		if mob.alpha > 0.02 then
			table.insert(actors, {
				y = mob.y,
				draw = function()
					draw_upright_at(mob.x, mob.y, function()
						mob.image = ctx.actor_images and ctx.actor_images[mob.type]
						draw_standing_actor(mob, mob.color, mob.alpha, nil, { 0.12, 0.08, 0.04 })
					end)
				end,
			})
		end
	end
	if ctx.seija and ctx.seija.alpha > 0.02 then
		table.insert(actors, {
			y = ctx.seija.y,
			draw = function()
				draw_upright_at(ctx.seija.x, ctx.seija.y, function()
					ctx.seija.image = ctx.actor_images and ctx.actor_images.seija
					draw_standing_actor(ctx.seija, { 0.95, 0.55, 1.0 }, ctx.seija.alpha, nil, { 0.18, 0.08, 0.22 })
				end)
			end,
		})
	end
	table.insert(actors, {
		y = ctx.player.y,
		draw = function()
			draw_upright_at(ctx.player.x, ctx.player.y, function()
				ctx.player.image = ctx.actor_images and ctx.actor_images[ctx.player.kind]
				draw_standing_actor(ctx.player, { 0.35, 0.72, 0.95 }, 1, ctx.player.aim)
				if ctx.control_fx.time > 0 then
					local pulse = 0.5 + 0.5 * math.sin(ctx.control_fx.time * 10)
					love.graphics.setColor(1, 0.3, 0.25, 0.35 + pulse * 0.25)
					love.graphics.circle("line", ctx.player.x, ctx.player.y, ctx.player.r + 8 + pulse * 4)
					if ctx.control_fx.sx < 0 then love.graphics.line(ctx.player.x - 20, ctx.player.y, ctx.player.x + 20, ctx.player.y) end
					if ctx.control_fx.sy < 0 then love.graphics.line(ctx.player.x, ctx.player.y - 20, ctx.player.x, ctx.player.y + 20) end
				end
			end)
		end,
	})
	table.sort(actors, function(a, b) return a.y < b.y end)
	for _, actor in ipairs(actors) do actor.draw() end
	love.graphics.pop()
	love.graphics.setScissor()
	effects.end_world_canvas(ctx)

	if ctx.screen_fx.flash > 0 then
		love.graphics.setColor(1, 0.35, 0.12, ctx.screen_fx.flash * 0.45)
		love.graphics.rectangle("line", 8, 8, ctx.VIEW_W - 16, ctx.H - 16)
		love.graphics.setColor(1, 0.55, 0.24, ctx.screen_fx.flash)
		love.graphics.print(ctx.screen_fx.label, 24, 132)
	end
	effects.draw_drunk_overlay(ctx)
	effects.draw_dark_overlay(ctx)
	ui.draw_order_panel(ctx)
	ui.draw_full_map_overlay(ctx)
	ui.draw_briefing(ctx)
	ui.draw_interference(ctx)
	ui.draw_briefing_menu(ctx)
	ui.draw_help_popup(ctx)
	draw_supply_trackers()
	draw_timer()
	love.graphics.setColor(0.8, 0.82, 0.84)
	love.graphics.print(("Seed: %d"):format(ctx.seed), 16, ctx.H - 28)
	draw_status_popup()
	love.graphics.setColor(1, 1, 1)
end
