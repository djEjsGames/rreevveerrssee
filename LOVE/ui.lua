local effects = require("effects")

local ui = {}
local TAU = math.pi * 2
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local briefing_menu_items = {
	{ key = "objective", label = "목표", angle = -math.pi / 2 },
	{ key = "supply", label = "보급", angle = math.pi / 6 },
	{ key = "seija", label = "세이자", angle = math.pi * 5 / 6 },
}
local briefing_menu_inner = 102
local briefing_menu_outer = 184

local function angle_diff(a, b)
	return (b - a + math.pi) % TAU - math.pi
end

local function optional_image(path)
	local ok, image = pcall(love.graphics.newImage, path)
	return ok and image or nil
end

function ui.load(ctx)
	ctx.sagume_image = love.graphics.newImage("Image/Sagume.png")
	ctx.seija_image = love.graphics.newImage("Image/Seija.png")
	ctx.doremi_image = love.graphics.newImage("Image/Doremi.png")
	ctx.actor_images = {
		ringo = optional_image("Image/Ringo.png"),
		seiran = optional_image("Image/Seiran.png"),
		tewi = optional_image("Image/Tewi.png"),
		cirno = optional_image("Image/Cirno.png"),
		suika = optional_image("Image/Suika.png"),
		mystia = optional_image("Image/Mystia.png"),
		rumia = optional_image("Image/Rumia.png"),
		seija = ctx.seija_image,
	}
	ctx.ui_font = love.graphics.newFont("Galmuri11-Bold.ttf", 16)
	love.graphics.setFont(ctx.ui_font)
end

function ui.start_briefing(ctx, preset, text, speaker)
	ctx.briefings = ctx.briefings or {}
	for _, briefing in ipairs(ctx.briefings) do
		briefing.push_from_y = briefing.y
		briefing.push_time = 0
		briefing.push_duration = 0.28
		briefing.target.y = briefing.target.y + 88
	end
	local target = { x = 24, y = 24 }
	local starts = {
		left = { x = -160, y = target.y },
		top = { x = target.x, y = -180 },
		corner = { x = -160, y = -180 },
	}
	table.insert(ctx.briefings, 1, {
		text = text,
		speaker = speaker or "Sagume",
		time = 0,
		duration = 5.0,
		in_time = 0.45,
		out_time = 0.35,
		start = starts[preset] or starts.left,
		target = target,
		x = target.x,
		y = target.y,
	})
	ctx.briefing = ctx.briefings[1]
end

function ui.start_interference(ctx, preset, text)
	local target = { x = ctx.VIEW_W - 136, y = 24 }
	local starts = {
		right = { x = ctx.VIEW_W + 24, y = target.y },
		top = { x = target.x, y = -180 },
		corner = { x = ctx.VIEW_W + 24, y = -180 },
	}
	ctx.interference = {
		text = text,
		time = 0,
		duration = 5.0,
		in_time = 0.45,
		out_time = 0.35,
		start = starts[preset] or starts.right,
		target = target,
		x = target.x,
		y = target.y,
	}
end

function ui.update_briefing(ctx, dt)
	if not ctx.briefings then return end
	for i = #ctx.briefings, 1, -1 do
	local briefing = ctx.briefings[i]
	briefing.time = briefing.time + dt
	if briefing.time < briefing.in_time then
		local t = effects.out_quint(briefing.time / briefing.in_time)
		briefing.x = briefing.start.x + (briefing.target.x - briefing.start.x) * t
		briefing.y = briefing.start.y + (briefing.target.y - briefing.start.y) * t
	elseif briefing.time > briefing.duration - briefing.out_time then
		local t = effects.out_quint((briefing.time - (briefing.duration - briefing.out_time)) / briefing.out_time)
		briefing.x = briefing.target.x + (briefing.start.x - briefing.target.x) * t
		briefing.y = briefing.target.y + (briefing.start.y - briefing.target.y) * t
	else
		briefing.x, briefing.y = briefing.target.x, briefing.target.y
	end
	if briefing.push_time then
		briefing.push_time = math.min(briefing.push_duration, briefing.push_time + dt)
		local t = effects.out_quint(briefing.push_time / briefing.push_duration)
		briefing.y = briefing.push_from_y + (briefing.target.y - briefing.push_from_y) * t
		if briefing.push_time >= briefing.push_duration then briefing.push_time, briefing.push_from_y, briefing.push_duration = nil, nil, nil end
	end
	if briefing.time >= briefing.duration then table.remove(ctx.briefings, i) end
	end
	ctx.briefing = ctx.briefings[1]
