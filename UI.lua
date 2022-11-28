	
-----------------------------------
-- Addon Variable Initialisation --
-----------------------------------

local addon = LongMacros;
if( not addon ) then
	error( "Global LongMacros does not exist." );
	return;
end

local module = {};
addon.ui = module;


---------------
-- Constants --
---------------

LONGMACROFRAME_CHAR_LIMIT_STRING = "%d/1023 Characters Used";

local NUM_LONGMACROS_PER_ROW = 6;

local DEFAULT_BLIZZ_MACRO_ICON = "INV_Misc_QuestionMark";
local MACRO_NOT_FOUND_TEXTURE = "INTERFACE\\ADDONS\\".. addon.name .."\\Textures\\Icon_QuestionMark";
local MACRO_LOCKED_TEXTURE = "INTERFACE\\ADDONS\\".. addon.name .."\\Textures\\Icon_Lock";

--common dialog prefixes 
local ACCOUNT_BLIZZ_MACRO_PREFIX_STRING = "The Blizzard Macro associated with this Long Macro is account-wide.\n\n";
local CREATE_BLIZZ_MACRO_PREFIX_STRING = "Unused Blizzard Macro slots:\n%d account-wide, %d "..UnitName("player").." specific.\n\n";
local DUPLICATE_BLIZZ_MACRO_PREFIX_STRING = "A Blizzard Macro named %s already exists.\n";
local DUPLICATE_BLIZZ_MACRO_DISCONNECT_PREFIX_STRING = DUPLICATE_BLIZZ_MACRO_PREFIX_STRING .. "Renaming this Long Macro will disconnect it from its old Blizzard Macro.\n\n";
local DUPLICATE_BLIZZ_MACRO_DELETE_PREFIX_STRING = DUPLICATE_BLIZZ_MACRO_PREFIX_STRING .. "Renaming this Long Macro will delete its old Blizzard Macro.\n\n";

--delete long macro dialog prompts
local DELETE_LONG_MACRO_PROMPT_STRING = "Do you want to delete this Long Macro?";
local DELETE_BOTH_MACROS_PROMPT_STRING = "Do you want to delete this Long Macro, and the Blizzard Macro associated with it?";
local DELETE_WHICH_MACRO_PROMPT_STRING = ACCOUNT_BLIZZ_MACRO_PREFIX_STRING .."Which do you want to delete?";

--create blizz macro dialog prompts
local CREATE_BLIZZ_MACRO_WHICH_PROMPT_STRING = CREATE_BLIZZ_MACRO_PREFIX_STRING .. "Which kind of macro do you want to create?";
local CREATE_BLIZZ_MACRO_ACCOUNT_PROMPT_STRING = CREATE_BLIZZ_MACRO_PREFIX_STRING .. "Create an account-wide macro?";
local CREATE_BLIZZ_MACRO_CHARACTER_PROMPT_STRING = CREATE_BLIZZ_MACRO_PREFIX_STRING .. "Create a "..UnitName("player").." specific macro?";

--failure messages
local FAIL_BLIZZ_MACROS_FULL_FEEDBACK_STRING = "No more room for Blizzard Macros.";
local FAIL_PICKUP_DURING_COMBAT_FEEDBACK_STRING = "Can't pick up Blizzard Macros during combat.";
local FAIL_PICKUP_ECLIPSED_FEEDBACK_STRING = "Can't pick up this Long Macro while a %s specific one with the same name exists.";

--rename long macro dialog prompts
local RENAME_WHICH_MACRO_PROMPT_STRING = ACCOUNT_BLIZZ_MACRO_PREFIX_STRING .. "Which do you want to rename?";
local RENAME_LONG_MACRO_PROMPT_STRING = DUPLICATE_BLIZZ_MACRO_DISCONNECT_PREFIX_STRING .. "Rename anyway?";

local RENAME_WHAT_BLIZZ_MACRO_PROMPT_STRING = DUPLICATE_BLIZZ_MACRO_DISCONNECT_PREFIX_STRING .. "What do you want to do with the old Blizzard Macro?";
local RENAME_DELETE_BLIZZ_MACRO_PROMPT_STRING = DUPLICATE_BLIZZ_MACRO_DELETE_PREFIX_STRING .. "Rename anyway?";


--button labels
local BOTH_MACROS_BUTTON_STRING = "Both Macros";
local LONG_MACRO_BUTTON_STRING = "Long Macro Only";

