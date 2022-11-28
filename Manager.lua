	
-----------------------------------
-- Addon Variable Initialisation --
-----------------------------------

local addon = LongMacros;
if( not addon ) then
	error( "Global LongMacros does not exist." );
	return;
end

local module = {};
addon.manager = module;


---------------
-- Constants --
---------------

local ACCOUNT_CONFIG_VERSION = 1;
local CHARACTER_CONFIG_VERSION = 1;


--------------------------------------
--  Commonly used Global Functions  --
--------------------------------------

local sort = table.sort;
local insert = table.insert;
local pairs = pairs;


-----------------------
-- Utility functions --
-----------------------

--returns the config variable of the appropriate scope
module.getConfig = function( isPerCharacter )
	if( isPerCharacter ) then 
		return LongMacrosCharacterConfig;
	else
		return LongMacrosAccountConfig;
	end
end


-------------------------------------
-- Long Macro management functions --
-------------------------------------

--creates a new Long Macro with the given name
--Arguments:
-- isPerCharacter: true if creating a per-character macro, false if account-wide
-- name: the name of the macro to create.
-- macroData (optional): table of data for the macro to create, defaults to a fresh macro with empty text
--Returns:
-- (1) Whether a macro was created (true), or one with the same name already existed (false)
module.createMacro = function( isPerCharacter, name, macroData )
	
	--make sure macro doesn't exist yet
	local config = module.getConfig(isPerCharacter);
	if( config.macros[name] ) then
		error( "Long Macro "..name.." already exists." );
		return false;
	end
	
	--create our macro
	if( not macroData ) then
		macroData = {
			isPerCharacter = isPerCharacter,
			name = name,
			macroText = ""
		};
	else
		macroData.name = name;	--even if macroData already existed, update our name
	end
	config.macros[name] = macroData;
	
	
	--handle situations when a same-named macro already exists in the other scope
	local otherConfig = module.getConfig( not isPerCharacter );
	if( otherConfig.macros[name] ) then
		if( isPerCharacter ) then			
			--steal the other macro's button
			addon.outOfCombatCall( addon.button.setButtonMacroText, name, macroData.macroText);
		end
			
		return true;
	end
	
	
	--create our button
	addon.outOfCombatCall( addon.button.initButton, name, macroData.macroText, name);
	
	return true;
end


--deletes the Long Macro with the given name
--Returns:
-- (1) Whether a macro was deleted (true), or none existed (false)
module.deleteMacro = function( isPerCharacter, name )
	local config = module.getConfig(isPerCharacter);
	
	--if macro doesn't exist, we're done
	if( not config.macros[name] ) then
		return false;
	end
	
	--delete our macro
	config.macros[name] = nil;
	
	--handle situations when a same-named macro already exists in the other scope
	local otherConfig = module.getConfig( not isPerCharacter );
	local otherMacroData = otherConfig.macros[name]
	if( otherMacroData ) then
		if( isPerCharacter ) then
			--give our button to the other macro
			addon.outOfCombatCall( addon.button.setButtonMacroText, name, otherMacroData.macroText);
		end
			
		return true;
	end
	
	--delete our button
	addon.outOfCombatCall( addon.button.deleteButton, name );
	
	return true;
end


--renames a Long Macro
--Returns:
-- (1) Whether a macro was deleted (true), or none existed (false)
module.renameMacro = function( isPerCharacter, oldName, newName )
	local config = module.getConfig(isPerCharacter);
	local macroData = config.macros[oldName];
	
	--if macro doesn't exist, we're done
	if( not macroData ) then
		return false;
	end
	
	if module.createMacro(isPerCharacter, newName, macroData) then
		return module.deleteMacro(isPerCharacter, oldName);
	else
		return false;
	end
	
end


--alters the given long macro's text
--Returns:
-- (1) Whether a macro was altered (true), or none existed (false)
module.setMacroText = function( isPerCharacter, name, macroText )	
	local config = module.getConfig(isPerCharacter);
	local macroData = config.macros[name];
	
	--if macro doesn't exist, we're done
	if( not macroData ) then
		error( "Long Macro "..name.." doesn't exist." );
		return false;
	end
	
	--upate our macro
	macroData.macroText = macroText;
	
	--if this long macro is eclipsed by a per-character one, we're done
	if( not isPerCharacter ) and ( LongMacrosCharacterConfig.macros[name] ) then
		return true;
	end
	
	--update our button
	addon.outOfCombatCall( addon.button.setButtonMacroText, name, macroText );
	
	return true;
end



--returns the table of data for the long macro with the given name
module.getMacroData = function( isPerCharacter, name )
	return module.getConfig(isPerCharacter).macros[name];
end


--returns an ordered list of all macro names in the requested context
module.getMacroNames = function( isPerCharacter )
	local config = module.getConfig(isPerCharacter);
	
	local names = {};
	for name in pairs( config.macros ) do
		insert(names, name);
	end
	
	sort(names);
	return names;	
end

-----------------------------------
-- Saved Variables loading setup --
-----------------------------------

--initializes the savedVars for this addon, if they are not defined,
-- then creates the buttons for all existing long macros in them
module.initSavedVars = function()
	--First time running addon
    if (LongMacrosAccountConfig==nil) then
        LongMacrosAccountConfig={
        	version = ACCOUNT_CONFIG_VERSION,
        	macros = {}
        };
        
    --first time running this version
    elseif( LongMacrosAccountConfig.version ~= ACCOUNT_CONFIG_VERSION ) then
    	error(
    		string.format("Invalid account-wide saved variable version: %d\n Current version: %d",
    			LongMacrosAccountConfig.version,
    			ACCOUNT_CONFIG_VERSION
    		)
    	)
    end
    
    --First time running addon on this character
    if (LongMacrosCharacterConfig==nil) then
        LongMacrosCharacterConfig={
        	version = CHARACTER_CONFIG_VERSION,
        	macros = {}
        };
        
    --first time running this version on this character
    elseif( LongMacrosCharacterConfig.version ~= CHARACTER_CONFIG_VERSION ) then
    	error(
    		string.format("Invalid per-character saved variable version: %d\n Current version: %d",
    			LongMacrosCharacterConfig.version,
    			CHARACTER_CONFIG_VERSION
    		)
    	)
    end
    
    
    --savedVar init done, create buttons
    for name, macroData in pairs(LongMacrosCharacterConfig.macros) do
    	addon.outOfCombatCall( addon.button.initButton, name, macroData.macroText, name );
    end
    
    for name, macroData in pairs(LongMacrosAccountConfig.macros) do
    	if( not LongMacrosCharacterConfig.macros[name] ) then
    		addon.outOfCombatCall( addon.button.initButton, name, macroData.macroText, name );
    	end
    end
end


do
    local frame = CreateFrame("Frame");
    frame:RegisterEvent("ADDON_LOADED");
    
    frame.addonCount = 2;
    
    frame.OnEvent = function(self, event, loadedAddon)
        if (loadedAddon == addon.name) then
        	--initialize savedVars, and create all necessary buttons
			module.initSavedVars();
			
			--LongMacro config tables are good to go: set UI to initially show account-wide tab
			LongMacroFrame_setIsPerCharacter(false);
		
		elseif (loadedAddon == "Blizzard_MacroUI") then
        	hooksecurefunc("MacroFrame_Update", LongMacroFrame_update);
		
		else
			return;
        end		    
        
        frame.addonCount = frame.addonCount - 1;
        if( frame.addonCount == 0 ) then	
        	self:SetScript("OnEvent", nil);
        end
    end
    
    frame:SetScript("OnEvent", frame.OnEvent);
end