end

function ui.update_interference(ctx, dt)
	local event = ctx.interference
	if not event then return end
	event.time = event.time + dt
	if event.time < event.in_time then
		local t = effects.out_quint(event.time / event.in_time)
		event.x = event.start.x + (event.target.x - event.start.x) * t
		event.y = event.start.y + (event.target.y - event.start.y) * t
	elseif event.time > event.duration - event.out_time then
		local t = effects.out_quint((event.time - (event.duration - event.out_time)) / event.out_time)
		event.x = event.target.x + (event.start.x - event.target.x) * t
		event.y = event.target.y + (event.start.y - event.target.y) * t
	else
		event.x, event.y = event.target.x, event.target.y
	end
	if event.time >= event.duration then ctx.interference = nil end
end

local function in_minimap_circle(px, py, cx, cy, radius)
	return (px - cx) ^ 2 + (py - cy) ^ 2 <= radius ^ 2
end

local function apply_minimap_fx(dx, dy, fx)
	local c, s = math.cos(fx.rot or 0), math.sin(fx.rot or 0)
	if fx.diag_scale then
		local dc, ds = math.cos(fx.diag_axis or math.pi / 4), math.sin(fx.diag_axis or math.pi / 4)
		local rx, ry = dx * dc - dy * ds, dx * ds + dy * dc
		rx = rx * fx.diag_scale
		dx, dy = rx * dc + ry * ds, -rx * ds + ry * dc
	end
	dx, dy = dx * (fx.sx or 1), dy * (fx.sy or 1)
	return dx * c - dy * s, dx * s + dy * c
end

local function current_minimap_fx(fx)
	if not fx.time then return fx end
	local t = effects.in_out_quint(math.min(1, fx.time / fx.duration))
	local diag_back = fx.mode == "diag_flip" and fx.time >= fx.duration * 0.5
	return {
		rot = fx.from.rot + (fx.to.rot - fx.from.rot) * t,
		sx = fx.mode == "diag_flip" and (diag_back and fx.to.sx or fx.from.sx) or fx.from.sx + (fx.to.sx - fx.from.sx) * t,
		sy = fx.mode == "diag_flip" and (diag_back and fx.to.sy or fx.from.sy) or fx.from.sy + (fx.to.sy - fx.from.sy) * t,
		mode = fx.mode,
		diag_axis = fx.diag_axis,
	}
end

local function local_minimap_point(ctx, x, y, cx, cy, scale)
	local fx = current_minimap_fx(ctx.minimap_fx.map)
	if ctx.minimap_fx.map.mode == "diag_flip" and ctx.minimap_fx.map.time then
		local t = effects.in_out_quint(math.min(1, ctx.minimap_fx.map.time / ctx.minimap_fx.map.duration))
		fx.diag_scale = math.abs(math.cos(t * math.pi))
	end
	local dx, dy = apply_minimap_fx((x - ctx.player.x) / ctx.TILE * scale, (y - ctx.player.y) / ctx.TILE * scale, fx)
	return cx + dx, cy + dy
end

local function draw_supply_ping(supply, x, y, base)
	local pulse = ((supply.time or 0) * 1.8) % 1
	local r = base + pulse * base * 2.4
	love.graphics.setColor(supply.color[1], supply.color[2], supply.color[3], (1 - pulse) * 0.65)
	love.graphics.circle("line", x, y, r)
	love.graphics.setColor(supply.color[1], supply.color[2], supply.color[3], 0.95)
	love.graphics.circle("fill", x, y, base)
end