local DELETE_BLIZZ_MACRO_BUTTON_STRING = "Delete Blizz Macro";
local KEEP_BLIZZ_MACRO_BUTTON_STRING = "Keep Blizz Macro";

local CREATE_ACCOUNT_BLIZZ_MACRO_BUTTON_STRING = "Account-Wide";
local CREATE_CHARACTER_BLIZZ_MACRO_BUTTON_STRING = UnitName("player").." Specific";


--------------------------------------
--  Commonly used Global Functions  --
--------------------------------------

local ceil = math.ceil;
local max = max;

local gsub = string.gsub;
local match = string.match;
local strlen = strlen;

local type = type;
local next = next;

local InCombatLockdown = InCombatLockdown;


--------------------------
-- Static Popup Dialogs --
--------------------------

StaticPopupDialogs["LONG_MACRO_CONFIRM_DELETE"] = {
	--text = DELETE_WHICH_MACRO_PROMPT_STRING,	--fill or clear these fields before caling StaticPopup_Show()
	--button1 = BOTH_MACROS_BUTTON_STRING,
	--button2 = LONG_MACRO_BUTTON_STRING,
	
	OnAccept = function(self, data)
		module.deleteMacro( data.isPerCharacter, data.macroName );
		module.deleteBlizzMacro( data.blizzMacroName );
	end,
	
	OnCancel = function(self, data)
		module.deleteMacro( data.isPerCharacter, data.macroName );
	end,
	
	button3 = CANCEL,
	
	hideOnEscape = true,
	noCancelOnEscape = true,
	noCancelOnReuse = true,
	notClosableByLogout = true,
	
	sound = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON,
	showAlert = true,
	preferredIndex = STATICPOPUPS_NUMDIALOGS,
	timeout = 0,
	whileDead = true
};


StaticPopupDialogs["LONG_MACRO_CONFIRM_DELETE_BLIZZ"] = {
	--text = DELETE_BLIZZ_MACRO_PROMPT_STRING,	--fill or clear these fields before caling StaticPopup_Show()
	--button1 = DELETE_BLIZZ_MACRO_BUTTON_STRING,
	--button2 = KEEP_BLIZZ_MACRO_BUTTON_STRING,
	
	OnAccept = function(self, data)		
		module.renameMacro( data.isPerCharacter, data.macroName, data.newMacroName );
		module.deleteBlizzMacro( data.blizzMacroName );
	end,
	
	OnCancel = function(self, data)
		module.renameMacro( data.isPerCharacter, data.macroName, data.newMacroName );
	end,
	
	button3 = CANCEL,
	
	hideOnEscape = true,
	noCancelOnEscape = true,
	noCancelOnReuse = true,
	notClosableByLogout = true,
	
	sound = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON,
	showAlert = true,
	preferredIndex = STATICPOPUPS_NUMDIALOGS,
	timeout = 0,
	whileDead = true
};


StaticPopupDialogs["LONG_MACRO_CONFIRM_RENAME"] = {
	--text = RENAME_WHICH_MACRO_PROMPT_STRING,	--fill or clear these fields before caling StaticPopup_Show()
	--button1 = BOTH_MACROS_BUTTON_STRING,
	--button2 = LONG_MACRO_BUTTON_STRING,
	
	OnAccept = function(self, data)
		module.renameMacro( data.isPerCharacter, data.macroName, data.newMacroName );
		module.renameBlizzMacro( data.blizzMacroName, data.newMacroName );
	end,
	
	OnCancel = function(self, data)
		module.renameMacro( data.isPerCharacter, data.macroName, data.newMacroName );
	end,
	
	button3 = CANCEL,
	
	hideOnEscape = true,
	noCancelOnEscape = true,
	noCancelOnReuse = true,
	notClosableByLogout = true,
	
	sound = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON,
	preferredIndex = STATICPOPUPS_NUMDIALOGS,
	timeout = 0,
	whileDead = true
};


StaticPopupDialogs["LONG_MACRO_CONFIRM_CREATE_BLIZZ"] = {
	--text = CREATE_BLIZZ_MACRO_WHICH_PROMPT_STRING,	--fill or clear these fields before caling StaticPopup_Show()
	--button1 = CREATE_ACCOUNT_BLIZZ_MACRO_BUTTON_STRING,
	--button2 = CREATE_CHARACTER_BLIZZ_MACRO_BUTTON_STRING,
	
	OnAccept = function(self, data)
		module.createBlizzMacro(false, data.blizzMacroName);
	end,
	
	OnCancel = function(self, data)
		module.createBlizzMacro(true, data.blizzMacroName);
	end,
	
	button3 = CANCEL,
	
	hideOnEscape = true,
	noCancelOnEscape = true,
	noCancelOnReuse = true,
	notClosableByLogout = true,
	
	sound = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON,
	preferredIndex = STATICPOPUPS_NUMDIALOGS,
	timeout = 0,
	whileDead = true
};

