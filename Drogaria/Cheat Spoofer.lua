local ffi = require("ffi")
local bit = require("bit")

ffi.cdef[[
    typedef struct {
        char         pad_0000[8];
        int32_t      client;
        int32_t      audible_mask;
        uint32_t     xuid_low;
        uint32_t     xuid_high;
        void*        voice_data;
        bool         proximity;
        bool         caster;
        char         pad_001E[2];
        int32_t      format;
        int32_t      sequence_bytes;
        uint32_t     section_number;
        uint32_t     uncompressed_sample_offset;
        char         pad_0030[4];
        uint32_t     has_bits;
    } voice_packet_t;
]]

local config = {
    enabled = ui.new_checkbox("LUA", "B", "Enable signature spoofer"),
    mode = ui.new_combobox("LUA", "B", "Spoof mode", {"Disabled", "Hide signatures", "Spoof as..."}),
    target_cheat = ui.new_combobox("LUA", "B", "Target cheat", {
        "Neverlose", "Nixware", "Pandora", "Onetap", "Fatality",
        "Plaguecheat", "Ev0lve", "Rifk7", "Airflow", "Gamesense"
    }),
    randomize = ui.new_checkbox("LUA", "B", "Randomize patterns"),
    status = ui.new_label("LUA", "B", "Status: Idle")
}

local state = {
    packet_count = 0,
    last_sig = nil,
    last_seq = nil,
    signature_counter = 0,
    xuid_pattern = {},
    random_base = math.random(0x1000, 0xFFFF)
}

local generators = {
    neverlose = function(packet, count)
        local base_xuid = state.random_base + math.floor(count / 4)
        local sig_ptr = ffi.cast("uint16_t*", ffi.cast("uintptr_t", packet) + 22)
        sig_ptr[0] = state.random_base
        packet.xuid_high = base_xuid
        
        if count % 4 == 0 then
            packet.xuid_high = state.xuid_pattern[1] or base_xuid
        else
            table.insert(state.xuid_pattern, packet.xuid_high)
            if #state.xuid_pattern > 4 then
                table.remove(state.xuid_pattern, 1)
            end
        end
    end,
    
    nixware = function(packet, count)
        packet.xuid_high = 0
    end,
    
    pandora = function(packet, count)
        local sig_ptr = ffi.cast("uint16_t*", ffi.cast("uintptr_t", packet) + 16)
        if count % 2 == 0 then
            sig_ptr[0] = 0x695B
        else
            sig_ptr[0] = 0x1B39
        end
    end,
    
    onetap = function(packet, count)
        local static_xuid = state.random_base
        local static_section = 1
        local static_offset = 0
        packet.xuid_low = static_xuid
        packet.section_number = static_section
        packet.uncompressed_sample_offset = static_offset
    end,
    
    fatality = function(packet, count)
        local sig_ptr = ffi.cast("uint16_t*", ffi.cast("uintptr_t", packet) + 16)
        if count % 2 == 0 then
            sig_ptr[0] = 0x7FFA
        else
            sig_ptr[0] = 0x7FFB
        end
    end,
    
    plaguecheat = function(packet, count)
        local sig_ptr = ffi.cast("uint16_t*", ffi.cast("uintptr_t", packet) + 44)
        sig_ptr[0] = 0x7275
    end,
    
    ev0lve = function(packet, count)
        if #state.xuid_pattern < 5 then
            local base = state.random_base + count
            table.insert(state.xuid_pattern, base)
            packet.xuid_high = base
        else
            local idx = (count % 5) + 1
            if idx == 1 then
                local val = state.xuid_pattern[1] + 1
                packet.xuid_high = val
                state.xuid_pattern = {val}
            elseif idx == 2 then
                local val = state.xuid_pattern[1] - 5
                packet.xuid_high = val
                table.insert(state.xuid_pattern, val)
            elseif idx == 3 then
                local val = state.xuid_pattern[1] + 5
                packet.xuid_high = val
                table.insert(state.xuid_pattern, val)
            else
                packet.xuid_high = state.xuid_pattern[1] + 1
            end
        end
    end,
    
    rifk7 = function(packet, count)
        local sig_ptr = ffi.cast("uint16_t*", ffi.cast("uintptr_t", packet) + 16)
        if count % 2 == 0 then
            sig_ptr[0] = 0x234
        else
            sig_ptr[0] = 0x134
        end
    end,
    
    airflow = function(packet, count)
        local sig_ptr = ffi.cast("uint16_t*", ffi.cast("uintptr_t", packet) + 16)
        sig_ptr[0] = 0xAFF1
    end,
    
    gamesense = function(packet, count)
        local sig_ptr = ffi.cast("uint16_t*", ffi.cast("uintptr_t", packet) + 22)
        local new_sig = state.random_base + (count % 256)
        sig_ptr[0] = new_sig
        packet.sequence_bytes = count * 13 % 10000
    end
}

