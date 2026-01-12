-- This lua was made if love by devlux
local pui = require("gamesense/pui")
local base64 = require("gamesense/base64")
local ffi = require("ffi")

local clipboard = {
    ffi = ffi.cdef([[
        typedef int(__thiscall* get_clipboard_text_count)(void*);
        typedef void(__thiscall* set_clipboard_text)(void*, const char*, int);
        typedef void(__thiscall* get_clipboard_text)(void*, int, const char*, int);
    ]]),
    export = function(text)
        local ptr = ffi.cast(ffi.typeof('void***'), client.create_interface('vgui2.dll', 'VGUI_System010'))
        local func = ffi.cast('set_clipboard_text', ptr[0][9])
        func(ptr, text, #text)
    end,
    import = function()
        local ptr = ffi.cast(ffi.typeof('void***'), client.create_interface('vgui2.dll', 'VGUI_System010'))
        local func = ffi.cast('get_clipboard_text_count', ptr[0][7])
        local len = func(ptr)
        if len > 0 then
            local buffer = ffi.new("char[?]", len)
            local size = len * ffi.sizeof("char[?]", len)
            local get_func = ffi.cast('get_clipboard_text', ptr[0][11])
            get_func(ptr, 0, buffer, size)
            return ffi.string(buffer, len - 1)
        end
        return ""
    end
}

local function rgb2hex(r, g, b)
    return string.format("%02X%02X%02XFF", r, g, b)
end

pui.accent = rgb2hex(ui.get(ui.reference("Misc", "Settings", "Menu color")))
pui.macros.title = "Drogaria Yaw"

local Tools = {
    skeet_menu_visibility = function(state, refs)
        for key, ref in pairs(refs) do
            if type(ref) == "table" then
                for _, r in ipairs(ref) do
                    ui.set_visible(r, state)
                end
            else
                ui.set_visible(ref, state)
            end
        end
    end,
    
    get_player_state = function()
        local local_player = entity.get_local_player()
        if not local_player or not entity.is_alive(local_player) then
            return "Global"
        end
        
        local flags = entity.get_prop(local_player, "m_fFlags")
        local on_ground = bit.band(flags, 1) == 1
        local ducking = entity.get_prop(local_player, "m_flDuckAmount") > 0.1
        local vx, vy = entity.get_prop(local_player, "m_vecVelocity")
        local velocity = math.sqrt(vx * vx + vy * vy)
        local moving = velocity > 1.1
        
        local dt_active = ui.get(Ref.Misc.dt[1]) and ui.get(Ref.Misc.dt[2])
        local hs_active = ui.get(Ref.Misc.hide[1]) and ui.get(Ref.Misc.hide[2])
        local sw_active = ui.get(Ref.Misc.slow[1]) and ui.get(Ref.Misc.slow[2])
        
        if hs_active and ui.get(Menu.Builder["Hide shot"].Override.ref) then
            return "Hide shot"
        end
        
        if not dt_active and not hs_active and ui.get(Menu.Builder["Fake lag"].Override.ref) then
            return "Fake lag"
        end
        
        local state = "Global"
        
        if not on_ground then
            state = ducking and "Air duck" or "Air"
        elseif ducking then
            state = moving and "Duck moving" or "Duck"
        elseif moving then
            state = sw_active and "Slow motion" or "Moving"
        else
            state = "Standing"
        end
        
        if Menu.Builder[state] and not ui.get(Menu.Builder[state].Override.ref) then
            return "Global"
        end
        
        return state
    end,
    
    states = {
        "Global", "Standing", "Moving", "Air", "Air duck", 
        "Duck", "Duck moving", "Slow motion", "Fake lag", "Hide shot"
    },

    distance = function(x1, y1, z1, x2, y2, z2)
        return math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2) + (z1 - z2) * (z1 - z2))
    end,

    extrapolate = function(player, ticks, x, y, z)
        local xv, yv, zv = entity.get_prop(player, "m_vecVelocity")
        local new_x = x + globals.tickinterval() * xv * ticks
        local new_y = y + globals.tickinterval() * yv * ticks
        local new_z = z + globals.tickinterval() * zv * ticks
        return new_x, new_y, new_z
    end,

    get_foot_center = function(ent)
        local lx, ly = entity.hitbox_position(ent, 6)
        local rx, ry = entity.hitbox_position(ent, 7)
        if not lx or not rx then return nil end
        return {x = (lx + rx) * 0.5, y = (ly + ry) * 0.5}
    end,

    any_enemy_visible = function()
        local enemies = entity.get_players(true)
        for i = 1, #enemies do
            if not entity.is_dormant(enemies[i]) then
                return true
            end
        end
        return false
    end
}

Ref = {
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
        fd = {ui.reference("RAGE", "Other", "Duck peek assist")},
        hide = {ui.reference("AA", "Other", "On shot anti-aim")},
        slow = {ui.reference("AA", "Other", "Slow motion")},
        fakelag = {ui.reference("AA", "Fake lag", "Limit")},
        quickpeek = {ui.reference("RAGE", "Other", "Quick peek assist")},
        legs = ui.reference("AA", "Other", "Leg movement"),
        thirdperson = {ui.reference("VISUALS", "Effects", "Force third person (alive)")}
    }
}
local Visuals = {
    notifications = {},
    max_notifications = 6,
    notification_duration = 5,
    notification_fade = 0.5,
    thirdperson_distance = 100,
    thirdperson_target = 100,
    watermark_alpha = 0,
    zeus_warning_alpha = 0,
    damage_markers = {},
}

local Misc = {
    clantag_enabled = false,
    clantag_prev = "",
    last_anim_update = 0
}
local ground_ticks = 0

local trashtalk_phrases = {
    "1",
    "sit down kid",
    "too ez",
    "nice try",
    "?",
    "ff pls",
    "uninstall",
    "outplayed",
    "gg ez",
    "cry more",
    "mad?",
    "skill diff",
    "lucky shot?",
    "sit",
    "owned"
}
local aa_group = pui.group("AA", "Anti-aimbot angles")
local other_group = pui.group("AA", "Other")

local AntiAim = {
    delay_ticks = 0,
    jitter_side = false,
    body_side = false,
    defensive_active = false,
    defensive_cmd = 0,
    defensive_check = 0,
    defensive_value = 0,
    spin_angle = 0,
    manual_yaw = 0,
    manual_input = 0,
    freestand_side = 0,
    peek_origin = nil,
    peek_was_pressed = false,
    peek_original_yaw = nil,
    peek_deadzone = 10,
    saved_fl_limit = nil
}

local defensive = {
    cmd = 0,
    check = 0,
    defensive = 0
}

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