StaticPopupDialogs["LONG_MACRO_FAIL_FEEDBACK"] = {
	--text = FAIL_BLIZZ_MACROS_FULL_FEEDBACK_STRING,	--fill this field before calling StaticPopup_Show()
	
	button2 = OKAY,
	
	hideOnEscape = true,
	
	sound = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON,
	showAlert = true,
	preferredIndex = STATICPOPUPS_NUMDIALOGS,
	timeout = 4,
	whileDead = true
};



-----------------------
-- Utility functions --
-----------------------

--Shows the Long Macro frame
module.frame_show = function(  )
	ShowUIPanel(LongMacroFrame);
end



----------------------------------------
--  Assorted gold-painting functions  --
----------------------------------------

--paints a Texture object gold
local paintTextureGold = function( texture )
	if texture == nil then return end
	
	texture:SetVertexColor(1, .75, .2, 1);
end


--paints all Texture objects inside a given frame gold
local paintFrameTexturesGold = function( frame )
	if frame == nil then return end
	
	for _, region in pairs( { frame:GetRegions() } ) do
		if( region:GetObjectType() == "Texture" ) then
			paintTextureGold(region)
		end
	end
end


--paints the "empty button" background of a Long Macro Button
LongMacroButton_paintGold = function( self )	
	self:RegisterForDrag("LeftButton");
	
	--(the texture we want is anonymous, so we need to do some digging)
	for _, region in pairs( { self:GetRegions() } ) do
		if( region:GetObjectType() == "Texture" and region:GetTexture() == "Interface\\Buttons\\UI-EmptySlot-Disabled" ) then
			paintTextureGold(region)
			return;
		end
	end
end


--paints the up, down, and current-scroll elements of a scroll frame
LongMacroScrollFrame_paintGold = function( self )
	local scrollBar = self.ScrollBar;
	paintFrameTexturesGold(scrollBar.ScrollUpButton);	--up arrow
	paintFrameTexturesGold(scrollBar.ScrollDownButton);	--down arrow
	
	paintTextureGold(
		_G[ scrollBar:GetName().."ThumbTexture" ]	--current scroll square
	)
end


--paints a tab
LongMacroTabButton_paintGold = function( self )
	paintFrameTexturesGold(self)
end


--paints a panel button
LongMacroPanelButton_paintGold = function( self )
	paintFrameTexturesGold(self)
end


--paints the long macro frame, and its various subtextures
LongMacroFrame_paintGold = function( self )	
	paintTextureGold(self.Bg)
	paintTextureGold(self.TitleBg)
	paintTextureGold(self.portrait)
	paintFrameTexturesGold(self.NineSlice)
	
	local inset = self.Inset;
	if inset ~= nil then
		paintTextureGold(inset.Bg)
		paintFrameTexturesGold(inset.NineSlice)
	end
end



----------------------------------------
--  Macro management functions  --
----------------------------------------

--deletes a long macro
module.deleteMacro = function( isPerCharacter, macroName )
	addon.manager.deleteMacro( isPerCharacter, macroName );
	LongMacroFrame_update();
	LongMacroFrameText:ClearFocus();
end


--deletes a long macro
module.renameMacro = function( isPerCharacter, macroName, newMacroName )
	addon.manager.renameMacro( isPerCharacter, macroName, newMacroName );
	
	LongMacroFrame_selectMacroName( newMacroName );
		
	LongMacroPopupFrame:Hide();
	LongMacroFrame_update();
end


--renames a blizzard macro, resetting its auto-generated body
module.renameBlizzMacro = function( blizzMacroName, newBlizzMacroName )
	addon.outOfCombatCall( 
		function()
			EditMacro( blizzMacroName, newBlizzMacroName, nil, "" );
			if( MacroFrame and MacroFrame:IsShown() ) then
				MacroFrame_Update();
			end
			LongMacroFrame_update();
		end
	)	
end


--deletes a blizzard macro
module.deleteBlizzMacro = function( blizzMacroName )
	addon.outOfCombatCall( 
		function()
			DeleteMacro( blizzMacroName );
			if( MacroFrame and MacroFrame:IsShown() ) then
				MacroFrame_Update();
			end
		end
	)	
