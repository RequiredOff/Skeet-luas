local g_esp_data = { }
local g_sim_ticks, g_net_data = { }, { }

-- Text glow settings
local glow_enabled = ui.new_checkbox("RAGE", "Other", "Enable Glow Effect")
local glow_intensity = ui.new_slider("RAGE", "Other", "Glow Intensity", 0, 15, 6, true, "%", 1, {})
local glow_radius = ui.new_slider("RAGE", "Other", "Glow Radius", 1, 20, 6, true, "px", 1, {})

-- Box color selection
local box_color_preset = ui.new_combobox("RAGE", "Other", "Box Color", {
    "Blue (Default)", "Red", "Green", "Yellow", "Purple", "Orange", "Cyan", "Pink", "White", "Lime", "Magenta", "Aqua"
})


local globals_tickinterval = globals.tickinterval
local entity_is_enemy = entity.is_enemy
local entity_get_prop = entity.get_prop
local entity_is_dormant = entity.is_dormant
local entity_is_alive = entity.is_alive
local entity_get_origin = entity.get_origin
local entity_get_local_player = entity.get_local_player
local entity_get_player_resource = entity.get_player_resource
local entity_get_bounding_box = entity.get_bounding_box
local entity_get_player_name = entity.get_player_name
local renderer_text = renderer.text
local w2s = renderer.world_to_screen
local line = renderer.line
local table_insert = table.insert
local client_trace_line = client.trace_line
local math_floor = math.floor
local globals_frametime = globals.frametime

local sv_gravity = cvar.sv_gravity
local sv_jump_impulse = cvar.sv_jump_impulse

