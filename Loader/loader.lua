local http = require("gamesense/http") or error("Failed to load http library")
local base64 = require("gamesense/base64") or error("Failed to load base64 library")

-- Debugging control variable
local DEBUG_ENABLED = false  -- Set to true to enable debug prints, false to disable

local loader_loaded_lua = false

local cache = {
    autoload = '',
}

-- GitHub repository details
local GITHUB_USER = "lux-206"
local GITHUB_REPO = "Igreja-Universal-Lua"
local GITHUB_BRANCH = "main"
local LUA_FOLDERS = {"Lua version Debug", "Lua version Public"}

local function url_encode(str)
    -- Simple URL encoding function to replace spaces with %20
    return str:gsub(" ", "%%20")
end

local function get_base_url(folder)
    return string.format("https://raw.githubusercontent.com/%s/%s/%s/%s",
        GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH, url_encode(folder))
end

-- Cache for script-to-folder mapping to avoid repeated API calls
local script_folder_map = {}

local function debug_log(...)
    if DEBUG_ENABLED then
        client.color_log(96, 255, 28, "[Debug]\0")
        client.color_log(255, 255, 255, ...)
    end
end

local function list_scripts(callback)
    local all_lua_files = {}
    local requests_completed = 0
    
    -- Function to process results when all requests are done
    local function process_results()
        if requests_completed == #LUA_FOLDERS then
            if #all_lua_files > 0 then
                -- Extract only script names (remove folder path) for the list
                local script_names = {}
                -- Update script_folder_map with the found scripts and their folders
                for _, script_path in ipairs(all_lua_files) do
                    local folder, filename = script_path:match("^([^/]+)%s*/%s*(.+)$")
                    if folder and filename then
                        script_folder_map[filename] = folder
                        table.insert(script_names, filename)
                    end
                end
                local lua_files_str = table.concat(script_names, ", ")
                callback(lua_files_str)
            else
                client.color_log(96, 255, 28, "[Lua Loader]\0")
                client.color_log(255, 0, 0, " No Lua scripts found - Check repository and folder names")
                debug_log("Repository: " .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/" .. GITHUB_BRANCH)
                debug_log("Folders checked: " .. table.concat(LUA_FOLDERS, ", "))
            end
        end
    end

    -- Fetch contents from each folder
    for _, folder in ipairs(LUA_FOLDERS) do
        local encoded_folder = url_encode(folder)
        local api_url = string.format("https://api.github.com/repos/%s/%s/contents/%s?ref=%s",
            GITHUB_USER, GITHUB_REPO, encoded_folder, GITHUB_BRANCH)
        
        debug_log("Requesting URL: " .. api_url)
        
        http.get(api_url,
            function(success, response)
                requests_completed = requests_completed + 1
                
                if not success then
                    client.color_log(96, 255, 28, "[Lua Loader]\0")
                    client.color_log(255, 0, 0, " HTTP request failed for folder " .. folder)
                    debug_log(" Status: " .. (response and response.status or "No response"))
                    process_results()
                    return
                end

                if response.status ~= 200 then
                    client.color_log(96, 255, 28, "[Lua Loader]\0")
                    client.color_log(255, 0, 0, " GitHub API error for folder " .. folder .. " (Status: " .. response.status .. ")")
                    process_results()
                    return
                end

                local json_data = response.body
                debug_log("API Response for " .. folder .. ": " .. json_data:sub(1, 200) .. (json_data:len() > 200 and "..." or ""))
                
                local decoded_data = json.parse(json_data)
                if decoded_data then
                    for _, file in ipairs(decoded_data) do
                        if file.name:match("%.lua$") then
                            -- Store with folder prefix for internal use, but only list the filename
                            local script_name = folder .. "/" .. file.name:gsub("%.lua$", "")
                            debug_log("Found script: " .. script_name)
                            table.insert(all_lua_files, script_name)
                        end
                    end
                else
                    client.color_log(96, 255, 28, "[Lua Loader]\0")
                    client.color_log(255, 0, 0, " Failed to parse JSON for folder " .. folder)
                end
                
                process_results()
            end
        )
    end
end

local function load_script(script_name, on_success)
    -- Look up the folder for the script name in the script_folder_map
    local folder = script_folder_map[script_name]
    if not folder then
        client.color_log(96, 255, 28, "[Lua Loader]\0")
        client.color_log(255, 0, 0, " Invalid script name - Use a script name from the list (e.g., 'Igreja_Universal_debug')")
        return
    end
    
    local load_url = get_base_url(folder) .. "/" .. script_name .. ".lua"
    debug_log("Loading URL: " .. load_url)
    
    http.get(load_url,
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
        client.color_log(96, 255, 28, "/load [scriptname]\0")
        client.color_log(255, 255, 255, " - loading script (e.g., 'Igreja_Universal_debug')")
        client.color_log(96, 255, 28, "/list\0")
        client.color_log(255, 255, 255, " - shows list of all available scripts")
        client.color_log(96, 255, 28, "/autoload [scriptname]\0")
        client.color_log(255, 255, 255, " - toggling auto load of script")
        if DEBUG_ENABLED then
            debug_log("Debugging is enabled")
        end
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
        -- Ensure the name format is consistent
        luaname = luaname:gsub("^%s*(.-)%s*$", "%1")  -- Trim whitespace
        cache.autoload = luaname
        database.write('lua-loader', json.stringify(cache))
        client.color_log(96, 255, 28, "[Lua Loader]\0")
        client.color_log(255, 255, 255, " Added " .. luaname .. " to autoload")
        debug_log("Autoload set to: " .. luaname)
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
        -- Ensure the name format is consistent
        luaname = luaname:gsub("^%s*(.-)%s*$", "%1")  -- Trim whitespace
        client.color_log(96, 255, 28, "[Lua Loader]\0")
        client.color_log(255, 255, 255, " Loading " .. luaname)
        
        load_script(luaname, function()
            client.color_log(96, 255, 28, "[Lua Loader]\0")
            client.color_log(255, 255, 255, " Lua has been loaded, hf")
            loader_loaded_lua = true
        end)
        debug_log("Loading script: " .. luaname)
        return true
    end

    if text:sub(0, 5) == "/list" then
        list_scripts(function(available_luas)
            client.color_log(96, 255, 28, "[Lua Loader]\0")
            client.color_log(255, 255, 255, " Available scripts: " .. available_luas)
        end)
        debug_log("Listing scripts requested")
        return true
    end
end

client.set_event_callback("console_input", handle_console_input)