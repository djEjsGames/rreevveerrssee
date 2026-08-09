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

local function carve_center_layout(ctx, room)
	carve_room(ctx, room)
end

local function overlaps_room(room, rooms, padding)
	padding = padding or 2
	for _, other in ipairs(rooms) do
		if room.x < other.x + other.w + padding and room.x + room.w + padding > other.x
			and room.y < other.y + other.h + padding and room.y + room.h + padding > other.y then
			return true
		end
	end
	return false
end

local function room_center(room)
	return { x = room.x + math.floor(room.w / 2), y = room.y + math.floor(room.h / 2) }
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

	local mid_x, mid_y = math.floor(ctx.MAP_W / 2), math.floor(ctx.MAP_H / 2)
	local center = { id = 5, x = mid_x - 5, y = mid_y - 5, w = 10, h = 10, template = "center" }
	ctx.rooms[5] = center
	carve_center_layout(ctx, center)

	local function add_room(id, center_x, center_y, w, h, template)
		local room = {
			id = id,
			x = math.max(2, math.min(ctx.MAP_W - w - 1, center_x - math.floor(w / 2))),
			y = math.max(2, math.min(ctx.MAP_H - h - 1, center_y - math.floor(h / 2))),
			w = w,
			h = h,
			template = template,
		}
		ctx.rooms[id] = room
		carve_room(ctx, room)
		return room
	end

	local required = {
		{ 1, 66, 44, 22, 22, "corner" },
		{ 2, mid_x, 34, 18, 18, "cardinal" },
		{ 3, ctx.MAP_W - 66, 44, 22, 22, "corner" },
		{ 4, 62, mid_y, 22, 18, "cardinal" },
		{ 6, ctx.MAP_W - 62, mid_y, 22, 18, "cardinal" },
		{ 7, 66, ctx.MAP_H - 44, 22, 22, "corner" },
		{ 8, mid_x, ctx.MAP_H - 34, 18, 18, "cardinal" },
		{ 9, ctx.MAP_W - 66, ctx.MAP_H - 44, 22, 22, "corner" },
	}
	for _, r in ipairs(required) do
		add_room(r[1], r[2], r[3], r[4] + math.random(0, 4), r[5] + math.random(0, 4), r[6])
	end

	local next_id = 10
	local outer_candidates = {
		{ 26, 24 }, { mid_x, 22 }, { ctx.MAP_W - 26, 24 },
		{ 24, mid_y }, { ctx.MAP_W - 24, mid_y },
		{ 26, ctx.MAP_H - 24 }, { mid_x, ctx.MAP_H - 22 }, { ctx.MAP_W - 26, ctx.MAP_H - 24 },
		{ mid_x, mid_y },
	}
	for i = #outer_candidates, 2, -1 do
		local j = math.random(i)
		outer_candidates[i], outer_candidates[j] = outer_candidates[j], outer_candidates[i]
	end
	local outer_count = math.random(4, 7)
	for i = 1, outer_count do
		local p = outer_candidates[i]
		local w, h = 18 + math.random(0, 8), 18 + math.random(0, 8)
		local room = { x = math.max(2, math.min(ctx.MAP_W - w - 1, p[1] - math.floor(w / 2))), y = math.max(2, math.min(ctx.MAP_H - h - 1, p[2] - math.floor(h / 2))), w = w, h = h }
		if not overlaps_room(room, ctx.rooms, 4) then
			add_room(next_id, p[1], p[2], w, h, "outer")
			next_id = next_id + 1
		end
	end

	for _ = 1, 130 do
		if next_id > 48 then break end
		local w, h = math.random(7, 16), math.random(6, 14)
		local x, y = math.random(34, ctx.MAP_W - 34 - w), math.random(28, ctx.MAP_H - 28 - h)
		local room = { id = next_id, x = x, y = y, w = w, h = h, template = "fill" }
		if not overlaps_room(room, ctx.rooms, 3) then
			ctx.rooms[next_id] = room
			carve_room(ctx, room)
			next_id = next_id + 1
		end
	end

	local connected = { center }
	for _, room in ipairs(ctx.rooms) do
		if room.id ~= 5 then
			local nearest = connected[1]
			local rc = room_center(room)
			local best = math.huge
			for _, other in ipairs(connected) do
				local oc = room_center(other)
				local d = (rc.x - oc.x) ^ 2 + (rc.y - oc.y) ^ 2
				if d < best then
					best, nearest = d, other
				end
			end
			carve_hall(ctx, room_center(nearest), rc)
			connected[#connected + 1] = room
		end
	end

	local links = {}
	for i = 1, #ctx.rooms - 1 do
		for j = i + 1, #ctx.rooms do
			local a, b = ctx.rooms[i], ctx.rooms[j]
			local ac, bc = room_center(a), room_center(b)
			links[#links + 1] = { a = a, b = b, d = (ac.x - bc.x) ^ 2 + (ac.y - bc.y) ^ 2 }
		end
	end
	table.sort(links, function(a, b) return a.d < b.d end)
	for i = 1, math.min(18, #links) do
		carve_hall(ctx, room_center(links[i].a), room_center(links[i].b))
	end

	ctx.player.x = (center.x + math.floor(center.w / 2)) * ctx.TILE
	ctx.player.y = (center.y + math.floor(center.h / 2)) * ctx.TILE
end

return mapmod
