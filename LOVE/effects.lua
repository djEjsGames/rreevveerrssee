local effects = {}

local distort_code = [[
extern number time;
extern number strength;
extern number mode;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
{
	vec2 uv = tc;
	if (mode < 0.5) {
		float wave = sin((tc.y + time * 0.28) * 24.0) * 0.012 * strength;
		float sway = sin((tc.x + time * 0.18) * 17.0) * 0.008 * strength;
		uv = tc + vec2(wave, sway);
	} else {
		vec2 center = vec2(0.5, 0.5);
		vec2 p = tc - center;
		float dist = length(p);
		float pulse = sin((1.0 - strength) * 3.141592);
		float angle = (1.0 - smoothstep(0.0, 0.75, dist)) * sin(time * 1.2) * 1.2 * pulse;
		float s = sin(angle);
		float c = cos(angle);
		uv = center + vec2(p.x * c - p.y * s, p.x * s + p.y * c);
	}
	return Texel(tex, uv) * color;
}
]]

local night_blind_code = [[
extern vec2 center;
extern number inner_radius;
extern number outer_radius;
extern number alpha;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
{
	float d = distance(sc, center);
	float a = smoothstep(inner_radius, outer_radius, d) * alpha;
	return vec4(0.0, 0.0, 0.0, a);
}
]]

function effects.out_quint(t)
	return 1 - (1 - t) ^ 5
end

function effects.in_out_quint(t)
	if t < 0.5 then return 16 * t ^ 5 end
	return 1 - (-2 * t + 2) ^ 5 / 2
end

local function finish_screen_tween(fx)
	if fx.time then
		fx.sx, fx.sy, fx.time = fx.to_sx, fx.to_sy, nil
	end
	if fx.rot_time then
		fx.rot, fx.rot_time = fx.to_rot, nil
	end
end

local function diag_flip_points(ctx)
	local fx = ctx.screen_fx
	local t = effects.in_out_quint(math.min(1, fx.rot_time / fx.rot_duration))
	local size = ctx.flip_size
	local cx, cy = ctx.VIEW_W / 2, ctx.H / 2
	local diag_scale = math.abs(math.cos(t * math.pi))
	local sx = fx.rot_time >= fx.rot_duration * 0.5 and fx.to_sx / fx.from_sx or 1
	local sy = fx.rot_time >= fx.rot_duration * 0.5 and fx.to_sy / fx.from_sy or 1
	local function point(dx, dy)
		local dc, ds = math.cos(fx.diag_axis or math.pi / 4), math.sin(fx.diag_axis or math.pi / 4)
		local rx, ry = dx * dc - dy * ds, dx * ds + dy * dc
		rx = rx * diag_scale
		dx, dy = rx * dc + ry * ds, -rx * ds + ry * dc
		return cx + dx * sx, cy + dy * sy
	end
	local half = size / 2
	local x1, y1 = point(-half, -half)
	local x2, y2 = point(half, -half)
	local x3, y3 = point(half, half)
	local x4, y4 = point(-half, half)
	return x1, y1, x2, y2, x3, y3, x4, y4
end

local function barycentric(px, py, ax, ay, bx, by, cx, cy)
	local den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
	if math.abs(den) < 0.00001 then return nil end
	local u = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / den
	local v = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / den
	local w = 1 - u - v
	if u >= -0.001 and v >= -0.001 and w >= -0.001 then return u, v, w end
	return nil
end

function effects.diag_flip_to_canvas(ctx, x, y)
	local fx = ctx.screen_fx
	if not (fx.diag_flip and fx.rot_time) then return x, y end
	local x1, y1, x2, y2, x3, y3, x4, y4 = diag_flip_points(ctx)
	local u, v, w = barycentric(x, y, x1, y1, x2, y2, x3, y3)
	if u then
		return (u * 0 + v * 1 + w * 1) * ctx.flip_size - (ctx.flip_size - ctx.VIEW_W) / 2,
			(u * 0 + v * 0 + w * 1) * ctx.flip_size - (ctx.flip_size - ctx.H) / 2
	end
	u, v, w = barycentric(x, y, x1, y1, x3, y3, x4, y4)
	if u then
		return (u * 0 + v * 1 + w * 0) * ctx.flip_size - (ctx.flip_size - ctx.VIEW_W) / 2,
			(u * 0 + v * 1 + w * 1) * ctx.flip_size - (ctx.flip_size - ctx.H) / 2
	end
	return x, y
