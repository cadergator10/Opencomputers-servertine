local module = {}
local GUI = require("GUI")

local userTable -- Holds userTable stuff.

local workspace, window, loc, database, style = table.unpack({...}) --Sets up necessary variables: workspace is workspace, window is area to work in, loc is localization file, database are database commands, and style is the selected style file.

module.name = "Example" --The name that shows up on the module's button.
module.table = {"testmod","testmod2"} --Set to the keys you want pulled from the userlist on the server,
module.debug = false --The database will set to true if debug mode on database is enabled. If you want to enable certain functions in debug mode.
module.config = {["iscool"] = {["label"] = "Is this a cool feature",["type"]="bool",["default"]=true,["server"]=false}} --optional. Lets you add config settings which can be pulled by database.checkConfig("name").
--[[ INFO ABOUT module.config
Each value of table must be this: ["name"] = {["label"] = "a label",["type"]="bool",["default"]=false}
name = name that the variable is stored in. What you'll call with database.checkConfig("name") replacing "name" with the name
label = What the label will be in the settings database
type = The type of input it takes. bool is a button, string is a string input, int is a number (int) input
default = Default value if created for first time. bool is true or false, string is string input, and int is a number.
server = Whether the settings are pushed to the server as well (server-side settings) Settings are always saved database side
]]


module.init = function(usTable) --Set userTable to what's received. Runs only once at the beginning
  userTable = usTable
end

module.onTouch = function() --Runs when the module's button is clicked. Set up the workspace here.
  
end

module.close = function()
  return {"testmod","testmod2"} --Return table of what you want the database to auto save (if enabled) of the keys used by this module
end

return module