local effects = require("effects")
local map = require("map")

local movement = {}

local function circle_hits_tile(ctx, px, py, radius, tx, ty)
	local left, top = (tx - 1) * ctx.TILE, (ty - 1) * ctx.TILE
	local nearest_x = math.max(left, math.min(px, left + ctx.TILE))
	local nearest_y = math.max(top, math.min(py, top + ctx.TILE))
	return (px - nearest_x) ^ 2 + (py - nearest_y) ^ 2 < radius ^ 2
end

function movement.hit_cube(ctx, px, py, radius, ignore)
	for _, cube in ipairs(ctx.cubes) do
		if cube ~= ignore then
			local dist = ((px - cube.x) ^ 2 + (py - cube.y) ^ 2) ^ 0.5
			if dist < radius + cube.r then return cube end
		end
	end
	return nil
end

function movement.blocked_at(ctx, px, py, radius, ignore)
	local min_x = math.floor((px - radius) / ctx.TILE) + 1
	local max_x = math.floor((px + radius) / ctx.TILE) + 1
	local min_y = math.floor((py - radius) / ctx.TILE) + 1
	local max_y = math.floor((py + radius) / ctx.TILE) + 1
	for ty = min_y, max_y do
		for tx = min_x, max_x do
			if map.wall_tile_at(ctx, tx, ty) and circle_hits_tile(ctx, px, py, radius, tx, ty) then return true end
		end
	end
	return movement.hit_cube(ctx, px, py, radius, ignore) ~= nil
end

function movement.move_circle_by(ctx, body, dx, dy)
	local radius = body.r or 11
	local nx, ny = body.x + dx, body.y + dy
	if not movement.blocked_at(ctx, nx, ny, radius, body) then
		body.x, body.y = nx, ny
		return true
	end
	local moved = false
	if not movement.blocked_at(ctx, nx, body.y, radius, body) then body.x = nx moved = true end
	if not movement.blocked_at(ctx, body.x, ny, radius, body) then body.y = ny moved = true end
	return moved
end

function movement.clear_mob_paths(ctx)
	for _, mob in ipairs(ctx.mobs) do
		mob.path = {}
		mob.path_i = 1
	end
end

local function move_player_by(ctx, dx, dy)
	local player = ctx.player
	local cube = movement.hit_cube(ctx, player.x + dx, player.y + dy, player.r)
	if cube then
		if cube.push_cd == 0 and not cube.move then
			local rel_x, rel_y = cube.x - player.x, cube.y - player.y
			local step_x, step_y = 0, 0
			if math.abs(rel_x) > math.abs(rel_y) and dx * rel_x > 0 then
				step_x = rel_x > 0 and ctx.TILE or -ctx.TILE
			elseif math.abs(rel_y) >= math.abs(rel_x) and dy * rel_y > 0 then
				step_y = rel_y > 0 and ctx.TILE or -ctx.TILE
			end
			if (step_x ~= 0 or step_y ~= 0) and not movement.blocked_at(ctx, cube.x + step_x, cube.y + step_y, cube.r, cube) then
				cube.move = { from_x = cube.x, from_y = cube.y, to_x = cube.x + step_x, to_y = cube.y + step_y, time = 0, duration = 0.5 }
				cube.push_cd = 0.5
				movement.clear_mob_paths(ctx)
			end
		end
		return false
	end
	return movement.move_circle_by(ctx, player, dx, dy)
end

function movement.move_body(ctx, body, dx, dy, distance)
	local len = math.sqrt(dx * dx + dy * dy)
	if len == 0 then return false end
	dx, dy = dx / len, dy / len
	for _ = 1, math.ceil(distance / 8) do
		local step = math.min(8, distance)
		if not movement.move_circle_by(ctx, body, dx * step, dy * step) then return false end
		distance = distance - step
	end
	return true
end

function movement.move_player(ctx, dx, dy, distance)
	local len = math.sqrt(dx * dx + dy * dy)
	if len == 0 then return false end
	dx, dy = dx / len, dy / len
	for _ = 1, math.ceil(distance / 8) do
		local step = math.min(8, distance)
		if not move_player_by(ctx, dx * step, dy * step) then return false end
		distance = distance - step
	end
	return true
end

function movement.input()
	return (love.keyboard.isDown("d") and 1 or 0) - (love.keyboard.isDown("a") and 1 or 0),
		(love.keyboard.isDown("s") and 1 or 0) - (love.keyboard.isDown("w") and 1 or 0)
end

function movement.start_dash(ctx, dx, dy)
	if ctx.player.dash_cd > 0 then return end
	if not dx or not dy then dx, dy = movement.input() end
	local len = math.sqrt(dx * dx + dy * dy)
	if len == 0 then return end
	ctx.player.dash = { x = dx / len, y = dy / len, time = 0, last = 0, duration = 0.3, distance = 116 }
	ctx.player.dash_cd = 0.42
end

function movement.update_dash(ctx, dt)
	local dash = ctx.player.dash
	if not dash then return false end
	dash.time = math.min(dash.duration, dash.time + dt)
	local now = effects.out_quint(dash.time / dash.duration)
	if not movement.move_player(ctx, dash.x, dash.y, (now - dash.last) * dash.distance) then
		ctx.player.dash = nil
		return true
	end
	ctx.afterimages[#ctx.afterimages + 1] = { x = ctx.player.x, y = ctx.player.y, t = 0.16 }
	dash.last = now
	if dash.time >= dash.duration then ctx.player.dash = nil end
	return true
end

function movement.update_cubes(ctx, dt)
	for _, cube in ipairs(ctx.cubes) do
		cube.push_cd = math.max(0, cube.push_cd - dt)
		if cube.move then
			local move = cube.move
			move.time = math.min(move.duration, move.time + dt)
			local t = effects.in_out_quint(move.time / move.duration)
			cube.x = move.from_x + (move.to_x - move.from_x) * t
			cube.y = move.from_y + (move.to_y - move.from_y) * t
			if move.time >= move.duration then
				cube.x, cube.y, cube.move = move.to_x, move.to_y, nil
			end
		end
	end
end

return movement