end


--creates a blizzard macro
module.createBlizzMacro = function( isPerCharacter, blizzMacroName )
	local isOutOfCombat, macroID = addon.outOfCombatCall( 
		function()
			local macroID = CreateMacro( blizzMacroName, DEFAULT_BLIZZ_MACRO_ICON, "", isPerCharacter );
			LongMacroFrame_update();
			if( MacroFrame and MacroFrame:IsShown() ) then
				MacroFrame_Update();
			end
			return macroID;
		end
	)
	
	if( isOutOfCombat ) then
		PickupMacro( macroID );
	end
end


----------------------------------
--  Button Container functions  --
----------------------------------

--sets up the button container with three rows of buttons to begin with
LongMacroButtonContainer_onLoad = function( self )
	self.numButtons = 0;	
	module.LongMacroButtonContainer_increaseNumButtons(self, 3 * NUM_LONGMACROS_PER_ROW);
end


--if the given button container has less buttons than requested, create new ones until it has that many
module.LongMacroButtonContainer_increaseNumButtons = function( self, numButtons )
	for i=(self.numButtons + 1), numButtons do
		module.LongMacroButtonContainer_createButton( self );
	end
end


--creates a button for the given button container
module.LongMacroButtonContainer_createButton = function( self )	
	local buttonID = self.numButtons + 1;
	self.numButtons = buttonID;
	
	local button = CreateFrame("CheckButton", "LongMacroButton"..buttonID, self, "LongMacroButtonTemplate");
	
	button:SetID(buttonID);
	
	if ( buttonID == 1 ) then
		button:SetPoint("TOPLEFT", self, "TOPLEFT", 6, -6);
	elseif ( mod(buttonID, NUM_LONGMACROS_PER_ROW) == 1 ) then
		button:SetPoint("TOP", "LongMacroButton"..(buttonID-NUM_LONGMACROS_PER_ROW), "BOTTOM", 0, -10);
	else
		button:SetPoint("LEFT", "LongMacroButton"..(buttonID-1), "RIGHT", 13, 0);
	end
end


----------------------------------
--  Long Macro Frame functions  --
----------------------------------

LongMacroFrame_onLoad = function( self )
	--paint the frame golden
	LongMacroFrame_paintGold(self);
	
	--make frame behave well with ShowUIPanel()
	self:SetAttribute("UIPanelLayout-defined", true)
	self:SetAttribute("UIPanelLayout-enabled", true)
	self:SetAttribute("UIPanelLayout-area", "left")
	self:SetAttribute("UIPanelLayout-pushable", 2)
	self:SetAttribute("UIPanelLayout-width", PANEL_DEFAULT_WIDTH)
	self:SetAttribute("UIPanelLayout-whileDead", true)
	
	
	--initialise tabs
	PanelTemplates_SetNumTabs(self, 2);
	PanelTemplates_SetTab(self, 1);
	
	--No need to initialise macro scope:
	--our VARIABLES_LOADED event handler already calls LongMacroFrame_setIsPerCharacter(false)
end


LongMacroFrame_onShow = function(self)
	LongMacroFrame_update();
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN);
end


LongMacroFrame_onHide = function(self)
	LongMacroPopupFrame:Hide();
	LongMacroFrame_saveMacro();
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE);
end


LongMacroFrame_setIsPerCharacter = function( isPerCharacter )
	LongMacroFrame.isPerCharacter = isPerCharacter;
	
	if next( addon.manager.getConfig(isPerCharacter).macros ) then
		LongMacroFrame_selectMacro(1);
	else
		LongMacroFrame_selectMacro(nil);
	end
end



LongMacroFrame_selectMacroName = function( macroName )
	local macroNames = addon.manager.getMacroNames( LongMacroFrame.isPerCharacter );
	
	local index = 1;
	for k, v in ipairs( macroNames ) do
		if( macroName == v ) then
			index = k;
			break;
		end
	end
	LongMacroFrame_selectMacro(index);
end


LongMacroFrame_selectMacro = function(id)
	LongMacroFrame.selectedMacro = id;
end


