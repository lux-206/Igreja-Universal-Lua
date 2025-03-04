local http = require("gamesense/http") or error("Failed to load http library")
local base64 = require("gamesense/base64") or error("Failed to load base64 library")

local loader_loaded_lua = false

local cache = {
    autoload = '',
}

-- GitHub repository details
local GITHUB_USER = "lux-206"
local GITHUB_REPO = "Igreja-Universal-Lua"
local GITHUB_BRANCH = "main"
local LUA_FOLDERS = {"Lua version Debug", "Lua version Public"}

local function get_base_url(folder)
    return string.format("https://raw.githubusercontent.com/%s/%s/%s/%s",
        GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH, folder)
end

local function list_scripts(callback)
    local all_lua_files = {}
    local requests_completed = 0
    
    -- Function to process results when all requests are done
    local function process_results()
        if requests_completed == #LUA_FOLDERS then
            if #all_lua_files > 0 then
                local lua_files_str = table.concat(all_lua_files, ", ")
                callback(lua_files_str)
            else
                client.color_log(96, 255, 28, "[Lua Loader]\0")
                client.color_log(255, 0, 0, " No Lua scripts found")
            end
        end
    end

    -- Fetch contents from each folder
    for _, folder in ipairs(LUA_FOLDERS) do
        http.get(string.format("https://api.github.com/repos/%s/%s/contents/%s?ref=%s",
            GITHUB_USER, GITHUB_REPO, folder, GITHUB_BRANCH),
            function(success, response)
                requests_completed = requests_completed + 1
                
                if success and response.status == 200 then
                    local json_data = response.body
                    local decoded_data = json.parse(json_data)
                    
                    if decoded_data then
                        for _, file in ipairs(decoded_data) do
                            if file.name:match("%.lua$") then
                                local script_name = folder .. "/" .. file.name:gsub("%.lua$", "")
                                table.insert(all_lua_files, script_name)
                            end
                        end
                    end
                end
                
                process_results()
            end
        )
    end
end

local function load_script(script_path, on_success)
    -- Split the path to get folder and filename
    local folder, filename = script_path:match("^(.+)/(.-)$")
    if not folder or not filename then
        client.color_log(96, 255, 28, "[Lua Loader]\0")
        client.color_log(255, 0, 0, " Invalid script path format")
        return
    end
    
    http.get(get_base_url(folder) .. "/" .. filename .. ".lua",
        function(success, response)
            if not success or response.status ~= 200 then
                client.color_log(96, 255, 28, "[Lua Loader]\0")
                client.color_log(255, 0, 0, " Something went wrong, make sure that you entered script name correctly")
                return
            end

            local lua_src = load(response.body)
            lua_src()
            on_success()
        end
    )
end

if database.read('lua-loader') then
    local json_parsed = json.parse(database.read('lua-loader'))
    if json_parsed.autoload and not (json_parsed.autoload == '') then
        cache.autoload = json_parsed.autoload
        client.color_log(96, 255, 28, "[Lua Loader]\0")
        client.color_log(255, 255, 255, ' To clear autoload type /autoload')
        client.color_log(96, 255, 28, "[Lua Loader]\0")
        client.color_log(255, 255, 255, ' Loading '..cache.autoload)

        load_script(cache.autoload, function()
            client.color_log(96, 255, 28, "[Lua Loader]\0")
            client.color_log(255, 255, 255, " Lua has been loaded, hf")
            loader_loaded_lua = true
        end)
    else
        list_scripts(function(available_luas)
            client.color_log(96, 255, 28, "[Lua Loader]\0")
            client.color_log(255, 255, 255, " Welcome back, type /help for instructions")
            client.color_log(96, 255, 28, "[Lua Loader]\0")
            client.color_log(255, 255, 255, " Available scripts: " .. available_luas)
        end)
    end
else
    list_scripts(function(available_luas)
        client.color_log(96, 255, 28, "[Lua Loader]\0")
        client.color_log(255, 255, 255, " Welcome back, type /help for instructions")
        client.color_log(96, 255, 28, "[Lua Loader]\0")
        client.color_log(255, 255, 255, " Available scripts: " .. available_luas)
    end)
end

local function split(string, separator)
    local tabl = {}
    for str in string.gmatch(string, "[^" .. separator .. "]+") do
        table.insert(tabl, str)
    end
    return tabl
end

local function handle_console_input(text)
    if text:sub(0, 5) == "/help" then
        client.color_log(96, 255, 28, "/load [folder/scriptname]\0")
        client.color_log(255, 255, 255, " - loading script (e.g., 'Lua version Debug/myscript')")
        client.color_log(96, 255, 28, "/list\0")
        client.color_log(255, 255, 255, " - shows list of all available scripts")
        client.color_log(96, 255, 28, "/autoload [folder/scriptname]\0")
        client.color_log(255, 255, 255, " - toggling auto load of script")
        return true
    end

    if text:sub(0, 9) == "/autoload" then
        luaname = split(text, " ")[2]
        if not luaname then
            client.color_log(96, 255, 28, "[Lua Loader]\0")
            client.color_log(255, 255, 255, " Cleared autoload")
            cache.autoload = ''
            database.write('lua-loader', json.stringify(cache))
            return true
        end
        cache.autoload = luaname
        database.write('lua-loader', json.stringify(cache))
        client.color_log(96, 255, 28, "[Lua Loader]\0")
        client.color_log(255, 255, 255, " Added " .. luaname .. " to autoload")
        return true
    end

    if text:sub(0, 5) == "/load" then
        if loader_loaded_lua then
            client.color_log(96, 255, 28, "[Lua Loader]\0")
            client.color_log(255, 255, 255, " You've already loaded lua, if you want to load other one reload script")
            return true
        end
        luaname = split(text, " ")[2]
        if not luaname then
            client.color_log(96, 255, 28, "[Lua Loader]\0")
            client.color_log(255, 255, 255, " Select script to load, type /help for instructions")
            return true
        end
        client.color_log(96, 255, 28, "[Lua Loader]\0")
        client.color_log(255, 255, 255, " Loading " .. luaname)
        
        load_script(luaname, function()
            client.color_log(96, 255, 28, "[Lua Loader]\0")
            client.color_log(255, 255, 255, " Lua has been loaded, hf")
            loader_loaded_lua = true
        end)
        return true
    end

    if text:sub(0, 5) == "/list" then
        list_scripts(function(available_luas)
            client.color_log(96, 255, 28, "[Lua Loader]\0")
            client.color_log(255, 255, 255, " Available scripts: " .. available_luas)
        end)
        return true
    end
end

client.set_event_callback("console_input", handle_console_input)