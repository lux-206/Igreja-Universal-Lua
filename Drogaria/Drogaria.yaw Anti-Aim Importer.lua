local ffi = require("ffi")
local json = require("json")
local base64 = require("gamesense/base64")

local Ref = {
    AA = {
        enabled = ui.reference("AA", "Anti-aimbot angles", "Enabled"),
        pitch = {ui.reference("AA", "Anti-aimbot angles", "Pitch")},
        yaw_base = ui.reference("AA", "Anti-aimbot angles", "Yaw base"),
        yaw = {ui.reference("AA", "Anti-aimbot angles", "Yaw")},
        jitter = {ui.reference("AA", "Anti-aimbot angles", "Yaw jitter")},
        body = {ui.reference("AA", "Anti-aimbot angles", "Body yaw")},
        freestand_body = ui.reference("AA", "Anti-aimbot angles", "Freestanding body yaw"),
        edge_yaw = ui.reference("AA", "Anti-aimbot angles", "Edge yaw"),
        freestanding = {ui.reference("AA", "Anti-aimbot angles", "Freestanding")},
        roll = ui.reference("AA", "Anti-aimbot angles", "Roll"),
    },
    Misc = {
        dt = {ui.reference("RAGE", "Aimbot", "Double tap")},
        hide = {ui.reference("AA", "Other", "On shot anti-aim")},
        slow = {ui.reference("AA", "Other", "Slow motion")},
    }
}

local Tools = {
    get_player_state = function()
        local local_player = entity.get_local_player()
        if not local_player or not entity.is_alive(local_player) then return nil end
        
        local flags = entity.get_prop(local_player, "m_fFlags")
        local on_ground = bit.band(flags, 1) == 1
        local ducking = entity.get_prop(local_player, "m_flDuckAmount") > 0.1
        local vx, vy = entity.get_prop(local_player, "m_vecVelocity")
        local velocity = math.sqrt(vx * vx + vy * vy)
        local moving = velocity > 1.1
        
        local dt_active = ui.get(Ref.Misc.dt[1]) and ui.get(Ref.Misc.dt[2])
        local hs_active = ui.get(Ref.Misc.hide[1]) and ui.get(Ref.Misc.hide[2])
        local sw_active = ui.get(Ref.Misc.slow[1]) and ui.get(Ref.Misc.slow[2])
        
        if hs_active then return "Hide shot" end
        if not dt_active and not hs_active then return "Fake lag" end
        
        local state = "Standing"
        if not on_ground then
            state = ducking and "Air duck" or "Air"
        elseif ducking then
            state = moving and "Duck moving" or "Duck"
        elseif moving then
            state = sw_active and "Slow motion" or "Moving"
        else
            state = "Standing"
        end
        
        return state
    end,
    
    get_weapon_class = function()
        local local_player = entity.get_local_player()
        if not local_player then return "regular" end
        
        local weapon = entity.get_player_weapon(local_player)
        if not weapon then return "regular" end
        
        local classname = entity.get_classname(weapon)
        
        if classname == "CKnife" or classname == "CWeaponTaser" then
            return "knife"
        elseif classname:find("Grenade") or classname:find("Flashbang") or classname:find("Smoke") or classname:find("Molotov") or classname:find("Decoy") or classname:find("HEGrenade") then
            return "grenade"
        else
            return "regular"
        end
    end,
    
    states = {"Standing", "Moving", "Air", "Air duck", "Duck", "Duck moving", "Slow motion", "Fake lag", "Hide shot"}
}

local defensive = {cmd = 0, check = 0, defensive = 0}

client.set_event_callback("run_command", function(e)
    defensive.cmd = e.command_number
end)

client.set_event_callback("predict_command", function(e)
    if e.command_number == defensive.cmd then
        local tickbase = entity.get_prop(entity.get_local_player(), "m_nTickBase")
        defensive.defensive = math.abs(tickbase - defensive.check)
        defensive.check = math.max(tickbase, defensive.check or 0)
        defensive.cmd = 0
    end
end)

client.set_event_callback("level_init", function()
    defensive.check, defensive.defensive = 0, 0
end)

local Recorder = {
    active = false,
    data = {},
    current_recording = nil,
    tick_count = 0,
    required_ticks = 64,
    state_progress = {},
    weapon_class = "regular",
    last_weapon_class = "regular"
}

for _, state in ipairs(Tools.states) do
    Recorder.state_progress[state] = {ticks_recorded = 0, samples = {}, complete = false}
end