LongMacroFrame_update = function()
	local isPerCharacter = LongMacroFrame.isPerCharacter;
	local macroNames = addon.manager.getMacroNames( isPerCharacter );
	local numMacros = #macroNames;
	
	--ensure selection is within bounds
	if( LongMacroFrame.selectedMacro ) then
		if ( LongMacroFrame.selectedMacro > numMacros ) then
			LongMacroFrame.selectedMacro = numMacros;
		end
		if ( LongMacroFrame.selectedMacro <= 0 ) then
			LongMacroFrame.selectedMacro = nil;
		end
	end
	
	local numShownButtons = max( 3, ceil(numMacros / NUM_LONGMACROS_PER_ROW) ) * NUM_LONGMACROS_PER_ROW;
	module.LongMacroButtonContainer_increaseNumButtons( LongMacroButtonContainer, numShownButtons );
	
	local numButtons = LongMacroButtonContainer.numButtons;
	
	local macroButtonName, macroButton, macroIcon, macroName;
	local _, name, texture, body;
	local selectedName, selectedBody, selectedIcon;
	
	-- Macro List
	for i=1, numButtons do
		macroButtonName = "LongMacroButton"..i;
		macroButton = _G[macroButtonName];
		macroIcon = _G[macroButtonName.."Icon"];
		macroName = _G[macroButtonName.."Name"];
		
		if ( i <= numShownButtons ) then
			if ( i <= numMacros ) then
				name = macroNames[i];
				
				body = addon.manager.getMacroData( isPerCharacter, name ).macroText;
				
				if( not isPerCharacter ) and addon.manager.getMacroData( true, name ) then
					macroButton.blizzMacroName = nil;	--a per-character long macro eclipses this one
					
					texture = MACRO_LOCKED_TEXTURE;
				else
					macroButton.blizzMacroName = name;
					
					_, texture = GetMacroInfo(name);
					texture = texture or MACRO_NOT_FOUND_TEXTURE;
				end
				
				macroIcon:SetTexture(texture);				
				macroName:SetText(name);
				macroButton:Enable();
				
				-- Highlight Selected Macro
				if ( LongMacroFrame.selectedMacro and (i == LongMacroFrame.selectedMacro) ) then
					macroButton:SetChecked(true);
					LongMacroFrameSelectedMacroName:SetText(name);
					LongMacroFrameText:SetText(body);
					LongMacroFrameSelectedMacroButton:SetID(i);
					LongMacroFrameSelectedMacroButton.macroName = name;
					LongMacroFrameSelectedMacroButton.blizzMacroName = macroButton.blizzMacroName;
					
					LongMacroFrameSelectedMacroButtonIcon:SetTexture(texture);
				else
					macroButton:SetChecked(false);
				end
			else
				macroButton:SetChecked(false);
				macroIcon:SetTexture("");
				macroName:SetText("");
				macroButton:Disable();
			end
			macroButton:Show();
		else
			macroButton:Hide();
		end
		
	end
	
	-- Macro Details
	if ( LongMacroFrame.selectedMacro ~= nil ) then
		LongMacroFrame_showDetails();
		LongMacroDeleteButton:Enable();
	else
		LongMacroFrame_hideDetails();
		LongMacroDeleteButton:Disable();
	end
	

	-- Disable Buttons
	if ( LongMacroPopupFrame:IsShown() ) then
		LongMacroEditButton:Disable();
		LongMacroDeleteButton:Disable();
	else
		LongMacroEditButton:Enable();
		--LongMacroDeleteButton:Enable();
	end

	if ( not LongMacroFrame.selectedMacro ) then
		LongMacroDeleteButton:Disable();
	end
end


LongMacroFrame_hideDetails = function()
	LongMacroEditButton:Hide();
	LongMacroFrameCharLimitText:Hide();
	LongMacroFrameText:Hide();
	LongMacroFrameSelectedMacroName:Hide();
	LongMacroFrameSelectedMacroBackground:Hide();
	LongMacroFrameSelectedMacroButton:Hide();
end


LongMacroFrame_showDetails = function()
	LongMacroEditButton:Show();
	LongMacroFrameCharLimitText:Show();
	LongMacroFrameEnterMacroText:Show();
	LongMacroFrameText:Show();
	LongMacroFrameSelectedMacroName:Show();
	LongMacroFrameSelectedMacroBackground:Show();
	LongMacroFrameSelectedMacroButton:Show();
end


LongMacroFrame_saveMacro = function()
	if ( LongMacroFrame.textChanged and LongMacroFrame.selectedMacro ) then
		addon.manager.setMacroText( LongMacroFrame.isPerCharacter, LongMacroFrameSelectedMacroButton.macroName, LongMacroFrameText:GetText() );
		LongMacroFrame.textChanged = nil;
	end
end


------------------------
--  Button functions  --
------------------------

