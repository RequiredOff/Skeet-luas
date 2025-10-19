local c_entity = require("gamesense/entity")

table.contains = function(source, target)
    local source_element = ui.get(source)
    for id, name in pairs(source_element) do
        if name == target then
            return true
        end
    end
    return false
end

local E_POSE_PARAMETERS = {
    STRAFE_YAW = 0,
    STAND = 1,
    LEAN_YAW = 2,
    SPEED = 3,
    LADDER_YAW = 4,
    LADDER_SPEED = 5,
    JUMP_FALL = 6,
    MOVE_YAW = 7,
    MOVE_BLEND_CROUCH = 8,
    MOVE_BLEND_WALK = 9,
    MOVE_BLEND_RUN = 10,
    BODY_YAW = 11,
    BODY_PITCH = 12,
    AIM_BLEND_STAND_IDLE = 13,
    AIM_BLEND_STAND_WALK = 14,
    AIM_BLEND_STAND_RUN = 14,
    AIM_BLEND_CROUCH_IDLE = 16,
    AIM_BLEND_CROUCH_WALK = 17,
    DEATH_YAW = 18
}

local animations_enabled = ui.new_checkbox("LUA", "A", "Animation Breaker")
local ground_legs = ui.new_combobox("LUA", "A", "Animation breaker: Leg movement", "Walking", "Jitter", "Moonwalk")
local ground_legs_type = ui.new_combobox("LUA", "A", "Ground legs ~ Type", "Default", "Modern")
local air_legs = ui.new_combobox("LUA", "A", "Animations ~ Air legs", "Disabled", "Static", "Jitter", "Moonwalk")
local addons = ui.new_multiselect("LUA", "A", "Animations Additions", "Body Lean", "Earthquake", "Pitch 0 on land")

ui.set(ground_legs, "Walking")
ui.set(ground_legs_type, "Default")
ui.set(air_legs, "Disabled")

local function adjust_visibility()
    local enabled = ui.get(animations_enabled)
    ui.set_visible(ground_legs, enabled)
    ui.set_visible(ground_legs_type, enabled and ui.get(ground_legs) == "Jitter")
    ui.set_visible(air_legs, enabled)
    ui.set_visible(addons, enabled)
end

adjust_visibility()
ui.set_callback(ground_legs, adjust_visibility)
ui.set_callback(animations_enabled, adjust_visibility)

-- Animation breaker runs every frame before render
-- Works instantly after shot because pre_render hooks pose parameters before engine applies them
local function animations_pre_render()
    if not ui.get(animations_enabled) then return end

    local lp = entity.get_local_player()
    if not lp or not entity.is_alive(lp) then return end

    local self_index = c_entity.new(lp)
    local self_anim_state = self_index:get_anim_state()
    if not self_anim_state then return end

    -- Ground legs animation manipulation
    local ground_legs_value = ui.get(ground_legs)
    if ground_legs_value == "Walking" then
        -- Normal walking - disable leg sliding
        local leg_movement_ref = ui.reference("AA", "other", "leg movement")
        if leg_movement_ref then
            ui.set(leg_movement_ref, "Never slide")
        end
    elseif ground_legs_value == "Jitter" then
        -- Fast leg jitter - rapid state switching
        local leg_movement_ref = ui.reference("AA", "other", "leg movement")
        if leg_movement_ref then
            ui.set(leg_movement_ref, globals.tickcount() % 4 > 1 and "Off" or "Always slide")
        end

        local ground_legs_type_value = ui.get(ground_legs_type)
        if ground_legs_type_value == "Default" then
            -- Simple jitter: switch between 1 and 0.5 every 4 ticks
            entity.set_prop(lp, "m_flPoseParameter", globals.tickcount() % 4 > 1 and 1 or 0.5, E_POSE_PARAMETERS.STRAFE_YAW)
        else
            -- Complex jitter: random values and intervals for chaotic look
            entity.set_prop(lp, "m_flPoseParameter", globals.tickcount() % client.random_float(3, 5) > 1 and client.random_float(0.5, 0.8) or 0, E_POSE_PARAMETERS.STRAFE_YAW)
        end
    elseif ground_legs_value == "Moonwalk" then
        -- Moonwalk - fixed value for reverse movement
        local leg_movement_ref = ui.reference("AA", "other", "leg movement")
        if leg_movement_ref then
            ui.set(leg_movement_ref, "Never slide")
        end
        entity.set_prop(lp, "m_flPoseParameter", 0.5, 7)
    end

    -- Air legs manipulation
    local air_legs_value = ui.get(air_legs)
    if air_legs_value == "Static" then
        entity.set_prop(lp, "m_flPoseParameter", 1, E_POSE_PARAMETERS.JUMP_FALL)
    elseif air_legs_value == "Jitter" then
        entity.set_prop(lp, "m_flPoseParameter", globals.tickcount() % 4 > 1 and 1 or 0, E_POSE_PARAMETERS.JUMP_FALL)
    elseif air_legs_value == "Moonwalk" then
        local self_anim_overlay = self_index:get_anim_overlay(6)
        if self_anim_overlay then
            local x_velocity = entity.get_prop(lp, "m_vecVelocity[0]")
            if math.abs(x_velocity) >= 3 then
                self_anim_overlay.weight = 1
            end
        end
    else
        entity.set_prop(lp, "m_flPoseParameter", 0, E_POSE_PARAMETERS.JUMP_FALL)
    end

    -- Additional animation effects
    if table.contains(addons, "Body Lean") then
        local self_anim_overlay = self_index:get_anim_overlay(12)
        if self_anim_overlay then
            local x_velocity = entity.get_prop(lp, "m_vecVelocity[0]")
            if math.abs(x_velocity) >= 3 then
                self_anim_overlay.weight = 1
            end
        end
    end

    if table.contains(addons, "Earthquake") then
        local self_anim_overlay = self_index:get_anim_overlay(12)
        if self_anim_overlay then
            self_anim_overlay.weight = client.random_float(0, 1)
        end
    end

    if table.contains(addons, "Pitch 0 on land") then
        if self_anim_state.hit_in_ground_animation then
            entity.set_prop(lp, "m_flPoseParameter", 0.5, E_POSE_PARAMETERS.BODY_PITCH)
        end
    end
end

-- Hook to pre_render event - executes every frame before rendering
-- This is why breaker works instantly after shot
client.set_event_callback("pre_render", animations_pre_render)