local time_to_ticks = function(t) return math_floor(0.5 + (t / globals_tickinterval())) end
local vec_substract = function(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
local vec_add = function(a, b) return { a[1] + b[1], a[2] + b[2], a[3] + b[3] } end
local vec_lenght = function(x, y) return (x * x + y * y) end

-- Get box color
local function get_box_color()
    local preset = ui.get(box_color_preset)
    
    -- Color presets
    local colors = {
        ["Blue (Default)"] = {47, 117, 221, 255},
        ["Red"] = {255, 45, 45, 255},
        ["Green"] = {45, 255, 45, 255},
        ["Yellow"] = {255, 255, 45, 255},
        ["Purple"] = {221, 45, 255, 255},
        ["Orange"] = {255, 165, 0, 255},
        ["Cyan"] = {45, 255, 255, 255},
        ["Pink"] = {255, 45, 255, 255},
        ["White"] = {255, 255, 255, 255},
        ["Lime"] = {128, 255, 0, 255},
        ["Magenta"] = {255, 0, 255, 255},
        ["Aqua"] = {0, 255, 255, 255}
    }
    
    local color = colors[preset] or colors["Blue (Default)"]
    return color[1], color[2], color[3], color[4]
end

-- Render 2D box
local function render_simple_box(x1, y1, x2, y2, r, g, b, a)
    -- Check if coordinates are valid (not nil)
    if not x1 or not y1 or not x2 or not y2 then
        return
    end
    
    -- Draw box lines
    line(x1, y1, x2, y1, r, g, b, a) -- Top
    line(x2, y1, x2, y2, r, g, b, a) -- Right
    line(x2, y2, x1, y2, r, g, b, a) -- Bottom
    line(x1, y2, x1, y1, r, g, b, a) -- Left
end

-- Render 3D box
local function render_simple_3d_box(points, edges, r, g, b, a)
    for i = 1, #edges do
        if points[edges[i][1]] ~= nil and points[edges[i][2]] ~= nil then
            local p1 = { w2s(points[edges[i][1]][1], points[edges[i][1]][2], points[edges[i][1]][3]) }
            local p2 = { w2s(points[edges[i][2]][1], points[edges[i][2]][2], points[edges[i][2]][3]) }
            
            if p1[1] ~= nil and p1[2] ~= nil and p2[1] ~= nil and p2[2] ~= nil then
                line(p1[1], p1[2], p2[1], p2[2], r, g, b, a)
            end
        end
    end
end

-- Render text with glow 
local function render_text_with_glow(x, y, r, g, b, a, flags, size, text)
    if not ui.get(glow_enabled) then
        renderer_text(x, y, r, g, b, a, flags, size, text)
        return
    end
    
    -- Use text color for glow
    local glow_r, glow_g, glow_b = r, g, b
    local glow_a = a
    local intensity = ui.get(glow_intensity) / 100.0
    local glow_alpha = math_floor(glow_a * intensity)
    
    local base_radius = ui.get(glow_radius)
    local glow_radius = base_radius * intensity
    local glow_layers = 10 
    
    for i = 1, glow_layers do
        local progress = i / glow_layers
        local current_radius = glow_radius * progress
        local alpha_falloff = math.pow(1 - progress, 2.5)
        local current_alpha = math_floor(glow_alpha * alpha_falloff * 0.6)
        
        if current_alpha > 1 then
            local point_count = 8
            local angle_step = math.pi * 2 / point_count
            
            for j = 0, point_count do
                local angle = j * angle_step
                local offset_x = math.cos(angle) * current_radius
                local offset_y = math.sin(angle) * current_radius
                
                renderer_text(
                    x + offset_x, y + offset_y, 
                    glow_r, glow_g, glow_b, current_alpha, 
                    flags, size, text
                )
            end
            
            for k = 1, point_count do
                local angle = (k - 0.5) * angle_step
                local offset_x = math.cos(angle) * current_radius
                local offset_y = math.sin(angle) * current_radius
                
                renderer_text(
                    x + offset_x, y + offset_y, 
                    glow_r, glow_g, glow_b, current_alpha * 0.7, 
                    flags, size, text
                )
            end
        end
    end
    
    for i = 1, 8 do
        local outer_radius = glow_radius * (1.1 + i * 0.2)
        local outer_alpha = math_floor(glow_alpha * 0.2 * (1 - i / 8))
        
        if outer_alpha > 1 then
            for j = 0, 16 do
                local angle = j * (math.pi * 2 / 16)
                local offset_x = math.cos(angle) * outer_radius
                local offset_y = math.sin(angle) * outer_radius
                
                renderer_text(
                    x + offset_x, y + offset_y, 
                    glow_r, glow_g, glow_b, outer_alpha, 
                    flags, size, text
                )
            end
        end
    end
    
    renderer_text(x, y, r, g, b, a, flags, size, text)
end


local get_entities = function(enemy_only, alive_only)
	local enemy_only = enemy_only ~= nil and enemy_only or false
    local alive_only = alive_only ~= nil and alive_only or true
    
    local result = {}

    local me = entity_get_local_player()
    local player_resource = entity_get_player_resource()
    
	for player = 1, globals.maxplayers() do
        local is_enemy, is_alive = true, true
        
        if enemy_only and not entity_is_enemy(player) then is_enemy = false end
        if is_enemy then
            if alive_only and entity_get_prop(player_resource, 'm_bAlive', player) ~= 1 then is_alive = false end
            if is_alive then table_insert(result, player) end
        end
	end

	return result
end

local extrapolate = function(ent, origin, flags, ticks)
    local tickinterval = globals_tickinterval()

    local sv_gravity = sv_gravity:get_float() * tickinterval
    local sv_jump_impulse = sv_jump_impulse:get_float() * tickinterval

    local p_origin, prev_origin = origin, origin

    local velocity = { entity_get_prop(ent, 'm_vecVelocity') }
    local gravity = velocity[3] > 0 and -sv_gravity or sv_jump_impulse

    for i=1, ticks do
        prev_origin = p_origin
        p_origin = {
            p_origin[1] + (velocity[1] * tickinterval),
            p_origin[2] + (velocity[2] * tickinterval),
            p_origin[3] + (velocity[3]+gravity) * tickinterval,
        }

        local fraction = client_trace_line(-1, 
            prev_origin[1], prev_origin[2], prev_origin[3], 
            p_origin[1], p_origin[2], p_origin[3]
        )

        if fraction <= 0.99 then
            return prev_origin
        end
    end

    return p_origin
end

local function g_net_update()
	local me = entity_get_local_player()
    local players = get_entities(true, true)

	for i=1, #players do
		local idx = players[i]
        local prev_tick = g_sim_ticks[idx]
        
        if entity_is_dormant(idx) or not entity_is_alive(idx) then
            g_sim_ticks[idx] = nil
            g_net_data[idx] = nil
            g_esp_data[idx] = nil
        else
            local player_origin = { entity_get_origin(idx) }
            local simulation_time = time_to_ticks(entity_get_prop(idx, 'm_flSimulationTime'))
    
            if prev_tick ~= nil then
                local delta = simulation_time - prev_tick.tick

                if delta < 0 or delta > 0 and delta <= 64 then
                    local m_fFlags = entity_get_prop(idx, 'm_fFlags')

                    local diff_origin = vec_substract(player_origin, prev_tick.origin)
                    local teleport_distance = vec_lenght(diff_origin[1], diff_origin[2])

                    local extrapolated = extrapolate(idx, player_origin, m_fFlags, delta-1)
    
                    if delta < 0 then
                        g_esp_data[idx] = 1
                    end

                    g_net_data[idx] = {
                        tick = delta-1,

                        origin = player_origin,
                        predicted_origin = extrapolated,

                        tickbase = delta < 0,
                        lagcomp = teleport_distance > 4096,
                    }
                end
            end
    
            if g_esp_data[idx] == nil then
                g_esp_data[idx] = 0
            end

            g_sim_ticks[idx] = {
                tick = simulation_time,
                origin = player_origin,
            }
        end
	end
end

local function g_paint_handler()
    local me = entity_get_local_player()
    local player_resource = entity_get_player_resource()

    if not me or not entity_is_alive(me) then
        return
    end

	local observer_mode = entity_get_prop(me, "m_iObserverMode")
	local active_players = {}

	if (observer_mode == 0 or observer_mode == 1 or observer_mode == 2 or observer_mode == 6) then
		active_players = get_entities(true, true)
	elseif (observer_mode == 4 or observer_mode == 5) then
		local all_players = get_entities(false, true)
		local observer_target = entity_get_prop(me, "m_hObserverTarget")
		local observer_target_team = entity_get_prop(observer_target, "m_iTeamNum")

		for test_player = 1, #all_players do
			if (
				observer_target_team ~= entity_get_prop(all_players[test_player], "m_iTeamNum") and
				all_players[test_player ] ~= me
			) then
				table_insert(active_players, all_players[test_player])
			end
		end
	end

    if #active_players == 0 then
        return
    end

    for idx, net_data in pairs(g_net_data) do
        if entity_is_alive(idx) and entity_is_enemy(idx) and net_data ~= nil then
            if net_data.lagcomp then
                local predicted_pos = net_data.predicted_origin
                local box_r, box_g, box_b, box_a = get_box_color() -- Get custom box color

                local min = vec_add({ entity_get_prop(idx, 'm_vecMins') }, predicted_pos)
                local max = vec_add({ entity_get_prop(idx, 'm_vecMaxs') }, predicted_pos)

                local points = {
                    {min[1], min[2], min[3]}, {min[1], max[2], min[3]},
                    {max[1], max[2], min[3]}, {max[1], min[2], min[3]},
                    {min[1], min[2], max[3]}, {min[1], max[2], max[3]},
                    {max[1], max[2], max[3]}, {max[1], min[2], max[3]},
                }

                local edges = {
                    {0, 1}, {1, 2}, {2, 3}, {3, 0}, {5, 6}, {6, 7}, {1, 4}, {4, 8},
                    {0, 4}, {1, 5}, {2, 6}, {3, 7}, {5, 8}, {7, 8}, {3, 4}
                }

                -- Render 3D box
                render_simple_3d_box(points, edges, box_r, box_g, box_b, box_a)
                
                -- Render connection line from origin to predicted position
                local origin = { entity_get_origin(idx) }
                local origin_w2s = { w2s(origin[1], origin[2], origin[3]) }
                local min_w2s = { w2s(min[1], min[2], min[3]) }

                if origin_w2s[1] ~= nil and origin_w2s[2] ~= nil and min_w2s[1] ~= nil and min_w2s[2] ~= nil then
                    line(origin_w2s[1], origin_w2s[2], min_w2s[1], min_w2s[2], box_r, box_g, box_b, box_a)
                end
            end

            local text = {
                [0] = '', [1] = 'LAG COM BREAKER',
                [2] = 'SHIFTING TICKBASE'
            }

            local x1, y1, x2, y2, a = entity_get_bounding_box(idx)
            local palpha = 0

            if g_esp_data[idx] > 0 then
                g_esp_data[idx] = g_esp_data[idx] - globals_frametime()*2
                g_esp_data[idx] = g_esp_data[idx] < 0 and 0 or g_esp_data[idx]

                palpha = g_esp_data[idx]
            end

            local tb = net_data.tickbase or g_esp_data[idx] > 0
            local lc = net_data.lagcomp

            if not tb or net_data.lagcomp then
                palpha = a
            end

            if x1 ~= nil and a > 0 then
                local name = entity_get_player_name(idx)
                local y_add = name == '' and -8 or 0

                render_text_with_glow(x1 + (x2-x1)/2, y1 - 18 + y_add, 255, 45, 45, palpha*255, 'c', 0, text[tb and 2 or (lc and 1 or 0)])
            end
        end
    end
end

client.set_event_callback('paint', g_paint_handler)
client.set_event_callback('net_update_end', g_net_update)
