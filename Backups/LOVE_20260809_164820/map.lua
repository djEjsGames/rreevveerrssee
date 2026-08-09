local mapmod = {}

local function carve_room(ctx, room)
	for y = room.y, room.y + room.h - 1 do
		for x = room.x, room.x + room.w - 1 do
			ctx.map[y][x] = 0
		end
	end
end

local function carve_tile(ctx, x, y)
	if ctx.map[y] and ctx.map[y][x] ~= nil then ctx.map[y][x] = 0 end
end

local function carve_wide_tile(ctx, x, y, axis, width)
	local first = -math.floor((width - 1) / 2)
	for offset = first, first + width - 1 do
		if axis == "x" then
			carve_tile(ctx, x, y + offset)
		else
			carve_tile(ctx, x + offset, y)
		end
	end
end

local function carve_hall(ctx, a, b)
	local width = math.random(2, 3)
	for x = math.min(a.x, b.x), math.max(a.x, b.x) do carve_wide_tile(ctx, x, a.y, "x", width) end
	for y = math.min(a.y, b.y), math.max(a.y, b.y) do carve_wide_tile(ctx, b.x, y, "y", width) end
end

local function block_tile(ctx, x, y)
	if ctx.map[y] and ctx.map[y][x] ~= nil then ctx.map[y][x] = 1 end
end

local function fill_room(ctx, room)
	for y = room.y, room.y + room.h - 1 do
		for x = room.x, room.x + room.w - 1 do block_tile(ctx, x, y) end
	end
end

local function carve_center_layout(ctx, room)
	local cx, cy = room.x + math.floor(room.w / 2), room.y + math.floor(room.h / 2)
	fill_room(ctx, room)
	local rooms = {
		{ x = cx - 4, y = cy - 4, w = 8, h = 8 },
		{ x = cx - 4, y = room.y + 2, w = 8, h = 6 },
		{ x = cx - 4, y = room.y + room.h - 8, w = 8, h = 6 },
		{ x = room.x + 2, y = cy - 4, w = 7, h = 8 },
		{ x = room.x + room.w - 9, y = cy - 4, w = 7, h = 8 },
		{ x = room.x + 3, y = room.y + 3, w = 6, h = 6 },
		{ x = room.x + room.w - 9, y = room.y + 3, w = 6, h = 6 },
		{ x = room.x + 3, y = room.y + room.h - 9, w = 6, h = 6 },
		{ x = room.x + room.w - 9, y = room.y + room.h - 9, w = 6, h = 6 },
	}
	for _, r in ipairs(rooms) do carve_room(ctx, r) end
	for _, r in ipairs(rooms) do
		carve_hall(ctx, { x = cx, y = cy }, { x = r.x + math.floor(r.w / 2), y = r.y + math.floor(r.h / 2) })
	end
end

function mapmod.tile_of(ctx, x, y)
	return math.floor(x / ctx.TILE) + 1, math.floor(y / ctx.TILE) + 1
end

function mapmod.tile_center(ctx, tx, ty)
	return { x = (tx - 0.5) * ctx.TILE, y = (ty - 0.5) * ctx.TILE }
end

function mapmod.wall_tile_at(ctx, tx, ty)
	return not ctx.map[ty] or ctx.map[ty][tx] ~= 0
end

function mapmod.wall_at(ctx, px, py)
	local x, y = mapmod.tile_of(ctx, px, py)
	return mapmod.wall_tile_at(ctx, x, y)
end

function mapmod.random_floor_point(ctx)
	for _ = 1, 200 do
		local x, y = math.random(2, ctx.MAP_W - 1), math.random(2, ctx.MAP_H - 1)
		if ctx.map[y] and ctx.map[y][x] == 0 then
			return { x = (x - 0.5) * ctx.TILE, y = (y - 0.5) * ctx.TILE }
		end
	end
	return { x = ctx.player.x, y = ctx.player.y }
end