function ui.update_minimap_fx(ctx, dt)
	for _, fx in pairs(ctx.minimap_fx) do
		if fx.time then
			fx.time = fx.time + dt
			if fx.time >= fx.duration then
				fx.rot, fx.sx, fx.sy = fx.to.rot, fx.to.sx, fx.to.sy
				fx.diag_axis = fx.to.diag_axis
				fx.time, fx.from, fx.to, fx.duration = nil, nil, nil, nil
			end
		end
	end
end

function ui.trigger_minimap_interference(ctx, forced)
	ctx.minimap_interference_timer = 20
	local rotations = { -2, -1, 1, 2 }
	local flips = { { -1, 1 }, { 1, -1 }, { -1, -1 } }
	local diag_axes = { math.pi / 4, math.pi * 3 / 4, math.pi * 5 / 4, math.pi * 7 / 4 }
	local function random_fx()
		if math.random(2) == 1 then
			return {
				mode = "rotate",
				rot_delta = rotations[math.random(#rotations)] * math.pi / 2,
				sx = nil,
				sy = nil,
			}
		end
		local flip = flips[math.random(#flips)]
		if flip[1] < 0 and flip[2] < 0 then
			return {
				mode = "diag_flip",
				rot = nil,
				flip_xy = true,
				diag_axis = diag_axes[math.random(#diag_axes)],
			}
		end
		return {
			mode = "flip",
			rot = nil,
			sx = flip[1],
			sy = flip[2],
		}
	end
	local function tween_fx(current)
		local target = forced or random_fx()
		target.rot = target.rot or current.rot + (target.rot_delta or 0)
		if target.flip_xy then
			target.sx, target.sy = -current.sx, -current.sy
		end
		if target.mode == "diag_flip" then
			target.diag_axis = target.diag_axis or diag_axes[math.random(#diag_axes)]
		end
		target.sx = target.sx or current.sx
		target.sy = target.sy or current.sy
		return {
			rot = current.rot,
			sx = current.sx,
			sy = current.sy,
			mode = target.mode,
			diag_axis = target.diag_axis,
			from = { rot = current.rot, sx = current.sx, sy = current.sy },
			to = target,
			time = 0,
			duration = 1.0,
		}, target
	end
	local map_fx, target = tween_fx(current_minimap_fx(ctx.minimap_fx.map))
	ctx.minimap_fx = { map = map_fx }
	effects.start_view_interference_fx(ctx, target)
	ctx.interference_i = ctx.interference_i % #ctx.interference_lines + 1
	ui.start_interference(ctx, "corner", ctx.interference_lines[ctx.interference_i])
	effects.play_sound(ctx, "spin")
end

local function draw_minimap(ctx)
	local x, y = ctx.PANEL_X + 20, 24
	local radius = math.min(ctx.W - ctx.PANEL_X - 48, 256) / 2
	local scale = radius / 12
	local cx, cy = x + radius + 4, y + 26 + radius
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("MINIMAP", x, y)
	y = y + 26
	love.graphics.setColor(0.06, 0.065, 0.07)
	love.graphics.circle("fill", cx, cy, radius)
	local minimap_fx = current_minimap_fx(ctx.minimap_fx.map)
	local center_tx = math.floor(ctx.player.x / ctx.TILE) + 1
	local center_ty = math.floor(ctx.player.y / ctx.TILE) + 1
	local tile_radius = math.ceil(radius / scale) + 1
	if ctx.minimap_fx.map.mode == "diag_flip" and ctx.minimap_fx.map.time then
		local t = effects.in_out_quint(math.min(1, ctx.minimap_fx.map.time / ctx.minimap_fx.map.duration))
		minimap_fx.diag_scale = math.abs(math.cos(t * math.pi))
	end
	for ty = center_ty - tile_radius, center_ty + tile_radius do
		for tx = center_tx - tile_radius, center_tx + tile_radius do
			local dx, dy = apply_minimap_fx((tx - center_tx) * scale, (ty - center_ty) * scale, minimap_fx)
			local px, py = cx + dx, cy + dy
			if ctx.map[ty] and ctx.map[ty][tx] == 0 and in_minimap_circle(px, py, cx, cy, radius) then
				love.graphics.setColor(0.26, 0.26, 0.28)
				love.graphics.rectangle("fill", px - scale / 2, py - scale / 2, scale, scale)
			end
		end
	end
	for _, objective in ipairs(ctx.objectives) do
		local px, py = local_minimap_point(ctx, objective.x, objective.y, cx, cy, scale)
		if objective.alpha > 0.02 and in_minimap_circle(px, py, cx, cy, radius) then
			love.graphics.setColor(objective.color[1], objective.color[2], objective.color[3], objective.done and objective.alpha * 0.35 or objective.alpha)
			love.graphics.circle("fill", px, py, 3)
		end
	end
	for _, trap in ipairs(ctx.traps) do
		local px, py = local_minimap_point(ctx, trap.x, trap.y, cx, cy, scale)
		if trap.alpha > 0.02 and in_minimap_circle(px, py, cx, cy, radius) then
			love.graphics.setColor(1, 0.35, 0.12, trap.used and trap.alpha * 0.35 or trap.alpha)
			love.graphics.circle("line", px, py, 3)
		end
	end
	for _, mob in ipairs(ctx.mobs) do
		local px, py = local_minimap_point(ctx, mob.x, mob.y, cx, cy, scale)
		if mob.alpha > 0.02 and in_minimap_circle(px, py, cx, cy, radius) then
			love.graphics.setColor(1, 0.68, 0.22, mob.alpha)
			love.graphics.circle("fill", px, py, 2)
		end
	end
	if ctx.seija then
		local px, py = local_minimap_point(ctx, ctx.seija.x, ctx.seija.y, cx, cy, scale)
		if ctx.seija.alpha > 0.02 and in_minimap_circle(px, py, cx, cy, radius) then
			love.graphics.setColor(0.95, 0.55, 1.0, ctx.seija.alpha)
			love.graphics.circle("fill", px, py, 3)
		end
	end
	for _, cube in ipairs(ctx.cubes) do
		local px, py = local_minimap_point(ctx, cube.x, cube.y, cx, cy, scale)
		if cube.alpha > 0.02 and in_minimap_circle(px, py, cx, cy, radius) then
			love.graphics.setColor(0.62, 0.66, 0.7, cube.alpha)
			love.graphics.rectangle("fill", px - 1.5, py - 1.5, 3, 3)
		end
	end
	for _, supply in ipairs(ctx.supplies) do
		local px, py = local_minimap_point(ctx, supply.x, supply.y, cx, cy, scale)
		if (supply.ping_time or 0) > 0 and in_minimap_circle(px, py, cx, cy, radius) then
			draw_supply_ping(supply, px, py, 2.5)
		end
	end
	for _, ping in ipairs(ctx.objective_pings) do
		local objective = ping.objective
		local px, py = local_minimap_point(ctx, objective.x, objective.y, cx, cy, scale)
		if in_minimap_circle(px, py, cx, cy, radius) then
			draw_supply_ping({ color = objective.color, time = ping.time }, px, py, 3.5)
		end
	end
	love.graphics.setColor(0.35, 0.72, 0.95)
	love.graphics.circle("fill", cx, cy, 4)
	love.graphics.setColor(0.55, 0.55, 0.58)
	love.graphics.circle("line", cx, cy, radius)
	love.graphics.setColor(0.82, 0.82, 0.82)
	for _, label in ipairs({ { "N", 0, -radius - 14 }, { "S", 0, radius + 8 }, { "W", -radius - 14, 0 }, { "E", radius + 14, 0 } }) do
		local dx, dy = apply_minimap_fx(label[2], label[3], minimap_fx)
		love.graphics.print(label[1], cx + dx - 5, cy + dy - 8)
	end
end

function ui.draw_order_panel(ctx)
	love.graphics.setColor(0.11, 0.11, 0.12)
	love.graphics.rectangle("fill", ctx.PANEL_X, 0, ctx.W - ctx.PANEL_X, ctx.H)
	love.graphics.setColor(0.26, 0.26, 0.28)
	love.graphics.line(ctx.PANEL_X, 0, ctx.PANEL_X, ctx.H)
	draw_minimap(ctx)
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("ORDER SHEET", ctx.PANEL_X + 20, 324)

	local font = love.graphics.getFont()
	for i, objective in ipairs(ctx.objectives) do
		local y = 356 + (i - 1) * 46
		love.graphics.setColor(objective.color)
		love.graphics.rectangle("fill", ctx.PANEL_X + 20, y + 2, 18, 18)
		love.graphics.setColor(objective.done and 0.55 or 1, objective.done and 0.55 or 1, objective.done and 0.55 or 1)
		love.graphics.print(objective.name, ctx.PANEL_X + 48, y)
		if objective.done then
			love.graphics.line(ctx.PANEL_X + 48, y + 9, ctx.PANEL_X + 48 + font:getWidth(objective.name), y + 9)
		end
	end
	love.graphics.setColor(ctx.state.objectives_done and 1 or 0.55, ctx.state.objectives_done and 1 or 0.55, ctx.state.objectives_done and 1 or 0.55)
	love.graphics.print("Capture Seija", ctx.PANEL_X + 48, 356 + #ctx.objectives * 46)
	if ctx.state.cleared then
		love.graphics.line(ctx.PANEL_X + 48, 365 + #ctx.objectives * 46, ctx.PANEL_X + 48 + font:getWidth("Capture Seija"), 365 + #ctx.objectives * 46)
	end
	love.graphics.setColor(0.62, 0.65, 0.68)
	love.graphics.print("H: Help", ctx.PANEL_X + 20, ctx.H - 30)
end

function ui.draw_help_popup(ctx)
	if ctx.help_popup <= 0 then return end
	local alpha = math.min(1, ctx.help_popup / 0.4)
	local w, h = 310, 150
	local x, y = ctx.VIEW_W - w - 18, ctx.H - h - 18
	love.graphics.setColor(0.06, 0.065, 0.07, 0.9 * alpha)
	love.graphics.rectangle("fill", x, y, w, h, 6, 6)
	love.graphics.setColor(0.7, 0.74, 0.78, alpha)
	love.graphics.rectangle("line", x, y, w, h, 6, 6)
	love.graphics.print("Controls", x + 14, y + 12)
	love.graphics.print("WASD: 이동    마우스: 시야", x + 14, y + 38)
	love.graphics.print("스페이스: 스텝 대시", x + 14, y + 62)
	love.graphics.print("B: 브리핑 호출", x + 14, y + 86)
	love.graphics.print("H: 도움말    R: 새 맵", x + 14, y + 110)
end

function ui.draw_full_map_overlay(ctx)
	if not ctx.full_map_open then return end
	local w, h = ctx.VIEW_W * 0.8, ctx.H * 0.8
	local x, y = (ctx.VIEW_W - w) / 2, (ctx.H - h) / 2
	local scale = math.min(w / ctx.MAP_W, h / ctx.MAP_H)
	local map_w, map_h = ctx.MAP_W * scale, ctx.MAP_H * scale
	local cx, cy = x + w / 2, y + h / 2
	local fx = current_minimap_fx(ctx.minimap_fx.map)
	if ctx.minimap_fx.map.mode == "diag_flip" and ctx.minimap_fx.map.time then
		local t = effects.in_out_quint(math.min(1, ctx.minimap_fx.map.time / ctx.minimap_fx.map.duration))
		fx.diag_scale = math.abs(math.cos(t * math.pi))
	end
	love.graphics.setColor(0.06, 0.07, 0.08, 0.74)
	love.graphics.rectangle("fill", x, y, w, h, 8, 8)
	love.graphics.setColor(0.75, 0.82, 0.9, 0.22)
	love.graphics.rectangle("line", x, y, w, h, 8, 8)
	love.graphics.setColor(0.86, 0.88, 0.9, 0.92)
	for _, label in ipairs({ { "N", 0, -h / 2 + 22 }, { "S", 0, h / 2 - 28 }, { "W", -w / 2 + 18, 0 }, { "E", w / 2 - 24, 0 } }) do
		local dx, dy = apply_minimap_fx(label[2], label[3], fx)
		love.graphics.print(label[1], cx + dx - 5, cy + dy - 8)
	end
	love.graphics.setColor(0.28, 0.29, 0.32, 0.78)
	for ty = 1, ctx.MAP_H do
		for tx = 1, ctx.MAP_W do
			if ctx.map[ty][tx] == 0 then
				local dx, dy = apply_minimap_fx((tx - 0.5 - ctx.MAP_W / 2) * scale, (ty - 0.5 - ctx.MAP_H / 2) * scale, fx)
				love.graphics.rectangle("fill", cx + dx - scale / 2, cy + dy - scale / 2, math.max(1, scale), math.max(1, scale))
			end
		end
	end
	love.graphics.setColor(0.35, 0.72, 0.95, 1)
	local pdx, pdy = apply_minimap_fx((ctx.player.x / ctx.TILE - ctx.MAP_W / 2) * scale, (ctx.player.y / ctx.TILE - ctx.MAP_H / 2) * scale, fx)
	love.graphics.circle("fill", cx + pdx, cy + pdy, 5)
	for _, supply in ipairs(ctx.supplies) do
		if (supply.ping_time or 0) > 0 then
		local dx, dy = apply_minimap_fx((supply.x / ctx.TILE - ctx.MAP_W / 2) * scale, (supply.y / ctx.TILE - ctx.MAP_H / 2) * scale, fx)
		draw_supply_ping(supply, cx + dx, cy + dy, 4)
		end
	end
	for _, ping in ipairs(ctx.objective_pings) do
		local objective = ping.objective
		local dx, dy = apply_minimap_fx((objective.x / ctx.TILE - ctx.MAP_W / 2) * scale, (objective.y / ctx.TILE - ctx.MAP_H / 2) * scale, fx)
		draw_supply_ping({ color = objective.color, time = ping.time }, cx + dx, cy + dy, 5)
	end
	if ctx.debug_npc_map then
		local function draw_icon(actor, image)
			if not image then return end
			local dx, dy = apply_minimap_fx((actor.x / ctx.TILE - ctx.MAP_W / 2) * scale, (actor.y / ctx.TILE - ctx.MAP_H / 2) * scale, fx)
			local s = 20 / image:getHeight()
			love.graphics.setColor(1, 1, 1, 0.95)
			love.graphics.draw(image, cx + dx, cy + dy, 0, s, s, image:getWidth() / 2, image:getHeight() / 2)
		end
		for _, mob in ipairs(ctx.mobs) do
			draw_icon(mob, ctx.actor_images and ctx.actor_images[mob.type])
		end
		if ctx.seija then draw_icon(ctx.seija, ctx.actor_images and ctx.actor_images.seija) end
	end
	love.graphics.setColor(1, 1, 1, 0.86)
	love.graphics.print("FULL MAP", x + 16, y + 14)
end

function ui.briefing_menu_choice(ctx, mx, my)
	local menu = ctx.briefing_menu
	if not menu then return nil end
	local dx, dy = mx - menu.x, my - menu.y
	local dist = (dx * dx + dy * dy) ^ 0.5
	if dist < briefing_menu_inner or dist > briefing_menu_outer then return nil end
	local angle = atan2(dy, dx)
	local picked, best = nil, math.huge
	for i, item in ipairs(briefing_menu_items) do
		local d = math.abs(angle_diff(item.angle, angle))
		if d < best then picked, best = i, d end
	end
	return briefing_menu_items[picked].key, picked
end

function ui.draw_briefing_menu(ctx)
	local menu = ctx.briefing_menu
	if not menu then return end
	local _, selected = ui.briefing_menu_choice(ctx, love.mouse.getPosition())
	love.graphics.setColor(0.04, 0.045, 0.05, 0.76)
	love.graphics.circle("fill", menu.x, menu.y, briefing_menu_outer)
	for i, item in ipairs(briefing_menu_items) do
		local a1, a2 = item.angle - math.pi / 3, item.angle + math.pi / 3
		local points = {}
		for step = 0, 12 do
			local a = a1 + (a2 - a1) * step / 12
			points[#points + 1] = menu.x + math.cos(a) * briefing_menu_outer
			points[#points + 1] = menu.y + math.sin(a) * briefing_menu_outer
		end
		for step = 12, 0, -1 do
			local a = a1 + (a2 - a1) * step / 12
			points[#points + 1] = menu.x + math.cos(a) * briefing_menu_inner
			points[#points + 1] = menu.y + math.sin(a) * briefing_menu_inner
		end
		love.graphics.setColor(i == selected and 0.35 or 0.16, i == selected and 0.5 or 0.18, i == selected and 0.7 or 0.22, i == selected and 0.64 or 0.38)
		love.graphics.polygon("fill", points)
		local lx, ly = menu.x + math.cos(item.angle) * 118, menu.y + math.sin(item.angle) * 118
		love.graphics.setColor(1, 1, 1, i == selected and 1 or 0.72)
		love.graphics.printf(item.label, lx - 32, ly - 8, 64, "center")
	end
	love.graphics.setColor(0.07, 0.075, 0.085, 0.94)
	love.graphics.circle("fill", menu.x, menu.y, briefing_menu_inner)
	love.graphics.setColor(1, 1, 1, 0.86)
	love.graphics.printf("브리핑\n선택", menu.x - 36, menu.y - 16, 72, "center")
	love.graphics.setColor(0.86, 0.9, 0.95, 0.9)
	love.graphics.circle("line", menu.x, menu.y, briefing_menu_outer)
	love.graphics.circle("line", menu.x, menu.y, briefing_menu_inner)
end

function ui.draw_briefing(ctx)
	if not ctx.briefings then return end
	for i = #ctx.briefings, 1, -1 do
	local briefing = ctx.briefings[i]
	local image = briefing.speaker == "Doremi" and ctx.doremi_image or ctx.sagume_image
	if image then
	local alpha = 1
	if briefing.time > briefing.duration - briefing.out_time then
		alpha = 1 - (briefing.time - (briefing.duration - briefing.out_time)) / briefing.out_time
	end
	local scale = 112 / image:getHeight()
	local x, y = briefing.x, briefing.y
	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.draw(image, x, y, 0, scale, scale)
	local bubble_x = x + image:getWidth() * scale + 14
	local bubble_y = y + 10
	love.graphics.setColor(0.96, 0.96, 0.9, alpha)
	love.graphics.rectangle("fill", bubble_x, bubble_y, 310, 74, 8, 8)
	love.graphics.setColor(0.18, 0.18, 0.16, alpha)
	love.graphics.rectangle("line", bubble_x, bubble_y, 310, 74, 8, 8)
	love.graphics.print(briefing.speaker, bubble_x + 14, bubble_y + 10)
	love.graphics.printf(briefing.text, bubble_x + 14, bubble_y + 34, 282)
	end
	end
end

function ui.draw_interference(ctx)
	local event, image = ctx.interference, ctx.seija_image
	if not event or not image then return end
	local alpha = 1
	if event.time > event.duration - event.out_time then
		alpha = 1 - (event.time - (event.duration - event.out_time)) / event.out_time
	end
	local scale = 112 / image:getHeight()
	local x, y = event.x, event.y
	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.draw(image, x, y, 0, scale, scale)
	local bubble_w, bubble_h = 310, 74
	local bubble_x = x - bubble_w - 14
	local bubble_y = y + 10
	love.graphics.setColor(0.18, 0.12, 0.22, alpha)
	love.graphics.rectangle("fill", bubble_x, bubble_y, bubble_w, bubble_h, 8, 8)
	love.graphics.setColor(0.95, 0.7, 1.0, alpha)
	love.graphics.rectangle("line", bubble_x, bubble_y, bubble_w, bubble_h, 8, 8)
	love.graphics.print("Seija", bubble_x + 14, bubble_y + 10)
	love.graphics.printf(event.text, bubble_x + 14, bubble_y + 34, bubble_w - 28)
end

return ui
