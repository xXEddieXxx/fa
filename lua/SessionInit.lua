-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
-- 

-- This is the user-side session specific top-level lua initialization
-- file.  It is loaded into a fresh lua state when a new session is
-- initialized.

    WARN('SessionInit.lua...') -- ADDED FROM ORG FA

-- Do global init
doscript '/lua/userInit.lua'

-- LOG('Active mods in UI session: ',repr(import('/lua/mods.lua').GetUiMods()))
LOG('Active mods in UI session: ')
import('/lua/mods.lua').PrintUiMods()

doscript '/lua/UserSync.lua'
