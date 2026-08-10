local effects = require("effects")
local map = require("map")
local movement = require("movement")
local ui = require("ui")
local vision = require("vision")

local entities = {}

local supply_types = {
	{ kind = "sight", icon = "S", color = { 0.25, 0.75, 1.0 } },
	{ kind = "fov", icon = "W", color = { 1.0, 0.82, 0.25 } },
	{ kind = "speed", icon = "M", color = { 0.4, 0.95, 0.45 } },
	{ kind = "unflip", icon = "F", color = { 0.95, 0.55, 1.0 } },
	{ kind = "unrotate", icon = "R", color = { 1.0, 0.58, 0.25 } },
}
local mob_types = {
	{ name = "Suika", type = "suika", color = { 1.0, 0.68, 0.22 }, speed = 160 },
	{ name = "Mystia", type = "mystia", color = { 0.45, 0.55, 1.0 }, speed = 190 },
	{ name = "Rumia", type = "rumia", color = { 0.5, 0.45, 0.62 }, speed = 180 },
	{ name = "Cirno", type = "cirno", color = { 0.35, 0.85, 1.0 }, speed = 200 },
}
local opposite_dir = {
	east = "west", west = "east", north = "south", south = "north",
	north_east = "south_west", north_west = "south_east",
	south_east = "north_west", south_west = "north_east",
}
local dir_names = {
	east = "동쪽", west = "서쪽", north = "북쪽", south = "남쪽",
	north_east = "동북쪽", north_west = "서북쪽",
	south_east = "동남쪽", south_west = "서남쪽",
}

local function add_objective(ctx, room, name, color)
	ctx.objectives[#ctx.objectives + 1] = {
		x = (room.x + math.floor(room.w / 2)) * ctx.TILE + ctx.TILE / 2,
		y = (room.y + math.floor(room.h / 2)) * ctx.TILE + ctx.TILE / 2,
		name = name,
		color = color,
		done = false,
		alpha = 0,
	}
end

local function add_trap(ctx, room, effect)
	ctx.traps[#ctx.traps + 1] = {
		x = (room.x + math.floor(room.w / 2)) * ctx.TILE + ctx.TILE / 2,
		y = (room.y + math.floor(room.h / 2)) * ctx.TILE + ctx.TILE / 2,
		effect = effect,
		alpha = 0,
		used = false,
	}
end