local function read_aa_settings()
    local is_defensive = (defensive.defensive > 1 and defensive.defensive < 14)
    
    return {
        enabled = ui.get(Ref.AA.enabled),
        pitch = ui.get(Ref.AA.pitch[1]),
        yaw_base = ui.get(Ref.AA.yaw_base),
        yaw_mode = ui.get(Ref.AA.yaw[1]),
        yaw_value = ui.get(Ref.AA.yaw[2]),
        jitter_mode = ui.get(Ref.AA.jitter[1]),
        jitter_value = ui.get(Ref.AA.jitter[2]),
        body_mode = ui.get(Ref.AA.body[1]),
        body_value = ui.get(Ref.AA.body[2]),
        roll = ui.get(Ref.AA.roll),
        is_defensive = is_defensive,
    }
end

local function analyze_pattern(samples)
    if #samples == 0 then return nil end
    
    local normal_samples = {}
    local defensive_samples = {}
    
    for _, sample in ipairs(samples) do
        if sample.is_defensive then
            table.insert(defensive_samples, sample)
        else
            table.insert(normal_samples, sample)
        end
    end
    
    local yaw_values = {}
    
    if #normal_samples > 0 then
        local last_yaw = normal_samples[1].yaw_value
        local tick_count = 1
        
        for i = 2, #normal_samples do
            if normal_samples[i].yaw_value ~= last_yaw then
                table.insert(yaw_values, {value = last_yaw, ticks = tick_count})
                last_yaw = normal_samples[i].yaw_value
                tick_count = 1
            else
                tick_count = tick_count + 1
            end
        end
        table.insert(yaw_values, {value = last_yaw, ticks = tick_count})
    end
    
    local pattern = {
        type = "Static",
        values = {},
        delay = 0,
        modifier = normal_samples[1] and normal_samples[1].jitter_mode or "Off",
        modifier_value = normal_samples[1] and normal_samples[1].jitter_value or 0,
        body_mode = normal_samples[1] and normal_samples[1].body_mode or "Static",
        body_value = normal_samples[1] and normal_samples[1].body_value or 0,
        pitch = normal_samples[1] and normal_samples[1].pitch or "Default",
        yaw_base = normal_samples[1] and normal_samples[1].yaw_base or "Local view",
        defensive = {}
    }
    
    if #yaw_values == 1 then
        pattern.type = "Static"
        pattern.values = {yaw_values[1].value}
    elseif #yaw_values == 2 then
        pattern.type = "Jitter L/R"
        pattern.values = {yaw_values[1].value, yaw_values[2].value}
        pattern.delay = math.floor((yaw_values[1].ticks + yaw_values[2].ticks) / 2)
    elseif #yaw_values > 2 then
        pattern.type = "Delay Jitter"
        pattern.values = {yaw_values[1].value, yaw_values[2].value}
        pattern.delay = yaw_values[1].ticks
    end
    
    if #defensive_samples > 0 then
        local def_pitch = defensive_samples[1].pitch
        local def_yaw_values = {}
        
        for _, sample in ipairs(defensive_samples) do
            table.insert(def_yaw_values, sample.yaw_value)
        end
        
        local unique_yaws = {}
        for _, yaw in ipairs(def_yaw_values) do
            unique_yaws[yaw] = true
        end
        
        local unique_count = 0
        for _ in pairs(unique_yaws) do
            unique_count = unique_count + 1
        end
        
        if unique_count > 5 then
            pattern.defensive.yaw_type = "Spin"
            pattern.defensive.yaw_value = 0
        else
            pattern.defensive.yaw_type = "Static Break"
            pattern.defensive.yaw_value = def_yaw_values[1] or 0
        end
        
        if def_pitch == "Down" then
            pattern.defensive.pitch = "Down"
        elseif def_pitch == "Up" then
            pattern.defensive.pitch = "Up"
        elseif def_pitch == "Off" then
            pattern.defensive.pitch = "Zero"
        else
            pattern.defensive.pitch = "Off"
        end
    else
        pattern.defensive.yaw_type = "Off"
        pattern.defensive.yaw_value = 0
        pattern.defensive.pitch = "Off"
    end
    
    return pattern
end

local function record_tick()
    if not Recorder.active then return end
    
    local local_player = entity.get_local_player()
    if not local_player or not entity.is_alive(local_player) then return end
    
    local state = Tools.get_player_state()
    if not state then return end
    
    local weapon_class = Tools.get_weapon_class()
    
    if weapon_class ~= Recorder.last_weapon_class then
        Recorder.last_weapon_class = weapon_class
    end
    
    Recorder.weapon_class = weapon_class
    
    local settings = read_aa_settings()
    settings.tick = Recorder.tick_count
    settings.state = state
    settings.weapon_class = weapon_class
    
    local progress = Recorder.state_progress[state]
    
    if not progress.complete then
        table.insert(progress.samples, settings)
        progress.ticks_recorded = progress.ticks_recorded + 1
        
        if progress.ticks_recorded >= Recorder.required_ticks then
            progress.complete = true
            client.color_log(100, 255, 100, "[AA Recorder] \0")
            client.color_log(255, 255, 255, "State '" .. state .. "' recording complete! (" .. progress.ticks_recorded .. " ticks)")
        end
    else
        table.insert(progress.samples, settings)
        progress.ticks_recorded = progress.ticks_recorded + 1
    end
    
    Recorder.tick_count = Recorder.tick_count + 1
