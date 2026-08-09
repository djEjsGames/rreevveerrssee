local effects = require("effects")

local ui = {}

function ui.load(ctx)
	ctx.sagume_image = love.graphics.newImage("Image/Sagume.png")
	ctx.seija_image = love.graphics.newImage("Image/Seija.png")
	ctx.doremi_image = love.graphics.newImage("Image/Doremi.png")
	ctx.ui_font = love.graphics.newFont("Galmuri11-Bold.ttf", 16)
	love.graphics.setFont(ctx.ui_font)
end

function ui.start_briefing(ctx, preset, text, speaker)
	local target = { x = 24, y = 24 }
	local starts = {
		left = { x = -160, y = target.y },
		top = { x = target.x, y = -180 },
		corner = { x = -160, y = -180 },
	}
	ctx.briefing = {
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
	}
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
	local briefing = ctx.briefing
	if not briefing then return end
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
	if briefing.time >= briefing.duration then ctx.briefing = nil end
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
		if supply.alpha > 0.02 and in_minimap_circle(px, py, cx, cy, radius) then
			love.graphics.setColor(supply.color[1], supply.color[2], supply.color[3], supply.alpha)
			love.graphics.circle("fill", px, py, 2.5)
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
	love.graphics.print("WASD: move    Mouse: aim", x + 14, y + 38)
	love.graphics.print("Space: step dash", x + 14, y + 62)
	love.graphics.print("B: ask Sagume    C: Doremi", x + 14, y + 86)
	love.graphics.print("G/V: test toggles", x + 14, y + 110)
	love.graphics.print("R: new map", x + 14, y + 132)
end

function ui.draw_briefing(ctx)
	local briefing = ctx.briefing
	local image = briefing and (briefing.speaker == "Doremi" and ctx.doremi_image or ctx.sagume_image)
	if not briefing or not image then return end
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