LongMacroButton_onClick = function(self, button)
	LongMacroFrame_saveMacro();
	LongMacroFrame_selectMacro( self:GetID() );
	LongMacroFrame_update();
	LongMacroPopupFrame:Hide();
	LongMacroFrameText:ClearFocus();
end

LongMacroButton_onDragStart = function(self, button)
	local blizzMacroName = self.blizzMacroName;
	
	if( not blizzMacroName ) then
		StaticPopupDialogs["LONG_MACRO_FAIL_FEEDBACK"].text = FAIL_PICKUP_ECLIPSED_FEEDBACK_STRING;
		StaticPopup_Show("LONG_MACRO_FAIL_FEEDBACK", UnitName("player") );
		
		return;
	end

	local macroID = GetMacroIndexByName(blizzMacroName);
	local numAccountMacros, numCharacterMacros;
	local dialog;
	
	if( macroID ~= 0 ) then
		if( InCombatLockdown() ) then	
			--fail: can't pick up during combat				
			StaticPopupDialogs["LONG_MACRO_FAIL_FEEDBACK"].text = FAIL_PICKUP_DURING_COMBAT_FEEDBACK_STRING;					
			StaticPopup_Show("LONG_MACRO_FAIL_FEEDBACK");
		else
			PickupMacro(macroID);
		end
		
	else
		numAccountMacros, numCharacterMacros = GetNumMacros();
		
		numAccountMacros = MAX_ACCOUNT_MACROS - numAccountMacros;
		numCharacterMacros = MAX_CHARACTER_MACROS - numCharacterMacros;
		
		if( numAccountMacros + numCharacterMacros == 0 ) then
			--fail: can't create any more blizz macros
			StaticPopupDialogs["LONG_MACRO_FAIL_FEEDBACK"].text = FAIL_BLIZZ_MACROS_FULL_FEEDBACK_STRING;					
			StaticPopup_Show("LONG_MACRO_FAIL_FEEDBACK");
		
		else
			dialog = StaticPopupDialogs["LONG_MACRO_CONFIRM_CREATE_BLIZZ"];
			
			if( numAccountMacros == 0 ) then
				--create blizz character macro (ok/cancel)
				dialog.text = CREATE_BLIZZ_MACRO_CHARACTER_PROMPT_STRING;
				dialog.button1 = nil;
				dialog.button2 = OKAY;
				
			elseif( numCharacterMacros == 0 ) then
				--create account character macro (ok/cancel)
				dialog.text = CREATE_BLIZZ_MACRO_ACCOUNT_PROMPT_STRING;
				dialog.button1 = OKAY;
				dialog.button2 = nil;
			
			else
				--prompt type of blizz macro to create (account/character/cancel)
				dialog.text = CREATE_BLIZZ_MACRO_WHICH_PROMPT_STRING;
				dialog.button1 = CREATE_ACCOUNT_BLIZZ_MACRO_BUTTON_STRING;
				dialog.button2 = CREATE_CHARACTER_BLIZZ_MACRO_BUTTON_STRING;
			end
			
			dialog = StaticPopup_Show("LONG_MACRO_CONFIRM_CREATE_BLIZZ", numAccountMacros, numCharacterMacros );
			if( dialog ) then
				dialog.data = { blizzMacroName = blizzMacroName };
			end
			
		end
	end
end


LongMacroNewButton_onClick = function(self, button)
	LongMacroFrame_saveMacro();
	LongMacroPopupFrame.mode = "new";
	LongMacroPopupFrame:Show();
end

LongMacroEditButton_onClick = function(self, button)
	LongMacroFrame_saveMacro();
	LongMacroPopupFrame.mode = "edit";
	LongMacroPopupFrame:Show();
end