end

local function generate_config()
    local config = {}
    
    for _, state in ipairs(Tools.states) do
        local progress = Recorder.state_progress[state]
        
        if progress.ticks_recorded > 0 then
            local pattern = analyze_pattern(progress.samples)
            
            if pattern then
                config[state] = {
                    Override = true,
                    Pitch = pattern.pitch or "Default",
                    YawBase = pattern.yaw_base or "Local view",
                    YawMode = pattern.type,
                    YawStatic = pattern.type == "Static" and pattern.values[1] or 0,
                    YawLeft = (#pattern.values >= 2 and pattern.values[1]) or 0,
                    YawRight = (#pattern.values >= 2 and pattern.values[2]) or 0,
                    YawDelay = pattern.delay or 2,
                    YawModifier = pattern.modifier or "Off",
                    YawModifierValue = pattern.modifier_value or 0,
                    BodyYaw = pattern.body_mode or "Static",
                    BodyYawValue = math.floor((pattern.body_value or 0) / 3),
                    DefensiveForce = {},
                    DefensivePitch = pattern.defensive.pitch or "Off",
                    DefensiveYaw = pattern.defensive.yaw_type or "Off",
                    DefensiveYawValue = pattern.defensive.yaw_value or 0
                }
            end
        end
    end
    
    return config
end

local function save_recording()
    local map_name = globals.mapname() or "unknown"
    local timestamp = math.floor(globals.realtime())
    local recording_name = map_name .. "_" .. timestamp
    
    local db = database.read("aa_recordings") or {}
    
    local recording_data = {
        name = recording_name,
        timestamp = timestamp,
        map = map_name,
        weapon_class = Recorder.weapon_class,
        total_ticks = Recorder.tick_count,
        states = {},
        config = generate_config()
    }
    
    for _, state in ipairs(Tools.states) do
        local progress = Recorder.state_progress[state]
        recording_data.states[state] = {
            ticks_recorded = progress.ticks_recorded,
            complete = progress.complete
        }
    end
    
    db[recording_name] = recording_data
    database.write("aa_recordings", db)
    
    Recorder.current_recording = recording_name
    
    client.color_log(137, 156, 255, "[AA Recorder] \0")
    client.color_log(255, 255, 255, "Recording saved as: " .. recording_name)
    
    return recording_name
end

local function save_to_drogaria()
    if not Recorder.current_recording then
        client.color_log(255, 100, 100, "[AA Recorder] \0")
        client.color_log(255, 255, 255, "No recording available to save!")
        return
    end
    
    local db = database.read("aa_recordings") or {}
    local recording_data = db[Recorder.current_recording]
    
    if not recording_data then
        client.color_log(255, 100, 100, "[AA Recorder] \0")
        client.color_log(255, 255, 255, "Recording data not found!")
        return
    end
    
    local drogaria_config = {
        MainSwitch = true,
        MainTab = "Anti-Aim",
        AntiAim = {SubTab = "Builder"},
        Home = {ConfigName = "Recorded_" .. recording_data.name, ConfigList = 0},
        Builder = {StateSelector = "Global"},
        Visuals = {},
        Misc = {},
        Extras = {}
    }
    
    drogaria_config.Builder["Global"] = {
        YawRight = 0,
        Override = true,
        YawModifierValue = 0,
        DefensiveYaw = "Off",
        DefensivePitch = "Off",
        BodyYaw = "Static",
        YawModifier = "Off",
        BodyYawValue = 0,
        DefensiveForce = {"~"},
        YawMode = "Static",
        YawStatic = 0,
        YawLeft = 0,
        Pitch = "Default",
        DefensiveYawValue = 0,
        YawDelay = 5,
        YawBase = "Local view"
    }
    
    for state, config in pairs(recording_data.config) do
        drogaria_config.Builder[state] = {
            YawRight = config.YawRight or 0,
            Override = config.Override or false,
            YawModifierValue = config.YawModifierValue or 0,
            DefensiveYaw = config.DefensiveYaw or "Off",
            DefensivePitch = config.DefensivePitch or "Off",
            BodyYaw = config.BodyYaw or "Static",
            YawModifier = config.YawModifier or "Off",
            BodyYawValue = config.BodyYawValue or 0,
            DefensiveForce = {"~"},
            YawMode = config.YawMode or "Static",
            YawStatic = config.YawStatic or 0,
            YawLeft = config.YawLeft or 0,
            Pitch = config.Pitch or "Default",
            DefensiveYawValue = config.DefensiveYawValue or 0,
            YawDelay = config.YawDelay or 5,
            YawBase = config.YawBase or "Local view"
        }
    end
    
    local drogaria_db = database.read("drogaria_yaw_configs") or {}
    local config_name = "Recorded_" .. recording_data.name
    local encrypted = base64.encode(json.stringify(drogaria_config))
    
    drogaria_db[config_name] = encrypted
    database.write("drogaria_yaw_configs", drogaria_db)
    
    client.color_log(100, 255, 100, "[AA Recorder] \0")
    client.color_log(255, 255, 255, "Saved to Drogaria Yaw as: '" .. config_name .. "'")
    client.color_log(255, 255, 100, "Load it from the Drogaria Yaw config list!")
end

local menu = {}

local function start_stop_callback()
    if not Recorder.active then
        Recorder.active = true
        Recorder.tick_count = 0
        Recorder.weapon_class = Tools.get_weapon_class()
        Recorder.last_weapon_class = Recorder.weapon_class
        Recorder.current_recording = nil
        
        for _, state in ipairs(Tools.states) do
            Recorder.state_progress[state] = {ticks_recorded = 0, samples = {}, complete = false}
        end
        
        ui.set(menu.start_stop, "Stop Recording")
        if menu.save_to_drogaria then
            ui.set_visible(menu.save_to_drogaria, false)
        end
        client.color_log(100, 255, 100, "[AA Recorder] \0")
        client.color_log(255, 255, 255, "Recording started! Weapon class: " .. Recorder.weapon_class)
    else
        Recorder.active = false
        ui.set(menu.start_stop, "Start Recording")
        
        client.color_log(255, 100, 100, "[AA Recorder] \0")
        client.color_log(255, 255, 255, "Recording stopped! Total ticks: " .. Recorder.tick_count)
        
        save_recording()
        
        if menu.save_to_drogaria then
            ui.set_visible(menu.save_to_drogaria, true)
        end
    end
end

menu.label = ui.new_label("AA", "Anti-aimbot angles", "─── AA Reverse Engineer ───")
menu.start_stop = ui.new_button("AA", "Anti-aimbot angles", "Start Recording", start_stop_callback)
menu.save_to_drogaria = ui.new_button("AA", "Anti-aimbot angles", "Save to Drogaria Yaw", save_to_drogaria)

ui.set_visible(menu.save_to_drogaria, false)

local function draw_indicator()
    if not Recorder.active then return end
    
    local screen_x, screen_y = client.screen_size()
    local x = screen_x - 300
    local y = 100
    
    renderer.rectangle(x, y, 280, 240, 20, 20, 20, 200)
    renderer.rectangle(x, y, 280, 25, 137, 156, 255, 255)
    
    renderer.text(x + 140, y + 5, 255, 255, 255, 255, "c", 0, "AA RECORDER")
    
    renderer.text(x + 10, y + 30, 255, 255, 100, 255, "", 0, "Weapon: " .. Recorder.weapon_class:upper())
    renderer.text(x + 10, y + 45, 200, 200, 200, 255, "", 0, "Total Ticks: " .. Recorder.tick_count)
    
    local offset = 65
    for i, state in ipairs(Tools.states) do
        local progress = Recorder.state_progress[state]
        local percentage = math.min(100, (progress.ticks_recorded / Recorder.required_ticks) * 100)
        local color = progress.complete and {100, 255, 100} or {255, 200, 100}
        
        renderer.text(x + 10, y + offset, color[1], color[2], color[3], 255, "", 0, state)
        
        local bar_width = 150
        local bar_x = x + 120
        renderer.rectangle(bar_x, y + offset, bar_width, 12, 40, 40, 40, 200)
        renderer.rectangle(bar_x, y + offset, (bar_width * percentage / 100), 12, color[1], color[2], color[3], 255)
        
        renderer.text(x + 275, y + offset, 200, 200, 200, 255, "r", 0, progress.ticks_recorded)
        
        offset = offset + 17
    end
end

client.set_event_callback("setup_command", record_tick)
client.set_event_callback("paint", draw_indicator)

client.color_log(137, 156, 255, "[AA Recorder] \0")
client.color_log(255, 255, 255, "Loaded! Use 'Start Recording' button to begin.")
