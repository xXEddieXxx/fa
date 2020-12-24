-- Copyright © 2006 Gas Powered Games, Inc.  All rights reserved.
-- 
-- This is the minimal setup required to load the game rules.

-- ADDED FROM ORG FA
WARN('RuleInit.lua...') 

-- Do global init
__blueprints = {}

-- Set up global diskwatch table (you can add callbacks to it to be notified of disk changes)
__diskwatch = {} -- ADDED FROM GlobalInit.lua

-- Set up custom Lua weirdness
doscript '/lua/system/config.lua'

-- Load system modules
doscript '/lua/system/import.lua' -- ADDED FROM GlobalInit.lua
doscript '/lua/system/repr.lua'
doscript '/lua/system/utils.lua' 

-- LOG('Active game mods for blueprint loading: ',repr(__active_mods))
LOG('Active mods for Blueprints loading: ')
import('/lua/mods.lua').Print(__active_mods)

doscript '/lua/footprints.lua'
doscript '/lua/system/Blueprints.lua'
LoadBlueprints()