Menu = {
    MainSwitch = aa_group:checkbox("\v\f<title>"),
    MainTab = aa_group:combobox("\vTab", {"Home", "Anti-Aim", "Visuals", "Misc"}),
    
    Home = {
        Label1 = aa_group:label("\vConfig System"),
        ConfigList = aa_group:listbox("\vConfigs", "-"),
        ConfigName = aa_group:textbox("\vConfig Name"),
        SaveBtn = aa_group:button("\vSave Config", function()
            local name = ui.get(Menu.Home.ConfigName.ref)
            if name == "" then
                client.color_log(255, 100, 100, "[Error] \0")
                client.color_log(255, 255, 255, "Config name cannot be empty!")
                return
            end
            
            local config_data = ConfigSystem:save()
            local encrypted = base64.encode(json.stringify(config_data))
            
            local db = database.read("drogaria_yaw_configs") or {}
            db[name] = encrypted
            database.write("drogaria_yaw_configs", db)
            
            ConfigSystem.update_list()
            
            local names = ConfigSystem.get_config_names()
            for i, config_name in ipairs(names) do
                if config_name == name then
                    ui.set(Menu.Home.ConfigList.ref, i - 1)
                    break
                end
            end
            
            client.color_log(137, 156, 255, "[Success] \0")
            client.color_log(255, 255, 255, "Config '" .. name .. "' saved!")
        end),
        LoadBtn = aa_group:button("\vLoad Config", function()
            local idx = ui.get(Menu.Home.ConfigList.ref)
            local names = ConfigSystem.get_config_names()
            
            if #names == 0 or idx < 0 or idx >= #names then
                client.color_log(255, 100, 100, "[Error] \0")
                client.color_log(255, 255, 255, "Select a config first!")
                return
            end
            
            local name = names[idx + 1]
            local db = database.read("drogaria_yaw_configs") or {}
            
            if db[name] then
                local success, data = pcall(json.parse, base64.decode(db[name]))
                if success then
                    ConfigSystem:load(data)
                    client.color_log(137, 156, 255, "[Success] \0")
                    client.color_log(255, 255, 255, "Config '" .. name .. "' loaded!")
                else
                    client.color_log(255, 100, 100, "[Error] \0")
                    client.color_log(255, 255, 255, "Failed to load config!")
                end
            end
        end),
        DeleteBtn = aa_group:button("\vDelete Config", function()
            local idx = ui.get(Menu.Home.ConfigList.ref)
            local names = ConfigSystem.get_config_names()
            
            if #names == 0 or idx < 0 or idx >= #names then
                client.color_log(255, 100, 100, "[Error] \0")
                client.color_log(255, 255, 255, "Select a config first!")
                return
            end
            
            local name = names[idx + 1]
            local db = database.read("drogaria_yaw_configs") or {}
            db[name] = nil
            database.write("drogaria_yaw_configs", db)
            
            ConfigSystem.update_list()
            
            local new_names = ConfigSystem.get_config_names()
            if #new_names > 0 then
                local new_idx = math.min(idx, #new_names - 1)
                ui.set(Menu.Home.ConfigList.ref, new_idx)
            end
            
            client.color_log(137, 156, 255, "[Success] \0")
            client.color_log(255, 255, 255, "Config '" .. name .. "' deleted!")
        end),
        RefreshBtn = aa_group:button("\vRefresh List", function()
            ConfigSystem.update_list()
        end),
        
        Label2 = aa_group:label("\vImport/Export"),
        ImportBtn = aa_group:button("\vImport from Clipboard", function()
            local code = clipboard.import()
            if code == "" then
                client.color_log(255, 100, 100, "[Error] \0")
                client.color_log(255, 255, 255, "Clipboard is empty!")
                return
            end
            
            local success, data = pcall(json.parse, base64.decode(code))
            if success then
                ConfigSystem:load(data)
                client.color_log(137, 156, 255, "[Success] \0")
                client.color_log(255, 255, 255, "Config imported!")
            else
                client.color_log(255, 100, 100, "[Error] \0")
                client.color_log(255, 255, 255, "Invalid config code!")
            end
        end),
        ExportBtn = aa_group:button("\vExport to Clipboard", function()
            local idx = ui.get(Menu.Home.ConfigList.ref)
            local names = ConfigSystem.get_config_names()
            
            if #names == 0 or idx < 0 or idx >= #names then
                client.color_log(255, 100, 100, "[Error] \0")
                client.color_log(255, 255, 255, "Select a config first!")
                return
            end
            
            local name = names[idx + 1]
            local db = database.read("drogaria_yaw_configs") or {}
            
            if db[name] then
                local encrypted = db[name]
                clipboard.export(encrypted)
                client.color_log(137, 156, 255, "[Success] \0")
                client.color_log(255, 255, 255, "Config '" .. name .. "' copied to clipboard!")
            else
                client.color_log(255, 100, 100, "[Error] \0")
                client.color_log(255, 255, 255, "Config not found!")
            end
        end)
    },
    
    AntiAim = {
        SubTab = aa_group:combobox("\vAA Section", {"Builder", "Extras"})
    },
    
    Builder = {
        StateSelector = aa_group:combobox("\vState", Tools.states)
    },
    
    Extras = {
        AntiBackstab = aa_group:checkbox("\rAnti-Backstab"),
        AntiBackstabDistance = aa_group:slider("\rBackstab Distance", 100, 500, 250, true, "u"),
        
        PeekYaw = aa_group:checkbox("\vPeek Yaw", false),
        
        Freestand = aa_group:checkbox("\rFreestand", false),
        FreestandKey = aa_group:hotkey("\rFreestand Key", true),
        
        UnbalancedDormant = aa_group:checkbox("\vUnbalanced Dormant AA"),
        
        SafeHeadKnife = aa_group:checkbox("\rSafe Head on Knife"),
        
        FastLadder = aa_group:checkbox("\rFast Ladder"),
        FastLadderModes = aa_group:multiselect("\rLadder Modes", {"Ascending", "Descending"}),
        
        DisableFLExploits = aa_group:checkbox("\rDisable FL on Exploits"),
    },
    
    Visuals = {
        Watermark = aa_group:checkbox("\vWatermark"),
        WatermarkColor = aa_group:color_picker("\vWatermark Color", 137, 156, 255, 255),
        
        HitLogs = aa_group:checkbox("\rHit/Miss Logs"),
        LogsColor = aa_group:color_picker("\rLogs Color", 137, 156, 255, 255),

        ConsoleLogs = aa_group:checkbox("\vConsole Logs"),
        
        DamageMarker = aa_group:checkbox("\v3D Damage Marker"),
        DamageMarkerColor = aa_group:color_picker("\vDamage Marker Color", 255, 255, 255, 255),
        
        ZeusWarning = aa_group:checkbox("\rZeus Warning"),
        ZeusWarningDistance = aa_group:slider("\rZeus Distance", 200, 700, 500, true, "u"),
        
        ThirdpersonAnim = aa_group:checkbox("\vThirdperson"),
        ThirdpersonMin = aa_group:slider("\rDistance", 50, 300, 100, true, "u")

    },
    
    Misc = {
        Clantag = aa_group:checkbox("\vClantag"),
        
        Trashtalk = aa_group:checkbox("\rTrashtalk"),
        
        AnimBreaker = aa_group:checkbox("\vAnimation Breakers"),
        AnimBreakerModes = aa_group:multiselect("\vAnim Modes", {"Static legs", "Air legs", "Leg fucker"}),

    }
}

for _, state in ipairs(Tools.states) do
    pui.macros.state = state
    
    Menu.Builder[state] = {
        Override = aa_group:checkbox(pui.format("\aFFFFFFFF Override \v\f<state>")),
        
        Pitch = aa_group:combobox(pui.format("\vPitch"), {"Default", "Down", "Up"}),
        
        YawBase = aa_group:combobox(pui.format("\vYaw"), {"Local view", "At targets"}),
        
        YawMode = aa_group:combobox(pui.format("Yaw Type"), {"Static", "Delay Jitter", "Jitter L/R"}),
        YawStatic = aa_group:slider(pui.format("\r Static"), -180, 180, 0, true, "°"),
        YawLeft = aa_group:slider(pui.format("\r Left"), -180, 180, -45, true, "°"),
        YawRight = aa_group:slider(pui.format("\r Right"), -180, 180, 45, true, "°"),
        YawDelay = aa_group:slider(pui.format("\r Delay"), 2, 15, 5, true, "t"),
        
        YawModifier = aa_group:combobox(pui.format("\r Yaw Modifier"), {"Off", "Offset", "Center", "Skitter"}),
        YawModifierValue = aa_group:slider(pui.format("\r Modifier Amount"), -180, 180, 0, true, "°"),
        
        BodyYaw = aa_group:combobox(pui.format("\v Body Yaw"), {"Static", "Jitter"}),
        BodyYawValue = aa_group:slider(pui.format("\r Body Yaw Amount"), -60, 60, 0, true, "°"),
        
        DefensiveLabel = other_group:label(pui.format("\v\f<state>\r \aFFFFFFFFDefensive Settings")),
        DefensiveForce = other_group:multiselect(pui.format("\r Force On"), {"Doubletap", "Hideshots"}),
        DefensivePitch = other_group:combobox(pui.format("\r Def Pitch"), {"Off", "Down", "Up","Zero"}),
        DefensiveYaw = other_group:combobox(pui.format("\r Def Yaw"), {"Off", "Static Break", "Spin"}),
        DefensiveYawValue = other_group:slider(pui.format("\r Def Yaw Amount"), -180, 180, 0, true, "°"),
    }
end

ConfigSystem = pui.setup(Menu)

ConfigSystem.get_config_names = function()
    local db = database.read("drogaria_yaw_configs") or {}
    local names = {}
    for name in pairs(db) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

ConfigSystem.update_list = function()
    local names = ConfigSystem.get_config_names()
    
    if #names == 0 then
        ui.update(Menu.Home.ConfigList.ref, "-")
    else
        ui.update(Menu.Home.ConfigList.ref, names)
    end
end

local function add_notification(text, r, g, b)
    table.insert(Visuals.notifications, {
        text = text,
        time = globals.realtime(),
        r = r or 255,
        g = g or 255,
        b = b or 255,
        alpha = 0
    })
    
    while #Visuals.notifications > Visuals.max_notifications do
        table.remove(Visuals.notifications, 1)
    end
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function draw_notifications()
    local screen_x, screen_y = client.screen_size()
    local y_offset = screen_y - 300
    local time = globals.frametime()
    
    for i = #Visuals.notifications, 1, -1 do
        local notif = Visuals.notifications[i]
        local life_time = globals.realtime() - notif.time
        
        if life_time > Visuals.notification_duration then
            table.remove(Visuals.notifications, i)
        else
            local alpha = 255
            if life_time < Visuals.notification_fade then
                alpha = lerp(0, 255, life_time / Visuals.notification_fade)
            elseif life_time > Visuals.notification_duration - Visuals.notification_fade then
                local fade_progress = (life_time - (Visuals.notification_duration - Visuals.notification_fade)) / Visuals.notification_fade
                alpha = lerp(255, 0, fade_progress)
            end
            
            notif.alpha = lerp(notif.alpha, alpha, time * 8)
            
            renderer.text(screen_x/2 - 10, y_offset, notif.r, notif.g, notif.b, notif.alpha, "c", 0, notif.text)
            y_offset = y_offset - 20
        end
    end
end

local function on_aim_hit(e)
    local target_name = entity.get_player_name(e.target)
    local hitgroup = ({"generic", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck"})[e.hitgroup + 1] or "body"
    local damage = e.damage
    local health = entity.get_prop(e.target, "m_iHealth")
    
    local r, g, b = ui.get(Menu.Visuals.LogsColor.ref)
    local text = string.format("%s in the %s for %d damage (%d health remaining)", target_name, hitgroup, damage, health)
    
    if ui.get(Menu.Visuals.HitLogs.ref) then
        add_notification(string.format("Hit %s in the %s for %d damage (%d health remaining)", target_name, hitgroup, damage, health), r, g, b)
    end
    
    if ui.get(Menu.Visuals.ConsoleLogs.ref) then
        client.color_log(172, 224, 13, "[+] \0")
        client.color_log(255, 255, 255, text)
    end
end


local function on_aim_miss(e)
    local target_name = entity.get_player_name(e.target)
    local hitgroup = ({"generic", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck"})[e.hitgroup + 1] or "body"
    local reason = e.reason
    
    local text = string.format("%s's %s due to %s", target_name, hitgroup, reason)
    
    if ui.get(Menu.Visuals.HitLogs.ref) then
        add_notification(string.format("Missed %s's %s due to %s", target_name, hitgroup, reason), 255, 100, 100)
    end
    
    if ui.get(Menu.Visuals.ConsoleLogs.ref) then
        client.color_log(255, 0, 0, "[-] \0")
        client.color_log(255, 255, 255, text)
    end
end

local function on_player_hurt(e)
    if not ui.get(Menu.Visuals.DamageMarker.ref) then return end
    
    local attacker = client.userid_to_entindex(e.attacker)
    local victim = client.userid_to_entindex(e.userid)
    
    if attacker ~= entity.get_local_player() then return end
    if not entity.is_enemy(victim) then return end
    
    local x, y, z = entity.hitbox_position(victim, 0)
    if not x then return end
    
    table.insert(Visuals.damage_markers, {
        x = x,
        y = y,
        z = z + 50,
        damage = e.dmg_health,
        time = globals.realtime(),
        alpha = 255,
        hitbox = e.hitgroup,
    })
end

local function draw_damage_markers()
    if not ui.get(Menu.Visuals.DamageMarker.ref) then return end
    
 
    local r, g, b = ui.get(Menu.Visuals.DamageMarkerColor.ref)
    local time = globals.frametime()
    
    for i = #Visuals.damage_markers, 1, -1 do
        local marker = Visuals.damage_markers[i]
        local life_time = globals.realtime() - marker.time
        
        if life_time > 4 then
            table.remove(Visuals.damage_markers, i)
        else
            marker.z = marker.z + 50 * time
            marker.alpha = lerp(marker.alpha, 0, time * 2)
            Head = marker.hitbox
            if Head == 1 then
                r, g, b = 117, 160, 13
            end
            
            local sx, sy = renderer.world_to_screen(marker.x, marker.y, marker.z)
            if sx and sy then

                renderer.text(sx, sy, r, g, b, marker.alpha, "c", 0, "-" .. marker.damage)
            end
        end
    end
end

local function draw_zeus_warning()
    if not ui.get(Menu.Visuals.ZeusWarning.ref) then return end
    
    local local_player = entity.get_local_player()
    if not local_player or not entity.is_alive(local_player) then return end
    
    local lx, ly, lz = entity.get_prop(local_player, "m_vecOrigin")
    local enemies = entity.get_players(true)
    local in_danger = false
    
    for i = 1, #enemies do
        local weapon = entity.get_player_weapon(enemies[i])
        if weapon and entity.get_classname(weapon) == "CWeaponTaser" then
            local ex, ey, ez = entity.get_prop(enemies[i], "m_vecOrigin")
            local distance = Tools.distance(lx, ly, lz, ex, ey, ez)
            
            if distance <= ui.get(Menu.Visuals.ZeusWarningDistance.ref) then
                in_danger = true
                break
            end
        end
    end
    
    local time = globals.frametime()
    Visuals.zeus_warning_alpha = lerp(Visuals.zeus_warning_alpha, in_danger and 255 or 0, time * 10)
    
    if Visuals.zeus_warning_alpha > 5 then
        local screen_x, screen_y = client.screen_size()
        renderer.text(screen_x / 2, screen_y / 2 + 50, 255, 255, 0, Visuals.zeus_warning_alpha, "c", 0, "⚠ ZEUS WARNING ⚠")
    end
end

local function draw_watermark()
    if not ui.get(Menu.Visuals.Watermark.ref) then return end
    
    local time = globals.frametime()
    Visuals.watermark_alpha = lerp(Visuals.watermark_alpha, 255, time * 5)
    
    local r, g, b = ui.get(Menu.Visuals.WatermarkColor.ref)
    local screen_x, screen_y = client.screen_size()
    
    -- Measure text components
    local cs_text = pui.macros.title
    local version_text = "[Anti-Aim]"
    local user_text = entity.get_player_name(entity.get_local_player()) .. " - gamesense"
    
    local cs_w, cs_h = renderer.measure_text("", cs_text)
    local version_w, version_h = renderer.measure_text("", version_text)
    local user_w, user_h = renderer.measure_text("", user_text)
    
    local total_w = cs_w + version_w
    local x_pos = screen_x - total_w - 10
    local y_pos = screen_y / 2 - 30
    

    renderer.text(x_pos, y_pos, 255, 255, 255, Visuals.watermark_alpha, "", 0, cs_text)
    renderer.text(x_pos + cs_w, y_pos, r, g, b, Visuals.watermark_alpha, "", 0, version_text)
    

   -- renderer.gradient(x_pos, y_pos + cs_h, cs_w, 2, 255, 255, 255, Visuals.watermark_alpha * 0.8, 255, 255, 255, 0, true)
   -- renderer.gradient(x_pos + cs_w, y_pos + cs_h, version_w, 2, r, g, b, Visuals.watermark_alpha * 0.8, r, g, b, 0, true)

    renderer.text(x_pos, y_pos + 10, 255, 255, 255, Visuals.watermark_alpha, "", 0, user_text)
end
local function handle_animated_thirdperson()
    if not ui.get(Menu.Visuals.ThirdpersonAnim.ref) then
        cvar.cam_idealdist:set_float(100)
        return
    end
    
    if not ui.get(Ref.Misc.thirdperson[1]) then 
        return 
    end
    
    local local_player = entity.get_local_player()
    if not local_player or not entity.is_alive(local_player) then return end

    local dist = ui.get(Menu.Visuals.ThirdpersonMin.ref)

    cvar.cam_idealdist:set_float(dist)
end

local clantag_data = {
    last_update = 0,
    animation_state = 0,
    direction = 1  -- 1 for forward, -1 for backward
}

local function animate_clantag(text)
    local padding = "               "
    local full_text = padding .. text .. padding
    local max_length = #full_text - 15
    
    -- Update animation every 0.3 seconds
    local current_time = globals.realtime()
    if current_time - clantag_data.last_update >= 0.3 then
        clantag_data.last_update = current_time
        
        -- Move the animation
        clantag_data.animation_state = clantag_data.animation_state + clantag_data.direction
        
        -- Reverse direction at the ends
        if clantag_data.animation_state >= max_length then
            clantag_data.direction = -1
            clantag_data.animation_state = max_length
        elseif clantag_data.animation_state <= 0 then
            clantag_data.direction = 1
            clantag_data.animation_state = 0
        end
    end
    
    local start_pos = clantag_data.animation_state + 1
    return full_text:sub(start_pos, start_pos + 15)
end

local function handle_clantag()
    if not ui.get(Menu.Misc.Clantag.ref) then
        if Misc.clantag_enabled then
            client.set_clan_tag("")
            Misc.clantag_enabled = false
            clantag_data.animation_state = 0
            clantag_data.direction = 1
        end
        return
    end
    
    Misc.clantag_enabled = true
    local text = "Drogaria.yaw"
    
    if globals.tickcount() % 2 == 0 then
        local tag = animate_clantag(text)
        
        if tag ~= Misc.clantag_prev then
            client.set_clan_tag(tag)
            Misc.clantag_prev = tag
        end
    end
end

local function on_player_death(e)
    if not ui.get(Menu.Misc.Trashtalk.ref) then return end
    
    local attacker = client.userid_to_entindex(e.attacker)
    local victim = client.userid_to_entindex(e.userid)
    
    if attacker ~= entity.get_local_player() then return end
    if not entity.is_enemy(victim) then return end
    
    local phrase = trashtalk_phrases[math.random(1, #trashtalk_phrases)]
    client.exec("say " .. phrase)
end

local function handle_anim_breakers()
    if not ui.get(Menu.Misc.AnimBreaker.ref) then
        ui.set(Ref.Misc.legs, "Never slide")
        return
    end
    
    local local_player = entity.get_local_player()
    if not local_player or not entity.is_alive(local_player) then return end
    
    local modes = ui.get(Menu.Misc.AnimBreakerModes.ref)
    local flags = entity.get_prop(local_player, "m_fFlags")
    local on_ground = bit.band(flags, 1) == 1
    
    for _, mode in ipairs(modes) do
        if mode == "Static legs" then
            entity.set_prop(local_player, "m_flPoseParameter", 1, 0)
        end
        
        if mode == "Air legs" and not on_ground then
            entity.set_prop(local_player, "m_flPoseParameter", 1, 6)
        end
        
        if mode == "Leg fucker" then
            local time = globals.realtime()
            if time - Misc.last_anim_update > 0.1 then
                local leg_state = math.random(0, 2)
                ui.set(Ref.Misc.legs, ({"Off", "Always slide", "Never slide"})[leg_state + 1])
                Misc.last_anim_update = time
            end
        end
    end
end

local function normalize_yaw(yaw)
    while yaw > 180 do yaw = yaw - 360 end
    while yaw < -180 do yaw = yaw + 360 end
    return yaw
end

local function handle_anti_backstab(cmd)
    if not ui.get(Menu.Extras.AntiBackstab.ref) then return false end
    
    local local_player = entity.get_local_player()
    if not local_player then return false end
    
    local lx, ly, lz = entity.get_prop(local_player, "m_vecOrigin")
    local enemies = entity.get_players(true)
    
    for i = 1, #enemies do
        local weapon = entity.get_player_weapon(enemies[i])
        if weapon and entity.get_classname(weapon) == "CKnife" then
            local ex, ey, ez = entity.get_prop(enemies[i], "m_vecOrigin")
            local distance = Tools.distance(lx, ly, lz, ex, ey, ez)
            
            if distance <= ui.get(Menu.Extras.AntiBackstabDistance.ref) then
                ui.set(Ref.AA.yaw[2], 180)
                ui.set(Ref.AA.pitch[1], "Off")
                ui.set(Ref.AA.jitter[1], "Off")
                ui.set(Ref.AA.jitter[2], 0)
                ui.set(Ref.AA.body[1], "Opposite")
                ui.set(Ref.AA.body[2], 0)
                return true
            end
        end
    end
    return false
end

local function handle_safe_head_knife(cmd)
    if not ui.get(Menu.Extras.SafeHeadKnife.ref) then return false end
    
    local local_player = entity.get_local_player()
    if not local_player then return false end
    
    local weapon = entity.get_player_weapon(local_player)
    if weapon and entity.get_classname(weapon) == "CKnife" then
        local flags = entity.get_prop(local_player, "m_fFlags")
        local ducking = entity.get_prop(local_player, "m_flDuckAmount") > 0.1
        local on_ground = bit.band(flags, 1) == 1
        
        if not on_ground and ducking then
            ui.set(Ref.AA.pitch[1], "Default")
            ui.set(Ref.AA.yaw_base, "At targets")
            ui.set(Ref.AA.yaw[1], "180")
            ui.set(Ref.AA.yaw[2], 0)
            ui.set(Ref.AA.jitter[1], "Off")
            ui.set(Ref.AA.jitter[2], 0)
            ui.set(Ref.AA.body[1], "Static")
            ui.set(Ref.AA.body[2], 0)
            return true
        end
    end
    return false
end

local function get_freestand_side()
    local local_player = entity.get_local_player()
    if not local_player then return 0 end
    
    local enemy = client.current_threat()
    if not enemy then return 0 end
    
    local lx, ly, lz = entity.get_prop(local_player, "m_vecOrigin")
    local ex, ey, ez = entity.get_prop(enemy, "m_vecOrigin")
    
    local yaw = math.deg(math.atan2(ey - ly, ex - lx))
    
    local left_damage = 0
    local right_damage = 0
    
    local left_yaw = yaw + 90
    local right_yaw = yaw - 90
    
    local left_x = lx + math.cos(math.rad(left_yaw)) * 55
    local left_y = ly + math.sin(math.rad(left_yaw)) * 55
    
    local right_x = lx + math.cos(math.rad(right_yaw)) * 55
    local right_y = ly + math.sin(math.rad(right_yaw)) * 55
    
    local _, left_dmg = client.trace_bullet(enemy, ex, ey, ez + 64, left_x, left_y, lz + 64, true)
    local _, right_dmg = client.trace_bullet(enemy, ex, ey, ez + 64, right_x, right_y, lz + 64, true)
    
    if left_dmg > 0 then return 1 end
    if right_dmg > 0 then return -1 end
    
    return 0
end

local function handle_freestand()
    if not ui.get(Menu.Extras.Freestand.ref) or not ui.get(Menu.Extras.FreestandKey.ref) then 
        ui.set(Ref.AA.freestanding[1], false)
        return false 
    end
    
    local local_player = entity.get_local_player()
    if not local_player then return false end
    
    ui.set(Ref.AA.freestanding[1], true)
    ui.set(Ref.AA.freestanding[2], "Always on")
    AntiAim.freestand_side = get_freestand_side()
    return true
end

local function handle_peek_yaw(cmd)
    if not ui.get(Menu.Extras.PeekYaw.ref) then 
        if AntiAim.peek_was_pressed then
            AntiAim.peek_origin = nil
            AntiAim.peek_was_pressed = false
        end
        return false 
    end
    
    local quickpeek = ui.get(Ref.Misc.quickpeek[1])
    local pressed = ui.get(Ref.Misc.quickpeek[2])
    
    local local_player = entity.get_local_player()
    if not local_player then return false end
    
    if pressed and not AntiAim.peek_was_pressed then
        AntiAim.peek_origin = Tools.get_foot_center(local_player)
        AntiAim.peek_original_yaw = ui.get(Ref.AA.yaw[2])
    end
    
    if not pressed and AntiAim.peek_was_pressed then
        AntiAim.peek_origin = nil
    end
    
    AntiAim.peek_was_pressed = pressed
    
    if AntiAim.peek_origin then
        local hx, hy = entity.hitbox_position(local_player, 1)
        if hx and hy then
            local dx = AntiAim.peek_origin.x - hx
            local dy = AntiAim.peek_origin.y - hy
            local dist = math.sqrt(dx * dx + dy * dy)
            
            if dist > AntiAim.peek_deadzone then
                local angle = math.deg(math.atan2(dy, dx))
                ui.set(Ref.AA.yaw[1], "Static")
                ui.set(Ref.AA.yaw[2], normalize_yaw(angle))
                return true
            end
        end
    end
    
    return false
end

local function handle_fast_ladder(cmd)
    if not ui.get(Menu.Extras.FastLadder.ref) then return end
    
    local local_player = entity.get_local_player()
    if not local_player then return end
    
    if entity.get_prop(local_player, "m_MoveType") ~= 9 then return end
    
    local pitch, yaw = client.camera_angles()
    cmd.yaw = math.floor(cmd.yaw + 0.5)
    cmd.roll = 0
    
    local modes = ui.get(Menu.Extras.FastLadderModes.ref)
    
    for _, mode in ipairs(modes) do
        if mode == "Ascending" and cmd.forwardmove > 0 then
            if pitch < 45 then
                cmd.pitch = 89
                cmd.in_moveright = 1
                cmd.in_moveleft = 0
                cmd.in_forward = 0
                cmd.in_back = 1
                
                if cmd.sidemove == 0 then
                    cmd.yaw = cmd.yaw + 90
                elseif cmd.sidemove < 0 then
                    cmd.yaw = cmd.yaw + 150
                elseif cmd.sidemove > 0 then
                    cmd.yaw = cmd.yaw + 30
                end
            end
        elseif mode == "Descending" and cmd.forwardmove < 0 then
            cmd.pitch = 89
            cmd.in_moveleft = 1
            cmd.in_moveright = 0
            cmd.in_forward = 1
            cmd.in_back = 0
            
            if cmd.sidemove == 0 then
                cmd.yaw = cmd.yaw + 90
            elseif cmd.sidemove > 0 then
                cmd.yaw = cmd.yaw + 150
            else
                cmd.yaw = cmd.yaw + 30
            end
        end
    end
end

local function handle_disable_fl_exploits()
    if not ui.get(Menu.Extras.DisableFLExploits.ref) then
        if AntiAim.saved_fl_limit then
            ui.set(Ref.Misc.fakelag[1], AntiAim.saved_fl_limit)
            AntiAim.saved_fl_limit = nil
        end
        return
    end
    
    local dt_active = ui.get(Ref.Misc.dt[1]) and ui.get(Ref.Misc.dt[2])
    local hs_active = ui.get(Ref.Misc.hide[1]) and ui.get(Ref.Misc.hide[2])
    local fd_active = ui.get(Ref.Misc.fd[1])
    
    if fd_active then
        if AntiAim.saved_fl_limit then
            ui.set(Ref.Misc.fakelag[1], AntiAim.saved_fl_limit)
            AntiAim.saved_fl_limit = nil
        end
        return
    end

    if (dt_active or hs_active) then
        if not AntiAim.saved_fl_limit then
            AntiAim.saved_fl_limit = ui.get(Ref.Misc.fakelag[1])
        end
        ui.set(Ref.Misc.fakelag[1], 1)
    else
        if AntiAim.saved_fl_limit then
            ui.set(Ref.Misc.fakelag[1], AntiAim.saved_fl_limit)
            AntiAim.saved_fl_limit = nil
        end
    end
end

local function handle_unbalanced_dormant()
    if not ui.get(Menu.Extras.UnbalancedDormant.ref) then return false end
        if not Tools.any_enemy_visible() then
            ui.set(Ref.AA.yaw[2], 0)
            ui.set(Ref.AA.jitter[1], "Center")
            ui.set(Ref.AA.jitter[2], 3)
            ui.set(Ref.AA.body[1], "Static")
            ui.set(Ref.AA.body[2], 180)
            
        end
    return false
end

local function OnSetupCommand(cmd)
    if not ui.get(Menu.MainSwitch.ref) then return end
    local local_player = entity.get_local_player()
    if not local_player or not entity.is_alive(local_player) then return end
    handle_freestand()
    handle_disable_fl_exploits()

    if handle_peek_yaw(cmd) then return end

    if handle_anti_backstab(cmd) then return end

    if handle_safe_head_knife(cmd) then return end

    handle_fast_ladder(cmd)

    if handle_unbalanced_dormant() then return end

    local state = Tools.get_player_state()
    if not Menu.Builder[state] or not ui.get(Menu.Builder[state].Override.ref) then return end

    local config = Menu.Builder[state]

    local dt_active = ui.get(Ref.Misc.dt[1]) and ui.get(Ref.Misc.dt[2])
    local hs_active = ui.get(Ref.Misc.hide[1]) and ui.get(Ref.Misc.hide[2])

    local is_defensive = (defensive.defensive > 1 and defensive.defensive < 14)

    local should_force_defensive = false
    local defensive_force = ui.get(config.DefensiveForce.ref)
    if defensive_force then
        if (#defensive_force > 0) then
            for _, mode in ipairs(defensive_force) do
                if mode == "Doubletap" and dt_active then
                    should_force_defensive = true
                elseif mode == "Hideshots" and hs_active then
                    should_force_defensive = true
                end
            end
        end
    end

    ui.set(Ref.AA.enabled, true)
    ui.set(Ref.AA.yaw_base, ui.get(config.YawBase.ref))
    ui.set(Ref.AA.yaw[1], "180")

    if is_defensive and ui.get(config.DefensivePitch.ref) ~= "Off" then
        local def_pitch = ui.get(config.DefensivePitch.ref)
        if def_pitch == "Down" then
            ui.set(Ref.AA.pitch[1], "Down")
        elseif def_pitch == "Up" then
            ui.set(Ref.AA.pitch[1], "Up")
        elseif def_pitch == "Zero" then
            ui.set(Ref.AA.pitch[1], "Off")
        end
    else
        local pitch = ui.get(config.Pitch.ref)
        if pitch ~= "Default" then
            ui.set(Ref.AA.pitch[1], pitch)
        else
            ui.set(Ref.AA.pitch[1], "Default")
        end
    end

    local final_yaw = 0

    if AntiAim.manual_yaw ~= 0 then
        ui.set(Ref.AA.yaw_base, "Local view")
        final_yaw = AntiAim.manual_yaw
    elseif is_defensive and ui.get(config.DefensiveYaw.ref) ~= "Off" then
        local def_yaw = ui.get(config.DefensiveYaw.ref)
        local def_value = ui.get(config.DefensiveYawValue.ref)
        
        if def_yaw == "Static Break" then
            final_yaw = def_value
        elseif def_yaw == "Spin" then
            AntiAim.spin_angle = (AntiAim.spin_angle + 30) % 360
            final_yaw = normalize_yaw(AntiAim.spin_angle - 180)
        end
    else
        local yaw_mode = ui.get(config.YawMode.ref)
        
        if yaw_mode == "Static" then
            final_yaw = ui.get(config.YawStatic.ref)
        elseif yaw_mode == "Delay Jitter" then
            AntiAim.delay_ticks = AntiAim.delay_ticks + 1
            local delay = ui.get(config.YawDelay.ref)
            
            if AntiAim.delay_ticks >= delay then
                AntiAim.delay_ticks = 0
                AntiAim.jitter_side = not AntiAim.jitter_side
            end
            
            final_yaw = AntiAim.jitter_side and ui.get(config.YawLeft.ref) or ui.get(config.YawRight.ref)
        elseif yaw_mode == "Jitter L/R" then
            AntiAim.delay_ticks = AntiAim.delay_ticks + 1
            local delay = 2
            
            if AntiAim.delay_ticks >= delay then
                AntiAim.delay_ticks = 0
                AntiAim.jitter_side = not AntiAim.jitter_side
            end
            
            final_yaw = AntiAim.jitter_side and ui.get(config.YawLeft.ref) or ui.get(config.YawRight.ref)
        end
    end

    ui.set(Ref.AA.yaw[2], normalize_yaw(final_yaw))

    local modifier = ui.get(config.YawModifier.ref)
    local modifier_value = ui.get(config.YawModifierValue.ref)

    if modifier == "Off" then
        ui.set(Ref.AA.jitter[1], "Off")
        ui.set(Ref.AA.jitter[2], 0)
    elseif modifier == "Offset" then
        ui.set(Ref.AA.jitter[1], "Offset")
        ui.set(Ref.AA.jitter[2], modifier_value)
    elseif modifier == "Center" then
        ui.set(Ref.AA.jitter[1], "Center")
        ui.set(Ref.AA.jitter[2], modifier_value)
    elseif modifier == "Skitter" then
        ui.set(Ref.AA.jitter[1], "Random")
        ui.set(Ref.AA.jitter[2], modifier_value)
    end

    local body_mode = ui.get(config.BodyYaw.ref)
    local body_value = (ui.get(config.BodyYawValue.ref)) * 3

    if body_mode == "Static" then
        ui.set(Ref.AA.body[1], "Static")
        ui.set(Ref.AA.body[2], body_value)
    elseif body_mode == "Jitter" then
        ui.set(Ref.AA.body[1], "Jitter")
        ui.set(Ref.AA.body[2], body_value)
    end

    if should_force_defensive then
        cmd.force_defensive = true
    end
end

local function UpdateMenuVisibility()
    local enabled = ui.get(Menu.MainSwitch.ref)
    local tab = ui.get(Menu.MainTab.ref)
    ui.set_visible(Menu.MainTab.ref, enabled)
    if not enabled then
        for _, ref in pairs({
            Menu.Home.Label1.ref, Menu.Home.ConfigName.ref, Menu.Home.SaveBtn.ref,
            Menu.Home.LoadBtn.ref, Menu.Home.DeleteBtn.ref, Menu.Home.ConfigList.ref,
            Menu.Home.RefreshBtn.ref, Menu.Home.Label2.ref, 
            Menu.Home.ImportBtn.ref, Menu.Home.ExportBtn.ref,
            Menu.AntiAim.SubTab.ref, Menu.Builder.StateSelector.ref
        }) do
            ui.set_visible(ref, false)
        end
        
        for _, state in ipairs(Tools.states) do
            for _, item in pairs(Menu.Builder[state]) do
                ui.set_visible(item.ref, false)
            end
        end
        
        for _, item in pairs(Menu.Extras) do
            ui.set_visible(item.ref, false)
        end
        
        for _, item in pairs(Menu.Visuals) do
            ui.set_visible(item.ref, false)
        end
        
        for _, item in pairs(Menu.Misc) do
            ui.set_visible(item.ref, false)
        end
        
        return
    end

    local is_home = (tab == "Home")
    local is_antiaim = (tab == "Anti-Aim")
    local is_visuals = (tab == "Visuals")
    local is_misc = (tab == "Misc")

    ui.set_visible(Menu.Home.Label1.ref, is_home)
    ui.set_visible(Menu.Home.ConfigName.ref, is_home)
    ui.set_visible(Menu.Home.SaveBtn.ref, is_home)
    ui.set_visible(Menu.Home.LoadBtn.ref, is_home)
    ui.set_visible(Menu.Home.DeleteBtn.ref, is_home)
    ui.set_visible(Menu.Home.ConfigList.ref, is_home)
    ui.set_visible(Menu.Home.RefreshBtn.ref, is_home)
    ui.set_visible(Menu.Home.Label2.ref, is_home)
    ui.set_visible(Menu.Home.ImportBtn.ref, is_home)
    ui.set_visible(Menu.Home.ExportBtn.ref, is_home)

    ui.set_visible(Menu.AntiAim.SubTab.ref, is_antiaim)
    ui.set_visible(Menu.Builder.StateSelector.ref, is_antiaim)
    if is_antiaim then
        local aa_subtab = ui.get(Menu.AntiAim.SubTab.ref)
        local is_builder = (aa_subtab == "Builder")
        local is_extras = (aa_subtab == "Extras")
        
        ui.set_visible(Menu.Builder.StateSelector.ref,is_antiaim and is_builder)
        
        if is_builder then
            local selected = ui.get(Menu.Builder.StateSelector.ref)
            for _, state in ipairs(Tools.states) do
                local is_selected = (state == selected)
                local override = ui.get(Menu.Builder[state].Override.ref)
                local show_settings = (is_selected and (override or state == "Global"))
                
                ui.set_visible(Menu.Builder[state].Override.ref, is_selected)
                ui.set_visible(Menu.Builder[state].Pitch.ref, show_settings)
                ui.set_visible(Menu.Builder[state].YawBase.ref, show_settings)
                
                local yaw_mode = ui.get(Menu.Builder[state].YawMode.ref)
                ui.set_visible(Menu.Builder[state].YawMode.ref, show_settings)
                ui.set_visible(Menu.Builder[state].YawStatic.ref, show_settings and yaw_mode == "Static")
                ui.set_visible(Menu.Builder[state].YawLeft.ref, show_settings and (yaw_mode == "Delay Jitter" or yaw_mode == "Jitter L/R"))
                ui.set_visible(Menu.Builder[state].YawRight.ref, show_settings and (yaw_mode == "Delay Jitter" or yaw_mode == "Jitter L/R"))
                ui.set_visible(Menu.Builder[state].YawDelay.ref, show_settings and yaw_mode == "Delay Jitter")
                
                local modifier = ui.get(Menu.Builder[state].YawModifier.ref)
                ui.set_visible(Menu.Builder[state].YawModifier.ref, show_settings)
                ui.set_visible(Menu.Builder[state].YawModifierValue.ref, show_settings and modifier ~= "Off")
                
                ui.set_visible(Menu.Builder[state].BodyYaw.ref, show_settings)
                ui.set_visible(Menu.Builder[state].BodyYawValue.ref, show_settings)
                
                ui.set_visible(Menu.Builder[state].DefensiveLabel.ref, show_settings)
                ui.set_visible(Menu.Builder[state].DefensiveForce.ref, show_settings)
                ui.set_visible(Menu.Builder[state].DefensivePitch.ref, show_settings)
                
                local def_yaw = ui.get(Menu.Builder[state].DefensiveYaw.ref)
                ui.set_visible(Menu.Builder[state].DefensiveYaw.ref, show_settings)
                ui.set_visible(Menu.Builder[state].DefensiveYawValue.ref, show_settings and (def_yaw == "Static Break"))
            end
            
            ui.set(Menu.Builder["Global"].Override.ref, true)
            ui.set_visible(Menu.Builder["Global"].Override.ref, false)
        else
            for _, state in ipairs(Tools.states) do
                for _, item in pairs(Menu.Builder[state]) do
                    ui.set_visible(item.ref, false)
                    ui.set_visible(Menu.Builder.StateSelector.ref, false)
                end
            end
        end
        
        ui.set_visible(Menu.Extras.AntiBackstab.ref, is_extras)
        ui.set_visible(Menu.Extras.AntiBackstabDistance.ref, is_extras and ui.get(Menu.Extras.AntiBackstab.ref))
        
        local peek_enabled = ui.get(Menu.Extras.PeekYaw.ref)
        local fs_enabled = ui.get(Menu.Extras.Freestand.ref)
        
        ui.set_visible(Menu.Extras.PeekYaw.ref, is_extras and not fs_enabled)
        ui.set_visible(Menu.Extras.Freestand.ref, is_extras and not peek_enabled)
        ui.set_visible(Menu.Extras.FreestandKey.ref, is_extras and fs_enabled)
        
        ui.set_visible(Menu.Extras.UnbalancedDormant.ref, is_extras)
        ui.set_visible(Menu.Extras.SafeHeadKnife.ref, is_extras)
        ui.set_visible(Menu.Extras.FastLadder.ref, is_extras)
        ui.set_visible(Menu.Extras.FastLadderModes.ref, is_extras and ui.get(Menu.Extras.FastLadder.ref))
        ui.set_visible(Menu.Extras.DisableFLExploits.ref, is_extras)
    else
        for _, state in ipairs(Tools.states) do
            for _, item in pairs(Menu.Builder[state]) do
                ui.set_visible(item.ref, false)
            end
        end
        
        for _, item in pairs(Menu.Extras) do
            ui.set_visible(item.ref, false)
        end
    end

    ui.set_visible(Menu.Visuals.Watermark.ref, is_visuals)
    ui.set_visible(Menu.Visuals.WatermarkColor.ref, is_visuals and ui.get(Menu.Visuals.Watermark.ref))
    ui.set_visible(Menu.Visuals.HitLogs.ref, is_visuals)
    ui.set_visible(Menu.Visuals.LogsColor.ref, is_visuals and ui.get(Menu.Visuals.HitLogs.ref))
    ui.set_visible(Menu.Visuals.DamageMarker.ref, is_visuals)
    ui.set_visible(Menu.Visuals.DamageMarkerColor.ref, is_visuals and ui.get(Menu.Visuals.DamageMarker.ref))
    ui.set_visible(Menu.Visuals.ZeusWarning.ref, is_visuals)
    ui.set_visible(Menu.Visuals.ZeusWarningDistance.ref, is_visuals and ui.get(Menu.Visuals.ZeusWarning.ref))
    ui.set_visible(Menu.Visuals.ThirdpersonAnim.ref, is_visuals)
    ui.set_visible(Menu.Visuals.ThirdpersonMin.ref, is_visuals and ui.get(Menu.Visuals.ThirdpersonAnim.ref))
    ui.set_visible(Menu.Visuals.ConsoleLogs.ref, is_visuals)

    

    ui.set_visible(Menu.Misc.Clantag.ref, is_misc)
    ui.set_visible(Menu.Misc.Trashtalk.ref, is_misc)
    ui.set_visible(Menu.Misc.AnimBreaker.ref, is_misc)
    ui.set_visible(Menu.Misc.AnimBreakerModes.ref, is_misc and ui.get(Menu.Misc.AnimBreaker.ref))

    Tools.skeet_menu_visibility(false, Ref.AA)
end

local function OnLoad()
    Tools.skeet_menu_visibility(false, Ref.AA)
    ConfigSystem.update_list()
    local names = ConfigSystem.get_config_names()
    if #names > 0 then
        ui.set(Menu.Home.ConfigList.ref, 0)
    end
end

local function OnUnload()
    Tools.skeet_menu_visibility(true, Ref.AA)
    if AntiAim.saved_fl_limit then
        ui.set(Ref.Misc.fakelag[1], AntiAim.saved_fl_limit)
    end
    if Misc.clantag_enabled then
        client.set_clan_tag("")
    end
    ui.set(Ref.Misc.legs, "Never slide")
end


client.set_event_callback("pre_render", handle_anim_breakers)
client.set_event_callback("player_death", on_player_death)
client.set_event_callback("player_hurt", on_player_hurt)
client.set_event_callback("aim_hit", on_aim_hit)
client.set_event_callback("aim_miss", on_aim_miss)
client.set_event_callback("shutdown", OnUnload)
client.set_event_callback("setup_command", OnSetupCommand)
client.set_event_callback("paint_ui", UpdateMenuVisibility)
client.set_event_callback("paint", function()
    draw_notifications()
    draw_damage_markers()
    draw_zeus_warning()
    draw_watermark()
    handle_clantag()
end)

client.set_event_callback("run_command", function()
    handle_animated_thirdperson()
    
end)
OnLoad()