end

function effects.start_view_interference_fx(ctx, target)
	local fx = ctx.screen_fx
	finish_screen_tween(fx)
	fx.basis_target = target
	fx.basis_committed = false
	fx.diag_flip = target.mode == "diag_flip"
	fx.diag_axis = target.diag_axis or math.pi / 4
	fx.from_rot, fx.from_sx, fx.from_sy = fx.rot or 0, fx.sx, fx.sy
	fx.to_rot, fx.to_sx, fx.to_sy = target.rot, target.sx, target.sy
	fx.rot_time, fx.time, fx.rot_duration, fx.duration = 0, 0, 1.0, 1.0
	fx.flash = 0.7
	fx.label = fx.diag_flip and "DIAGONAL FLIP" or "VIEW SHIFT"
end

function effects.start_control_flip_fx(ctx)
	local flips = {
		{ sx = -1, sy = 1, label = "INPUT H FLIP" },
		{ sx = 1, sy = -1, label = "INPUT V FLIP" },
		{ sx = -1, sy = -1, label = "INPUT H/V FLIP" },
	}
	local picked = flips[math.random(#flips)]
	ctx.control_fx = { sx = picked.sx, sy = picked.sy, time = 10.0, duration = 10.0, label = picked.label }
	effects.play_sound(ctx, "spin")
end

function effects.reset_control_flip(ctx)
	ctx.control_fx = { sx = 1, sy = 1, time = 0, duration = 0, label = "" }
	effects.play_sound(ctx, "cleansing")
end

function effects.update_control_fx(ctx, dt)
	local fx = ctx.control_fx
	if not fx or fx.time <= 0 then return end
	fx.time = math.max(0, fx.time - dt)
	if fx.time == 0 then
		fx.sx, fx.sy, fx.label = 1, 1, ""
	end
end

function effects.reset_view_rotation(ctx)
	local fx = ctx.screen_fx
	finish_screen_tween(fx)
	fx.diag_flip, fx.diag_axis = nil, nil
	fx.from_rot, fx.from_sx, fx.from_sy = fx.rot or 0, fx.sx or 1, fx.sy or 1
	fx.to_rot, fx.to_sx, fx.to_sy = 0, 1, 1
	fx.rot_time, fx.time, fx.rot_duration, fx.duration = 0, 0, 1.0, 1.0
	fx.basis_target = { rot = 0, sx = 1, sy = 1 }
	fx.basis_committed = false
	fx.flash = 0.7
	fx.label = "VIEW RESET"
	effects.play_sound(ctx, "cleansing")
end

function effects.update_screen_fx(ctx, dt)
	local fx = ctx.screen_fx
	if fx.time then
		fx.time = math.min(fx.duration, fx.time + dt)
		if not fx.diag_flip then
			local t = effects.out_quint(fx.time / fx.duration)
			fx.sx = fx.from_sx + (fx.to_sx - fx.from_sx) * t
			fx.sy = fx.from_sy + (fx.to_sy - fx.from_sy) * t
		end
		if fx.time >= fx.duration then fx.time = nil end
	end
	if fx.rot_time then
		fx.rot_time = math.min(fx.rot_duration, fx.rot_time + dt)
		local t = effects.in_out_quint(fx.rot_time / fx.rot_duration)
		fx.rot = fx.from_rot + (fx.to_rot - fx.from_rot) * t
		if fx.rot_time >= fx.rot_duration then fx.rot_time = nil end
	end
	local flip_half = fx.time and fx.duration and fx.time >= fx.duration * 0.5
	local rot_half = fx.rot_time and fx.rot_duration and fx.rot_time >= fx.rot_duration * 0.5
	if fx.basis_target and not fx.basis_committed and (flip_half or rot_half) then
		ctx.view_basis = { rot = fx.basis_target.rot, sx = fx.basis_target.sx, sy = fx.basis_target.sy }
		fx.basis_committed = true
	end
	if not fx.time and not fx.rot_time and fx.basis_target then
		if fx.diag_flip then
			fx.sx, fx.sy = fx.basis_target.sx, fx.basis_target.sy
		end
		fx.basis_target, fx.basis_committed, fx.diag_flip = nil, nil, nil
	end
	fx.flash = math.max(0, fx.flash - dt)
end

function effects.start_drunk_fx(ctx)
	local strength = ctx.drunk_fx and ctx.drunk_fx.strength or 1.0
	ctx.drunk_fx = { time = 0, duration = 10.0, strength = strength, start_strength = strength }
	effects.play_sound(ctx, "drunken")
end

function effects.start_night_blind_fx(ctx)
	ctx.night_blind_fx = { time = 0, duration = 8.0 }
end

function effects.start_rumia_dark_fx(ctx)
	ctx.rumia_dark_fx = { time = 0, duration = 7.0, spots = {} }
	for _ = 1, 6 do
		ctx.rumia_dark_fx.spots[#ctx.rumia_dark_fx.spots + 1] = {
			x = ctx.VIEW_W / 2 + math.random(-220, 220),
			y = ctx.H / 2 + math.random(-150, 150),
			r = math.random(63, 240),
		}
	end
end

function effects.load(ctx)
	ctx.world_canvas = love.graphics.newCanvas(ctx.VIEW_W, ctx.H)
	local flip_size = math.max(ctx.VIEW_W, ctx.H)
	ctx.flip_canvas = love.graphics.newCanvas(flip_size, flip_size)
	ctx.flip_size = flip_size
	ctx.distort_shader = love.graphics.newShader(distort_code)
	ctx.night_blind_shader = love.graphics.newShader(night_blind_code)
	ctx.sounds = {
		drunken = love.filesystem.getInfo("Audio/Effect/Drunken.mp3") and love.audio.newSource("Audio/Effect/Drunken.mp3", "static") or nil,
		spin = love.filesystem.getInfo("Audio/Effect/Spin.mp3") and love.audio.newSource("Audio/Effect/Spin.mp3", "static") or nil,
		move = love.filesystem.getInfo("Audio/Effect/Move.mp3") and love.audio.newSource("Audio/Effect/Move.mp3", "static") or nil,
		cleansing = love.filesystem.getInfo("Audio/Effect/Cleansing.mp3") and love.audio.newSource("Audio/Effect/Cleansing.mp3", "static") or nil,
	}
	if love.filesystem.getInfo("Audio/BGM/BGM1.mp3") then
		ctx.bgm = love.audio.newSource("Audio/BGM/BGM1.mp3", "stream")
		ctx.bgm:setLooping(true)
		ctx.bgm:setVolume(0.36)
		ctx.bgm:play()
	end
end

function effects.play_sound(ctx, name)
	if ctx.sounds and ctx.sounds[name] then
		ctx.sounds[name]:clone():play()
	end
end

function effects.update_drunk_fx(ctx, dt)
	local fx = ctx.drunk_fx
	if not fx then return end
	fx.time = fx.time + dt
	fx.strength = fx.start_strength * math.max(0, 1 - fx.time / fx.duration)
	if fx.time >= fx.duration then ctx.drunk_fx = nil end
end

function effects.update_dark_fx(ctx, dt)
	if ctx.night_blind_fx then
		local fx = ctx.night_blind_fx
		fx.time = fx.time + dt
		if fx.time >= fx.duration then ctx.night_blind_fx = nil end
	end
	if ctx.rumia_dark_fx then
		local fx = ctx.rumia_dark_fx
		fx.time = fx.time + dt
		if fx.time >= fx.duration then ctx.rumia_dark_fx = nil end
	end
end

function effects.update_afterimages(ctx, dt)
	for i = #ctx.afterimages, 1, -1 do
		ctx.afterimages[i].t = ctx.afterimages[i].t - dt
		if ctx.afterimages[i].t <= 0 then table.remove(ctx.afterimages, i) end
	end
end

function effects.apply_screen_fx(ctx)
	love.graphics.translate(ctx.VIEW_W / 2, ctx.H / 2)
	if ctx.drunk_fx then
		local t, s = ctx.drunk_fx.time, ctx.drunk_fx.strength
		love.graphics.translate(math.sin(t * 2.4) * 12 * s, math.cos(t * 1.9) * 9 * s)
		love.graphics.rotate(math.sin(t * 1.5) * 0.3 * s)
	end
	love.graphics.rotate(ctx.screen_fx.rot or 0)
	love.graphics.scale(ctx.screen_fx.sx, ctx.screen_fx.sy)
	love.graphics.translate(-ctx.VIEW_W / 2, -ctx.H / 2)
end

function effects.draw_drunk_overlay(ctx)
	local fx = ctx.drunk_fx
	if not fx then return end
	local a = fx.strength
	love.graphics.setColor(0.4, 0.9, 0.85, 0.10 * a)
	love.graphics.rectangle("fill", 0, 0, ctx.VIEW_W, ctx.H)
	love.graphics.setColor(1, 0.35, 0.75, 0.08 * a)
	love.graphics.rectangle("fill", math.sin(fx.time * 2.2) * 18, 0, ctx.VIEW_W, ctx.H)
	love.graphics.setColor(1, 1, 1, 0.45 * a)
	love.graphics.print("DIZZY", 24, 132)
end

function effects.draw_dark_overlay(ctx)
	if ctx.night_blind_fx then
		local fx = ctx.night_blind_fx
		local t = math.min(1, fx.time / 1.4)
		local fade = math.min(1, (fx.duration - fx.time) / 1.0)
		local r = math.max(84, math.max(ctx.VIEW_W, ctx.H) * (0.52 - 0.32 * effects.out_quint(t)))
		ctx.night_blind_shader:send("center", { ctx.VIEW_W / 2, ctx.H / 2 })
		ctx.night_blind_shader:send("inner_radius", r * 0.58)
		ctx.night_blind_shader:send("outer_radius", r)
		ctx.night_blind_shader:send("alpha", 0.78 * fade)
		love.graphics.setShader(ctx.night_blind_shader)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.rectangle("fill", 0, 0, ctx.VIEW_W, ctx.H)
		love.graphics.setShader()
	end
	if ctx.rumia_dark_fx then
		local fx = ctx.rumia_dark_fx
		local fade = math.min(1, fx.time / 0.5, (fx.duration - fx.time) / 1.0)
		love.graphics.setColor(0, 0, 0, 0.78 * fade)
		for _, spot in ipairs(fx.spots) do
			love.graphics.circle("fill", spot.x, spot.y, spot.r)
		end
	end
end

function effects.begin_world_canvas(ctx)
	love.graphics.setCanvas(ctx.world_canvas)
	love.graphics.clear(0.06, 0.065, 0.07, 1)
end

function effects.end_world_canvas(ctx)
	love.graphics.setCanvas()
	local use_shader = ctx.drunk_fx
	if use_shader then
		ctx.distort_shader:send("time", ctx.drunk_fx.time)
		ctx.distort_shader:send("strength", ctx.drunk_fx.strength)
		ctx.distort_shader:send("mode", ctx.settings.distort_mode == "swirl" and 1 or 0)
		love.graphics.setShader(ctx.distort_shader)
	end
	love.graphics.setColor(1, 1, 1)
	if ctx.screen_fx.diag_flip and ctx.screen_fx.rot_time then
		love.graphics.setShader()
		love.graphics.setCanvas(ctx.flip_canvas)
		love.graphics.clear(0, 0, 0, 0)
		love.graphics.setColor(1, 1, 1)
		love.graphics.draw(ctx.world_canvas, (ctx.flip_size - ctx.VIEW_W) / 2, (ctx.flip_size - ctx.H) / 2)
		love.graphics.setCanvas()
		if use_shader then love.graphics.setShader(ctx.distort_shader) end
		local t = effects.in_out_quint(math.min(1, ctx.screen_fx.rot_time / ctx.screen_fx.rot_duration))
		local diag_scale = math.abs(math.cos(t * math.pi))
		local x1, y1, x2, y2, x3, y3, x4, y4 = diag_flip_points(ctx)
		local mesh = love.graphics.newMesh({
			{ x1, y1, 0, 0, 1, 1, 1, 1 },
			{ x2, y2, 1, 0, 1, 1, 1, 1 },
			{ x3, y3, 1, 1, 1, 1, 1, 1 },
			{ x4, y4, 0, 1, 1, 1, 1, 1 },
		}, "fan")
		mesh:setTexture(ctx.flip_canvas)
		love.graphics.draw(mesh, 0, 0)
		if diag_scale < 0.06 then
			love.graphics.setColor(1, 1, 1, 0.9)
			love.graphics.setLineWidth(4)
			love.graphics.line(x1, y1, x3, y3)
		end
		love.graphics.setLineWidth(1)
		love.graphics.setColor(1, 1, 1)
	else
		love.graphics.draw(ctx.world_canvas, 0, 0)
	end
	love.graphics.setShader()
end

return effects
