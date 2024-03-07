local modemPort = 1000 --1000 is new default. Port is chosen on device setups.
local syncPort = 199

local component = require("component")
local event = require("event")
local modem = component.modem
local ser = require ("serialization")
local term = require("term")
local gpu = component.gpu
local fs = require("filesystem")
local shell = require("shell")
local process = require("process")
local thread = require("thread")
local keyboard = require("keyboard")
local uuid = require("uuid")

local version = "4.0.3"

local serverModules = "https://raw.githubusercontent.com/cadergator10/opencomputer-security-system/main/src/server/modules/modules.txt"

local commands = {"setdevice","signIn","updateuserlist","loginfo","getquery","syncport","moduleinstall", "devModeChange","settingUpdate","integritySync"}
local skipcrypt = {"loginfo","getquery","syncport"}

local modules = {}
local modulepath = "/modules"

local logUsers = {}

local viewport = 0
local viewhistory = {}
local dohistory = true
local eventcheckpull = true
local evthread

local revealPort = false

local debug = false

local syncKey = nil
local databaseLink = "" --the uuid of the database's modem. Makes sure only one database can perform certain actions

--------Main Functions

local function convert( chars, dist, inv )
  return string.char( ( string.byte( chars ) - 32 + ( inv and -dist or dist ) ) % 95 + 32 )
end