local function add_mob(ctx, info)
	info = info or mob_types[1]
	local start = map.random_floor_point(ctx)
	local points = {}
	for _ = 1, 4 do points[#points + 1] = map.random_floor_point(ctx) end
	ctx.mobs[#ctx.mobs + 1] = {
		x = start.x,
		y = start.y,
		r = 11,
		name = info.name,
		type = info.type,
		color = info.color,
		target = 1,
		points = points,
		path = {},
		path_i = 1,
		speed = info.speed + math.random() * 25,
		effect = math.random(3) == 1 and "flip_x" or math.random(2) == 1 and "flip_y" or "flip_xy",
		cd = 0,
		alpha = 0,
	}
end

local function add_ice(ctx, tx, ty, spread_left)
	if map.wall_tile_at(ctx, tx, ty) then return end
	local key = tx .. "," .. ty
	if ctx.ice_by_key[key] then
		ctx.ice_by_key[key].time = 2
		return
	end
	local ice = { tx = tx, ty = ty, time = 2, age = 0, spread = spread_left and 0.5 or 0, spread_left = spread_left or 0 }
	ctx.ice_by_key[key] = ice
	ctx.ice_tiles[#ctx.ice_tiles + 1] = ice
end

local function spawn_cirno_ice(ctx, mob)
	local tx, ty = map.tile_of(ctx, mob.x, mob.y)
	if tx ~= mob.last_ice_tx or ty ~= mob.last_ice_ty then
		mob.last_ice_tx, mob.last_ice_ty = tx, ty
		add_ice(ctx, tx, ty, 3)
	end
end

local function start_suika_collision(ctx, mob)
	ui.start_briefing(ctx, "top", "한잔 해~", "Suika")
	ctx.suika_event = {
		mob = mob,
		time = 0,
		hold = 2.0,
		duration = 2.0,
		px = ctx.player.x,
		py = ctx.player.y,
		mx = mob.x,
		my = mob.y,
	}
	mob.cd = 1.0
	mob.path = {}
end

local function add_cube(ctx)
	local function snap(point)
		return {
			x = math.floor(point.x / ctx.TILE + 0.5) * ctx.TILE,
			y = math.floor(point.y / ctx.TILE + 0.5) * ctx.TILE,
		}
	end
	local function fits(point)
		local tx, ty = math.floor(point.x / ctx.TILE), math.floor(point.y / ctx.TILE)
		for y = ty, ty + 1 do
			for x = tx, tx + 1 do
				if map.wall_tile_at(ctx, x, y) then return false end
			end
		end
		return true
	end
	local point = snap(map.random_room_point(ctx))
	for _ = 1, 200 do
		local ok = fits(point) and ((point.x - ctx.player.x) ^ 2 + (point.y - ctx.player.y) ^ 2) ^ 0.5 > ctx.TILE * 3
		for _, cube in ipairs(ctx.cubes) do
			if ((point.x - cube.x) ^ 2 + (point.y - cube.y) ^ 2) ^ 0.5 < ctx.TILE * 2 then ok = false break end
		end
		if ok then break end
		point = snap(map.random_room_point(ctx))
	end
	ctx.cubes[#ctx.cubes + 1] = { x = point.x, y = point.y, r = ctx.TILE, alpha = 0, push_cd = 0, move = nil }
end

local function add_supply_item(ctx, point, info)
	ctx.supplies[#ctx.supplies + 1] = {
		x = point.x,
		y = point.y,
		r = 12,
		kind = info.kind,
		icon = info.icon,
		color = info.color,
		alpha = 0,
		time = ctx.supply_lifetime,
		ping_time = 0,
	}
end

local function add_supply(ctx)
	local info = supply_types[math.random(#supply_types)]
	local zones = {
		function() return { x = math.random(2, ctx.MAP_W - 1), y = math.random(2, math.floor(ctx.MAP_H * 0.28)) } end,
		function() return { x = math.random(2, ctx.MAP_W - 1), y = math.random(math.floor(ctx.MAP_H * 0.72), ctx.MAP_H - 1) } end,
		function() return { x = math.random(2, math.floor(ctx.MAP_W * 0.28)), y = math.random(2, ctx.MAP_H - 1) } end,
		function() return { x = math.random(math.floor(ctx.MAP_W * 0.72), ctx.MAP_W - 1), y = math.random(2, ctx.MAP_H - 1) } end,
	}
	local function zone_point(fn)
		for _ = 1, 120 do
			local p = fn()
			local point = { x = (p.x - 0.5) * ctx.TILE, y = (p.y - 0.5) * ctx.TILE }
			if ctx.map[p.y] and ctx.map[p.y][p.x] == 0 then return point end
		end
		return map.random_room_point(ctx)
	end
	for i = #zones, 2, -1 do
		local j = math.random(i)
		zones[i], zones[j] = zones[j], zones[i]
	end
	add_supply_item(ctx, zone_point(zones[1]), info)
	local speaker = ctx.player.kind == "ringo" and "Seiran" or "Ringo"
	ui.start_briefing(ctx, "left", "보급품을 뒀어. 잘 찾아봐.", speaker)
	ctx.sagume_location_timer = 30
	ctx.state.prompt = "Supply dropped."
end

local function add_seija(ctx)
	local start = map.random_floor_point(ctx)
	local points = {}
	for _ = 1, 5 do points[#points + 1] = map.random_floor_point(ctx) end
	ctx.seija = {
		x = start.x,
		y = start.y,
		r = 13,
		target = 1,
		points = points,
		path = {},
		path_i = 1,
		speed = 120,
		aim = 0,
		sight = 280,
		fov = math.rad(75),
		flee_cd = 0,
		alpha = 0,
	}
end

function entities.populate(ctx)
	ctx.objectives, ctx.traps, ctx.mobs, ctx.cubes, ctx.supplies = {}, {}, {}, {}, {}
	ctx.ice_tiles, ctx.ice_by_key = {}, {}
	add_objective(ctx, ctx.rooms[2], "빨강 당고", { 0.92, 0.2, 0.18 })
	add_objective(ctx, ctx.rooms[6], "초록 당고", { 0.35, 0.82, 0.42 })
	add_objective(ctx, ctx.rooms[8], "파랑 당고", { 0.2, 0.55, 0.95 })
	add_trap(ctx, ctx.rooms[1], "flip_x")
	add_trap(ctx, ctx.rooms[3], "flip_xy")
	add_trap(ctx, ctx.rooms[7], "flip_y")
	add_trap(ctx, ctx.rooms[9], "flip_xy")
	for i = 1, 5 do add_mob(ctx, mob_types[(i - 1) % #mob_types + 1]) end
	for _ = 1, 8 do add_cube(ctx) end
	add_seija(ctx)
end

function entities.update_supplies(ctx, dt)
	for i = #ctx.supplies, 1, -1 do
		local supply = ctx.supplies[i]
		supply.time = supply.time - dt
		supply.ping_time = math.max(0, (supply.ping_time or 0) - dt)
		if supply.time <= 0 then
			table.remove(ctx.supplies, i)
			break
		else
		local dist = ((ctx.player.x - supply.x) ^ 2 + (ctx.player.y - supply.y) ^ 2) ^ 0.5
		if dist < ctx.player.r + supply.r then
			if supply.kind == "sight" then
				ctx.player.sight_bonus = ctx.player.sight_bonus + 45
				ctx.state.prompt = "Supply acquired."
			elseif supply.kind == "fov" then
				ctx.player.fov_bonus = ctx.player.fov_bonus + math.rad(8)
				ctx.state.prompt = "Supply acquired."
			elseif supply.kind == "speed" then
				ctx.player.speed_bonus = ctx.player.speed_bonus + 16
				ctx.state.prompt = "Supply acquired."
			elseif supply.kind == "unflip" then
				effects.reset_control_flip(ctx)
				ctx.state.prompt = "Input restored."
			elseif supply.kind == "unrotate" then
				effects.reset_view_rotation(ctx)
				ui.reset_minimap_fx(ctx)
				ctx.state.prompt = "View direction restored."
			end
			table.remove(ctx.supplies, i)
			break
		end
		end
	end
	ctx.supply_timer = ctx.supply_timer - dt
	if ctx.supply_timer <= 0 then
		ctx.supply_timer = ctx.supply_interval
		if #ctx.supplies == 0 then add_supply(ctx) end
	end
end

function entities.update_traps(ctx, dt)
	local profile = ctx.profiles[ctx.player.profile]
	local speed = ctx.fade_modes[ctx.settings.fade_mode].speed
	for _, trap in ipairs(ctx.traps) do
		local dist = ((ctx.player.x - trap.x) ^ 2 + (ctx.player.y - trap.y) ^ 2) ^ 0.5
		local seen = dist < profile.sight / 2 and vision.visible(ctx, trap.x, trap.y)
		local target = (seen or trap.used) and 1 or 0
		trap.alpha = speed and trap.alpha + (target - trap.alpha) * math.min(1, dt * speed) or target
		if not trap.used and dist < 28 then
			trap.used = true
			effects.start_control_flip_fx(ctx)
		end
	end
end

function entities.update_mobs(ctx, dt)
	if ctx.suika_event then return end
	for _, mob in ipairs(ctx.mobs) do
		mob.cd = math.max(0, mob.cd - dt)
		if not mob.path[mob.path_i] then
			local target = mob.points[mob.target]
			mob.path = map.find_path(ctx, mob.x, mob.y, target.x, target.y)
			mob.path_i = 1
			if #mob.path == 0 then mob.points[mob.target] = map.random_floor_point(ctx) end
		end

		local node = mob.path[mob.path_i]
		if node then
			local dx, dy = node.x - mob.x, node.y - mob.y
			if dx * dx + dy * dy < 8 * 8 then
				mob.path_i = mob.path_i + 1
			elseif not movement.move_body(ctx, mob, dx, dy, mob.speed * dt) then
				mob.path = {}
			elseif mob.type == "cirno" then
				spawn_cirno_ice(ctx, mob)
			end
		elseif mob.path_i > #mob.path then
			mob.target = mob.target % #mob.points + 1
			mob.path = {}
		end

		local dist = ((ctx.player.x - mob.x) ^ 2 + (ctx.player.y - mob.y) ^ 2) ^ 0.5
		if mob.cd == 0 and ctx.player.groggy == 0 and dist < ctx.player.r + mob.r then
			if mob.type == "suika" then
				start_suika_collision(ctx, mob)
			elseif mob.type == "mystia" then
				effects.start_night_blind_fx(ctx)
				ui.start_briefing(ctx, "top", "칠성장어가 야맹증에 좋대~", "Mystia")
				mob.cd = 8
			elseif mob.type == "rumia" then
				effects.start_rumia_dark_fx(ctx)
				ui.start_briefing(ctx, "top", "그-런건-가-", "Rumia")
				mob.cd = 8
			end
		end
	end
end

function entities.update_ice(ctx, dt)
	for i = #ctx.ice_tiles, 1, -1 do
		local ice = ctx.ice_tiles[i]
		ice.age = ice.age + dt
		ice.time = ice.time - dt
		if ice.spread_left > 0 then
			ice.spread = ice.spread - dt
			if ice.spread <= 0 then
				local next_spread = ice.spread_left - 1
				ice.spread_left = 0
				for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					add_ice(ctx, ice.tx + d[1], ice.ty + d[2], next_spread)
					add_ice(ctx, ice.tx + d[1] * 2, ice.ty + d[2] * 2, next_spread)
				end
			end
		end
		if ice.time <= 0 then
			ctx.ice_by_key[ice.tx .. "," .. ice.ty] = nil
			table.remove(ctx.ice_tiles, i)
		end
	end
end

function entities.update_suika_event(ctx, dt)
	local event = ctx.suika_event
	if not event then return false end
	event.time = math.min(event.duration, event.time + dt)
	ctx.player.x, ctx.player.y = event.px, event.py
	event.mob.x, event.mob.y = event.mx, event.my
	if event.time >= event.duration then
		event.mob.cd = 2.0
		ctx.player.groggy = 1.0
		ctx.suika_event = nil
	end
	return true
end

function entities.update_seija(ctx, dt)
	local seija = ctx.seija
	if not seija or ctx.state.cleared then return end
	seija.flee_cd = math.max(0, seija.flee_cd - dt)
	if seija.flee_cd == 0 and vision.visible_from(ctx, seija, ctx.player.x, ctx.player.y, seija.sight, seija.fov) then
		local best, best_dist = nil, -1
		for _ = 1, 12 do
			local point = map.random_floor_point(ctx)
			local dist = (point.x - ctx.player.x) ^ 2 + (point.y - ctx.player.y) ^ 2
			if dist > best_dist then best, best_dist = point, dist end
		end
		seija.path = map.find_path(ctx, seija.x, seija.y, best.x, best.y)
		seija.path_i = 1
		seija.flee_cd = 1.0
	end
	if not seija.path[seija.path_i] then
		local target = seija.points[seija.target]
		seija.path = map.find_path(ctx, seija.x, seija.y, target.x, target.y)
		seija.path_i = 1
		if #seija.path == 0 then seija.points[seija.target] = map.random_floor_point(ctx) end
	end

	local node = seija.path[seija.path_i]
	if node then
		local dx, dy = node.x - seija.x, node.y - seija.y
		if dx * dx + dy * dy < 8 * 8 then
			seija.path_i = seija.path_i + 1
		elseif not movement.move_body(ctx, seija, dx, dy, seija.speed * dt) then
			seija.path = {}
		else
			seija.aim = math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)
		end
	elseif seija.path_i > #seija.path then
		seija.target = seija.target % #seija.points + 1
		seija.path = {}
	end

	local dist = ((ctx.player.x - seija.x) ^ 2 + (ctx.player.y - seija.y) ^ 2) ^ 0.5
	if dist < ctx.player.r + seija.r then
		if ctx.state.objectives_done then
			ctx.state.cleared = true
			ctx.state.result = "Seija captured. Press R for a new map."
		else
			ctx.state.prompt = "Complete all orders before capturing Seija."
		end
	end
end

function entities.update_objectives(ctx)
	local complete = true
	for _, objective in ipairs(ctx.objectives) do
		local dist = ((ctx.player.x - objective.x) ^ 2 + (ctx.player.y - objective.y) ^ 2) ^ 0.5
		if dist < 34 then objective.done = true end
		if not objective.done then complete = false end
	end
	ctx.state.objectives_done = complete
	if complete and not ctx.state.done then
		ctx.state.done = true
		ctx.state.prompt = "Orders complete. Capture Seija."
	end
end

return entities