LongMacroDeleteButton_onClick = function(self, button)
	local dialog = StaticPopupDialogs["LONG_MACRO_CONFIRM_DELETE"];
	
	local isPerCharacter = LongMacroFrame.isPerCharacter;
	local macroName = LongMacroFrameSelectedMacroButton.macroName;
	local blizzMacroName = LongMacroFrameSelectedMacroButton.blizzMacroName;
	local blizzMacroBody;
	
	if( blizzMacroName ) then
		blizzMacroBody = GetMacroBody( blizzMacroName );
	end
	
	if( not blizzMacroBody or													--blizz macro doesn't exist
		not match(blizzMacroBody, addon.button.AUTO_GENERATED_PATTERN) or		--blizz macro is not auto-generated
		addon.manager.getMacroData( not isPerCharacter, macroName )				--two long-macros with this name exist (one account-wide, one for this character)
	) then
		--delete just long macro (ok/cancel)
		dialog.text = DELETE_LONG_MACRO_PROMPT_STRING;
		dialog.button1 = nil;
		dialog.button2 = OKAY;
		
	elseif( GetMacroIndexByName(blizzMacroName) <= MAX_ACCOUNT_MACROS ) then	--blizz macro is account-wide
		--prompt which macro to delete (both/long/cancel)
		dialog.text = DELETE_WHICH_MACRO_PROMPT_STRING;
		dialog.button1 = BOTH_MACROS_BUTTON_STRING;
		dialog.button2 = LONG_MACRO_BUTTON_STRING;
	
	else																		--blizz macro is character specific
		--delete both macros (ok/cancel)
		dialog.text = DELETE_BOTH_MACROS_PROMPT_STRING;
		dialog.button1 = OKAY;
		dialog.button2 = nil;
	end	
	
	dialog = StaticPopup_Show("LONG_MACRO_CONFIRM_DELETE");
	if( dialog ) then
		dialog.data = {
			isPerCharacter = isPerCharacter,
			macroName = macroName,
			blizzMacroName = blizzMacroName
		};
	end
end

LongMacroFrameSaveButton_onClick = function()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	LongMacroFrame_saveMacro();
	LongMacroFrame_update();
	LongMacroPopupFrame:Hide();
	LongMacroFrameText:ClearFocus();
end

LongMacroFrameCancelButton_onClick = function()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	LongMacroFrame_update();
	LongMacroPopupFrame:Hide();
	LongMacroFrameText:ClearFocus();
end


-----------------------------
--  Popup frame functions  --
-----------------------------

LongMacroPopupFrame_cancelEdit = function()
	LongMacroPopupFrame:Hide();
	LongMacroFrame_update();
end