local function crypt(str,k,inv)
  local enc= "";
  for i=1,#str do
    if(#str-k[5] >= i or not inv)then
      for inc=0,3 do
	if(i%4 == inc)then
	  enc = enc .. convert(string.sub(str,i,i),k[inc+1],inv);
	  break;
	end
      end
    end
  end
  if(not inv)then
    for i=1,k[5] do
      enc = enc .. string.char(math.random(32,126));
    end
  end
  return enc;
end

--// exportstring( string )
--// returns a "Lua" portable version of the string
local function exportstring( s )
	s = string.format( "%q",s )
	-- to replace
	s = string.gsub( s,"\\\n","\\n" )
	s = string.gsub( s,"\r","\\r" )
	s = string.gsub( s,string.char(26),"\"..string.char(26)..\"" )
	return s
end
--// The Save Function
local function saveTable(  tbl,filename )
	local tableFile = assert(io.open(filename, "w"))
  tableFile:write(ser.serialize(tbl))
  tableFile:close()
end

--// The Load Function
local function loadTable( sfile )
	local tableFile = io.open(sfile)
    if tableFile ~= nil then
  		return ser.unserialize(tableFile:read("*all"))
    else
        return nil
    end
end

local function deepcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
      copy = {}
      for orig_key, orig_value in next, orig, nil do
          copy[deepcopy(orig_key)] = deepcopy(orig_value)
      end
      setmetatable(copy, deepcopy(getmetatable(orig)))
  else -- number, string, boolean, etc
      copy = orig
  end
  return copy
end

local function addcommands(tabler,crypttable)
  for _,value in pairs(tabler) do
    table.insert(commands,value)
  end
  for _,value in pairs(crypttable) do
    table.insert(skipcrypt,value)
  end
end

local function advWrite(text,color,wrap,clear,pos,bypass)
  if dohistory or bypass then
    if pos then term.setCursor(1,pos) end
    if clear then term.clearLine() end
    gpu.setForeground(color or gpu.getForeground())
    term.write(text,wrap or true)
  end
end
local function historyUpdate(text,color,wrap,newline,rewrite)
    if rewrite then
      dohistory = true
      for i=1,#viewhistory,1 do
        advWrite("",nil,false,true,i+3)
        for j=1,#viewhistory[i],2 do
          advWrite(viewhistory[i][j],viewhistory[i][j+1],false)
        end
      end
    elseif newline then
      for i=2,#viewhistory,1 do
        advWrite("",nil,false,true,i+2)
        for j=1,#viewhistory[i],2 do
          advWrite(viewhistory[i][j],viewhistory[i][j+1],false)
        end
        viewhistory[i-1] = viewhistory[i]
      end
      viewhistory[#viewhistory] = {}
      advWrite("",0xFFFFFF,false,true,#viewhistory + 3)
    end
  table.insert(viewhistory[#viewhistory],text)
  table.insert(viewhistory[#viewhistory],color)
  advWrite("",0xFFFFFF,wrap,true,#viewhistory + 3)
  for i=1,#viewhistory[#viewhistory],2 do
    advWrite(viewhistory[#viewhistory][i],viewhistory[#viewhistory][i+1],wrap)
  end
end

--------Server Functions

local function msgToModule(type,command, data, more) --Sends message to modules and returns the data.
  if type == "message" then
    for _,value in pairs(modules) do --p1 is true/false if program received command, p2 is data to send back to other device (nil if nothing is sent back), p3 is what to log on server (nil if nothing to log), p4 is color of logged text (nil if staying white or nothing to log), p5 is a change to userTable that must be saved & updated.
      local p1, p2, p3, p4, p5, p6, p7 = value.message(command,data,more)
      if p1 then
        return p1, p2, p3, p4, p5, p6, p7
      end
    end
    return false
  else
    for _,value in pairs(modules) do --p1 is true/false if program received command, p2 is data to send back to other device (nil if nothing is sent back), p3 is what to log on server (nil if nothing to log), p4 is color of logged text (nil if staying white or nothing to log), p5 is a change to userTable that must be saved & updated.
      value.piggyback(command,data)
    end
  end
end

local bing,add,from,port
local function bdcst(address,port,data,data2)
  if bing and address then
    modem.send(address,port,"rebroadcast",ser.serialize({["uuid"]=add,["data"]=data,["data2"]=data2})) --issue
  else
    if address then
      modem.send(address,port,data,data2)
    else
      modem.broadcast(port,data,data2)
    end
  end
end

local function checkPerms(data)
  if data.command == "check" or data.command == "return" then
    local good = data.command == "check" and false or {}
    local pre = ""
    local goodthing = function(value)
      if data.command == "check" then
        good = true
      else
        table.insert(good,value)
      end
    end
    if data.prefix ~= nil then
      pre = data.prefix .. "."
    end
    if logUsers[data.user] == nil then return false, "No user found" end
    for _,value in pairs(logUsers[data.user].perms) do
      if value == "all" then
        goodthing(value)
        if data.command == "check" then break end
      end
      if value == pre .. "*" and pre ~= "" then
        goodthing(value)
        if data.command == "check" then break end
      end
      for i=1,#data,1 do
        if value == pre .. data[i] then
          goodthing(value)
          break
        end
      end
      if data.command == "check" and good then break end
    end
    if data.command == "return" then
      return true, good
    end
    if good then
      return true, true
    else
      return true, false
    end
    return false, "incorrect command"
  end
end

--------Getting tables and setting up terminal
term.clear()
_,viewport = term.getViewport()
for i=1,viewport - 5,1 do
  viewhistory[i] = {"",0xFFFFFF}
end

local settingTable = loadTable("settings.txt")
if settingTable == nil then
  settingTable = {["cryptKey"]={1,2,3,4,5},["port"]=1000,["debug"]=false,["devMode"]=false,["dbSettings"]={},["databaseLink"]=""}
  saveTable(settingTable,"settings.txt")
end
settingTable = loadTable("settings.txt")

if settingTable.debug == nil then
  settingTable.debug = false
  saveTable(settingTable,"settings.txt")
end
if settingTable.port == nil then
  settingTable.port = 1000
  saveTable(settingTable,"settings.txt")
end
if settingTable.devMode == nil then
  settingTable.devMode = false
  saveTable(settingTable,"settings.txt")
end
if settingTable.dbSettings == nil then
  settingTable.dbSettings = {}
  saveTable(settingTable,"settings.txt")
end
if settingTable.databaseLink == nil then
  settingTable.databaseLink = ""
  saveTable(settingTable,"settings.txt")
end
databaseLink = settingTable.databaseLink
modemPort = settingTable.port
debug = settingTable.debug

modulepath = fs.path(shell.resolve(process.info().path)).. "/modules"
if fs.exists(modulepath) == false then
  os.execute("mkdir modules")
end
local crashTable = {}
for file in fs.list(modulepath .. "/") do --TEST: Does this successfully pull the Main.lua in folders.
  local result, reason = loadfile(modulepath .. "/" .. file .. "/Main.lua")
  if result then
    local success, result = pcall(result)
    if success then
      table.insert(modules,result)
    else
      table.insert(crashTable,"Error loading module in folder named " .. file .. ". Reason: " .. result)
    end
  end
end

logUsers = loadTable("users.txt")
if logUsers == nil then
  logUsers = {}
  saveTable(logUsers,"users.txt")
end

term.clear()
local doorTable = loadTable("devicelist.txt")
if doorTable == nil then
  doorTable = {}
end
print("Checking all devices saved in devicelist...")
modem.close()
if modem.isOpen(modemPort) == false then
  modem.open(modemPort)
end
local count = 1
local check = false
for _,value in pairs(doorTable) do
  if value["repeat"] ~= false then
    modem.send(value["repeat"],modemPort,"rebroadcast",ser.serialize({["uuid"]=value.id,["data"]="deviceCheck"}))
  else
    modem.send(value.id,modemPort,"deviceCheck")
  end
  local e, _, from, port, _, command, msg = event.pull(1,"modem_message")
  if e then

  else
    table.remove(doorTable,count)
    check = true
  end
  count = count + 1
end
if check then
  saveTable(doorTable,"devicelist.txt")
end

advWrite("Servertine version: " .. version .. (settingTable.devMode == true and " DEV MODE" or ""),0xFFFFFF,false,true,1,true)
advWrite(#modules .. " modules loaded / port hidden",nil,false,true,2,true)
advWrite("---------------------------------------------------------------------------",0xFFFFFF,false,true,3,true)
advWrite("---------------------------------------------------------------------------",0xFFFFFF,false,true,#viewhistory + 4,true)

local userTable = loadTable("userlist.txt")

if userTable == nil then
  userTable = {} --sets up setting var without any settings in it.
  --All setup for security alone has been removed from here due to it being seperated into a module entirely.
  saveTable(userTable,"userlist.txt")
else
  if userTable.refactored ~= true then
    if userTable.settings ~= nil then
      userTable.passSettings = userTable.settings
      userTable.settings = nil
    end
    if userTable.passSettings ~= nil then
      for i=1,#userTable.passSettings.var,1 do
        if userTable.passSettings.type[i] == "string" then
          if userTable.passSettings.data[i] == false then
            userTable.passSettings.data[i] = 1
          end
        elseif userTable.passSettings.type[i] == "-string" then
          if userTable.passSettings.data[i] == false then
            userTable.passSettings.type[i] = "string"
            userTable.passSettings.data[i] = 2
          end
        end
      end
    end
    if #userTable > 0 then
      userTable.passes = {}
      for i=1,#userTable,1 do
        table.insert(userTable.passes,userTable[1])
        table.remove(userTable,1)
      end
    end
    if userTable.passSettings ~= nil and userTable.passSettings.sectors ~= nil then
      userTable.sectors = userTable.passSettings.sectors
      userTable.passSettings.sectors = nil
    end
    userTable.refactored = true
    saveTable(userTable,"userlist.txt")
  end
end

local server = {["crypt"] = function(str,reverse)
  return crypt(str,settingTable.cryptKey,reverse)
end,["copy"] = deepcopy,["send"]=function(direct,data,data2)
  bdcst(direct and from or nil,modemPort,data,data2)
end,["modulemsg"]=function(command,data)
  return msgToModule("message",command,data,add)
end,["print"]=function(msg) --print to screen using history
  if type(msg) == "table" then
    historyUpdate(msg[1].text,msg[1].color or 0xFFFFFF,false,msg[1].line or true)
    for i=2,#msg,1 do
      historyUpdate(msg[i].text,msg[i].color or 0xFFFFFF,false,msg[i].line or false)
    end
  else
    historyUpdate(msg,0xFFFFFF,false,true)
  end
end,["configCheck"]=function(cfg) --Check module specific settings
  return settingTable.dbSettings[cfg]
end,["advsend"]=function(address,link,port,data,data2)
  if link and address then
    modem.send(link,port == nil and modemPort or port,"rebroadcast",ser.serialize({["uuid"]=add,["data"]=data,["data2"]=data2})) --issue
  else
    if address then
      modem.send(address,port == nil and modemPort or port,data,data2)
    else
      modem.broadcast(port == nil and modemPort or port,data,data2)
    end
  end
end}

for _,value in pairs(modules) do
  addcommands(value.commands,value.skipcrypt,value.table)
  value.debug = debug
  value.init(userTable, doorTable, server)
  for keyed,valued in pairs(value.table) do
    if userTable[keyed] == nil then
      userTable[keyed] = deepcopy(valued)
    end
  end
end
for _,value in pairs(modules) do
  value.setup()
end

server = nil

--------Main Loop & Program
local function serversettings()
  local selected = 1
  local pr = revealPort and "hide port" or "reveal port"
  local set = {"delete all modules",pr,"unlink database","close menu"}
  local fresh = function() --Doesn't display all options. You scroll through now (bigger menu possible)
    local nextmsg = (selected == 1 and "  " or "< ") .. set[selected] .. (selected == #set and "  " or "  >")
    advWrite(nextmsg,0xFFFFFF,true,true,#viewhistory + 5,true)
  end
  fresh()
  os.sleep(0.5)
  while true do
    local _,_,_,p = event.pull("key_down")
    local char = keyboard.keys[p]
    if char == "left" then
      if selected > 1 then
        selected = selected - 1
        fresh()
        os.sleep(0.5)
      end
    elseif char == "right" then
      if selected < #set then
        selected = selected + 1
        fresh()
        os.sleep(0.5)
      end
    elseif char == "enter" then
      if selected == 1 then --clear all the modules
        local path = shell.getWorkingDirectory()
        fs.remove(path .. "/modules")
        os.execute("mkdir modules")
        term.clear()
        print("Wiped modules. Restart server")
        os.exit()
      elseif selected == 2 then --enable syncPort (allowing quick setup of stuff) and show on screen
        if revealPort == false then revealPort = true else revealPort = false end
        if revealPort then
          advWrite(#modules .. " modules loaded / port shown: " .. modemPort,nil,false,true,2,true)
          modem.open(syncPort)
        else
          advWrite(#modules .. " modules loaded / port hidden",nil,false,true,2,true)
          modem.close(syncPort)
        end
        advWrite("Press enter to bring up menu",0xFFFFFF,false,true,#viewhistory + 5,true)
        os.sleep(1)
        eventcheckpull = true
        thread.current():kill()
      elseif selected == 3 then --Allow a different database to connect
        databaseLink = ""
        settingTable.databaseLink = ""
        saveTable(settingTable,"settings.txt")
        advWrite("Press enter to bring up menu",0xFFFFFF,false,true,#viewhistory + 5,true)
        os.sleep(1)
        eventcheckpull = true
        thread.current():kill()
      elseif selected == 4 then --back to menu
        advWrite("Press enter to bring up menu",0xFFFFFF,false,true,#viewhistory + 5,true)
        os.sleep(1)
        eventcheckpull = true
        thread.current():kill()
      end
    end
  end
end

local function eventCheck()
  while true do
    local e, p1, from, port, p2, command, msg = event.pullMultiple("modem_message","key_down")
    if e == "modem_message" then
      event.push("itzamsg", p1, from, port, p2, command, msg)
    elseif e == "key_down" and keyboard.keys[port] == "enter" and eventcheckpull then
      thread.create(serversettings)
      eventcheckpull = false
    end
  end
end

advWrite("Press enter to bring up menu",0xFFFFFF,false,true,#viewhistory + 5,true)
evthread = thread.create(eventCheck)

for i=1,#crashTable,1 do
  historyUpdate(crashTable[i],0xFF0000,false,true)
end

while true do
  if modem.isOpen(modemPort) == false then
    modem.open(modemPort)
  end
  bing,add = false, false
  local command, msg,e
  e, _, from, port, _, command, msg = event.pull("itzamsg")
  add = from
  if command == "rebroadcast" then --Checking if message is from range extender
    bing = true
    msg = ser.unserialize(msg)
    command = msg.command
    add = msg.uuid
    msg = msg.data
  end

  local data = msg
  local go = false

  for _,value in pairs(commands) do --Checking if a correct command from module or base server
    if command == value then
      go = true
      break
    end
  end

  if go then
    for _,value in pairs(skipcrypt) do --Checking if the command's data is unencrypted or crypted.
      if command == value then
        go = false
        break
      end
    end

    if go then
      if msg ~= nil then
        data = crypt(msg, settingTable.cryptKey, true) 
      end
    end

    if port == modemPort then
      if command == "updateuserlist" then --Receives a table of the parts of the table that need to be changed. Because it will do this instead of resetting the entire table, different devices won't mess with other device configurations.
        data = ser.unserialize(data)
        if data ~= nil then
          for key,value in pairs(data) do
            userTable[key] = value
          end
          local goboi = false
          if settingTable.pass == false then
            goboi = true
          end
          historyUpdate("Updated userlist received",0x0000C0,false,true)
          saveTable(userTable, "userlist.txt")
          for _,value in pairs(modules) do
            value.setup()
          end
        else
          historyUpdate("Error updating userlist: cryptKey may be incorrect",0xFF0000,false,true)
        end
      elseif command == "signIn" then
        data = ser.unserialize(data)
        if data ~= nil then
          if data.command == "signIn" then
            local count = 0
            for _,_ in pairs(logUsers) do
              count = count + 1
            end
            if count == 0 then
              if data.user == "admin" and data.pass == "password" .. tostring(modemPort) then
                bdcst(from,port,crypt("true",settingTable.cryptKey),crypt(ser.serialize({"all"}),settingTable.cryptKey))
              else
                bdcst(from,port,crypt("false",settingTable.cryptKey))
              end
            else
              if logUsers[data.user] ~= nil and crypt(logUsers[data.user].pass,settingTable.cryptKey,true) == data.pass then
                bdcst(from,port,crypt("true",settingTable.cryptKey),crypt(ser.serialize(logUsers[data.user].perms),settingTable.cryptKey))
              else
                bdcst(from,port,crypt("false",settingTable.cryptKey))
              end
            end
          elseif data.command == "update" then
            logUsers = data.data
            saveTable(logUsers,"users.txt")
          elseif data.command == "grab" then
            local count = 0
            for _,_ in pairs(logUsers) do
              count = count + 1
            end
            if count == 0 then
              bdcst(from,port,crypt("true",settingTable.cryptKey),crypt(ser.serialize(logUsers),settingTable.cryptKey))
            else
              local e,worked = checkPerms({["command"]="check",["user"]=data.user,["pass"]=data.pass,["prefix"]="dev","usermanagement"})
              if e and worked then
                bdcst(from,port,crypt("true",settingTable.cryptKey),crypt(ser.serialize(logUsers),settingTable.cryptKey))
              else
                bdcst(from,port,crypt("false",settingTable.cryptKey))
              end
            end
          end
        else
          historyUpdate("Error signing in: cryptKey may be incorrect",0xFF0000,false,true)
        end
      elseif command == "integritySync" then --Verify integrity between Database config and Server config (mainly devMode) Setup to be able to accept a yes/no to fix error, but atm is set to auto correct.
        data = ser.unserialize(data)
        if data ~= nil and (databaseLink == "" or from == databaseLink) then --Bad cryptKey likely
          if data.syncKey == nil then --If nil, then its a verification
            if databaseLink == "" then
              databaseLink = from
              settingTable.databaseLink = from
              saveTable(settingTable,"settings.txt")
            end
            if data.devMode ~= settingTable.devMode then
              syncKey = uuid.next()
              bdcst(from,port,crypt("true",settingTable.cryptKey),crypt(ser.serialize({["good"]=false,["key"]=syncKey,["text"]="devLink is incorrect"}),settingTable.cryptKey))
              settingTable.devMode = data.devMode
              saveTable(settingTable,"settings.txt")
              dohistory = false
              evthread:kill()
              os.exit()
            else
              bdcst(from,port,crypt("true",settingTable.cryptKey),crypt(ser.serialize({["good"]=true}),settingTable.cryptKey))
            end
          elseif data.syncKey == syncKey then --syncKey is the same as one sent to the server
            bdcst(from,port,crypt("true",settingTable.cryptKey))
          else --Bad syncKey.
            bdcst(from,port,crypt("false",settingTable.cryptKey))
          end
        else
          bdcst(from,port,crypt("false",settingTable.cryptKey))
        end
      elseif command == "moduleinstall" then
        --TEST: Does module installation work? I gotta move this all to another gitpod thing
        data = ser.unserialize(data)
        if data ~= nil then
          bdcst(from,port,crypt("true",settingTable.cryptKey))
          dohistory = false
          evthread:kill()
          term.clear()
          print("Received modules list. Downloading modules...")
          local path = shell.getWorkingDirectory()
          fs.remove(path .. "/modules")
          os.execute("mkdir modules")
          for j=1,#data,1 do
            os.execute("mkdir modules/" .. "modid" .. tostring(data[j].module.id))
            for i=1,#data[j].files,1 do
              if data[j].files[i].serverModule == true then
                if settingTable.devMode == false then
                  os.execute("wget -f " .. data[j].files[i].url .. " modules/modid" .. tostring(data[j].module.id) .. "/" .. data[j].files[i].path)
                elseif data[j].files[i].devUrl ~= nil then
                  os.execute("wget -f " .. data[j].files[i].devUrl .. " modules/modid" .. tostring(data[j].module.id) .. "/" .. data[j].files[i].path)
                end
              end
            end
          end
          print("Finished downloading modules. Restart server")
          os.exit()
        else
          bdcst(from,port,crypt("false",settingTable.cryptKey))
        end
      elseif command == "devModeChange" then --Remove all modules and save backups IF prev mode wasn't dev mode
        data = ser.unserialize(data)
        if data ~= nil and data.devMode ~= nil then
          local messUp = (data.devMode == settingTable.devMode)
          bdcst(from,port,crypt("true",settingTable.cryptKey))
          dohistory = false
          evthread:kill()
          term.clear()
          print("Developer mode has been set to " .. tostring(data.devMode))
          if not messUp then
            local path = shell.getWorkingDirectory()
            fs.remove(path .. "/modules")
            os.execute("mkdir modules")
            if (data.devMode) then
              print("Backing up any settings") --IMAHERE
              saveTable({["devices"]=doorTable,["config"]=userTable},"normalModeBackup.txt")
              saveTable({},"deviceList.txt")
              saveTable({},"userList.txt")
              print("Finished")
            else
              print("Returning last settings")
              local lastSettings = loadTable("normalModeBackup.txt")
              if lastSettings ~= nil then
                print("Found settings backup")
                saveTable(lastSettings.devices,"deviceList.txt")
                saveTable(lastSettings.config,"userList.txt")
              else
                print("No settings backup found")
                saveTable({},"deviceList.txt")
                saveTable({},"userList.txt")
              end
              print("Finished")
            end
          else
            print("Nothing has been done to background files just in cass (no modules wiped, backups made, files deleted, etc.)")
          end
          settingTable.devMode = data.devMode
          saveTable(settingTable,"settings.txt")
          os.exit()
        end
      elseif command == "settingUpdate" then --database settings broadcast here
        data = ser.unserialize(data)
        if data ~= nil then
          bdcst(from,port,crypt("true",settingTable.cryptKey))
          settingTable.dbSettings = data
          saveTable(settingTable,"settings.txt")
        else
          bdcst(from,port,crypt("false",settingTable.cryptKey))
        end
      elseif command == "checkPerms" then --Example with passes module & adding variables{["user"]="username",["command"]="check",["prefix"]="passes","addvar"} = checks both check.* and check.addvar and all
        data = ser.unserialize(data)
        if data ~= nil then
          local e,worked = checkPerms(data)
          if e then
            bdcst(from,port,crypt("true",settingTable.cryptKey),crypt(tostring(worked),settingTable.cryptKey))
          else
            bdcst(from,port,crypt("false",settingTable.cryptKey),crypt(worked,settingTable.cryptKey))
          end
        else
          historyUpdate("Error checking perms: cryptKey may be incorrect",0xFF0000,false,true)
        end
      elseif command == "setdevice" then
        historyUpdate("Received device parameters from id: " .. add,0xFFFF80,false,true)
        local tmpTable = ser.unserialize(data)
        if tmpTable ~= nil then
          tmpTable["id"] = add
          tmpTable["repeat"] = bing == true and from or false
          local isInAlready = false
          for i=1,#doorTable,1 do
            if doorTable[i].id == add then
              isInAlready = true
              doorTable[i] = tmpTable
              break
            end
          end
          if isInAlready == false then table.insert(doorTable,tmpTable) end
          saveTable(doorTable, "devicelist.txt")
          for _,value in pairs(modules) do
            value.setup()
          end
        else
          historyUpdate("Error setting device: cryptKey may be incorrect",0xFF0000,false,true)
        end
      elseif command == "loginfo" then
        data = ser.unserialize(data) --Array of arrays. Each array has text and color (color optional)
        if data ~= nil then
          historyUpdate(data[1].text,data[1].color or 0xFFFFFF,false,true)
          for i=2,#data,1 do
            historyUpdate(data[i].text,data[i].color or 0xFFFFFF,false,false)
          end
        elseif debug == true then
          historyUpdate("Received faulty loginfo command parameters",0xFF0000,false,true)
        end
      elseif command == "getquery" then
        local wait = ser.unserialize(data)
        local docrypt = true
        data = {}
        data.data = {}
        if wait ~= nil then
          for i=1,#wait,1 do
            if wait[i] ~= "&&&crypt" then
              data.data[wait[i]] = userTable[wait[i]] --Issue
            else
              docrypt = false
            end
          end
        end
        data.num = 3
        data.version = version
        data = ser.serialize(data)
        data = docrypt and crypt(data,settingTable.cryptKey) or data
        bdcst(from, port, data)
      else
        local p1,p2,p3,p4,p5,p6,p7 = msgToModule("message",command,data,add)
        if p1 then
          if p4 ~= nil then
            if p4 == false then
              bdcst(nil,port,p5,p6)
            else
              bdcst(from, port, p5,p6)
            end
          end
          if p2 then --holdup
            historyUpdate(p2[1].text,p2[1].color or 0xFFFFFF,false,true)
            for i=2,#p2,1 do
              historyUpdate(p2[i].text,p2[i].color or 0xFFFFFF,false,p2[i].line or false)
            end
          end
          if p3 then
            saveTable(userTable, "userlist.txt")
            for _,value in pairs(modules) do
              value.setup()
            end
          end
        end
      end
      msgToModule("piggyback",command,data)
    else
      if command == "syncport" then
        if port == syncPort and revealPort then
          bdcst(from,port,tostring(modemPort))
        end
      end
    end
  end
   gpu.setForeground(0xFFFFFF)
end
