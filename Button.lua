	
-----------------------------------
-- Addon Variable Initialisation --
-----------------------------------

local addon = LongMacros;
if( not addon ) then
	error( "Global LongMacros does not exist." );
	return;
end

local module = {};
addon.button = module;

--------------------------------------
--  Commonly used Global Functions  --
--------------------------------------

local gmatch = string.gmatch;
local match = string.match;
local strlower = strlower;

local insert = table.insert;
local ipairs = ipairs;
local pairs = pairs;
local next = next;
local max = max;

local SecureCmdItemParse = SecureCmdItemParse;
local GetContainerItemID = GetContainerItemID;
local GetInventoryItemID = GetInventoryItemID;
local QueryCastSequence = QueryCastSequence;
local GetNetStats = GetNetStats;
local GetMacroBody = GetMacroBody;
local SetMacroItem = SetMacroItem;
local SetMacroSpell = SetMacroSpell;

---------------
-- Constants --
---------------

local BLIZZ_MACRO_SIZE_MAX = 255;
local BUTTON_NAME_PREFIX = "LongMacro_";
local AUTO_GENERATED_PREFIX = "#longmacro\n";

module.AUTO_GENERATED_PATTERN = "^" .. AUTO_GENERATED_PREFIX;

-------------------------------------------
--  Custom macro state update functions  --
-------------------------------------------

--snippet of code to run every time our custom driver changes states
--Arguments:
-- self: the frame running the snippet
-- newstate: the current state of our driver
local ON_MACROSTATE_SNIPPET = [[
	local command, target, action = strmatch( newstate or "", "^<(.*),(.*)>%s*(.*)" );
	local targetPrefix;
	
	if( target == "" ) or ( target == "target" ) then target = nil; end
	
	self:SetAttribute("state-command", command);
	self:SetAttribute("state-target", target);
	self:SetAttribute("state-action", action);
	
	control:CallMethod("updateEventHandlers");
    control:CallMethod("updateMacro");
]];


--function that converts a slash command's arguments string into a state-parseable line of "[conditions] <command,target> action" states, separated by semicolons
--Arguments:
-- command: the slash command that's being parsed (e.g.: "/cast" )
-- args: the arguments string to parse (e.g.: "[help] Heal; [mod,@focus][combat,@focus][] Smite" )
--Returns:
-- (1) the resulting parsed string (e.g.: "[help] </cast,> Heal; [mod,@focus][combat,@focus] </cast,focus> Smite; [] </cast,> <castsequence> Smite" )
-- (2) whether the parsed string is terminal (contains an always-true condition, or a conditionless block)
module.parseMacroLine = function( command, args )
	command = command or "";
	local result = "";
	local isTerminal = false;
	local separator = "";	--becomes ";" after first block
	
	local conditions, actions;
	local lastTarget, matchingConditions;
	local target;
	
	--split args into semicolon-separated blocks
	--(the separator and all whitespace immediately after it are stripped)
	for conditionBlock in gmatch( args, "([^;]+);?%s*" ) do
		conditions, actions = match( conditionBlock, "(%[.*%])([^%[%]]*)" );		
		
		if( not conditions ) then
			conditions = "[]";
			actions = conditionBlock;
		end
		
		--get rid of useless first arg in case of equipslot
		if( command == "/equipslot" ) then
			actions = match( actions, "%S*%s*(.*)" );
		end
		
		--separate conditions that have different targets
		lastTarget = nil;
		matchingConditions = "";	--consecutive conditions with the same target	
		for condition in gmatch(conditions, "%b[]" ) do
			target = match( condition, "@([^,%]]+)" ) or match( condition, "target=([^,%]]+)" ) or "";
			
			if( matchingConditions == "") or (target == lastTarget) then	--first condition, or it matches previous one's target: smoosh them together
				matchingConditions = matchingConditions .. condition;
				
			else															--diferent target from last condition: add what DID match to the result string
				result = result .. separator .. matchingConditions .. "<" .. command .. "," .. lastTarget .. ">" .. actions;
				separator = ";";
			
				matchingConditions = condition;								--and reset our matching string with just the new condition
			end
			
			lastTarget = target;
			
			--blocks with a [] condition are always run, no need to check anything after them
			if( condition == "[]" ) then 	
				isTerminal = true;
				break;
			end
		end
		
		--add the last matching condition chunk to result string
		result = result .. separator .. matchingConditions .. "<" .. command .. "," .. lastTarget .. ">" .. actions;
		separator = ";";
	
		if isTerminal then
			return result, true;
		end	
	end
	
	return result, false;
