Controller = {};
Menu = {
    Skeet = {
        aa = {
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
            Master = ui.new_checkbox("AA", "Anti-aimbot angles", " \a899CFFFF Igreja Universal"),
        },
    }
    
};
Controller.skeet_menu = function(state)
    for _, ref in pairs(Menu.aa) do
        ui.set_visible(ref, state)
    end
end
Callback = {
    ui.set_callback(Menu.Universal.global.Master,Controller.skeet_menu(ui.get(Menu.Universal.global.Master)))
}

