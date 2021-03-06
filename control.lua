local function addtotable(table, factor)
    for i, item in pairs(table) do
        if type(item) == "table" then
            table[i] = addtotable(item, factor)
        elseif type(item) == "number" then
            table[i] = item + factor
        end
    end
    return table
end
local alwaysoncond = {
    condition = {
        comparator = "≥",
        constant = 0,
        first_signal = {type = "virtual", name = "signal-anything"}
    }
}

local entites_to_monitor = {["cool-lamp"] = 1}
local function monitored_place(entity)
    if global.monitored_entities == nil then global.monitored_entities = {} end
    if entity.name == "cool-lamp" then
        local c = entity.get_or_create_control_behavior()
        c.circuit_condition = alwaysoncond
    end
    global.monitored_entities[entity.unit_number] =
        {entity = entity, lightsprite = nil, lightdraw = nil}
end
local function monitored_remove(entity)
    if entity.lightsprite then
        rendering.destroy(entity.lightsprite)
        rendering.destroy(entity.lightdraw)
    end
    if global.monitored_entities[entity.unit_number] ~= nil then
        global.monitored_entities[entity.unit_number] = nil
    end

end
-- lifted straight from nixie source lol!
local filters = {}
local names = {}
for name in pairs(entites_to_monitor) do
    filters[#filters + 1] = {filter = "name", name = name}
    filters[#filters + 1] = {filter = "ghost_name", name = name}
    names[#names + 1] = name
end
script.on_init(function() global.monitored_entities = {}; end)
-- script.on_load(function() force_scan() end)
local function onPlaceEntity(entity)
    local num = entites_to_monitor[entity.name]
    if num then -- i guess this is lua's "if item in"
        monitored_place(entity)
    end
    -- if entity.name == "sun-lamp" then
    --     entity.surface.brightness_visual_weights =
    --         addtotable(entity.surface.brightness_visual_weights, 0.5)
    -- end
end
local function onRemoveEntity(entity)
    local num = entites_to_monitor[entity.name]
    if num then -- i guess this is lua's "if item in"
        monitored_remove(entity)
    end
    -- if entity.name == "sun-lamp" then
    --     entity.surface.brightness_visual_weights =
    --         addtotable(entity.surface.brightness_visual_weights, -0.5)
    -- end
end
local function get_signals_filtered(entity, signal)
    return entity.get_merged_signal(signal)
end
local function rgblamp(mentity)
    local lamp = mentity["entity"]
    local c = lamp.get_or_create_control_behavior()
    -- defaultc = {comparator = "<", constant = 0, first_signal = {type = "item"}}
    -- if c.circuit_condition.condition == defaultc then
    --     c.circuit_condition = alwaysoncond
    -- end

    local color
    if not c.disabled then
        local red = get_signals_filtered(lamp, {
            ["type"] = "virtual",
            ["name"] = "signal-red"
        })
        red = math.min(255, math.max(red, 0))
        local green = get_signals_filtered(lamp, {
            ["type"] = "virtual",
            ["name"] = "signal-green"
        })
        green = math.min(255, math.max(green, 0))
        local blue = get_signals_filtered(lamp, {
            ["type"] = "virtual",
            ["name"] = "signal-blue"
        })
        blue = math.min(255, math.max(blue, 0))
        color = {r = red, g = green, b = blue, a = 255}
    else
        print(serpent.block(c.circuit_condition))
        color = {r = 0, g = 0, b = 0, a = 0}
    end
    if mentity["lightsprite"] == nil then
        mentity["lightdraw"] = nil -- fucking lua, lack of value will equal nil but not be assignable
        mentity["lightsprite"] = rendering.draw_sprite {
            sprite = "cool-light",
            tint = color,
            target = lamp,
            -- time_to_live = 2,
            surface = lamp.surface,
            render_layer = "light-effect"
        };
    else
        rendering.set_color(mentity["lightsprite"], color)
    end
    if mentity["lightdraw"] == nil then
        mentity["lightdraw"] = nil
        mentity["lightdraw"] = rendering.draw_light {
            sprite = "utility/light_small",
            color = color,
            target = lamp,
            -- time_to_live = 2,
            surface = lamp.surface,
            render_layer = "light-effect"
        };
    else
        rendering.set_color(mentity["lightdraw"], color)
    end
end
local function onTick()
    if global.monitored_entities == nil then global.monitored_entities = {} end
    for id, mentity in pairs(global.monitored_entities) do
        local entity = mentity["entity"]
        if entity.valid then
            if (entity.name == "cool-lamp") then
                if entity.is_connected_to_electric_network() then
                    rgblamp(mentity)
                end
            end
        else

            monitored_remove(mentity)
            -- global.monitored_entities[id] = nil
        end

    end
end
local function handle_sun_explosion(params)
    if params.effect_id == "sun-lamp-death" then
        if params.target_entity.status == defines.entity_status.working then -- needs power to explode
            params.target_entity.surface.create_entity {
                name = "atomic-rocket",
                position = params.target_entity.position,
                target = params.target_entity,
                source = params.source_entity,
                speed = 1,
                max_range = 1
            }
        end
    end
end
local function RegisterPicker()
    if remote.interfaces["picker"] and
        remote.interfaces["picker"]["dolly_moved_entity_id"] then
        script.on_event(remote.call("picker", "dolly_moved_entity_id"),
                        function(event)
            onRemoveEntity(event.moved_entity)
            onPlaceEntity(event.moved_entity)
        end)
    end
end
script.on_load(function() RegisterPicker() end)
script.on_event(defines.events.on_tick, onTick)
script.on_event(defines.events.on_script_trigger_effect, handle_sun_explosion)
script.on_event(defines.events.on_built_entity,
                function(event) onPlaceEntity(event.created_entity) end, filters)
script.on_event(defines.events.on_robot_built_entity,
                function(event) onPlaceEntity(event.created_entity) end, filters)
script.on_event(defines.events.script_raised_built,
                function(event) onPlaceEntity(event.entity) end)
script.on_event(defines.events.script_raised_revive,
                function(event) onPlaceEntity(event.entity) end)
script.on_event(defines.events.on_entity_cloned,
                function(event) onPlaceEntity(event.destination) end)

-- script.on_event(defines.events.on_pre_player_mined_item,
--                 function(event) onRemoveEntity(event.entity) end, filters)
-- script.on_event(defines.events.on_robot_pre_mined,
--                 function(event) onRemoveEntity(event.entity) end, filters)
-- script.on_event(defines.events.on_entity_died,
--                 function(event) onRemoveEntity(event.entity) end, filters)
-- script.on_event(defines.events.script_raised_destroy,
--                 function(event) onRemoveEntity(event.entity) end)
