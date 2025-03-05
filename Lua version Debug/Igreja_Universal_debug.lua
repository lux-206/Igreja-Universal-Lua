
Tools = {
    skeet_menu_visibility = function(state, menu_ref_table)
        for _, ref in pairs(menu_ref_table) do
            ui.set_visible(ref, state)
        end
    end,
    invert_bool = function(value)
        return not value
    end
};
Menu = {
    Skeet = {
        AA = {
            enabled = ui.reference("AA", "Anti-aimbot angles", "Enabled"),
            pitch = ui.reference("AA", "Anti-aimbot angles", "Pitch"),
            pitch_val = select(2, ui.reference("AA", "Anti-aimbot angles", "Pitch")),
            yaw_base = ui.reference("AA", "Anti-aimbot angles", "Yaw base"),
            yaw = ui.reference("AA", "Anti-aimbot angles", "Yaw"),
            yaw_val = select(2, ui.reference("AA", "Anti-aimbot angles", "Yaw")),
            jitter = ui.reference("AA", "Anti-aimbot angles", "Yaw jitter"),
            jitter_val = select(2, ui.reference("AA", "Anti-aimbot angles", "Yaw jitter")),
            body = ui.reference("AA", "Anti-aimbot angles", "Body yaw"),
            body_val = select(2, ui.reference("AA", "Anti-aimbot angles", "Body yaw")),
            freestand_body = ui.reference("AA", "Anti-aimbot angles", "Freestanding body yaw"),
            edge_yaw = ui.reference("AA", "Anti-aimbot angles", "Edge yaw"),
            freestanding = ui.reference("AA", "Anti-aimbot angles", "Freestanding"),
            freestanding_key = select(2, ui.reference("AA", "Anti-aimbot angles", "Freestanding")),
            roll = ui.reference("AA", "Anti-aimbot angles", "Roll")
        },
        quick_peek = ui.reference("rage", "other", "quick peek assist"),
        dt = ui.reference("Rage", "Aimbot", "Double Tap"),
        hs = ui.reference("aa", "other", "on shot anti-aim"),
        fd = ui.reference("rage", "other", "duck peek assist"),
        sp = ui.reference("rage", "aimbot", "force safe point"),
        fb = ui.reference("rage", "aimbot", "force body aim"),
        fs = ui.reference("aa", "anti-aimbot angles", "freestanding"),
        clantag = ui.reference("MISC", "Miscellaneous", "Clan tag spammer"),
        legMovement = ui.reference("AA", "Other", "Leg movement")
    },
    Universal = {
        global = {
            Master = ui.new_checkbox("AA", "Anti-aimbot angles", " \a899CFFFF Igreja Universal")
        },
        AA = {
            selector = ui.new_combobox("AA", "Anti-aimbot angles", " \a899CFFFF Selector ", {"Builder","Others"}),
            Builder =  {
                Type = ui.new_combobox("AA", "Anti-aimbot angles", "Builder type ", {"Default+","Jesus"}),
                Default = {},
                Jesus = {
                    Pitch = ui.new_combobox("AA", "Anti-aimbot angles", "Pitch", {"Off","Default","Up","Down","Minimal","Random"}),
                    Yaw_base = ui.new_combobox("AA", "Anti-aimbot angles", "Yaw Base", {"Local view","At targets"}),
                    Yaw = ui.new_slider("AA", "Anti-aimbot angles","Yaw",0,179,0,true),
                    Desync = ui.new_slider("AA", "Anti-aimbot angles","Desync",0,179,0,true),
                    Update_time = ui.new_combobox("AA", "Anti-aimbot angles", "Speed Method", {"Fast","Slow + Breaker"})
                }
            },
            Others = {
                Enalbe_roll = ui.new_checkbox("AA", "Anti-aimbot angles", "Roll AA"),
                Roll_mode = ui.new_combobox("AA", "Anti-aimbot angles", " Roll AA type ", {"Normal","Sway"}),
                Roll = ui.new_slider("AA", "Anti-aimbot angles","Roll",-45,45,0,true),
                Roll_sway = ui.new_slider("AA", "Anti-aimbot angles","Roll",0,45,0,true)
            }
        },
    }
    
};
functions = {
    update_menu_visibility = function()
        local master = ui.get(Menu.Universal.global.Master)
        local selector = master and ui.get(Menu.Universal.AA.selector) or nil
        local builder_type = selector == "Builder" and ui.get(Menu.Universal.AA.Builder.Type) or nil

        Tools.skeet_menu_visibility(false, Menu.Skeet.AA)
        Tools.skeet_menu_visibility(false, Menu.Universal.AA.Builder.Default)
        Tools.skeet_menu_visibility(false, Menu.Universal.AA.Builder.Jesus)
        Tools.skeet_menu_visibility(false, Menu.Universal.AA.Others)
        ui.set_visible(Menu.Universal.AA.selector, false)
        ui.set_visible(Menu.Universal.AA.Builder.Type, false)
    
        if master then
            ui.set_visible(Menu.Universal.AA.selector, true)
            if selector == "Builder" then
                ui.set_visible(Menu.Universal.AA.Builder.Type, true)
                if builder_type == "Default+" then
                    Tools.skeet_menu_visibility(true, Menu.Universal.AA.Builder.Default)
                elseif builder_type == "Jesus" then
                    Tools.skeet_menu_visibility(true, Menu.Universal.AA.Builder.Jesus)
                end
            elseif selector == "Others" then
                Tools.skeet_menu_visibility(true, Menu.Universal.AA.Others)
            end
        end
    end
};

Callback = {
    Menu = {
        onload = function()
           -- Tools.skeet_menu_visibility(true,Menu.Skeet.AA)
            Tools.skeet_menu_visibility(false, Menu.Universal.AA.Builder.Default)
            Tools.skeet_menu_visibility(false, Menu.Universal.AA.Builder.Jesus)
            Tools.skeet_menu_visibility(false, Menu.Universal.AA.Others)
            ui.set_visible(Menu.Universal.AA.selector, false)
            ui.set_visible(Menu.Universal.AA.Builder.Type, false)
            functions.update_menu_visibility()
        end,
        Skeet = ui.set_callback(Menu.Universal.global.Master, function()
            Tools.skeet_menu_visibility(invert_bool(ui.get(Menu.Universal.global.Master)),Menu.Skeet.AA)
        end),
        AA = {
            Master = ui.set_callback(Menu.Universal.global.Master, functions.update_menu_visibility),
            Selector = ui.set_callback(Menu.Universal.AA.selector, functions.update_menu_visibility),
            Type = ui.set_callback(Menu.Universal.AA.Builder.Type, functions.update_menu_visibility)
        },
        unload = client.set_event_callback("shutdown", function()
            Tools.skeet_menu_visibility((true),Menu.Skeet.AA)
        end)
    }
   -- AA = client.set_event_callback("setup_command",)
}
