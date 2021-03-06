-- Module to handle hooks
local pcall = pcall
local type = type
local table = table
local tostring = tostring
local error = error

local tu = require("tableUtils")

local M = {}
package.loaded[...] = M
if setfenv and type(setfenv) == "function" then
	setfenv(1,M)	-- Lua 5.1
else
	_ENV = M		-- Lua 5.2+
end

-- The hook structure looks like this:
--[[
{
	key = <string>,			-- string which tells when the hook has to be executed
	func = <function>,		-- function code for the hook that is executed
	info = <string>,		-- OPTIONAL any string description/information to associate with the hook. Can be used for logging or debugging purposes
	id = <integer>			-- Unique ID for the hook. Format is H<num> i.e. H followed by a unique number
	disable = <boolean>		-- if true then the hook is not processed
}
]]
-- Hooks are located at cnvobj.hook

--[[ DEFINED HOOKS IN lua-gl (keys)
MOUSECLICKPRE
MOUSECLICKPOST
UNDOADDED
RESIZED
]]
-- Hooks are processed in the order they were added
-- A hook function is only called once for a hook event. Even if it was added multiple times
function processHooks(cnvobj, key, params)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	if #cnvobj.hook == 0 then
		return
	end
	local done = {}	-- This takes care of the possibility in case a hook modifies the hook array and some hook is removed then the hooks already executed are not executed again
	params = params or {}
	--for i=#cnvobj.hook, 1, -1 do
	local i = 1
	while i <= #cnvobj.hook do
		if not cnvobj.hook[i].disable and cnvobj.hook[i].key == key and not tu.inArray(done,cnvobj.hook[i].func) then
			done[#done + 1] = cnvobj.hook[i].func
			local status, val = pcall(cnvobj.hook[i].func, table.unpack(params))
			if not status then
				error("Key: "..key.." Hook info: "..cnvobj.hook[i].info.." error: " .. val)
			end
			i = 1
		else
			i = i + 1
		end
	end
end

-- Function to add a hook
-- key is the key at which the hook will be executed. For the list of valid keys see the top of this module
-- func is the function that is called to execute the hook
-- info is a string info to associate with the hook for logging and debugging purposes
addHook = function(cnvobj,key,func,info)
	if not cnvobj or type(cnvobj) ~= "table" then
		return nil,"Not a valid lua-gl object"
	end
	if type(func) ~= "function" then
		return nil,"Need a function to add as a hook"
	end
	local hook = {
		key = key,
		func = func,
		info = info,
		id = "H"..tostring(cnvobj.hook.ids + 1)
	}
	local index = #cnvobj.hook
	cnvobj.hook[index+1] = hook
	cnvobj.hook.ids = cnvobj.hook.ids + 1
	return hook.id
end

removeHook = function(cnvobj,id)
	if not cnvobj or type(cnvobj) ~= "table" or not id then
		return
	end
	for i = 1,#cnvobj.hook do
		if cnvobj.hook[i].id == id then
			table.remove(cnvobj.hook,i)
			break
		end
	end
end

