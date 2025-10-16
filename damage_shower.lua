local vector = require("vector")
local csgo_weapons = require("gamesense/csgo_weapons")
local configure_combobox = ui.new_combobox( "RAGE", "Other", "Hitbox Selection",  
"Stomach",
"Chest",
"Leg/feets"
)
local static_mode_combobox =
    ui.new_multiselect(
    "RAGE", "Other", "Enable Hit Mark on:",  
    "Head",
    "Chest",
    "Stomach",
    "Leg/feets"
)

local glow_enabled = ui.new_checkbox("RAGE", "Other", "Enable Glow Effect")
local glow_intensity = ui.new_slider("RAGE", "Other", "Glow Intensity", 0, 15, 6, true, "%", 1, {})
local glow_radius = ui.new_slider("RAGE", "Other", "Glow Radius", 1, 20, 6, true, "px", 1, {})
local show_threat_indicators = ui.new_checkbox("RAGE", "Other", "Show Threat Indicators")

local function render_text_with_glow(x, y, r, g, b, a, flags, size, text)
    if not ui.get(glow_enabled) then
        renderer.text(x, y, r, g, b, a, flags, size, text)
        return
    end
    
    local glow_r, glow_g, glow_b = r, g, b
    local glow_a = a
    local intensity = ui.get(glow_intensity) / 100.0
    local glow_alpha = math.floor(glow_a * intensity)
    
    local base_radius = ui.get(glow_radius)
    local glow_radius = base_radius * intensity
    local glow_layers = 10 
    
    for i = 1, glow_layers do
        local progress = i / glow_layers
        local current_radius = glow_radius * progress
        local alpha_falloff = math.pow(1 - progress, 2.5)
        local current_alpha = math.floor(glow_alpha * alpha_falloff * 0.6)
        
        if current_alpha > 1 then
            local point_count = 8
            local angle_step = math.pi * 2 / point_count
            
            for j = 0, point_count do
                local angle = j * angle_step
                local offset_x = math.cos(angle) * current_radius
                local offset_y = math.sin(angle) * current_radius
                
                renderer.text(
                    x + offset_x, y + offset_y, 
                    glow_r, glow_g, glow_b, current_alpha, 
                    flags, size, text
                )
            end
            
            for k = 1, point_count do
                local angle = (k - 0.5) * angle_step
                local offset_x = math.cos(angle) * current_radius
                local offset_y = math.sin(angle) * current_radius
                
                renderer.text(
                    x + offset_x, y + offset_y, 
                    glow_r, glow_g, glow_b, current_alpha * 0.7, 
                    flags, size, text
                )
            end
        end
    end
    
    for i = 1, 8 do
        local outer_radius = glow_radius * (1.1 + i * 0.2)
        local outer_alpha = math.floor(glow_alpha * 0.2 * (1 - i / 8))
        
        if outer_alpha > 1 then
            for j = 0, 16 do
                local angle = j * (math.pi * 2 / 16)
                local offset_x = math.cos(angle) * outer_radius
                local offset_y = math.sin(angle) * outer_radius
                
                renderer.text(
                    x + offset_x, y + offset_y, 
                    glow_r, glow_g, glow_b, outer_alpha, 
                    flags, size, text
                )
            end
        end
    end
    
    renderer.text(x, y, r, g, b, a, flags, size, text)
end

local function contains(tbl, val)
    for i = 1, #tbl do
        if tbl[i] == val then
            return true
        end
    end
    return false
end

local function hitbox_selection()
    local owo = ui.get(configure_combobox)
    if owo == "Stomach" then return 1.25 end
    if owo == "Chest" then return 1 end
    if owo == "Leg/feets" then return 0.75 end
end

local function hitbox_selection_hitbox()
    local lethal_head = 0
    local lethal_chest = 0
    local lethal_stomach = 0 
    local lethal_pelvis = 0
    if contains(ui.get(static_mode_combobox), "Head") then
        lethal_head = 255
    end
    if contains(ui.get(static_mode_combobox), "Chest") then
        lethal_chest = 255
    end
    if contains(ui.get(static_mode_combobox), "Stomach") then
        lethal_stomach = 255
    end
    if contains(ui.get(static_mode_combobox), "Leg/feets") then
        lethal_pelvis = 255
    end
    return lethal_head, lethal_chest, lethal_stomach, lethal_pelvis
end

