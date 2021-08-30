# CJRAutoBank

User-scriptable auto-banking for ESO.

## NB
- CJRAB.DryRun is enabled by default.  This prevents any transfers from actually occurring.    Once you have things set up and understand it, you can change it to false to actually do the bank transfers.
- tabstops=4.  Append `?ts=4` to the URL to see the code indentation properly.

## TO USE:
- Copy sample_Config.lua to Config.lua and change the details for your chars.
- Copy sample_UserScript.lua to UserScript.lua.
- Copy sample_SlashCommands.lua to SlashCommands.lua.

## FIRST RUN
- Set up your FCO ItemSaver icons (see below).
- Use /dumpfcoicons to display their indexes, and update Config.lua accordingly.
- Visit a bank and verify that it is doing what you expect (DryRun is enabled).
- Config.lua: Change CJRAB.DryRun to false to enable bank transfers.

## FCOItemSaver setup (for use with the sample UserScript):
	- Settings > Addons > FCO ItemSaver
		GENERAL SETTINGS
			Save settings		Account Wide
		ICONS > DYNAMIC ICONS > DYNAMIC ICONS
			1ST DYNAMIC:	"reserved"		Icon:150 (pink coins)
			2ND DYNAMIC:	"Writ Mats"		Icon:128 (green triangle)
