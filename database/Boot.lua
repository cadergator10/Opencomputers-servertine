--The startup which checks for updates and whether it's using OpenOS or MineOS
local compat = require("Compat")
local config = compat.loadTable("bootconfig.txt")
local term = not compat.isMine and require("term") or nil

local arg = ...

local function installer(version)
    if compat.isMine then
        compat.system.addWindow(0xE1E1E1)
    else
        term.clear()
        local install = false
        local isConfig = config == nil
        if config == nil then
            config = {["version"] = -1,["checkVersion"]=true}
            compat.saveTable(config,"bootconfig.txt")
            print("New system: Installing servertine")
            install = true
        else
            print("New version for the Servertine Database is available!")
            print(config.version .. " -> " .. version)
            print("Would you like to install this version? yes or no\nSome modules may require the new version")
            local text = term.read():sub(1,-2)
            while text ~= "yes" and text ~= "no" do
                print("Invalid input")
                text = term.read():sub(1,-2)
            end
            if text == "yes" then
                install = true
            else
                print("Do you want the system to remember your decision?")
                local text = term.read():sub(1,-2)
                while text ~= "yes" and text ~= "no" do
                    print("Invalid input")
                    text = term.read():sub(1,-2)
                end
                if text == "yes" then
                    config.checkVersion = false
                    compat.saveTable(config,"bootconfig.txt")
                end
            end
        end
        if install then
            --perform install
            return true
        elseif not isConfig then
            return true
        else
            return false
        end
    end
end

local function erHandle(er)
    error("Something went wrong:\n" .. er .. "\nError reporting will be available in the future")
end


if config == nil then
end
local result, reason = loadfile(compat.fs.path(compat.system.getCurrentScript()) .. "/Database.lua")
if result then
    local success, result = xpcall(result,erHandle)
else
    local goodToRun = installer()
    if goodToRun then
        result, reason = loadfile(compat.fs.path(compat.system.getCurrentScript()) .. "/Database.lua")
        if result then
            local success, result = xpcall(result,erHandle)
        else
            error("Failed to run installed program. It'sa makea no sensea")
        end
    end
end