local function on_paint()
    local players = entity.get_players(true)
    local local_player = entity.get_local_player()
    if local_player == nil or not entity.is_alive(local_player) then return end
    local weapon_ent = entity.get_player_weapon(entity.get_local_player())
	local alpha = {hitbox_selection_hitbox()}
	local weapon_idx = entity.get_prop(weapon_ent, "m_iItemDefinitionIndex")
    for i = 1, #players do
        local player_index = players[i]
        local weapon = csgo_weapons[weapon_idx]
        local local_origin = vector(entity.get_prop(local_player, "m_vecAbsOrigin"))
        local distance = local_origin:dist(vector(entity.get_prop(player_index, "m_vecOrigin")))	
        local weapon_adjust = weapon.damage
        local dmg_after_range = (weapon_adjust * math.pow(weapon.range_modifier, (distance * 0.002)))
        local armor = entity.get_prop(player_index,"m_ArmorValue")
        local newdmg = dmg_after_range * (weapon.armor_ratio * 0.5)
        if dmg_after_range - (dmg_after_range * (weapon.armor_ratio * 0.5)) * 0.5 > armor then
            newdmg = dmg_after_range - (armor / 0.5)
        end
        --Damage display
        local newdmg_indi = newdmg * hitbox_selection()
        --Stomach array
        local stomach_x, stomach_y, stomach_z = entity.hitbox_position(player_index, 3)
		local wx, wy = renderer.world_to_screen(stomach_x, stomach_y, stomach_z)
        --Chest array
        local chest_x, chest_y, chest_z = entity.hitbox_position(player_index, 5)
		local cx, cy = renderer.world_to_screen(chest_x, chest_y, chest_z)
        --Head array
        local head_x, head_y, head_z = entity.hitbox_position(player_index, 0)
		local hx, hy = renderer.world_to_screen(head_x, head_y, head_z)
        --Leg array
        local pelvis_x, pelvis_y, pelvis_z = entity.hitbox_position(player_index, 8)
		local px, py = renderer.world_to_screen(pelvis_x, pelvis_y, pelvis_z)
        local pelvis_x2, pelvis_y2, pelvis_z2 = entity.hitbox_position(player_index, 7)
		local mx, my = renderer.world_to_screen( pelvis_x2, pelvis_y2, pelvis_z2)
        local enemy_target_idx = client.current_threat()
        --Check is Hitbox lethal
        local enemy_health = entity.get_prop(player_index, "m_iHealth")
        local is_lethal_indi = enemy_health >= newdmg_indi
        local is_lethal_stomach = enemy_health >= (newdmg * 1.25)
        local is_lethal_chest = enemy_health >= newdmg 
        local is_lethal_head = enemy_health >= newdmg * 4
        local is_lethal_pelvis = enemy_health >= newdmg * 0.75
        -- Get enemy bounding box array
        local x1, y1, x2, y2, mult = entity.get_bounding_box(player_index)
        if x1 ~= nil and mult > 0 then
            y1 = y1 - 17
            x1 = x1 + ((x2 - x1) / 2)
            if y1 ~= nil then 

                local damage_r = is_lethal_indi and 255 or 253
                local damage_g = is_lethal_indi and 255 or 69
                local damage_b = is_lethal_indi and 255 or 106
                render_text_with_glow(x1, y1, damage_r, damage_g, damage_b, 255, "cb", 0, math.floor(newdmg_indi)) 
                
                render_text_with_glow(px, py, 253, 69, 106, alpha[4], "cbd", 0, is_lethal_pelvis and " " or "+" )  
                render_text_with_glow(mx, my, 253, 69, 106, alpha[4], "cbd", 0, is_lethal_pelvis and " " or "+" )  
                
                render_text_with_glow(wx, wy, 253, 69, 106, alpha[3], "cbd", 0, is_lethal_stomach and "" or "+" )
                
                render_text_with_glow(cx, cy, 253, 69, 106, alpha[2], "cbd", 0, is_lethal_chest and " " or "+" )  
                
                render_text_with_glow(hx, hy, 253, 69, 106, alpha[1], "cbd", 0, is_lethal_head and " " or "+" )  
                
                if ui.get(show_threat_indicators) and player_index == enemy_target_idx then
                    -- Display threat with glow
                    render_text_with_glow(x1 + 12, y1, 255, 255, 255, 255, "cbd", 0, "-") 
                    render_text_with_glow(x1 - 12, y1, 255, 255, 255, 255, "cbd", 0, "-")
                end
            end
        end
    end
end

client.set_event_callback('paint', on_paint)