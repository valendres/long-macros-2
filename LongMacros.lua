
-----------------------------------
-- Addon Variable Initialisation --
-----------------------------------

if( LongMacros ) then
	error( "Global LongMacros already exists." );
	return;
end

local addon = {};
addon.name = "LongMacros";

LongMacros = addon;


--------------------------------------
--  Commonly used Global Functions  --
--------------------------------------

local insert = table.insert;
local ipairs = ipairs;
local unpack = unpack;
local print = print;

local InCombatLockdown = InCombatLockdown;



-------------------------
-- Slash-command setup --
-------------------------
SLASH_LONGMACRO1 = '/l';
SLASH_LONGMACRO2 = '/lm';
SLASH_LONGMACRO3 = '/longmacro';
function SlashCmdList.LONGMACRO(msg, editbox)
    addon.ui.frame_show();
end


--------------------------
--  Out-of-combat only  --
--   function calling   --
--------------------------

--calls callback with the given arguments as soon as the player is out of combat
--Returns:
-- (1)	whether the callback function was immediately called (true), or it was delayed (false)
-- (...)everything that the callback function returned, if it was called immediately
addon.outOfCombatCall = function( callback, ... )
	if( InCombatLockdown() ) then
		
		if( not addon.outOfCombatQueue ) then
			print("LongMacros: Currently in combat. Delaying changes until combat ends...");
			addon.outOfCombatQueue = {};
			addon.outOfCombatFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
		end
		
		insert( addon.outOfCombatQueue,
			{
				callback = callback,
				args = {...}
			}
		);
		return false;
		
	else
		return true, callback( ... );
	end
end


--end-of-combat event handling setup
do
	local frame = CreateFrame("frame");
	addon.outOfCombatFrame = frame;

	local function onEvent (self, event, ...)
		frame:UnregisterEvent("PLAYER_REGEN_ENABLED");
		
		print("LongMacros: ...combat ended. Applying delayed changes.");
		
		for _, queued in ipairs(addon.outOfCombatQueue) do
			queued.callback( unpack(queued.args) );
		end
		addon.outOfCombatQueue = nil;
		
	end
	
	frame:SetScript("OnEvent", onEvent);
end