local function hide_signatures(packet)
    local sig_16 = ffi.cast("uint16_t*", ffi.cast("uintptr_t", packet) + 16)
    local sig_22 = ffi.cast("uint16_t*", ffi.cast("uintptr_t", packet) + 22)
    local sig_44 = ffi.cast("uint16_t*", ffi.cast("uintptr_t", packet) + 44)
    
    sig_16[0] = math.random(0x1000, 0xFFFE)
    sig_22[0] = math.random(0x1000, 0xFFFE)
    sig_44[0] = math.random(0x1000, 0xFFFE)
    
    packet.xuid_high = math.random(1, 0xFFFF)
    packet.sequence_bytes = math.random(1000, 9999)
    packet.section_number = math.random(0, 10)
    packet.uncompressed_sample_offset = math.random(0, 1000)
end

local function on_voice_packet(event)
    if not ui.get(config.enabled) then return end
    
    local packet = ffi.cast("voice_packet_t*", event.data)
    local mode = ui.get(config.mode)
    
    state.packet_count = state.packet_count + 1
    
    if mode == "Hide signatures" then
        hide_signatures(packet)
        ui.set(config.status, string.format("Status: Hiding signatures (%d packets)", state.packet_count))
        
    elseif mode == "Spoof as..." then
        hide_signatures(packet)
        
        local target = ui.get(config.target_cheat)
        local cheat_map = {
            ["Neverlose"] = "neverlose", ["Nixware"] = "nixware", ["Pandora"] = "pandora",
            ["Onetap"] = "onetap", ["Fatality"] = "fatality", ["Plaguecheat"] = "plaguecheat",
            ["Ev0lve"] = "ev0lve", ["Rifk7"] = "rifk7", ["Airflow"] = "airflow",
            ["Gamesense"] = "gamesense"
        }
        
        local cheat_key = cheat_map[target]
        
        if ui.get(config.randomize) then
            if state.packet_count % 10 < 7 then
                generators[cheat_key](packet, state.packet_count)
            end
        else
            generators[cheat_key](packet, state.packet_count)
        end
        
        ui.set(config.status, string.format("Status: Spoofing as %s (%d packets)", cheat_key:upper(), state.packet_count))
    else
        ui.set(config.status, "Status: Disabled")
    end
end

local function on_config_change()
    local enabled = ui.get(config.enabled)
    local mode = ui.get(config.mode)
    
    ui.set_visible(config.mode, enabled)
    ui.set_visible(config.target_cheat, enabled and mode == "Spoof as...")
    ui.set_visible(config.randomize, enabled and mode == "Spoof as...")
    ui.set_visible(config.status, enabled)
    
    state.packet_count = 0
    state.xuid_pattern = {}
    state.random_base = math.random(0x1000, 0xFFFF)
end

ui.set_callback(config.enabled, on_config_change)
ui.set_callback(config.mode, on_config_change)
ui.set_callback(config.target_cheat, function()
    state.packet_count = 0
    state.xuid_pattern = {}
    state.random_base = math.random(0x1000, 0xFFFF)
end)

client.set_event_callback("voice", on_voice_packet)

on_config_change()

client.set_event_callback("shutdown", function()
    client.color_log(100, 255, 100, "[Spoofer] \0")
    client.color_log(255, 255, 255, "Unloaded - sent " .. state.packet_count .. " spoofed packets")
end)