end


--function that converts a macro's string into a single state-parsable line of "[conditions] <command,target> action", separated by semicolons
--Returns:
-- (1) the resulting parsed string
-- (2) whether the parsed string contains any castsequence commands
-- (3) whether the parsed string contains any showtooltip commands (even if they don't have any args)
module.parseMacroString = function( macroString )
	local result = "";
	local separator = "";	--becomes ";" after first line
	local foundTerminal = false;
	local foundCastsequence = false;
	local foundShowtooltip = false;
 	
 	local command, args;
 	local parsedArgs, isTerminal;
 	
 	--split macro into lines
 	for line in gmatch( macroString, "[^\r\n]+") do
 		command, args = match( line, "^([#/]%S+)%s*(.*)$" );
 		foundShowtooltip = foundShowtooltip or (command == "#showtooltip");
 		
		--catch just the lines that are valid commands with at least one argument
 		if (command and args and (args ~= "") ) then
 			command = strlower(command);
						
			parsedArgs, isTerminal = nil, false;
			
			--find out what command we were given, parse its args if appropriate command
			if( command == "#show" or
				command == "#showtooltip"
			) then
				parsedArgs, isTerminal = module.parseMacroLine(command, args);				
				foundTerminal = foundTerminal or isTerminal;
				
				if( result == "" ) then
					isTerminal = true;
				end
				
				
			elseif(	command == "/cast" or
					command == "/use" or
					command == "/spell" or
					command == "/equip" or
					command == "/equipslot"
			) then
				parsedArgs, isTerminal = module.parseMacroLine(command, args);				
				foundTerminal = foundTerminal or isTerminal;
				
			
			elseif(	command == "/castrandom" or
					command == "/userandom"
			) then
				args = match( args, "^[^,]+" );
				if( args ) then
					parsedArgs, isTerminal = module.parseMacroLine(command, args);				
					foundTerminal = foundTerminal or isTerminal;
				end
			
			
			elseif ( command == "/castsequence" ) then
				parsedArgs, isTerminal = module.parseMacroLine(command, args);				
				foundTerminal = foundTerminal or isTerminal;
				foundCastsequence = true;
			end
			
			
			--add prased args to resulting string
			if( parsedArgs ) then
				result = result .. separator .. parsedArgs;
				separator = ";";
						
				if isTerminal then
					break;
				end	
			end	
			
		end
	end
	
	if( not foundTerminal ) then	--to ensure we're always in SOME state, add a dummy blank one if no terminal condition was found
		result = result .. separator .. module.parseMacroLine("#show", "[]");
	end
	
	return result, foundCastsequence, foundShowtooltip;
end



-- function to update the given macro's spell or item with the given command's action and target
--Arguments:
-- self: the stateHandler frame updating its macro
-- writeBlizzIfEmpty (optional): whether we should write the blizz macro's text, if it's currently empty
module.stateHandler_updateMacro = function( self, writeBlizzIfEmpty )
	self.needsUpdate = false;
	
	local blizzMacroName = self.blizzMacroName;
	if( not blizzMacroName ) or ( not GetMacroBody(blizzMacroName) ) then
		return
	end
	
	if writeBlizzIfEmpty and (self.blizzMacroString ~= "") then
		module.safeEditBlizzMacro(blizzMacroName, self.blizzMacroString);
	end
	
	local command = self:GetAttribute("state-command");
	local target = self:GetAttribute("state-target");
	local action = self:GetAttribute("state-action");
	
	local _, item, spell, bag, slot;
	local itemID;
	
	if( action ) then
		_, item, spell = QueryCastSequence(action);		--also works for regular cast parsing, to tell items from spells
		
		if( item ) then
			_, bag, slot = SecureCmdItemParse(item);
		
			if( slot ) then
				--use equipped, or from bags?
				if( bag ) then
					self.itemBag = 0+bag;
					itemID = GetContainerItemID(bag, slot);
				else
					itemID = GetInventoryItemID("player", slot);
				end				
				
				
				--make sure the targetted slot isn't empty
				if( itemID ) then
					item = "item:" .. itemID;
				else
					item = nil;	--slot empty: show nothing
					spell = nil;
				end				
			end			
		end

		if( command == "/castsequence" ) then 
			self.castSequenceSpell = spell;
		
		elseif( match(action, "," )	 ) then		-- Not a castsequence, but there's a comma in the action string anyway? 
			spell = action;						-- That means it's a spell with a weird name, like "Invoke Xuen, the White Tiger".
		end
		
	end
	
	if( item ) then
		SetMacroItem(blizzMacroName, item, target);
		
	elseif( spell ) then
		SetMacroSpell(blizzMacroName, spell, target);
			
	else
		SetMacroItem( blizzMacroName, "item:1217" );	--this is a valid item with a questionmark icon (to force icon update)
		SetMacroSpell( blizzMacroName, "" );			--smoosh it with "cast nothing" immediately afterwards
	end
end


--force button state update
module.stateHandler_forceUpdateState = function( self )
	local onStateSnippet = self:GetAttribute("_onstate-macrostate") or "";
			
	local loadedFunc = loadstring( "return function( self, newstate, control ) " .. onStateSnippet .. " end" );
	loadedFunc()(
		self,
		SecureCmdOptionParse(self.stateDriverString or ""),
		{
			CallMethod = function(control, methodName, ...)
			    self[methodName](self, ...);
			end
		}
	);
end


-- function to update which of the given macro's event handlers should be active
module.stateHandler_updateEventHandlers = function( self )
	
	local command = self:GetAttribute("state-command");
	local action = self:GetAttribute("state-action");
	local target = self:GetAttribute("state-target");
	
	local targetPrefix = target and match(target, "^(.+)target$" );	
	self.targetPrefix = targetPrefix;
	
	self:conditionalRegisterEvent( "UNIT_TARGET", targetPrefix );											--if macro is [@somethingtarget], listen to when something's target changes
	self:conditionalRegisterEvent( "PLAYER_FOCUS_CHANGED", (target == focus) or (targetPrefix == focus) );	--if macro is [@focus] or {@focustarget], listen to when focus changes
	
	
	local reset, resetTime;
	
	if( command == "/castsequence" ) then
		self:RegisterEvent("PLAYER_DEAD");
		self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED");
		
		reset = match(action, "^reset=(%S*)%s" ) or "";
		
		self:conditionalRegisterEvent( "PLAYER_TARGET_CHANGED", strmatch(reset, "target") );
		self:conditionalRegisterEvent( "PLAYER_REGEN_ENABLED", strmatch(reset, "combat") );
		self:conditionalRegisterEvent( "MODIFIER_STATE_CHANGED", strmatch(reset, "alt") or strmatch(reset, "ctrl") or strmatch(reset, "shift") );
		
		
		resetTime = strmatch( reset, "%d+" );
		if( resetTime ) then
			self.castSequenceResetTime = 0+resetTime;
		end
		
		self:conditionalRegisterEvent( "UNIT_SPELLCAST_INTERRUPTED", resetTime );
		self:conditionalRegisterEvent( "UNIT_SPELLCAST_FAILED", resetTime );
		self:conditionalRegisterEvent( "UNIT_SPELLCAST_FAILED_QUIET", resetTime );
		self:conditionalRegisterEvent( "UNIT_SPELLCAST_SENT", resetTime );
		
			
	else	--not a castsequence: don't listen to any events
		self:UnregisterEvent("PLAYER_DEAD");
		self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED");		
		
		self:UnregisterEvent("PLAYER_TARGET_CHANGED");
		self:UnregisterEvent("PLAYER_REGEN_ENABLED");
		self:UnregisterEvent("MODIFIER_STATE_CHANGED");
		
		self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED");
		self:UnregisterEvent("UNIT_SPELLCAST_FAILED");
		self:UnregisterEvent("UNIT_SPELLCAST_FAILED_QUIET");
		self:UnregisterEvent("UNIT_SPELLCAST_SENT");
	end
end



--enables/disables handling of a given event, depending on a given condition
module.stateHandler_conditionalRegisterEvent = function( self, event, condition )
	if( condition ) then
		self:RegisterEvent(event);
	else
		self:UnregisterEvent(event);
	end
end




-----------------------------------------
--  Event / Update handling functions  --
-----------------------------------------

--table of auxiliary functions for event handling
do	
	module.eventHandlers = {};	
	local eventHandlers = module.eventHandlers;
	
	
	eventHandlers["UPDATE_MACROS"] = function( self )
		self:updateMacro( true );	--also write the macro's body if it's blank
	end
	
	
	
	eventHandlers["UNIT_INVENTORY_CHANGED"] = function( self, event, unit )
		if( unit == "player" ) then
			self.needsUpdate = true;
		end
	end
	
	eventHandlers["ACTIONBAR_SLOT_CHANGED"] = function( self, event, slot )
		if( GetActionInfo(slot) == "macro" ) then
			self.needsUpdate = true;
		end
	end
	
	eventHandlers["UNIT_TARGET"] = function( self, event, unit )
		if( self.targetPrefix == unit ) then
			self.needsUpdate = true;
		end
	end
	
	
	local spellcastHandler = function( self, event, ... )
		local unit, spellName, spellId
		
		if ( event == "UNIT_SPELLCAST_SENT" ) then
			unit, _, _, spellId = ...
		else
			unit, _, spellId = ...
		end
	
		if ( spellId ) then
			spellName = GetSpellInfo(spellId)
		end
	
		if ( not spellName ) or ( unit ~= "player" and unit ~= "pet") then
			return;
		end
		
		if( strlower(spellName) ~= self.castSequenceSpell ) then
			return
		end
		
		local resetTime;
		local _, lagHome, lagWorld;
		local delay;
			
		--cast finished: update now
		if ( event == "UNIT_SPELLCAST_SUCCEEDED"  ) then
			self.needsUpdate = true;
			
		--cast started (or failed to start): reset after time expires
		else
			resetTime = self.castSequenceResetTime;
			
			if( resetTime ) then
				_, _, lagHome, lagWorld = GetNetStats();
				delay = max(lagHome, lagWorld)/1000;
				
				self.scheduledUpdates = self.scheduledUpdates or {};
				insert( self.scheduledUpdates, resetTime + delay);
				insert( self.scheduledUpdates, resetTime + delay + max(delay, 1));	--account for lag possibly doubling, or increasing by one second (whichever's worse)		
			end
		end
	end
	eventHandlers["UNIT_SPELLCAST_SUCCEEDED"] = spellcastHandler;
	eventHandlers["UNIT_SPELLCAST_INTERRUPTED"] = spellcastHandler;
	eventHandlers["UNIT_SPELLCAST_FAILED"] = spellcastHandler;
	eventHandlers["UNIT_SPELLCAST_FAILED_QUIET"] = spellcastHandler;
	eventHandlers["UNIT_SPELLCAST_SENT"] = spellcastHandler;
	
	
	local genericHandler = function ( self )
		self.needsUpdate = true;
	end
	eventHandlers["BAG_UPDATE_DELAYED"] = genericHandler;
	eventHandlers["SPELLS_CHANGED"] = genericHandler;
	eventHandlers["PLAYER_EQUIPMENT_CHANGED"] = genericHandler;
	eventHandlers["MERCHANT_CLOSED"] = genericHandler;
	eventHandlers["CRITERIA_UPDATE"] = genericHandler;
	eventHandlers["PLAYER_DEAD"] = genericHandler;
	eventHandlers["PLAYER_TARGET_CHANGED"] = genericHandler;
	eventHandlers["PLAYER_FOCUS_CHANGED"] = genericHandler;
	eventHandlers["PLAYER_REGEN_ENABLED"] = genericHandler;
	eventHandlers["MODIFIER_STATE_CHANGED"] = genericHandler;
end

-- function to be run every time a castsequence-related event happens
module.stateHandler_onEvent = function( self, event, ... )
	local handler = module.eventHandlers[event];
	if( handler ) then
		handler( self, event, ... );
	end	
end


-- function to keep frame spell updated any time changes happen
module.stateHandler_onUpdate = function( self, elapsed )		
	if( self.needsUpdate ) then
		self:updateMacro();
	end
	
	if( self.scheduledUpdates ) then
		for k, v in pairs(self.scheduledUpdates) do
			self.scheduledUpdates[k] = v-elapsed;
			
			if( self.scheduledUpdates[k] <= 0 ) then
				self.scheduledUpdates[k] = nil;
				self.needsUpdate = true;	--update on NEXT frame
			end
		end
		
		if( self.needsUpdate and not next(self.scheduledUpdates) ) then
			self.scheduledUpdates = nil;	--list empty: drop it
		end
	end
end


-------------------------------------------
--  Blizzard macro management functions  --
-------------------------------------------

--generates the text for a blizzard macro associated with the given button name
module.generateBlizzMacroText = function( longMacroName, hasShowtooltip )
	local buttonName = module.toButtonName(longMacroName);
	local charsLeft = BLIZZ_MACRO_SIZE_MAX;
	
	local comments = AUTO_GENERATED_PREFIX;
	local command = "/click ";
	local args = buttonName;
	
	local line;
	local options;
	
	charsLeft = charsLeft - comments:len() - command:len() - args:len();
	if( charsLeft < 0 ) then
		error( "Generated button name is too long." );
		return;
	end
	
	if( hasShowtooltip ) then
		line = "#showtooltip\n";
		charsLeft = charsLeft - line:len();	
		
		if( charsLeft >= 0 ) then
			comments = comments .. line;
		end
	end
	
	options = {
		 "[btn:2]" .. buttonName .. " RightButton; ",
		 "[btn:3]" .. buttonName .. " MiddleButton; ",
		 "[btn:4]" .. buttonName .. " Button4; ",
		 "[btn:5]" .. buttonName .. " Button5; ",
	}
	
	for _, option in ipairs( options ) do
		charsLeft = charsLeft - option:len();	
		
		if( charsLeft >= 0 ) then
			args = option .. args;
		else
			break;
		end
	end
	
	return comments .. command .. args;
end

--edits one of blizzard's macros, but only if it's empty, or was auto-generated
--will delay macro changes until player is out of combat
--Arguments:
-- blizzMacroName: name of blizzard macro to edit
-- body: the body to give that macro, if appropriate
-- autoGeneratedPattern (optional): specifies what pattern auto-generated macros must match (if ommitted, only empty macros will be edited)
-- forceRefresh (optional): if true, EditMacro will still be called (causing no changes) if macro wasn't auto-generated
--		(this gets rid of any lingering SetMacroSpell/SetMacroIcon on that macro)
--Returns:
--(1) whether a macro with the given name exists
module.safeEditBlizzMacro = function( blizzMacroName, body, autoGeneratedPattern, forceRefresh )
	local oldBody = blizzMacroName and GetMacroBody(blizzMacroName);
	
	if( oldBody ) then
		if( oldBody == "" ) or ( autoGeneratedPattern and match(oldBody, autoGeneratedPattern) ) then 
			addon.outOfCombatCall( EditMacro, blizzMacroName, nil, nil, body );
			
		elseif( forceRefresh ) then
			addon.outOfCombatCall( EditMacro, blizzMacroName, nil, nil, oldBody );
			
		end
		
		return true;
		
	else
		return false;		
	end
end


-----------------------------------
--  Button management functions  --
-----------------------------------

--table of "deleted" buttons
local deletedButtons = {};


--returns the button name associated with a given long macro name
module.toButtonName = function( longMacroName )
	return BUTTON_NAME_PREFIX .. longMacroName;
end


--returns the button with the given longMacroName, if it exists and hasn't been deleted
module.getButton = function( longMacroName )
	--if button's dead, return nothing
	if( deletedButtons[longMacroName] ) then
		return nil;
	end
	
	local buttonName = module.toButtonName(longMacroName);
	return _G[buttonName];
end


--"deletes" the custom macro button with the given name
module.deleteButton = function( longMacroName )	
	local btn = module.getButton( longMacroName );
	
	--do nothing if button doesn't exist
	if( not btn ) then
		return;
	end
	
	
	--button destruction
	deletedButtons[longMacroName] = btn;
	
	btn.stateDriverString = nil;
	btn:Disable();
	btn:setBlizzMacro( nil );	
	
	
	--statehandler destruction
	local stateHandler = btn.stateHandler;
	
	stateHandler.blizzMacroString = nil;
	stateHandler:SetScript("OnUpdate", nil);
	stateHandler:SetScript("OnEvent", nil);	
	UnregisterStateDriver(stateHandler, "macrostate");		
end


--creates a custom macro button with the given name
--(will re-use previously destroyed button frames with the same name)
module.createButton = function( longMacroName )
	local btn = deletedButtons[longMacroName];
		
	--revive button if it's dead
	if( btn ) then
		deletedButtons[longMacroName] = nil;
		
		btn:Enable();		
		
		return btn;
		
	--create new button if it isn't dead
	else			
		if module.getButton( longMacroName ) then
			error( "Button " .. longMacroName .. " already exists." );
			return;
		end

		--button setup
		btn = CreateFrame("button", module.toButtonName(longMacroName), UIParent , "SecureUnitButtonTemplate");
		btn.longMacroName = longMacroName;
		
		btn.delete = module.button_delete;
		btn.setMacroText = module.button_setMacroText;
		btn.setBlizzMacro = module.button_setBlizzMacro;
		
		btn:SetAttribute("type", "macro");
		
		--statehandler setup
		local stateHandler = CreateFrame("frame", nil, btn, "SecureHandlerStateTemplate");
		btn.stateHandler = stateHandler;
		
		stateHandler.conditionalRegisterEvent = module.stateHandler_conditionalRegisterEvent;
		
		stateHandler.updateEventHandlers = module.stateHandler_updateEventHandlers;			
		stateHandler.updateMacro = module.stateHandler_updateMacro;
		stateHandler.forceUpdateState = module.stateHandler_forceUpdateState;
		
		
		return btn;
	end	
end



--alters the macroText of the custom macro button with the given name
module.setButtonMacroText = function( longMacroName, macroText )
	local btn = module.getButton( longMacroName );
	
	if( not btn ) then
		error( "Button " .. longMacroName .. " does not exist." );
		return;
	end
	
	btn:setMacroText( macroText );
end


--creates a custom macro button and associated state driver, and initializes them
module.initButton = function( longMacroName, macroText, blizzMacroName )
	local btn = module.createButton( longMacroName );
	btn:setMacroText( macroText );
	btn:setBlizzMacro( blizzMacroName );
end


--"deletes" the given custom macro button
module.button_delete = function( self )
	module.deleteButton( self.longMacroName );
end


--alters the given custom button's macro text, updating everything associated with it
module.button_setMacroText = function( self, macroText )	
	--button setup
	self:SetAttribute("macrotext", macroText);
		
	--statehandler setup
	local stateHandler = self.stateHandler;
	
	local stateDriverString, foundCastsequence, foundShowtooltip = module.parseMacroString(macroText);
	stateHandler.stateDriverString = stateDriverString;
	
	local oldMacroString = stateHandler.blizzMacroString;
	stateHandler.blizzMacroString = module.generateBlizzMacroText( self.longMacroName, foundShowtooltip );
	
	--keep blizz macro updated, if we wrote its body
	if( oldMacroString ~= stateHandler.blizzMacroString ) then
		module.safeEditBlizzMacro( stateHandler.blizzMacroName, stateHandler.blizzMacroString, module.AUTO_GENERATED_PATTERN );
	end
	
	
	--setup event handling
	stateHandler:UnregisterAllEvents();
	stateHandler:RegisterEvent("UPDATE_MACROS");
	stateHandler:RegisterEvent("UNIT_INVENTORY_CHANGED");
	stateHandler:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
	stateHandler:RegisterEvent("BAG_UPDATE_DELAYED");
	stateHandler:RegisterEvent("SPELLS_CHANGED");
	stateHandler:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	stateHandler:RegisterEvent("MERCHANT_CLOSED");
	--stateHandler:RegisterEvent("CRITERIA_UPDATE");  --This event was firing WAY too often, resulting in a massive FPS drop.
	stateHandler:SetScript("OnEvent", module.stateHandler_onEvent);
	stateHandler:SetScript("OnUpdate", module.stateHandler_onUpdate);
	
	
	
	--make frame respond to macro state changes
	RegisterStateDriver(stateHandler, "macrostate", stateDriverString );
	stateHandler:SetAttribute("_onstate-macrostate", ON_MACROSTATE_SNIPPET);
	
	stateHandler:forceUpdateState();
end


--alters what blizzard macro the given custom button should be associated with
module.button_setBlizzMacro = function( self, blizzMacroName )
	local stateHandler = self.stateHandler;
	local oldMacroName = stateHandler.blizzMacroName
	
	if ( blizzMacroName == oldMacroName) then
		return;		--no change happened, we're done
	end

	--update new macro
	stateHandler.blizzMacroName = blizzMacroName;
	module.safeEditBlizzMacro( blizzMacroName, stateHandler.blizzMacroString, module.AUTO_GENERATED_PATTERN );
	
	--clear old macro (if we didn't write it, keep it as is, but force a refresh)
	module.safeEditBlizzMacro( oldMacroName, "", module.AUTO_GENERATED_PATTERN, true );	
end
