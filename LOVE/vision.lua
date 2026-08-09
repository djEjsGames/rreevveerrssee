local map = require("map")

local vision = {}

local function angle_diff(a, b)
	return (a - b + math.pi) % (math.pi * 2) - math.pi
end

function vision.visible(ctx, x, y)
	local profile = ctx.profiles[ctx.player.profile]
	local sight = profile.sight + (ctx.player.sight_bonus or 0)
	local fov = profile.fov + (ctx.player.fov_bonus or 0)
	local dx, dy = x - ctx.player.x, y - ctx.player.y
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist <= profile.near then
		local hit_x, hit_y = map.cast_ray(ctx, math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx), dist)
		return ((hit_x - ctx.player.x) ^ 2 + (hit_y - ctx.player.y) ^ 2) ^ 0.5 >= dist - 8
	end
	if dist > sight then return false end
	local angle = math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)
	if math.abs(angle_diff(angle, ctx.player.aim)) > fov / 2 then return false end
	local hit_x, hit_y = map.cast_ray(ctx, angle, dist)
	return ((hit_x - ctx.player.x) ^ 2 + (hit_y - ctx.player.y) ^ 2) ^ 0.5 >= dist - 8
end

function vision.visible_from(ctx, viewer, x, y, sight, fov)
	local dx, dy = x - viewer.x, y - viewer.y
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist > sight then return false end
	local angle = math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)
	if math.abs(angle_diff(angle, viewer.aim or 0)) > fov / 2 then return false end
	local hit_x, hit_y = map.cast_ray_from(ctx, viewer.x, viewer.y, angle, dist)
	return ((hit_x - viewer.x) ^ 2 + (hit_y - viewer.y) ^ 2) ^ 0.5 >= dist - 8
end

function vision.update_alpha(ctx, list, dt)
	local speed = ctx.fade_modes[ctx.settings.fade_mode].speed
	for _, item in ipairs(list) do
		local target = (item.done or item.used or vision.visible(ctx, item.x, item.y)) and 1 or 0
		item.alpha = speed and item.alpha + (target - item.alpha) * math.min(1, dt * speed) or target
	end
end

function vision.sight_polygon(ctx)
	local profile = ctx.profiles[ctx.player.profile]
	local sight = profile.sight + (ctx.player.sight_bonus or 0)
	local fov = profile.fov + (ctx.player.fov_bonus or 0)
	local points = { ctx.player.x, ctx.player.y }
	for i = 0, profile.rays do
		local angle = ctx.player.aim - fov / 2 + fov * i / profile.rays
		local x, y = map.cast_ray(ctx, angle, sight)
		points[#points + 1] = x
		points[#points + 1] = y
	end
	return points
end

function vision.near_sight_polygon(ctx)
	local profile = ctx.profiles[ctx.player.profile]
	local points = { ctx.player.x, ctx.player.y }
	for i = 0, 72 do
		local angle = math.pi * 2 * i / 72
		local x, y = map.cast_ray(ctx, angle, profile.near)
		points[#points + 1] = x
		points[#points + 1] = y
	end
	return points
end

function vision.body_sight_polygon(ctx, body, sight, fov, rays)
	local points = { body.x, body.y }
	for i = 0, rays do
		local angle = (body.aim or 0) - fov / 2 + fov * i / rays
		local x, y = map.cast_ray_from(ctx, body.x, body.y, angle, sight)
		points[#points + 1] = x
		points[#points + 1] = y
	end
	return points
end

return vision