function mapmod.random_room_point(ctx)
	for _ = 1, 200 do
		local room = ctx.rooms[math.random(#ctx.rooms)]
		local x = math.random(room.x + 1, room.x + room.w - 2)
		local y = math.random(room.y + 1, room.y + room.h - 2)
		if ctx.map[y] and ctx.map[y][x] == 0 then
			return { x = (x - 0.5) * ctx.TILE, y = (y - 0.5) * ctx.TILE }
		end
	end
	return mapmod.random_floor_point(ctx)
end

function mapmod.cube_blocks_tile(ctx, tx, ty)
	local center = mapmod.tile_center(ctx, tx, ty)
	for _, cube in ipairs(ctx.cubes) do
		local dist = ((center.x - cube.x) ^ 2 + (center.y - cube.y) ^ 2) ^ 0.5
		if dist < cube.r + 11 then return true end
	end
	return false
end

function mapmod.blocked_tile_at(ctx, tx, ty)
	return mapmod.wall_tile_at(ctx, tx, ty) or mapmod.cube_blocks_tile(ctx, tx, ty)
end

local function tile_key(tx, ty)
	return tx .. "," .. ty
end

function mapmod.find_path(ctx, from_x, from_y, to_x, to_y)
	local sx, sy = mapmod.tile_of(ctx, from_x, from_y)
	local gx, gy = mapmod.tile_of(ctx, to_x, to_y)
	if mapmod.blocked_tile_at(ctx, gx, gy) then return {} end

	local open = { { x = sx, y = sy, g = 0, f = math.abs(gx - sx) + math.abs(gy - sy) } }
	local came_from, best_g, closed = {}, { [tile_key(sx, sy)] = 0 }, {}

	while #open > 0 do
		local best = 1
		for i = 2, #open do
			if open[i].f < open[best].f then best = i end
		end
		local current = table.remove(open, best)
		local current_key = tile_key(current.x, current.y)
		if current.x == gx and current.y == gy then
			local path = {}
			while current_key do
				local x, y = current_key:match("^(%-?%d+),(%-?%d+)$")
				path[#path + 1] = mapmod.tile_center(ctx, tonumber(x), tonumber(y))
				current_key = came_from[current_key]
			end
			local reversed = {}
			for i = #path - 1, 1, -1 do reversed[#reversed + 1] = path[i] end
			return reversed
		end

		closed[current_key] = true
		for _, step in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local nx, ny = current.x + step[1], current.y + step[2]
			local key = tile_key(nx, ny)
			if not closed[key] and not mapmod.blocked_tile_at(ctx, nx, ny) then
				local g = current.g + 1
				if not best_g[key] or g < best_g[key] then
					best_g[key] = g
					came_from[key] = current_key
					open[#open + 1] = { x = nx, y = ny, g = g, f = g + math.abs(gx - nx) + math.abs(gy - ny) }
				end
			end
		end
	end
	return {}
end

function mapmod.cast_ray_from(ctx, ox, oy, angle, max_dist)
	local hit_x, hit_y = ox, oy
	for dist = 0, max_dist, 6 do
		local x = ox + math.cos(angle) * dist
		local y = oy + math.sin(angle) * dist
		if mapmod.wall_at(ctx, x, y) then return hit_x, hit_y end
		hit_x, hit_y = x, y
	end
	return hit_x, hit_y
end

function mapmod.cast_ray(ctx, angle, max_dist)
	return mapmod.cast_ray_from(ctx, ctx.player.x, ctx.player.y, angle, max_dist)
end

function mapmod.generate(ctx)
	ctx.seed = os.time()
	math.randomseed(ctx.seed)
	ctx.map, ctx.rooms = {}, {}

	for y = 1, ctx.MAP_H do
		ctx.map[y] = {}
		for x = 1, ctx.MAP_W do ctx.map[y][x] = 1 end
	end

	local center = { id = 5, x = 31, y = 18, w = 30, h = 30, template = "center" }
	ctx.rooms[5] = center
	carve_center_layout(ctx, center)

	local function make_room(id, gx, gy, template)
		local size = 12 + math.random(0, 3)
		local center_x = gx < 0 and 16 or gx > 0 and 76 or 46
		local center_y = gy < 0 and 8 or gy > 0 and 56 or 33
		local room = {
			id = id,
			x = math.max(2, math.min(ctx.MAP_W - size - 1, center_x - math.floor(size / 2))),
			y = math.max(2, math.min(ctx.MAP_H - size - 1, center_y - math.floor(size / 2))),
			w = size,
			h = size,
			template = template,
		}
		ctx.rooms[id] = room
		carve_room(ctx, room)
	end

	make_room(1, -1, -1, "corner")
	make_room(2, 0, -1, "cardinal")
	make_room(3, 1, -1, "corner")
	make_room(4, -1, 0, "cardinal")
	make_room(6, 1, 0, "cardinal")
	make_room(7, -1, 1, "corner")
	make_room(8, 0, 1, "cardinal")
	make_room(9, 1, 1, "corner")

	for _, id in ipairs({ 1, 2, 3, 4, 6, 7, 8, 9 }) do
		local room = ctx.rooms[id]
		carve_hall(ctx, { x = center.x + math.floor(center.w / 2), y = center.y + math.floor(center.h / 2) }, { x = room.x + math.floor(room.w / 2), y = room.y + math.floor(room.h / 2) })
	end

	ctx.player.x = (ctx.rooms[5].x + math.floor(ctx.rooms[5].w / 2)) * ctx.TILE
	ctx.player.y = (ctx.rooms[5].y + math.floor(ctx.rooms[5].h / 2)) * ctx.TILE
end

return mapmod