LongMacroPopupOkayButton_update = function()
	local text = LongMacroPopupEditBox:GetText();
	text = gsub(text, "[\"%[%]; ]", "_");
	
	if( (strlen(text) <= 0) or
		(
			addon.manager.getMacroData( LongMacroFrame.isPerCharacter, text ) and
			(
				LongMacroPopupFrame.mode == "new" or
				text ~= LongMacroFrameSelectedMacroButton.macroName
			)
		)
	) then		--disable if empty name, or a macro with that name already exists in our current scope (and is not the one we're editing)
		LongMacroPopupOkayButton:Disable();
	else
		LongMacroPopupOkayButton:Enable();
	end
end


LongMacroPopupOkayButton_onClick = function()
	local isPerCharacter = LongMacroFrame.isPerCharacter;
	
	local macroName, blizzMacroName, blizzMacroBody, isBlizzPerCharacter;
	local newBlizzMacroBody;
	local dialog;	
	
	local text = LongMacroPopupEditBox:GetText();
	text = gsub(text, "[\"%[%]; ]", "_");
	
	if ( LongMacroPopupFrame.mode == "new" ) then
		addon.manager.createMacro( isPerCharacter, text );
		
		LongMacroFrame_selectMacroName( text );
		
		LongMacroPopupFrame:Hide();
		LongMacroFrame_update();
		
	elseif ( LongMacroPopupFrame.mode == "edit" ) then			
		macroName = LongMacroFrameSelectedMacroButton.macroName;
		
		--if name didn't change, do nothing
		if( macroName == text ) then
			return
		end
		
		blizzMacroName = LongMacroFrameSelectedMacroButton.blizzMacroName;		
		if( blizzMacroName ) then
			isBlizzPerCharacter = GetMacroIndexByName(blizzMacroName) > MAX_ACCOUNT_MACROS;
			
			blizzMacroBody = GetMacroBody( blizzMacroName );
			newBlizzMacroBody = GetMacroBody( text );
		end


		if( not blizzMacroBody or												--blizz macro doesn't exist (or our account-wide long macro is eclipsed by a character-specific one)
			not match(blizzMacroBody, addon.button.AUTO_GENERATED_PATTERN)		--blizz macro is not auto-generated
		) then
			--rename only long
			module.renameMacro( isPerCharacter, macroName, text );
		
		
		elseif( not newBlizzMacroBody and isBlizzPerCharacter ) then			--no blizz macro with new name exists yet, old one is character-specific
			--rename both
			module.renameMacro( isPerCharacter, macroName, text );
			module.renameBlizzMacro( blizzMacroName, text );
		
				
		elseif( not newBlizzMacroBody ) then									--no blizz macro with new name exists yet, old one is account-wide
			--ask which to rename (both/long/cancel)
			dialog = StaticPopupDialogs["LONG_MACRO_CONFIRM_RENAME"];
			dialog.text = RENAME_WHICH_MACRO_PROMPT_STRING;
			dialog.button1 = BOTH_MACROS_BUTTON_STRING;
			dialog.button2 = LONG_MACRO_BUTTON_STRING;
			
			dialog = StaticPopup_Show("LONG_MACRO_CONFIRM_RENAME");
			if( dialog ) then
				dialog.data = {
					isPerCharacter = isPerCharacter,
					macroName = macroName,
					newMacroName = text,
					blizzMacroName = blizzMacroName
				};
			end
			

		elseif addon.manager.getMacroData( not isPerCharacter, macroName ) then	--two long-macros with this name exist: ours is character-specific, and there's an account-wide one
			--confirm rename long (ok/cancel)
			dialog = StaticPopupDialogs["LONG_MACRO_CONFIRM_RENAME"];
			dialog.text = RENAME_LONG_MACRO_PROMPT_STRING;
			dialog.button1 = nil;
			dialog.button2 = OKAY;
			
			dialog = StaticPopup_Show("LONG_MACRO_CONFIRM_RENAME", text);
			if( dialog ) then
				dialog.data = {
					isPerCharacter = isPerCharacter,
					macroName = macroName,
					newMacroName = text
				};
			end

		elseif( isBlizzPerCharacter ) then										--blizz macro with new name already exists, old one is character-specific
			--confirm rename that deletes old blizz (ok/cancel)
			dialog = StaticPopupDialogs["LONG_MACRO_CONFIRM_DELETE_BLIZZ"];
			dialog.text = RENAME_DELETE_BLIZZ_MACRO_PROMPT_STRING;
			dialog.button1 = OKAY;
			dialog.button2 = nil;
			
			dialog = StaticPopup_Show("LONG_MACRO_CONFIRM_DELETE_BLIZZ", text);
			if( dialog ) then
				dialog.data = {
					isPerCharacter = isPerCharacter,
					macroName = macroName,
					newMacroName = text,
					blizzMacroName = blizzMacroName
				};
			end
			

		else																	--blizz macro with new name already exists, old one is account-wide
			--ask whether to delete old blizz (delete/keep/cancel)		
			dialog = StaticPopupDialogs["LONG_MACRO_CONFIRM_DELETE_BLIZZ"];
			dialog.text = RENAME_WHAT_BLIZZ_MACRO_PROMPT_STRING;
			dialog.button1 = DELETE_BLIZZ_MACRO_BUTTON_STRING;
			dialog.button2 = KEEP_BLIZZ_MACRO_BUTTON_STRING;
			
			dialog = StaticPopup_Show("LONG_MACRO_CONFIRM_DELETE_BLIZZ", text);
			if( dialog ) then
				dialog.data = {
					isPerCharacter = isPerCharacter,
					macroName = macroName,
					newMacroName = text,
					blizzMacroName = blizzMacroName
				};
			end
		end
	end
end



LongMacroPopupFrame_onShow = function(self)
	LongMacroPopupEditBox:SetFocus();

	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN);
		
	if ( self.mode == "new" ) then
		LongMacroPopupEditBox:SetText("");
		LongMacroFrameSelectedMacroButtonIcon:SetTexture(MACRO_NOT_FOUND_TEXTURE);
	elseif ( self.mode == "edit" ) then
		LongMacroPopupEditBox:SetText( LongMacroFrameSelectedMacroButton.macroName );
	end
	
	LongMacroPopupOkayButton_update();

	if ( self.mode == "new" ) then
		LongMacroFrameText:Hide();
	end
	
	-- Disable Buttons
	LongMacroEditButton:Disable();
	LongMacroDeleteButton:Disable();
	LongMacroNewButton:Disable();
	LongMacroFrameTab1:Disable();
	LongMacroFrameTab2:Disable();
end

LongMacroPopupFrame_onHide = function(self)
	if ( self.mode == "new" ) then
		LongMacroFrameText:Show();
		LongMacroFrameText:SetFocus();
	end
	
	-- Enable Buttons
	LongMacroEditButton:Enable();
	LongMacroDeleteButton:Enable();
	LongMacroNewButton:Enable();
	
	-- Enable tabs
	PanelTemplates_UpdateTabs(LongMacroFrame);
end
