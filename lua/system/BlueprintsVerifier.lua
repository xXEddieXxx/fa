-- ==========================================================================================
-- * Authors : HUSSAR
-- * Summary : Provides functions for verifying unit blueprints for:
-- * invalid values, missing values, mistakes, and
-- * misconfiguration (e.g. bp.Categories has 'TECH1' and bp.General.TechLevels = 'RULEUTL_Experimental'
-- ==========================================================================================

LOG('BlueprintsVerifier.lua ... ')
-- loading validation tables for blueprints
doscript '/lua/system/BlueprintsSchema.lua'

-- safely wrap a given string with quote symbols
function Quote(str)
    return '"' .. (str or 'nil') .. '"'
end

local BPA = import('/lua/system/BlueprintsAnalyzer.lua') 
 
-- Initializes the Stats table for tracking statistics and logging/debugging while verifying blueprints
-- for better performance, all issues/corrections are registered in these tables and logged 
-- when all blueprints are verified
function CreateStats()
    return {      
        -- table for storing issues found in blueprints
        Issues = { logging = true, limit = 50, found = {} },
        -- table for storing corrections made in blueprints
        Corrections = { logging = true, limit = 50, found = {} },
        -- table for storing all possible/valid values used in blueprints
        Blueprints = { 
            logging = false, -- enable to re-generate tables for BlueprintsSchema.lua
            found = {} 
        },
        -- table for tracking corrections in bp.Abilities
        Abilities = { 
            logging = true,    -- logs basic stats when true
            debugging = false, -- logs more details when true
            added = 0, matched = 0, removed = 0, changes = {} 
        },
        -- table for tracking corrections in bp.Categories
        Categories = { 
            logging = true,    -- logs basic stats when true
            debugging = false, -- logs more details when true
            added = 0, matched = 0, removed = 0, changes = {},
            -- auto-correct missing/invalid categories or report them as issues
            autoCorrect = true
        },
    }
end

local Stats = CreateStats()
local currentBp = '' -- updated by the Verify(blueprints) function

local ValidSlots = { LCH = true, RCH = true, Back = true }

-- this table defines ordering of issues and corrections using their severity
-- this ensure that issues with higher severity are logged first
-- and issues with lower severity are logged last or not at all 
-- if Stats.Issues.Limit is reached by issues with higher severity
local Severity = {
    CRITICAL = 1,
    HIGH = 2, 
    LOW  = 3, 
    MIN  = 4,
    NONE = 5,
}
-- this table defines quick lookup of ordering of issues and corrections by their severity
local SeverityLookup = table.lookup(Severity)

-- consider using logic from:
-- \Mods\BrewLAN_Plenae\Logger\hook\lua\system\Blueprints.lua

-- reports statistics (if enabled) about blueprint verification process 
function ReportStats()
    -- logging statistics about valid values in blueprints
    if Stats.Blueprints.logging then
        --LOG('Blueprints valid values: ')
        local list = table.indexize(Stats.Blueprints.found)
        table.sort(list, function(a,b) 
            return a.id < b.id
        end)
        for key, item in list or {} do
            if item.min and item.max then
                local min = string.format('%0.4f', item.min)
                local max = string.format('%0.4f', item.max)
                local range = "{ Min = " .. min .. ", Max = " .. max .. " }"
                LOG('Existing range for ' .. item.id .. ' = ' .. range)
            elseif item.enums then
                local info = ''
                local enums = table.unhash(item.enums)
                table.sort(enums)
                for _, v in enums or {} do
                    info = info .. "\n\t'" .. v .. "',"
                end 
                LOG('Existing strings for ' .. item.id .. ' = { ' .. info .. '\n}') 
            end
        end
    end
    -- logging statistics about categories in blueprints
    if Stats.Categories.logging then
        LOG('Blueprints verification... categories... ')
        if Stats.Categories.debugging and table.size(Stats.Categories.changes) > 0 then
            LOG('Blueprints verification... categories changes:')
            table.print(Stats.Categories.changes, '', LOG)
        end
        local info = 'categories: ' 
        info = info .. Stats.Categories.added .. ' added, '
        info = info .. Stats.Categories.removed .. ' removed, '
        info = info .. Stats.Categories.matched .. ' matched'
        LOG('Blueprints verification... ' .. info) 
    end
    -- logging statistics about abilities in blueprints
    if Stats.Abilities.logging then
        LOG('Blueprints verification... abilities... ')
        local summary = '' 
        summary = summary .. Stats.Abilities.added .. ' added, '
        summary = summary .. Stats.Abilities.removed .. ' removed, '
        summary = summary .. Stats.Abilities.matched .. ' matched'
        LOG('Blueprints verification... abilities: ' .. summary) 
    end
    -- logging corrections made in blueprints
    Stats.Corrections.count = table.size(Stats.Corrections.found)
    if Stats.Corrections.logging and Stats.Corrections.count > 0  then
        LOG('Blueprints verification... corrections: ')
        -- sort by severity and then by info
        table.sort(Stats.Corrections.found, function(a,b)
            return a.severity .. a.info < b.severity .. b.info
        end)
        -- limit logging of corrections to predefined number
        for i, correction in Stats.Corrections.found do
            if i < Stats.Corrections.limit then 
                WARN(correction.info)
            end
        end
    end
    -- logging issues found in blueprints
    Stats.Issues.count = table.size(Stats.Issues.found)
    if Stats.Issues.logging and Stats.Issues.count > 0  then
        LOG('Blueprints verification... issues: ')
        -- sort by severity and then by info
        table.sort(Stats.Issues.found, function(a,b)
            return a.severity .. a.info < b.severity .. b.info
        end)
        -- limit logging of corrections to predefined number
        for i, issue in Stats.Issues.found do
            if i < Stats.Issues.limit then 
                WARN(issue.info)
            end
        end 
    end
    -- logging final summary of verification process
    local summary = 'Blueprints verification... completed.'
    summary = summary .. ' Found '.. Stats.Issues.count .. ' issues'
    summary = summary .. ' and made '.. Stats.Corrections.count .. ' corrections'
    summary = summary .. ' in ' .. Stats.Blueprints.count .. ' unit blueprints'
    LOG(summary) 
end

-- logs an issue found in specified blueprint and optional info how to fix it
function LogIssue(severity, bp, msg, fix)
    if not Stats.Issues.logging then return end
    
    local severityName = SeverityLookup[severity] or 'HIGH'
    local info = severityName ..' '.. msg
    if bp then
       info = info .. ' in ' .. currentBp
    end
    if fix then
       info = info .. fix
    end
    -- for best performance all issues are stored in a table that will be logged at end of verification
    table.insert(Stats.Issues.found, { severity = severity, info = info })
end

-- logs a correction made in specified blueprint
function LogCorrection(severity, bp, msg)
    if severity == Severity.NONE then return end
    if not Stats.Corrections.logging then return end

    local severityName = SeverityLookup[severity] or 'HIGH'
    local info = severityName ..' '.. msg
    if bp then
       info = info .. ' in ' .. currentBp
    end
    -- for best performance all corrections are stored in a table that will be logged at end of verification 
    table.insert(Stats.Corrections.found, { severity = severity, info = info })
end

-- logs addition of specified category only if it is not already in bp.CategoriesHash
function LogCategoryAdded(severity, bp, category, logChanges)
    if severity == Severity.NONE then return end
    -- skip if the category is already in the blueprint
    if bp.CategoriesHash[category] then return end

    if Stats.Categories.autoCorrect then
        --bp.CategoriesHash[category] = true
        bp.CategoriesHashChanged = true
        LogCorrection(severity, bp, 'bp.Categories added ' .. category)
    else 
        LogIssue(severity, bp, 'bp.Categories is missing ' .. category)
    end

    if logChanges and logChanges.added then
        table.insert(logChanges.added, category)
    end
end

-- logs removal of specified category only if it is already in bp.CategoriesHash
function LogCategoryRemoved(severity, bp, category, logChanges)
    if severity == Severity.NONE then return end

    -- skip if the category is not in the blueprint
    if not bp.CategoriesHash[category] then return end
     
    if Stats.Categories.autoCorrect then
        --bp.CategoriesHash[category] = false
        bp.CategoriesHashChanged = true
        LogCorrection(severity, bp, 'bp.Categories removed ' .. category)
    else 
        LogIssue(severity, bp, 'bp.Categories has wrong category ' .. category)
    end

    if logChanges and logChanges.removed then
        table.insert(logChanges.removed, category)
    end
end

-- register a value at specified table's key
-- this function is executed only when Stats.Blueprints.logging is true
-- this function is used to generate BlueprintsSchema.lua
function RegisterValue(value, key) 
    if not Stats.Blueprints.logging then return end
    if value == nil then return end

    if type(value) == 'number' then
        -- keep track of range of passed numbers
        if not Stats.Blueprints.found[key] then 
            Stats.Blueprints.found[key] = { min = 10000, max = 0, id = key } 
        end  
        Stats.Blueprints.found[key].min = math.min(Stats.Blueprints.found[key].min, value)
        Stats.Blueprints.found[key].max = math.max(Stats.Blueprints.found[key].max, value)
        
    elseif type(value) == 'string' then
        -- keep track of all possible value of strings
        if not Stats.Blueprints.found[key] then
            Stats.Blueprints.found[key] = { id = key, enums = {} }
        end  
        Stats.Blueprints.found[key].enums[value] = true
    end
end

-- register all values in specified table
-- this function is executed only when Stats.Blueprints.logging is true
-- this function is used to generate BlueprintsSchema.lua
function RegisterValuesIn(tbl, key)
    if not Stats.Blueprints.logging then return end
    if tbl == nil then return end

    for k, v in tbl do
        if type(v) == 'number' then
           RegisterValue(v, key .. '.' .. k)
        elseif type(v) == 'string' then
           RegisterValue(v, key)
        end
    end
end
 
function IsMissing(value)
    if value == nil then return true end
    if type(value) == 'number' then return value <= 0 end
    if type(value) == 'string' then return value == '' end
    if type(value) == 'table' then return table.size(value) == 0 end
    return false
end

function IsMissingOrZero(value)
    return value == nil or value == 0
end

-- check if a given blueprint has valid value in a given key of its table
function IsValid(bp, tableName, tableKey, validValues)
    local t = bp[tableName]
    if IsMissing(t) then  
        LogIssue(Severity.HIGH, bp, 'bp.' .. tableName .. ' table is missing')
        return false
    end
    local target = 'bp.' .. tableName .. '.' .. tableKey
    local value = t[tableKey] 

    if IsMissing(value) then 
        LogIssue(Severity.HIGH, bp, target .. ' is missing')
        return false
    elseif not validValues[value] then   
        LogIssue(Severity.HIGH, bp, target ..  ' has invalid value ' .. Quote(value))
        return false
    end
    return true
end

-- verify values of blueprints in specified table
function Verify(blueprints)
    LOG('Blueprints verification...') 
    
--    _G['testBPA'] = import('/lua/system/BlueprintsTest.lua')
   
--    _ALERT('_ALERT')
--    global.vars()
 
--    LogMods(GetSelectedSimMods())
-- table.print(__active_mods, '__active_mods')

--    LOG( 'StringContains '.. tostring( StringContains("debudg math", {'math', 'debug'}) ))
--    global.moho()
--    LogMods(__active_mods)
--    _G['test_BPA'].testFrom('BlueprintsAnalyzer.lua')
--    table.print(TM, 'TM')
--    table.print(TG, 'TG')

--    testBPA.testFrom()
--    _G['testBPA2'].testFrom()

    -- we need to verify only units and structures (no dummy blueprints)
    local units = BPA.GetUnitsFrom(blueprints)
  
    Stats = CreateStats()
    Stats.Blueprints.count = table.size(units)

--    table.print(Buffs, 'Buffs')

--    if T3MassExtractorAdjacencyBuffs then
--        LOG('T3MassExtractorAdjacencyBuffs')
--    end
--    if __module_metatable['T3MassExtractorAdjacencyBuffs'] then
--        LOG('__module_metatable')
--    end
--    if _G['T1EnergyStorageAdjacencyBuffs'] then
--        LOG('_G ' ..repr(T1EnergyStorageAdjacencyBuffs) )
--    end

    for _, bp in units do

        -- keep track of current blueprint for reporting issues
        local desc = BPA.GetUnitTechAndDescription(bp)
        currentBp = bp.ID .. '_unit.bp (' .. desc .. ') '
        
--        local test =  BPA.IsUnitWithIntelOmni(bp)
--        local cat = bp.CategoriesHash.OMNI
--        if cat or test then
--            LOG(tostring(test).. ' '.. tostring(cat) .. ' '.. bp.General.Category 
--            .. ' '.. currentBp  .. ' ' .. bp.General.Classification)
--        end
--        if not test and cat  then
--            WARN(tostring(test).. ' '.. tostring(cat) .. ' '.. bp.General.Category 
--            .. ' '.. currentBp  .. ' ' .. bp.General.Classification)
--        end
--        if test and not cat  then
--            WARN(tostring(test).. ' '.. tostring(cat) .. ' '.. bp.General.Category 
--            .. ' '.. currentBp  .. ' ' .. bp.General.Classification)
--        end
      --  if bp.ID == 'daa0206' then
      --  end
      
        -- note verifications depends on running VerifyCategories first
        VerifyCategories(bp)
        VerifyDisplay(bp)

        VerifyAI(bp)
        VerifyAdjacency(bp)
        VerifyAudio(bp)
        VerifyBuffs(bp)
        VerifyEconomy(bp)
        VerifyEnhancements(bp)
        VerifyFootprint(bp)

        VerifyDefense(bp)
        VerifyGeneral(bp)
        VerifyIntel(bp)
        
        VerifyLifebar(bp)
      --  VerifyPhysics(bp)
        VerifySizeHitbox(bp)
        VerifySelection(bp)
        VerifyTransport(bp)
        VerifyWeapons(bp)
      --  VerifyWreckage(bp)
        VerifyVeterancy(bp)

        if bp.CategoriesHashChanged or table.size(bp.CategoriesHash) ~= table.size(bp.Categories) then
           -- TODO-HUSSAR sync
           --bp.Categories = table.unhash(bp.CategoriesHash)
        end
    end 

    ReportStats()
end

-- verify if AI table has info about unit's guard scan radius and guard return radius
-- if not present then default to longest weapon range * longest tracking radius
-- Also, it takes ACU/SCU enhancements into account which fixes move-attack range issues
function VerifyAI(bp)
    -- TODO-HUSSAR remove modGSR logic in from Blueprints.lua
    if not bp.AI then bp.AI = {} end

    -- check if an unit needs default value for GuardReturnRadius
    if not bp.AI.GuardReturnRadius then
        bp.AI.GuardReturnRadius = 3
        LogCorrection(Severity.LOW, bp, 'Set bp.AI.GuardReturnRadius to 3 (default)')
    end

    -- skip changing GRS when it is already set in blueprint
    if bp.AI.GuardScanRadius then return end

    local radius = nil
    local is = bp.CategoriesHash
    if is.ENGINEER and not is.SUBCOMMANDER and not is.COMMAND then
        radius = 26
    elseif is.SCOUT then
        radius = 10
    else -- if bp.Weapon then
        local range = 0
        local tracking = 1.05
        for i, w in bp.Weapon or {} do
            local isDefense = w.WeaponCategory == 'Defense'
            local isAntiAir = w.RangeCategory == 'UWRC_AntiAir' 
            local ignore = w.CountedProjectile or isAntiAir or isDefense
            if not ignore then
                if w.MaxRadius then
                    range = math.max(w.MaxRadius, range)
                end
                if w.TrackingRadius then
                    tracking = math.max(w.TrackingRadius, tracking)
                end
            end
        end
        for name, array in bp.Enhancements or {} do
            for key, value in array do
                if key == 'NewMaxRadius' then
                    range = math.max(value, range)
                end
            end
        end
        radius = range * tracking
    end
     
    bp.AI.GuardScanRadius = radius
    LogCorrection(Severity.LOW, nil, 'Set bp.AI.GuardReturnRadius to ' .. radius .. ' (calculated)') 
end

-- verify bp.Audio table in a given blueprint
function VerifyAudio(bp)
     if table.empty(bp.Audio) then
         LogIssue(Severity.LOW, bp, 'bp.Audio table is missing')
     else
         for name, sound in bp.Audio do
             if type(name) ~= 'string' then
                LogIssue(Severity.LOW, bp, 'bp..Audio.'..name..' must be a string')
             end
             local cue, bank = GetCueBank(sound)
             if not cue then 
                LogIssue(Severity.LOW, bp, 'bp.Audio.'..name..' has unknown cue')
             elseif not bank then 
                LogIssue(Severity.LOW, bp, 'bp.Audio.'..name..' has unknown bank')
             end
         end
     end
end

-- verify bp.Adjacency value in a given blueprint
function VerifyAdjacency(bp)
    if not bp.Adjacency then return end

--    if not global.exist(bp.Adjacency) then 
--        LogIssue(Severity.LOW, bp, 'bp.Adjacency.'..bp.Adjacency..' is not defined')
--    end
end

-- verify bp.Buffs table in a given blueprint
function VerifyBuffs(bp)
    -- skipping pre-enhanced units since they are the same as base units
    if bp.CategoriesHash.ISPREENHANCEDUNIT then return end
    if bp.CategoriesHash.SATELLITE then return end
    
    if BPA.IsUnitKamikaze(bp) then return end

    -- skipping blueprints without offensive weapons
    local weapons = BPA.GetWeaponsWithOffense(bp, 1)
    if table.empty(weapons) then return end

    if table.empty(bp.Buffs) then
        LogIssue(Severity.LOW, bp, 'bp.Buffs table is missing', 'but it has weapons')
    else 
        for name, levels in bp.Buffs do
            if name == 'Regen' and table.size(levels) < 5 then
              LogIssue(Severity.LOW, bp, 'bp.Buffs.' .. name .. ' has less than 5 levels')
            end

--            if name ~= 'Regen'   then
--                LogIssue(Severity.LOW, bp, 'bp.Buffs.' .. name .. ' not Regen')
--            end
        end
    end

end

-- verify bp.Defense table in a given blueprint
function VerifyDefense(bp) 
    -- skipping pre-enhanced units since they are the same as base units
    if bp.CategoriesHash.ISPREENHANCEDUNIT then return end

    if IsMissing(bp.Defense) then
        LogIssue(Severity.HIGH, bp, 'bp.Defense table is missing')
        return
    end

    RegisterValuesIn(bp.Defense, 'bp.Defense')

    if IsValid(bp, 'Defense', 'ArmorType', ValidEnums.Defense.ArmorTypes) then
        if BPA.IsUnitTech4(bp) and bp.Defense.ArmorType ~= 'Experimental' then
            LogIssue(Severity.LOW, bp, 'bp.Defense.ArmorType should be Experimental')
        elseif BPA.IsUnitStructure(bp) then 
            local tmd = table.size(BPA.GetWeaponsWithTMD(bp))
            if tmd > 0 then
                if bp.Defense.ArmorType ~= 'TMD' then
                    LogIssue(Severity.LOW, bp, 'bp.Defense.ArmorType should be TMD')
                end
            elseif BPA.IsUnitCrabEgg(bp) then
                if bp.Defense.ArmorType ~= 'Normal' then
                    LogIssue(Severity.LOW, bp, 'bp.Defense.ArmorType should be Normal')
                end 
            elseif bp.Defense.ArmorType ~= 'Structure' then
                LogIssue(Severity.LOW, bp, 'bp.Defense.ArmorType should be Structure')
            end
        end
    end

    local threatLevels = { 
        'AirThreatLevel', 'EconomyThreatLevel', 
        'SubThreatLevel', 'SurfaceThreatLevel', 
    }  
    for _, key in threatLevels do
        if IsMissing(bp.Defense[key]) then
            bp.Defense[key] = 0
            --skipping LogCorrection(bp, 'Set missing bp.Defense.'.. key .. ' to value of 0')
        end
    end 

    if IsMissing(bp.Defense.Health) then
        LogIssue(Severity.HIGH, bp, 'bp.Defense.Health is missing')
    elseif IsMissing(bp.Defense.MaxHealth) then
        LogIssue(Severity.HIGH, bp, 'bp.Defense.MaxHealth is missing')
    else
        local min = tostring(bp.Defense.Health)
        local max = tostring(bp.Defense.MaxHealth)
        if min ~= max then 
            LogIssue(Severity.HIGH, bp, 'bp.Defense.Health ('..min..') does not match bp.Defense.MaxHealth ('..max..')') 
        end
    end

    if type(bp.Defense.Shield) == 'table' and bp.Defense.Shield.ShieldSize > 0 then  
        if bp.Defense.Shield.ShieldSize > 3 then
            local shieldOffset = bp.Defense.Shield.ShieldVerticalOffset
            if type(shieldOffset) ~= "number" or shieldOffset >= 0 then
                LogIssue(Severity.HIGH, bp, 'bp.Defense.Shield.ShieldVerticalOffset is missing')
            end
        end
        local shieldHP = bp.Defense.Shield.ShieldMaxHealth
        if type(shieldHP) ~= "number" or shieldHP < 1 then
            LogIssue(Severity.HIGH, bp, 'bp.Defense.Shield.ShieldMaxHealth is missing')
        end
        local shieldRegen = bp.Defense.Shield.ShieldRegenRate
        if IsMissing(bp.Defense.Shield.ShieldRegenRate) then
            LogIssue(Severity.HIGH, bp, 'bp.Defense.Shield.ShieldRegenRate is missing')
        end

        if IsMissing(bp.Economy.MaintenanceConsumptionPerSecondEnergy) then
            LogIssue(Severity.HIGH, bp, 'bp.Economy.Maintenance...Energy is missing but unit has shield')
        end

    end
end

-- verify bp.Display table in a given blueprint
function VerifyDisplay(bp)
 
    if bp.Display.AbilitiesORG then
       bp.Display.Abilities = table.copy(bp.Display.AbilitiesORG)
    else 
       bp.Display.AbilitiesORG = table.copy(bp.Display.Abilities or {}) 
    end

    VerifyDisplaysAbilities(bp)
    VerifyDisplaysMesh(bp)

end

-- verify bp.Display.Mesh table in a given blueprint
function VerifyDisplaysMesh(bp)
    --TODO-HUSSAR re-use CheckDisplayMesh() from Uveso's Debugger
end

-- TODO-HUSSAR localize new ability strings:
-- ability_movingfast = "Fast Moving"
-- ability_movingslow = "Slow Moving"
-- ability_artillery = "Artillery"
-- ability_areadamage = "Area Damage" 
-- ability_stratmissilelaunch = "Strategic Missile Launcher"
-- ability_tacmissilelaunch = "Tactical Missile Launcher" 
-- ability_largevision = "Large Vision Sensor"
-- ability_remotevision = "Remote Vision Sensor"
-- ability_bomber = "Bomber"
-- ability_gunship = "Gunship"
-- ability_scout = "Scout"
-- ability_sniper = "Sniper"
-- ability_adjacency_bonus = "Adjacency Bonus"
-- ability_producer_mass = "Mass Producer"
-- ability_producer_energy = "Energy Producer"
-- ability_shieldbreaker = "Shield Breaker"
-- ability_toggleweapons = "Auto-toggle Weapons" 
-- ability_teleporter = "Teleportation"

-- this table defines functions for checking actual abilities of unit blueprints
-- instead of using bp.Display.Abilities table which might not be accurate or up-to-date for all units
local AbilityRules = {
    -- weapon abilities:
    ["ability_bomber"] =        { Match = BPA.GetWeaponsWithBombs, Name = 'Bomber', IsNew = true },
    ["ability_gunship"] =       { Match = BPA.GetWeaponsWithGunship, Name = 'Gunship', IsNew = true },
    ["ability_areadamage"] =    { Match = BPA.GetWeaponsWithAreaDamage, Name = 'Area Damage', IsNew = true },
    ["ability_shieldbreaker"] = { Match = BPA.GetWeaponsWithShieldDamage, Name = 'Shield Breaker', IsNew = true },
    ["ability_manuallaunch"] =  { Match = BPA.GetWeaponsWithManualLaunch, Name = 'Manual Launch' },
    ["ability_stun"] =          { Match = BPA.GetWeaponsWithStunEffect, Name = 'EMP Weapon' },
    ["ability_depthcharge"] =   { Match = BPA.GetWeaponsWithDepthCharges, Name = 'Depth Charges' },
    ["ability_torpedo"] =       { Match = BPA.GetWeaponsWithTorpedoes, Name = 'Torpedoes' },
    ["ability_torpedodef"] =    { Match = BPA.GetWeaponsWithTorpedoDefense, Name = 'Torpedo Defense' },
    ["ability_aa"] =            { Match = BPA.GetWeaponsWithAntiAir, Name = 'Anti-Air' },
    ["ability_suicideweapon"] = { Match = BPA.GetWeaponsWithKamikaze, Name = 'Suicide Weapon' },
    ["ability_deploys"] =       { Match = BPA.GetWeaponsWithDeployment, Name = 'Deploys' },
    ["ability_artillery"] =     { Match = BPA.GetWeaponsWithArtillery, Name = 'Artillery', IsNew = true },
    ["ability_sniper"] =        { Match = BPA.GetWeaponsWithSniperDamage, Name = 'Sniper', IsNew = true },
    ["ability_toggleweapons"] = { Match = BPA.GetWeaponsWithAutoToggleAirAndLand, Name = 'Auto-toggle Weapons', IsNew = true },
    ["ability_tacmissiledef"] =         { Match = BPA.GetWeaponsWithTMD, Name = 'Tactical Missile Defense' },
    ["ability_tacmissilelaunch"] =      { Match = BPA.GetWeaponsWithTML, Name = 'Tactical Missile Launcher', IsNew = true },
    ["ability_stratmissiledef"] =       { Match = BPA.GetWeaponsWithSMD, Name = 'Strategic Missile Defense', IsNew = true },
    ["ability_stratmissilelaunch"] =    { Match = BPA.GetWeaponsWithSML, Name = 'Strategic Missile Launcher', IsNew = true },
    ["ability_tacticalmissledeflect"] = { Match = BPA.IsUnitWithTacticalDeflection, Name = 'Tactical Missile Deflection' },
    -- build abilities:
    ["ability_adjacency_bonus"] =  { Match = BPA.IsUnitWithBonusAdjacency, Name = 'Adjacency Bonus', IsNew = true },
    ["ability_factory"] =          { Match = BPA.IsUnitWithFactorySuite, Name = 'Factory' },
    ["ability_repairs"] =          { Match = BPA.IsUnitWithCommandRepair, Name = 'Repairs' },
    ["ability_reclaim"] =          { Match = BPA.IsUnitWithCommandReclaim, Name = 'Reclaims' },
    ["ability_aquatic"] =          { Match = BPA.IsUnitStructureAquatic, Name = 'Aquatic' },
    ["ability_notcap"] =           { Match = BPA.IsUnitNotCapturable, Name = 'Not Capturable' },
    ["ability_upgradable"] =       { Match = BPA.IsUnitUpgradable, Name = 'Upgradeable' },
    ["ability_customizable"] =     { Match = BPA.IsUnitWithEnhancements, Name = 'Customizable' },
    ["ability_airstaging"] =       { Match = BPA.IsUnitWithAirStaging, Name = 'Air Staging' },
    ["ability_sacrifice"] =        { Match = BPA.IsUnitWithCommandSacrifice, Name = 'Sacrifice' },
    ["ability_engineeringsuite"] = { Match = BPA.IsUnitWithEngineeringSuite, Name = 'Engineering Suite' },
    -- movement abilities:
    ["ability_deathaoe"] =    { Match = BPA.IsUnitVolatile, Name = 'Volatile' },
    ["ability_massive"] =     { Match = BPA.IsUnitMassive, Name = 'Massive' },
    ["ability_amphibious"] =  { Match = BPA.IsUnitAmphibious, Name = 'Amphibious' },
    ["ability_submersible"] = { Match = BPA.IsUnitSubmersible, Name = 'Submersible' },
    ["ability_hover"] =       { Match = BPA.IsUnitMobileHover, Name = 'Hover' },
    ["ability_transport"] =   { Match = BPA.IsUnitTransportingByAir, Name = 'Transport' },
    ["ability_carrier"] =     { Match = BPA.IsUnitTransportingInside, Name = 'Carrier' },
    ["ability_movingfast"] =  { Match = BPA.IsUnitMobileFast, Name = 'Fast Moving', IsNew = true },
    ["ability_movingslow"] =  { Match = BPA.IsUnitMobileSlow, Name = 'Slow Moving', IsNew = true },
    ["ability_teleporter"] =  { Match = BPA.IsUnitWithTeleporter, Name = 'Teleportation', IsNew = true },
    -- intel abilities:
    ["ability_omni"] =            { Match = BPA.IsUnitWithIntelOmni, Name = 'Omni Sensor' },
    ["ability_radar"] =           { Match = BPA.IsUnitWithIntelRadar, Name = 'Radar' },
    ["ability_sonar"] =           { Match = BPA.IsUnitWithIntelSonar, Name = 'Sonar' },
    ["ability_cloak"] =           { Match = BPA.IsUnitWithIntelCloak, Name = 'Cloaking' },
    ["ability_jamming"] =         { Match = BPA.IsUnitWithIntelJamming, Name = 'Jamming' },
    ["ability_scout"] =           { Match = BPA.IsUnitWithIntelScout, Name = 'Scout', IsNew = true },
    ["ability_largevision"] =     { Match = BPA.IsUnitWithIntelLargeVision, Name = 'Large Vision', IsNew = true },
    ["ability_remotevision"] =    { Match = BPA.IsUnitWithIntelRemoteVision, Name = 'Remote Vision', IsNew = true },
    ["ability_stealthfield"] =    { Match = BPA.IsUnitWithStealthField, Name = 'Stealth Field' },
    ["ability_personalstealth"] = { Match = BPA.IsUnitWithStealthSuite, Name = 'Personal Stealth' },
    -- shield abilities:
    ["ability_personalshield"] = { Match = BPA.IsUnitWithShieldSuite, Name = 'Personal Shield' },
    ["ability_shielddome"] =     { Match = BPA.IsUnitWithShieldDome, Name = 'Shield Dome' },
  -- economic abilities:
  --["ability_producer_mass"] =   { Match = BPA.IsUnitWithMassProdution, Name = 'Mass Producer', IsNew = true },
  --["ability_producer_energy"] = { Match = BPA.IsUnitWithEnergyProdution, Name = 'Energy Producer', IsNew = true },
}

-- Verifies and corrects bp.Abilities since they are just informative to players 
-- and they do not affect the game mechanic if:
-- - they are missing in blueprints
-- - they are incorrectly set in blueprints
function VerifyDisplaysAbilities(bp)
    -- skipping pre-enhanced units since they are the same as base units
    if bp.CategoriesHash.ISPREENHANCEDUNIT then return end

    -- keep track of changes in abilities
    local changes = { added = {}, matched = {}, removed = {}, all = {} }
    local orgAbilities = table.hash(bp.Display.Abilities)
    local logAbility = Stats.Abilities.debugging

    for key, rule in AbilityRules do
        local ability = '<LOC '..key..'>' .. rule.Name
        if rule.Match(bp)  then
            changes.all[ability] = true
            if orgAbilities[ability] then
               changes.matched[ability] = true
            else
               changes.added[ability] = true
               if logAbility and not rule.IsNew then
                  LogCorrection(Severity.MIN, bp, 'bp.Abilities added ' .. Quote(key) .. '')
               end
            end
        elseif orgAbilities[ability] then
            changes.removed[ability] = true
            if logAbility then
               LogCorrection(Severity.LOW, bp, 'bp.Abilities removed ' .. Quote(key) .. '')
            end
        end
    end

    bp.Display.Abilities = table.unhash(changes.all)

    if Stats.Abilities.logging then
        -- collect basic stats in non-debugging mode
        local countAdded = table.size(changes.added)
        local countMatched = table.size(changes.matched)
        local countRemoved = table.size(changes.removed)
        Stats.Abilities.added = Stats.Abilities.added + countAdded
        Stats.Abilities.matched = Stats.Abilities.matched + countMatched
        Stats.Abilities.removed = Stats.Abilities.removed + countRemoved
        -- collect detailed stats in debugging mode
        if Stats.Abilities.debugging and (countAdded > 0 or countRemoved > 0) then
             if countAdded > 0 then 
                changes.added = 'ADDED bp.Abilities: '.. table.concatkeys(changes.added, ', ')
             else
                changes.added = ''
             end
             if countRemoved > 0 then
                changes.removed = 'REMOVED bp.Abilities: '.. table.concatkeys(changes.removed, ', ')
             else
                changes.removed = '' 
             end
             Stats.Abilities.changes[currentBp] = changes
        end
    end
end

-- verify bp.Economy table in a given blueprint
function VerifyEconomy(bp)
    RegisterValuesIn(bp.Economy, 'bp.Economy')

    if BPA.IsUnitBuildable(bp) and
       BPA.IsUnitStructure(bp) and not BPA.IsUnitCrabEgg(bp) then
        local bonusIDs = table.hash(bp.Economy.RebuildBonusIds)
        if not bonusIDs[bp.ID] then
            LogIssue(Severity.CRITICAL, bp, 'bp.Economy.RebuildBonusIds is missing ' .. Quote(bp.ID))
        end

        if IsMissing(bp.Economy.BuildCostEnergy) then 
            LogIssue(Severity.CRITICAL, bp, 'bp.Economy.BuildCostEnergy is missing')
        elseif IsMissing(bp.Economy.BuildCostMass) then 
            LogIssue(Severity.CRITICAL, bp, 'bp.Economy.BuildCostMass is missing')
        elseif IsMissing(bp.Economy.BuildTime) then 
            LogIssue(Severity.CRITICAL, bp, 'bp.Economy.BuildTime is missing')
        end
    end
end

-- verify bp.Enhancements table in a given blueprint
function VerifyEnhancements(bp)
    -- skipping pre-enhanced units since they are the same as base units
    if not bp.Enhancements or bp.CategoriesHash.ISPREENHANCEDUNIT then return end

    --local upgrades = table.filter(bp.Enhancements, function(v, k) return k ~= 'Slots' end)
    --LOG('VerifyEnhancements ' .. table.concatkeys(upgrades, ', ')) 

    if type(bp.Enhancements.Slots) ~= 'table' then 
        LogIssue(Severity.HIGH, bp, 'bp.Enhancements is missing Slots table')
    end

    for id, upgrade in bp.Enhancements do
        if id == 'Slots' then -- slots table
            for name, slot in upgrade or {} do
                local upgadeInfo = 'bp.Enhancements.'..id.. '.' .. name
                if type(slot.x) ~= 'number' then 
                    LogIssue(Severity.LOW, bp, upgadeInfo.. ' is missing x position')
                    break
                elseif type(slot.y) ~= 'number' then 
                    LogIssue(Severity.LOW, bp, upgadeInfo .. ' is missing y position')
                    break
                end
            end
        else -- actual upgrade definition
            local upgadeInfo = 'bp.Enhancements.'..id 
            local upgradeRemoval = string.find(id, 'Remove')
            if upgradeRemoval then
                if IsMissing(upgrade.Prerequisite) then 
                    LogIssue(Severity.LOW, bp, upgadeInfo .. ' is missing Prerequisite value')
                end
                if IsMissing(upgrade.RemoveEnhancements) then 
                    LogIssue(Severity.LOW, bp, upgadeInfo .. ' is missing RemoveEnhancements table')
                end 
            end 

            if IsMissing(upgrade.Name) then 
                LogIssue(Severity.HIGH, bp, upgadeInfo .. ' is missing Name')
            end

            if IsMissing(upgrade.Icon) then 
                LogIssue(Severity.HIGH, bp, upgadeInfo .. ' is missing Icon')
            end

            if IsMissing(upgrade.Slot) then 
                LogIssue(Severity.HIGH, bp, upgadeInfo .. ' is missing Slot')
            elseif not ValidSlots[upgrade.Slot] then 
                LogIssue(Severity.HIGH, bp, upgadeInfo .. ' has invalid Slot:' .. tostring(upgrade.Slot))
            end

            if IsMissingOrZero(upgrade.BuildTime) then 
                LogIssue(Severity.LOW, bp, upgadeInfo .. ' has no BuildTime: ' .. tostring(upgrade.BuildTime))
            elseif IsMissingOrZero(upgrade.BuildCostMass) then 
                LogIssue(Severity.LOW, bp, upgadeInfo .. ' has no BuildCostMass: ' .. tostring(upgrade.BuildCostMass))
            elseif IsMissingOrZero(upgrade.BuildCostEnergy) then 
                LogIssue(Severity.LOW, bp, upgadeInfo .. ' has no BuildCostEnergy: ' .. tostring(upgrade.BuildCostEnergy))
            end
        end
    end
end

-- verify bp.Footprint table in a given blueprint
function VerifyFootprint(bp)
    if not BPA.IsUnitStructure(bp) or BPA.IsUnitCrabEgg(bp) then return end

    if IsMissing(bp.Footprint) then 
        LogIssue(Severity.HIGH, bp, 'Missing bp.Footprint')
    elseif IsMissing(bp.Footprint.SizeX) then 
        LogIssue(Severity.HIGH, bp, 'Missing bp.Footprint.SizeX')
    elseif IsMissing(bp.Footprint.SizeZ) then 
        LogIssue(Severity.HIGH, bp, 'Missing bp.Footprint.SizeZ')
    else
        -- TODO-HUSSAR check these conditions should be correct for all units 
--        local numFootprintX = bp.Footprint.SizeX or 0
--        local numFootprintZ = bp.Footprint.SizeZ or 0 
--        local numHitboxX = math.max(1, math.round(bp.SizeX or 0))
--        local numHitboxZ = math.max(1, math.round(bp.SizeZ or 0))

--        local strFootprintX = 'bp.Footprint.SizeX (' .. string.format("%.1f", numFootprintX) .. ')'
--        local strFootprintZ = 'bp.Footprint.SizeZ (' .. string.format("%.1f", numFootprintZ) .. ')'
--        local strHitboxSizeX = 'bp.SizeX (' .. string.format("%.1f", numHitboxX) .. ')'
--        local strHitboxSizeZ = 'bp.SizeZ (' .. string.format("%.1f", numHitboxZ) .. ')'

--        if numFootprintX ~= numHitboxX then
--            LogIssue(Severity.HIGH, bp, strFootprintX .. ' is not matching ' .. strHitboxSizeX)
--        end 
    end
end

function VerifyGeneral(bp)
    -- skipping pre-enhanced units since they are the same as base units
    if bp.CategoriesHash.ISPREENHANCEDUNIT then return end

    VerifyGeneralSymbols(bp)

    IsValid(bp, 'General', 'Category', ValidEnums.General.Categories)
    IsValid(bp, 'General', 'FactionName', ValidEnums.General.FactionNames)
    IsValid(bp, 'General', 'Classification', ValidEnums.General.Classifications)
    
    --TODO-HUSSAR enable
    --VerifyGeneralCommands(bp)
    VerifyGeneralToggles(bp)
    VerifyCategoriesWithTech(bp)
    VerifyGeneralSelection(bp)

    -- check if units have Description and Interface HelpText
    if not bp.Description then
        LogIssue(Severity.LOW, bp, 'bp.Description is missing')
        if not bp.Interface or not bp.Interface.HelpText then
            LogIssue(Severity.LOW, bp, 'bp.Interface.HelpText is missing')
        end
    end
     
    if BPA.IsUnitWithEngineeringSuite(bp) then
        -- for some reason AEON T1-T3 engineers do not have building bones!
        if table.empty(bp.General.BuildBones) and not bp.CategoriesHash.AEON then
            LogIssue(Severity.LOW, bp, 'bp.General.BuildBones table is missing')
        end
    end

    if BPA.IsUnitWithFactoryStructure(bp) and not bp.CategoriesHash.GATE then
        if not bp.General.BuildBones then
            LogIssue(Severity.LOW, bp, 'bp.General.BuildBones table is missing')
        end
    end
end
  
function VerifyGeneralSymbols(bp)

    if not IsValid(bp, 'General', 'Icon', ValidEnums.General.Icons) then
        return -- skip rest of verification
    end

    -- skipping crab eggs because they are difficult to verify
    if BPA.IsUnitCrabEgg(bp) then return end

    local expectedIcon = 'unknown'
    if BPA.IsUnitAmphibious(bp) or BPA.IsUnitMobileHover(bp) or BPA.IsUnitStructureAquatic(bp) then
        expectedIcon = 'amph'
    elseif BPA.IsUnitTypeNaval(bp) or BPA.IsUnitStructureNaval(bp) then
        expectedIcon = 'sea'
    elseif BPA.IsUnitWithFactorySatellite(bp) then
        expectedIcon = 'land'
    elseif BPA.IsUnitWithFactoryAir(bp) then
        expectedIcon = 'air'
    elseif BPA.IsUnitTypeAir(bp) or BPA.IsUnitStructureAir(bp) then
        expectedIcon = 'air'
    elseif BPA.IsUnitTypeLand(bp) or BPA.IsUnitStructureLand(bp) then
        expectedIcon = 'land'
    end

    expectedIcon = Quote(expectedIcon)
    local actualIcon = Quote(bp.General.Icon)
    if actualIcon ~= expectedIcon then
        --LogIssue(Severity.LOW, bp, 'bp.General.Icon is '.. actualIcon  .. ' instead of ' .. expectedIcon)
    end

    RegisterValue(bp.BuildIconSortPriority, 'bp.BuildIconSortPriority') 
    if IsMissing(bp.BuildIconSortPriority) and BPA.IsUnitBuildable(bp) then
        local min = ValidRanges.BuildIconSortPriority.Min
        --bp.BuildIconSortPriority = min
        LogCorrection(Severity.LOW, bp, 'Set missing bp.BuildIconSortPriority to ' .. min)
    end
      
    RegisterValue(bp.StrategicIconSortPriority, 'bp.StrategicIconSortPriority') 
    if IsMissing(bp.StrategicIconSortPriority) and not BPA.IsUnitCommander(bp) then 
        local min = ValidRanges.StrategicIconSortPriority.Min
        bp.StrategicIconSortPriority = min
        LogCorrection(Severity.LOW, bp, 'Set missing bp.StrategicIconSortPriority to ' .. min)
    end

    local actualStratIcon = bp.StrategicIconName
    RegisterValue(actualStratIcon, 'bp.StrategicIconName')

    if IsMissing(actualStratIcon) then 
        LogIssue(Severity.HIGH, bp, 'bp.StrategicIconName is missing')
    elseif not ValidEnums.Other.StrategicIconNames[actualStratIcon] then
        LogIssue(Severity.HIGH, bp, 'bp.StrategicIconName has invalid ' .. Quote(actualStratIcon) .. ' value')
    else
        -- checking if bp.StrategicIconName matches unit's strategic group and purpose
        -- these values are calculated based on unit's weapons stats and abilities
        local group = BPA.GetUnitStrategicGroup(bp)
        local purpose = BPA.GetUnitStrategicPurpose(bp)
        local expectedIcon = 'icon_' .. group .. '_' .. purpose
        expectedIcon = Quote(expectedIcon)
        actualStratIcon = Quote(actualStratIcon)
        if expectedIcon ~= actualStratIcon then
            LogIssue(Severity.LOW, bp, 'bp.StrategicIconName is ' ..actualStratIcon .. ' instead of ' .. expectedIcon)
        end
    end
end

function VerifyGeneralSelection(bp)

    if IsMissing(bp.General.SelectionPriority) then
        LogIssue(Severity.CRITICAL, bp, 'bp.General.SelectionPriority is missing')
    else
        local priority = bp.General.SelectionPriority

        if bp.CategoriesHash.TRANSPORTATION and bp.ID ~= 'uea0203' then
            if priority ~= 2 then
                LogIssue(Severity.CRITICAL, bp, 'bp.General.SelectionPriority is '.. priority .. ' instead of 2')
            end

        elseif bp.CategoriesHash.ENGINEER and bp.CategoriesHash.CONSTRUCTION and not bp.CategoriesHash.STATIONASSISTPOD then
            if priority ~= 3 then
                LogIssue(Severity.CRITICAL, bp, 'bp.General.SelectionPriority is '.. priority .. ' instead of 3')
            end

        elseif bp.CategoriesHash.POD then
            if priority ~= 6 then
                LogIssue(Severity.CRITICAL, bp, 'bp.General.SelectionPriority is '.. priority .. ' instead of 6')
            end
        
        elseif bp.CategoriesHash.STRUCTURE and not BPA.IsUnitCrabEgg(bp) then
            if priority ~= 5 then
                LogIssue(Severity.CRITICAL, bp, 'bp.General.SelectionPriority is '.. priority .. ' instead of 5')
            end

        elseif bp.CategoriesHash.MOBILE or BPA.IsUnitCrabEgg(bp) then
            if priority ~= 1 then
                LogIssue(Severity.CRITICAL, bp, 'bp.General.SelectionPriority is '.. priority .. ' instead of 1')
            end

        else
            LogIssue(Severity.CRITICAL, bp, 'bp.General.SelectionPriority is '.. priority .. ' instead of ?')
        end
    end
end

function VerifyGeneralCommands(bp)
    if BPA.IsUnitCrabEgg(bp) then return end

    -- a function for asserting status of a command
    -- using CommandHash lookup table generated in Blueprints.lua
    local function AssertCommand(name, expectedStatus, reason)
        local actualStatus = bp.General.CommandHash[name]
        -- assuming not set commands are disabled (false)
        if actualStatus == nil then actualStatus = false end
        if actualStatus ~= expectedStatus then
            local msg = string.gsub(name, 'RULEUCC_', '')
            msg = msg .. ' should be ' .. tostring(expectedStatus)
            LogIssue(Severity.LOW, bp, 'bp.General.CommandCaps.'.. msg, reason)
        end
    end

    -- getting some useful stats about weapons for simpler verification
    local weaponsTML = table.size(BPA.GetWeaponsWithTML(bp))
    local weaponsSML = table.size(BPA.GetWeaponsWithSML(bp))
    local weaponsSMD = table.size(BPA.GetWeaponsWithSMD(bp))
    local weaponsOC = table.size(BPA.GetWeaponsWithOvercharge(bp))
    local weaponsOffensive = table.size(BPA.GetWeaponsWithOffense(bp))
    local weaponsDefensive = table.size(BPA.GetWeaponsWithDefense(bp))
    local weaponsGunship = table.size(BPA.GetWeaponsWithGunship(bp))
    local weaponsKamikaze = table.size(BPA.GetWeaponsWithKamikaze(bp))

    if weaponsOffensive > 0 then
        AssertCommand('RULEUCC_RetaliateToggle', true, 'because it has offensive weapons')
    elseif weaponsDefensive > 0 then
        AssertCommand('RULEUCC_RetaliateToggle', true, 'because it has defensive weapons')
    elseif BPA.IsUnitWithFactorySuite(bp) and not bp.CategoriesHash.ORBITALSYSTEM then
        AssertCommand('RULEUCC_RetaliateToggle', true, 'because it has factory attack-move')
    else
        AssertCommand('RULEUCC_RetaliateToggle', false, 'because it has no weapons')
    end

    if BPA.IsUnitWithTacticalPlatform(bp) or BPA.IsUnitWithStrategicPlatform(bp) then
        AssertCommand('RULEUCC_Attack', false, 'because it has manual launch only')
    elseif weaponsOffensive > 0 then
        AssertCommand('RULEUCC_Attack', true, 'because it has offensive weapons')
    else
        AssertCommand('RULEUCC_Attack', false, 'because it has no weapons')
    end

    if BPA.IsUnitWithFuelLimited(bp) then
        AssertCommand('RULEUCC_Patrol', false, 'because it has no re-fueling')
        AssertCommand('RULEUCC_Move', true, 'because it is mobile unit')
    elseif BPA.IsUnitMobile(bp) then
        AssertCommand('RULEUCC_Patrol', true, 'because it is mobile unit')
        AssertCommand('RULEUCC_Move', true, 'because it is mobile unit')
    elseif BPA.IsUnitWithFactoryRallyPoint(bp) then
        AssertCommand('RULEUCC_Patrol', true, 'because it is factory with rally point')
        AssertCommand('RULEUCC_Move', true, 'because it is factory with rally point')
    else
        AssertCommand('RULEUCC_Patrol', false, 'because it is stationary unit')
        AssertCommand('RULEUCC_Move', false, 'because it is stationary unit')
    end

    if BPA.IsUnitMobile(bp) then
        AssertCommand('RULEUCC_Stop', true, 'because it can stop moving') 
    elseif BPA.IsUnitWithFactorySuite(bp)  then
        AssertCommand('RULEUCC_Stop', true, 'because it can stop building units')
    elseif BPA.IsUnitWithConstructionSuite(bp) then
        AssertCommand('RULEUCC_Stop', true, 'because it can stop building structures')
    elseif BPA.IsUnitUpgradable(bp)  then
        AssertCommand('RULEUCC_Stop', true, 'because it can stop upgrading')
    elseif weaponsSMD > 0 or weaponsSMD > 0 then
        AssertCommand('RULEUCC_Stop', true, 'because it can stop building missiles')
    elseif weaponsOffensive > 0 then
        AssertCommand('RULEUCC_Stop', true, 'because it can stop attacking')
    else
        AssertCommand('RULEUCC_Stop', false, 'because it cannot stop any action')
    end 

    if BPA.IsUnitUpgradable(bp)  then
        AssertCommand('RULEUCC_Pause', true, 'because it can be upgraded')
    elseif BPA.IsUnitWithFactorySuite(bp) then
        AssertCommand('RULEUCC_Pause', true, 'because it can build units')
    elseif BPA.IsUnitWithEngineeringSuite(bp) then
        AssertCommand('RULEUCC_Pause', true, 'because it can build structures')
    elseif weaponsTML > 0 and BPA.IsUnitStructure(bp) then
        AssertCommand('RULEUCC_Pause', true, 'because it can build missiles')
    elseif weaponsSML > 0 or weaponsSMD > 0 then
        AssertCommand('RULEUCC_Pause', true, 'because it can build missiles')
    else
        AssertCommand('RULEUCC_Pause', false, 'because it cannot build/upgrade')
    end

    if weaponsTML > 0 and BPA.IsUnitStructure(bp) then
        AssertCommand('RULEUCC_Tactical', true, 'because it can build TMLs')
        AssertCommand('RULEUCC_SiloBuildTactical', true, 'because it can store TMLs')
    elseif weaponsSMD > 0 and BPA.IsUnitStructure(bp) then
        AssertCommand('RULEUCC_SiloBuildTactical', true, 'because it can store SMDs')
    else
        AssertCommand('RULEUCC_Tactical', false, 'because it cannot build TMLs')
        AssertCommand('RULEUCC_SiloBuildTactical', false, 'because it cannot store TMLs')
    end

    -- excluding UEF ACU because its Billy nuke is installed as an upgrade
    if weaponsSML > 0 and not bp.CategoriesHash.COMMAND then
        AssertCommand('RULEUCC_Nuke', true, 'because it can build nukes')
        AssertCommand('RULEUCC_SiloBuildNuke', true, 'because it can store nukes')
    else
        AssertCommand('RULEUCC_Nuke', false, 'because it cannot build nukes')
        AssertCommand('RULEUCC_SiloBuildNuke', false, 'because it cannot store nukes')
    end

    -- excluding SERA SCU because its OC weapon is installed as an upgrade
    -- and thus RULEUCC_Overcharge is enabled in script and it not enabled in blueprint by default
    if weaponsOC > 0 and not bp.CategoriesHash.SUBCOMMANDER then 
        AssertCommand('RULEUCC_Overcharge', true, 'because it has OC weapon')
    else
        AssertCommand('RULEUCC_Overcharge', false, 'because it has no OC weapon')
    end

    -- no unit has Teleport enabled by default
    AssertCommand('RULEUCC_Teleport', false, 'because teleport is an upgrade')

    -- checking RULEUCC_Transport command
    if bp.Transport.StorageSlots > 0 then
        AssertCommand('RULEUCC_Transport', true, 'because it has storage slots')
    elseif bp.Transport.DockingSlots > 0 then
        AssertCommand('RULEUCC_Transport', true, 'because it has docking slots')
    elseif BPA.IsUnitMobileAir(bp) then
       if bp.Air.TransportHoverHeight > 0 then
           AssertCommand('RULEUCC_Transport', true, 'because it has transport hover')
       else 
           AssertCommand('RULEUCC_Transport', false, 'because it has no transport hover')
       end 
    else
        AssertCommand('RULEUCC_Transport', false, 'because it cannot fly or dock/store units')
    end
    
    if BPA.IsUnitMobileAir(bp) and bp.Air and bp.Air.TransportHoverHeight > 0 then
        AssertCommand('RULEUCC_Ferry', true, 'because it can fly/transport/land')
    else
        AssertCommand('RULEUCC_Ferry', false, 'because it cannot fly/transport/land')
    end
    
    if bp.CategoriesHash.EXPERIMENTAL then
        AssertCommand('RULEUCC_CallTransport', false, 'because it is T4')
    elseif BPA.IsUnitWithEngineeringDrone(bp) then
        AssertCommand('RULEUCC_CallTransport', false, 'because it is drone')
    elseif BPA.IsUnitMobileNaval(bp) then
        AssertCommand('RULEUCC_CallTransport', false, 'because it is mobile navy')
    elseif BPA.IsUnitMobileLand(bp) then
        AssertCommand('RULEUCC_CallTransport', true, 'because it is mobile land')
    elseif BPA.IsUnitMobileAir(bp) then  
        if weaponsKamikaze > 0 then
            AssertCommand('RULEUCC_CallTransport', false, 'because it is kamikaze')
        else 
            -- not sure why mobile air can call transports!
            AssertCommand('RULEUCC_CallTransport', true, 'because it is mobile air')
        end
    else 
        AssertCommand('RULEUCC_CallTransport', false, 'because it is not mobile land/air')
    end

    -- checking RULEUCC_Dock command
    if bp.CategoriesHash.EXPERIMENTAL then
        AssertCommand('RULEUCC_Dock', false, 'because it is T4')
    elseif BPA.IsUnitMobileOrbital(bp) then
        AssertCommand('RULEUCC_Dock', false, 'because it is satellite')
    elseif BPA.IsUnitWithEngineeringDrone(bp) then
        AssertCommand('RULEUCC_Dock', false, 'because it is drone')
    elseif BPA.IsUnitMobileAir(bp) then
        if bp.ID == 'uea0203' then 
            AssertCommand('RULEUCC_Dock', true, 'because it is gunship')
        elseif weaponsKamikaze > 0 then
            AssertCommand('RULEUCC_Dock', false, 'because it is kamikaze')
        elseif BPA.IsUnitTransportingByAir(bp) then
            AssertCommand('RULEUCC_Dock', false, 'because it is transport')
        else
            AssertCommand('RULEUCC_Dock', true, 'because it can fly')
        end
    else
        AssertCommand('RULEUCC_Dock', false, 'because it cannot fly')
    end

    if BPA.IsUnitMobileSub(bp) then
        AssertCommand('RULEUCC_Dive', true, 'because it is SurfacingSub')
    else
        AssertCommand('RULEUCC_Dive', false, 'because it is not SurfacingSub')
    end

    if not bp.Economy.BuildRate or bp.Economy.BuildRate == 0 then
        AssertCommand('RULEUCC_Repair', false, 'because it has no bp.Economy.BuildRate')
    elseif BPA.IsUnitWithFactorySuite(bp) then
        AssertCommand('RULEUCC_Repair', false, 'because it is Factory') 
    elseif BPA.IsUnitMobileAir(bp) and BPA.IsUnitWithEngineeringDrone(bp) then
        AssertCommand('RULEUCC_Repair', true, 'because it is Drone')
    elseif BPA.IsUnitWithAssistingStation(bp) then
        AssertCommand('RULEUCC_Repair', true, 'because it is assist suite')
    elseif BPA.IsUnitMobileLand(bp) and BPA.IsUnitWithBuildingBones(bp)  then
        AssertCommand('RULEUCC_Repair', true, 'because it has build bones')
    elseif BPA.IsUnitMobileLand(bp) and BPA.IsUnitWithBuildingSuite(bp)  then
        AssertCommand('RULEUCC_Repair', true, 'because it has build suite')
    else
        AssertCommand('RULEUCC_Repair', false, 'because it has no assist/build suite')
    end

    -- TODO-HUSSAR add verifications for these commands:
    -- RULEUCC_Guard (aka Assist)
    -- RULEUCC_Sacrifice 
    -- RULEUCC_Reclaim
    -- RULEUCC_Capture 
end

function VerifyGeneralToggles(bp)
    if not bp.General.ToggleHash then return end

    if BPA.IsUnitCrabEgg(bp) then return end   
    
    -- a function for asserting status of a toggles
    -- using ToggleHash lookup table generated in Blueprints.lua
    local function AssertToggle(name, expectedStatus, reason)
        local actualStatus = bp.General.ToggleHash[name]
        -- assuming not set toggles are disabled (false)
        if actualStatus == nil then actualStatus = false end
        if actualStatus ~= expectedStatus then
            local issue = string.gsub(name, 'RULEUTC_', '')  .. ' should be ' 
            issue = issue .. tostring(expectedStatus)
            LogIssue(Severity.LOW, bp, 'bp.General.ToggleCaps.'.. issue, reason)
        end
    end
    
    -- weapon toggles
    local weapons = BPA.GetWeaponsWithOffense(bp)
    if table.size(weapons) >= 2 and table.identical(weapons[1].RackBones, weapons[2].RackBones) then
        AssertToggle('RULEUTC_WeaponToggle', true, 'because it has 2 toggleable weapons')
    elseif BPA.IsUnitWithEngineeringDrone(bp) then
        AssertToggle('RULEUTC_WeaponToggle', true, 'because it has drone-rebuild override')
    else
        AssertToggle('RULEUTC_WeaponToggle', false, 'because it has no 2 toggleable weapons')
    end

    -- shield toggles
    if BPA.IsUnitWithShieldSuite(bp) and BPA.IsUnitWithEnergyConsumption(bp) then
        AssertToggle('RULEUTC_ShieldToggle', true, 'because it has shield suite')
    elseif BPA.IsUnitWithShieldDome(bp) and BPA.IsUnitWithEnergyConsumption(bp) then
        AssertToggle('RULEUTC_ShieldToggle', true, 'because it has shield dome')
    else
        AssertToggle('RULEUTC_ShieldToggle', false, 'because it has no shields')
    end

    -- production toggles
    if BPA.IsUnitWithMassProdution(bp) and BPA.IsUnitWithEnergyConsumption(bp) then
        AssertToggle('RULEUTC_ProductionToggle', true, 'because it has mass production')
    elseif BPA.IsUnitWithMassFabrication(bp) then
        AssertToggle('RULEUTC_ProductionToggle', true, 'because it has mass fabrication')
    elseif BPA.IsUnitWithEngineeringStation(bp) then
        AssertToggle('RULEUTC_ProductionToggle', true, 'because it has area-assist override')
    elseif BPA.IsUnitMobileLand(bp) and BPA.IsUnitKamikaze(bp) then
        AssertToggle('RULEUTC_ProductionToggle', true, 'because it has detonate override')
    else
        AssertToggle('RULEUTC_ProductionToggle', false, 'because it has no production')
    end

    -- intel toggles
    if BPA.IsUnitWithIntelJamming(bp) and BPA.IsUnitWithEnergyConsumption(bp) then
        AssertToggle('RULEUTC_JammingToggle', true, 'because it has jamming sensor')
        AssertToggle('RULEUTC_IntelToggle', false, 'because it has jamming sensor already')
        AssertToggle('RULEUTC_CloakToggle', false, 'because it has jamming sensor already')
    elseif BPA.IsUnitWithIntelCloak(bp) then
        AssertToggle('RULEUTC_CloakToggle', true, 'because it has cloak suite')
        AssertToggle('RULEUTC_IntelToggle', false, 'because it has cloak suite already')
        AssertToggle('RULEUTC_JammingToggle', false, 'because it has cloak suite already')
    elseif BPA.IsUnitWithStealthSuite(bp) and BPA.IsUnitWithEnergyConsumption(bp) then
        AssertToggle('RULEUTC_StealthToggle', true, 'because it has stealth suite')
        AssertToggle('RULEUTC_IntelToggle', false, 'because it has stealth already')
    elseif BPA.IsUnitWithStealthField(bp) and BPA.IsUnitWithEnergyConsumption(bp) and not BPA.IsUnitWithIntelSonarMobile(bp) then
        AssertToggle('RULEUTC_StealthToggle', true, 'because it has stealth field')
        AssertToggle('RULEUTC_IntelToggle', false, 'because it has stealth already')
    elseif BPA.IsUnitWithIntelSensor(bp) and BPA.IsUnitWithEnergyConsumption(bp) then
        AssertToggle('RULEUTC_IntelToggle', true, 'because it has intel sensor')
        AssertToggle('RULEUTC_CloakToggle', false, 'because it has intel sensor already')
        AssertToggle('RULEUTC_StealthToggle', false, 'because it has intel sensor already')
        AssertToggle('RULEUTC_JammingToggle', false, 'because it has intel sensor already')
    else
        AssertToggle('RULEUTC_CloakToggle', false, 'because it has no cloak suite')
        AssertToggle('RULEUTC_IntelToggle', false, 'because it has no intel sensor')
        AssertToggle('RULEUTC_StealthToggle', false, 'because it has no stealth suite/field')
        AssertToggle('RULEUTC_JammingToggle', false, 'because it has no jamming sensor')
    end
end

-- bp.Intel = {
--     ActiveIntel = { Omni = true },
--     Cloak = true,
--     FreeIntel = false,
--     OmniRadius = 16,
--     RadarStealth = true,
--     ReactivateTime = 2,
--     SonarStealth = true,
--     VisionRadius = 26,
--     WaterVisionRadius = 26,
-- },
function VerifyIntel(bp)
    if bp.CategoriesHash.WALL then return end

    RegisterValuesIn(bp.Intel, 'bp.Intel')

    local function Get(key)
        return 'bp.Intel.' ..key ..' ('.. bp.Intel[key] ..')'
    end

    if IsMissing(bp.Intel) then 
        LogIssue(Severity.LOW, bp, "bp.Intel table is missing")

    elseif not bp.Intel.VisionRadius then
        LogIssue(Severity.HIGH, bp, 'bp.Intel.VisionRadius is missing')

    elseif bp.Intel.VisionRadius < 0 then
         LogIssue(Severity.HIGH, bp, 'bp.Intel.VisionRadius is negative')

    elseif bp.Intel.SonarRadius < 0 then
         LogIssue(Severity.HIGH, bp, 'bp.Intel.SonarRadius is negative')
       
    elseif bp.Intel.RadarRadius < 0 then
         LogIssue(Severity.HIGH, bp, 'bp.Intel.RadarRadius is negative')

    elseif not bp.Intel.VisionRadius or bp.Intel.VisionRadius <= 0 then
        LogIssue(Severity.HIGH, bp, 'bp.Intel.VisionRadius is missing')

    elseif not bp.Intel.CloakField and bp.Intel.CloakFieldRadius > 0 then
        LogIssue(Severity.HIGH, bp, 'bp.Intel.CloakField = false but ' .. Get('CloakFieldRadius'))

    elseif bp.Intel.CloakField and bp.Intel.CloakFieldRadius < 1 then
        LogIssue(Severity.HIGH, bp, 'bp.Intel.CloakField = true but ' .. Get('CloakFieldRadius'))

    elseif bp.Intel.RadarRadius > 0 and bp.Intel.RadarRadius < bp.Intel.VisionRadius then
        LogIssue(Severity.HIGH, bp, Get('RadarRadius') .. ' is less than ' .. Get('VisionRadius'))
    end

    if BPA.IsUnitMobileAir(bp) then
        if bp.Intel.SonarStealth and not bp.Intel.RadarStealth then
            LogIssue(Severity.HIGH, bp, 'bp.Intel.RadarStealth is missing but SonarStealth = true ')
        end
    end
    
    if BPA.IsUnitMobileNaval(bp) or BPA.IsUnitStructure(bp) then 
        if bp.Intel.RadarStealth and not bp.Intel.SonarStealth then
            LogIssue(Severity.HIGH, bp, 'bp.Intel.SonarStealth is missing but RadarStealth = true ')
        end
    end

    if BPA.IsUnitMobileNaval(bp) or BPA.IsUnitStructureNaval(bp) then 
        if not bp.Intel.WaterVisionRadius then
            LogIssue(Severity.HIGH, bp, 'bp.Intel.WaterVisionRadius is missing')
        elseif bp.Intel.WaterVisionRadius < 0 then
            LogIssue(Severity.HIGH, bp, 'bp.Intel.WaterVisionRadius is negative')
        end
    end
end

function VerifyPhysicsLayers(bp)

    -- BuildOnLayerCaps table is converted to a number when loading blueprints so using 
    -- BuildOnLayerHash table generated in Blueprints.lua
    local found = false
    for layer, isEnabled in bp.Physics.BuildOnLayerHash or {} do
        if not ValidEnums.Physics.BuildOnLayers[layer] then
            LogIssue(Severity.HIGH, bp, 'bp.Physics.BuildOnLayerCaps has unknown layer ' .. Quote(layer))
        elseif isEnabled then
            found = true
        end
    end 
    if not found then
        LogIssue(Severity.HIGH, bp, 'bp.Physics.BuildOnLayerCaps is missing at least 1 layer') 
        return -- skip rest of verification
    end

    -- a function for asserting a value of BuildOnLayer 
    local function AssertLayer(info, name, expectedStatus)
        local actualStatus = bp.Physics.BuildOnLayerHash[name]
        -- assuming not set layers are disabled (false)
        if actualStatus == nil then actualStatus = false end
        if actualStatus ~= expectedStatus then
            local msg = string.gsub(name, 'LAYER_', '')
            msg = msg .. ' should be ' .. tostring(expectedStatus)
            local reason = 'because it is ' .. info
            LogIssue(Severity.LOW, bp, 'bp.Physics.BuildOnLayerCaps.' .. msg, reason)
        end
    end 

    if BPA.IsUnitStructureAquatic(bp) then
        AssertLayer('Aquatic structure', 'LAYER_Air', false)
        AssertLayer('Aquatic structure', 'LAYER_Land', true) -- Aquatic
        AssertLayer('Aquatic structure', 'LAYER_Orbit', false)
        AssertLayer('Aquatic structure', 'LAYER_Seabed', false)
        AssertLayer('Aquatic structure', 'LAYER_Water', true) -- Aquatic
        AssertLayer('Aquatic structure', 'LAYER_Sub', false)

    elseif BPA.IsUnitStructureAmphibious(bp) then
        AssertLayer('Amphibious structure', 'LAYER_Air', false)
        AssertLayer('Amphibious structure', 'LAYER_Land', true) -- Amphibious
        AssertLayer('Amphibious structure', 'LAYER_Orbit', false)
        AssertLayer('Amphibious structure', 'LAYER_Seabed', true) -- Amphibious
        AssertLayer('Amphibious structure', 'LAYER_Water', false)
        AssertLayer('Amphibious structure', 'LAYER_Sub', false)

    elseif BPA.IsUnitStructureSubmerged(bp) then
        AssertLayer('Submerged structure', 'LAYER_Air', false)
        AssertLayer('Submerged structure', 'LAYER_Land', false)
        AssertLayer('Submerged structure', 'LAYER_Orbit', false)
        AssertLayer('Submerged structure', 'LAYER_Seabed', false)
        AssertLayer('Submerged structure', 'LAYER_Water', false)
        AssertLayer('Submerged structure', 'LAYER_Sub', true) -- Submerged only

    elseif BPA.IsUnitStructureNaval(bp) then
        AssertLayer('Naval structure', 'LAYER_Air', false)
        AssertLayer('Naval structure', 'LAYER_Land', false)
        AssertLayer('Naval structure', 'LAYER_Orbit', false)
        AssertLayer('Naval structure', 'LAYER_Seabed', false)
        AssertLayer('Naval structure', 'LAYER_Water', true) -- Naval only
        AssertLayer('Naval structure', 'LAYER_Sub', false)

    elseif BPA.IsUnitStructureLand(bp) then
        AssertLayer('Land structure', 'LAYER_Air', false)
        AssertLayer('Land structure', 'LAYER_Land', true) -- Land only
        AssertLayer('Land structure', 'LAYER_Orbit', false)
        AssertLayer('Land structure', 'LAYER_Seabed', false)
        AssertLayer('Land structure', 'LAYER_Water', false)
        AssertLayer('Land structure', 'LAYER_Sub', false)

    elseif BPA.IsUnitMobileOrbital(bp) then
        AssertLayer('Orbital unit', 'LAYER_Air', true) -- launches from Air to Orbit
        AssertLayer('Orbital unit', 'LAYER_Land', false)
        AssertLayer('Orbital unit', 'LAYER_Orbit', false) -- cannot be built on orbit
        AssertLayer('Orbital unit', 'LAYER_Seabed', false)
        AssertLayer('Orbital unit', 'LAYER_Water', false)
        AssertLayer('Orbital unit', 'LAYER_Sub', false)

    elseif BPA.IsUnitMobileAir(bp) then
       AssertLayer('Air unit', 'LAYER_Air', true) -- airplane
       AssertLayer('Air unit', 'LAYER_Land', false)
       AssertLayer('Air unit', 'LAYER_Orbit', false)
       AssertLayer('Air unit', 'LAYER_Seabed', false)
       AssertLayer('Air unit', 'LAYER_Water', false)
       AssertLayer('Air unit', 'LAYER_Sub', false) 

    elseif BPA.IsUnitMobileSub(bp) then
        AssertLayer('Submarine', 'LAYER_Air', false)
        AssertLayer('Submarine', 'LAYER_Land', false)
        AssertLayer('Submarine', 'LAYER_Orbit', false)
        AssertLayer('Submarine', 'LAYER_Seabed', false)
        -- check for Submarines built above or above water
        if bp.ID == 'xss0201' or bp.CategoriesHash.EXPERIMENTAL then
            AssertLayer('Submarine above water', 'LAYER_Water', true)
            AssertLayer('Submarine above water', 'LAYER_Sub', true)
        else
            AssertLayer('Submarine below water', 'LAYER_Water', false)
            AssertLayer('Submarine below water', 'LAYER_Sub', true)
        end

    elseif BPA.IsUnitMobileNaval(bp) then
        AssertLayer('Naval unit', 'LAYER_Air', false)
        AssertLayer('Naval unit', 'LAYER_Land', false)
        AssertLayer('Naval unit', 'LAYER_Orbit', false)
        AssertLayer('Naval unit', 'LAYER_Seabed', false)
        AssertLayer('Naval unit', 'LAYER_Water', true)
        AssertLayer('Naval unit', 'LAYER_Sub', false)

    elseif BPA.IsUnitMobileAmphibious(bp) then
        AssertLayer('Amphibious', 'LAYER_Air', false) 
        AssertLayer('Amphibious', 'LAYER_Orbit', false) 
        AssertLayer('Amphibious', 'LAYER_Sub', false)
        -- check for motion type
        if bp.Physics.MotionType == 'RULEUMT_AmphibiousFloating' and
           bp.CategoriesHash.EXPERIMENTAL then
            AssertLayer('Amphibious with float motion', 'LAYER_Land', true)
            AssertLayer('Amphibious with float motion', 'LAYER_Water', true)
            AssertLayer('Amphibious with float motion', 'LAYER_Seabed', false)
        elseif bp.Physics.MotionType == 'RULEUMT_Amphibious' and
               bp.CategoriesHash.EXPERIMENTAL then
            AssertLayer('Amphibious with seabed motion', 'LAYER_Land', true)
            AssertLayer('Amphibious with seabed motion', 'LAYER_Water', true)
            AssertLayer('Amphibious with seabed motion', 'LAYER_Seabed', true)
        end

    elseif BPA.IsUnitMobileHover(bp) then
        AssertLayer('Hover unit', 'LAYER_Air', false)
        AssertLayer('Hover unit', 'LAYER_Land', true) -- Hover
        AssertLayer('Hover unit', 'LAYER_Orbit', false)
        AssertLayer('Hover unit', 'LAYER_Seabed', false) -- Hover
        AssertLayer('Hover unit', 'LAYER_Water', false)
        AssertLayer('Hover unit', 'LAYER_Sub', false)

    elseif BPA.IsUnitMobileLand(bp) then
        AssertLayer('Land unit', 'LAYER_Air', false)
        AssertLayer('Land unit', 'LAYER_Land', true) -- Land only
        AssertLayer('Land unit', 'LAYER_Orbit', false)
        AssertLayer('Land unit', 'LAYER_Seabed', false)
        AssertLayer('Land unit', 'LAYER_Water', false)
        AssertLayer('Land unit', 'LAYER_Sub', false)

    else
        -- LogIssue(Severity.LOW, bp, 'bp.Physics.BuildOnLayerCaps not asserted')
    end
end

function VerifyPhysicsSizes(bp)

    if not bp.Physics.SkirtSizeX > 0 then
        LogIssue(Severity.HIGH, bp, "bp.Physics.SkirtSizeX is missing") return
    elseif not bp.Physics.SkirtSizeZ > 0 then
        LogIssue(Severity.HIGH, bp, "bp.Physics.SkirtSizeZ is missing") return
    end

    -- for simplicity, we are just checking bp.Physics.Skirt sizes in stationary units
    if not BPA.IsUnitBuildByEngineer(bp) then return end
     
    if bp.Physics.SkirtOffsetX > 0 or bp.Physics.SkirtOffsetZ > 0 then
        LogIssue(Severity.HIGH, bp, 'bp.Physics.SkirtOffset is not negative')
    end
    
    local strSkirtSizeX = 'bp.Physics.SkirtSizeX ' .. string.format("%.1f", bp.Physics.SkirtSizeX) 
    local strSkirtSizeZ = 'bp.Physics.SkirtSizeZ ' .. string.format("%.1f", bp.Physics.SkirtSizeZ) 
    local strHitboxSizeX = 'bp.SizeX ' .. string.format("%.1f", bp.SizeX) 
    local strHitboxSizeZ = 'bp.SizeZ ' .. string.format("%.1f", bp.SizeZ) 
    
    if math.mod(bp.Physics.SkirtSizeX, 1) > 0 then 
        LogIssue(Severity.HIGH, bp, strSkirtSizeX .. ' is not integer')
    elseif bp.Physics.SkirtSizeX < bp.SizeX then 
        LogIssue(Severity.HIGH, bp, strSkirtSizeX .. ' is smaller than hitbox ' .. strHitboxSizeX)
    end
    
    if math.mod(bp.Physics.SkirtSizeZ, 1) > 0 then 
        LogIssue(Severity.HIGH, bp, strSkirtSizeZ .. ' is not integer')
    elseif bp.Physics.SkirtSizeZ < bp.SizeZ then
        LogIssue(Severity.HIGH, bp, strSkirtSizeZ .. ' is smaller than hitbox ' .. strHitboxSizeZ) 
    end 

end

function VerifyPhysics(bp)
    -- skipping verification of some units
    if bp.CategoriesHash.ISPREENHANCEDUNIT then return end
--    if bp.CategoriesHash.SUBCOMMANDER then return end

    if not IsValid(bp, 'Physics', 'MotionType', ValidEnums.Physics.MotionTypes) then
        LogIssue(Severity.HIGH, bp, 'bp.Physics.MotionType is invalid')
        return -- skip rest of verification
    end
    
    VerifyPhysicsSizes(bp)
    
    if bp.CategoriesHash.COMMAND then return end

    VerifyPhysicsLayers(bp)
end

function VerifyLifebar(bp)
    -- skipping pre-enhanced units since they are the same as base units
    if bp.CategoriesHash.ISPREENHANCEDUNIT then return end

    if IsMissing(bp.LifeBarSize) then 
        LogIssue(Severity.LOW, bp, "bp.LifeBarSize is missing") return
    elseif IsMissing(bp.LifeBarHeight) then 
        LogIssue(Severity.LOW, bp, "bp.LifeBarHeight is missing") return
    elseif IsMissing(bp.LifeBarOffset) then 
        LogIssue(Severity.LOW, bp, "bp.LifeBarOffset is missing") return
    else
        if bp.LifeBarSize < bp.SizeX * 0.25 then
            local strLifeBarSize = 'bp.LifeBarSize ' .. string.format("%.1f", bp.LifeBarSize) 
            local strHitboxSize = 'bp.SizeX ' .. string.format("%.1f", bp.SizeX * 0.25) 
            LogIssue(Severity.LOW, bp, strLifeBarSize..' is smaller than 25% of hitbox ' .. strHitboxSize)
        end
    end
      
end

function VerifySelection(bp)
    -- skipping pre-enhanced units since they are the same as base units
    if bp.CategoriesHash.ISPREENHANCEDUNIT then return end

    if IsMissing(bp.SelectionSizeX) then 
        LogIssue(Severity.LOW, bp, "bp.SelectionSizeX is missing") return
    elseif IsMissing(bp.SelectionSizeZ) then 
        LogIssue(Severity.LOW, bp, "bp.SelectionSizeZ is missing") return
    elseif IsMissing(bp.SelectionThickness) then 
        LogIssue(Severity.LOW, bp, "bp.SelectionThickness is missing") return
    elseif not bp.CategoriesHash.SELECTABLE then
        LogIssue(Severity.HIGH, bp, "bp.Categories.SELECTABLE is missing") return
    else
        local sizeRatio = 1.0
        if BPA.IsUnitBuildByEngineer(bp) or BPA.IsUnitCrabEgg(bp) or BPA.IsUnitUpgradeLevel(bp) then
            sizeRatio = 2.0
        elseif BPA.IsUnitBuildByFactory(bp) or BPA.IsUnitCommander(bp) or
               BPA.IsUnitSatellite(bp) or BPA.IsUnitWithEngineeringDrone(bp) then
            sizeRatio = 2.5
        end

        local strRatio = string.format("%.2f", sizeRatio)
        local strSelectionSizeX = 'bp.SelectionSizeX ' .. string.format("%.1f", bp.SelectionSizeX) 
        local strSelectionSizeZ = 'bp.SelectionSizeZ ' .. string.format("%.1f", bp.SelectionSizeZ) 
        local strHitboxRatioX = 'bp.SizeX/'..strRatio..'='..string.format("%.2f", bp.SizeX / sizeRatio) 
        local strHitboxRatioZ = 'bp.SizeZ/'..strRatio..'='..string.format("%.2f", bp.SizeZ / sizeRatio) 

        -- checking if selection is too small based on hitbox bp.SizeX
        if bp.SizeX > 1 and bp.SizeX / sizeRatio > bp.SelectionSizeX then
            LogIssue(Severity.MIN, bp, strSelectionSizeX..' is smaller than hitbox '..strHitboxRatioX)
        end
        -- checking if selection is too small based on hitbox bp.SizeZ
        if bp.SizeZ > 1 and bp.SizeZ / sizeRatio > bp.SelectionSizeZ then
            LogIssue(Severity.MIN, bp, strSelectionSizeZ..' is smaller than hitbox '..strHitboxRatioZ)
        end
    end
    
end

-- check if blueprint has valid hitbox sizes (AKA red wireframe skeleton)
function VerifySizeHitbox(bp)
    -- skipping pre-enhanced units since they are the same as base units
    if bp.CategoriesHash.ISPREENHANCEDUNIT then return end
    
    if not bp.SizeX > 0 then
        LogIssue(Severity.HIGH, bp, "bp.SizeX is missing")
    elseif not bp.SizeY > 0 then
        LogIssue(Severity.HIGH, bp, "bp.SizeY is missing")
    elseif not bp.SizeZ > 0 then
        LogIssue(Severity.HIGH, bp, "bp.SizeZ is missing")
    end
    -- note hitbox is checked against bp.Selection sizes in VerifySelection(bp)
    -- also hitbox is checked against bp.Physics.Skirt sizes in VerifyPhysicsSizes(bp)
    -- so we do not need to make additional checks here
end

function VerifyTransport(bp)
    -- skipping pre-enhanced units since they are the same as base units
    if bp.CategoriesHash.ISPREENHANCEDUNIT then return end

    -- check for TRANSPORT categories
    if BPA.IsUnitTransportingByAir(bp) then
        LogCategoryAdded(Severity.LOW, bp, 'TRANSPORTATION')
        LogCategoryAdded(Severity.LOW, bp, 'TRANSPORTFOCUS')
    else 
        LogCategoryRemoved(Severity.LOW, bp, 'TRANSPORTATION')
        LogCategoryRemoved(Severity.LOW, bp, 'TRANSPORTFOCUS')
    end

    -- skipping non-mobile land units since only those can be transported
    if not BPA.IsUnitMobileLand(bp) then return end

    if IsMissing(bp.Transport) then 
        LogIssue(Severity.HIGH, bp, 'bp.Transport table is missing')

    elseif IsMissing(bp.Transport.TransportClass) then 
        LogIssue(Severity.HIGH, bp, 'bp.Transport.TransportClass is missing')

    elseif BPA.IsUnitMobileLand(bp) and not BPA.IsUnitMobileAmphibious(bp) and bp.ID ~= 'xrl0302' then
        -- checking if bp.Transport.TransportClass (size) matches tech level
        local tc = bp.Transport.TransportClass

        if bp.CategoriesHash.TECH1 and tc ~= 1 then
            LogIssue(Severity.HIGH, bp, 'bp.Transport.TransportClass = ' .. tc .. ' instead of 1')
        elseif bp.CategoriesHash.TECH2 and tc ~= 2 then
            LogIssue(Severity.HIGH, bp, 'bp.Transport.TransportClass = ' .. tc .. ' instead of 2')
        elseif bp.CategoriesHash.TECH3 and tc ~= 3 then
            LogIssue(Severity.HIGH, bp, 'bp.Transport.TransportClass = ' .. tc .. ' instead of 3')
        elseif bp.CategoriesHash.EXPERIMENTAL then
            -- skipping EXPERIMENTAL units since they have various TransportClass
        end
    end 
    
end

-- verify that the blueprint has wreckage that appears when unit dies
function VerifyWreckage(bp)
    -- skipping pre-enhanced units since they are the same as base units
    if bp.CategoriesHash.ISPREENHANCEDUNIT then return end
    
    -- skipping units without any wreckages
    if bp.CategoriesHash.COMMAND or bp.CategoriesHash.POD or BPA.IsUnitKamikaze(bp) then 
        return
    end

    if not bp.Wreckage then
        LogCorrection(Severity.LOW, bp, 'bp.Wreckage added with default values')
        -- TODO-HUSSAR remove setting of bp.Wreckage in Blueprints.lua since we are adding it here
        bp.Wreckage = {
            Blueprint = '/props/DefaultWreckage/DefaultWreckage_prop.bp',
            EnergyMult = 0, MassMult = 0.9, HealthMult = 0.9,
            ReclaimTimeMultiplier = 1,
            WreckageLayers = {
                Air = false, Land = false,
                Sub = true, Seabed = true, Water = true,
            },
        }
    end

    if IsMissing(bp.Wreckage.Blueprint) then
        LogIssue(Severity.LOW, bp, 'bp.Wreckage.Blueprint prop is missing')
    end

    -- a function for asserting a value of Wreckage Layer
    local function AssertWreckage(info, layerName, layerStatus)
        if bp.Wreckage.WreckageLayers[layerName] == nil then
            LogIssue(Severity.LOW, bp, 'bp WreckageLayers.' .. layerName .. ' is missing')
        elseif bp.Wreckage.WreckageLayers[layerName] ~= layerStatus then
            local msg = ' should be ' .. tostring(layerStatus) .. ' for ' .. info
            LogIssue(Severity.MIN, bp, 'bp WreckageLayers.' .. layerName .. msg)
        end
    end
    
    -- assuming wreckages cannot stay in air but they must fall to ground, sink to seabed, or float
    AssertWreckage('any blueprint', 'Air', false)

    local is = bp.CategoriesHash -- for simpler/shorter IF conditions
    if is.LAND and is.STRUCTURE then
        -- these settings ensure that Land structures can be re-built from their wreckages:
        AssertWreckage('LAND structure', 'Land', true)
        AssertWreckage('LAND structure', 'Sub', false)
        AssertWreckage('LAND structure', 'Seabed', false)
        AssertWreckage('LAND structure', 'Water', false)
    end

    if is.NAVAL and (is.STRUCTURE or BPA.IsUnitWithIntelSonarMobile(bp)) then
        -- these settings ensure that Naval structures can be re-built from their wreckages:
        AssertWreckage('NAVAL structure', 'Land', false)
        AssertWreckage('NAVAL structure', 'Sub', false)
        AssertWreckage('NAVAL structure', 'Seabed', false)
        AssertWreckage('NAVAL structure', 'Water', true) -- wreckage sinks on water
    end

    if is.NAVAL and is.MOBILE and not BPA.IsUnitWithIntelSonarMobile(bp) then
        AssertWreckage('NAVAL mobile','Seabed', true)
        AssertWreckage('NAVAL mobile','Water', true) -- wreckage sinks in water

        if bp.Physics.MotionType == 'RULEUMT_Amphibious' then
            AssertWreckage('NAVAL amphibious', 'Land', true)
            AssertWreckage('NAVAL amphibious', 'Sub', true)
        elseif bp.Physics.MotionType == 'RULEUMT_AmphibiousFloating' then
            AssertWreckage('NAVAL amphibious', 'Land', true)
--            AssertWreckage('NAVAL amphibious', 'Sub', true)
        else
            AssertWreckage('NAVAL mobile', 'Land', false)
            AssertWreckage('NAVAL mobile', 'Sub', true)
        end

--        if BPA.IsUnitAmphibious(bp) then
--            AssertWreckage('NAVAL amphibious', 'Land', true)
--            AssertWreckage('NAVAL amphibious', 'Sub', true)
--        else
--            AssertWreckage('NAVAL mobile', 'Land', false)
--            AssertWreckage('NAVAL mobile', 'Sub', true)
--        end
    end

    if is.MOBILE and is.AIR then 
        AssertWreckage('AIR mobile', 'Land', true)
        AssertWreckage('AIR mobile', 'Sub', true)
        AssertWreckage('AIR mobile', 'Seabed', true)
        AssertWreckage('AIR mobile', 'Water', true) -- wreckage sinks on impact with water
    end

    if is.MOBILE and is.LAND then
        if BPA.IsUnitMobileHover(bp) then
            AssertWreckage('LAND hover', 'Land', true)
            AssertWreckage('LAND hover', 'Sub', true)
            AssertWreckage('LAND hover', 'Seabed', true)
            AssertWreckage('LAND hover', 'Water', true) -- wreckage sinks in water
        elseif BPA.IsUnitMobileAmphibious(bp) then
            AssertWreckage('LAND amphibious', 'Land', true)
            AssertWreckage('LAND amphibious', 'Sub', true)
            AssertWreckage('LAND amphibious', 'Seabed', true)
            AssertWreckage('LAND amphibious', 'Water', true) -- wreckage sinks in water
        else
            AssertWreckage('LAND mobile', 'Land', true)
            AssertWreckage('LAND mobile', 'Sub', false)
            AssertWreckage('LAND mobile', 'Seabed', false)
            AssertWreckage('LAND mobile', 'Water', false)
        end
    end

end

function VerifyVeterancy(bp) 
    -- skip kamikaze units (Mercy and Fire Beetle) because they cannot vet
    if BPA.IsUnitKamikaze(bp) then return end

    -- copied from game.lua
    local veteranDefaults = {
        Level1 = 25,
        Level2 = 100,
        Level3 = 250,
        Level4 = 500,
        Level5 = 1000,
    }
    local weaponsCount = table.size(BPA.GetWeaponsWithOffense(bp, 1))
    local veteranLevels = table.size(bp.Veteran)

    -- assuming that only units with offensive weapons can gain veterancy/experience
    if weaponsCount > 0 then
        -- TODO-HUSSAR uncomment this code and remove VeteranDefault from game.lua
        -- bp.Veteran = veteranDefaults
        -- LogCorrection(Severity.LOW, bp, 'Set bp.Veteran to default values')
        
        -- TODO-HUSSAR instead of reporting these issues:
        if veteranLevels == 0 then
            LogIssue(Severity.LOW, bp, 'bp.Veteran table is missing')
        elseif veteranLevels < 5 then
            LogIssue(Severity.LOW, bp, 'bp.Veteran table has less than 5 levels')
        end
    end
end

function VerifyWeapons(bp)
    -- skipping pre-enhanced units since they are the same as base units
    if bp.CategoriesHash.ISPREENHANCEDUNIT then return end

    for wid, weapon in bp.Weapon or {} do
        -- checking weapons only with damage and skipping dummy weapons
        if BPA.IsWeaponValid(weapon) then -- BPA.GetWeaponDamage(weapon) > 0 then
            local info = 'bp.Weapon['.. wid.. ']'
            local rc = weapon.RangeCategory
            RegisterValue(rc, 'bp.Weapon.RangeCategory')

            if IsMissing(rc) then 
               LogIssue(Severity.HIGH, bp, info .. '.RangeCategory is missing')
            elseif not ValidEnums.Weapon.RangeCategories[rc] then   
                LogIssue(Severity.HIGH, bp, info .. '.RangeCategory has invalid ' .. Quote(rc) .. ' value')
            end

            local wc = weapon.WeaponCategory
            RegisterValue(wc, 'bp.Weapon.WeaponCategory') 
            if IsMissing(wc) then 
               LogIssue(Severity.HIGH, bp, info .. '.WeaponCategory is missing')
            elseif not ValidEnums.Weapon.WeaponCategories[wc] then   
                LogIssue(Severity.HIGH, bp, info .. '.WeaponCategory is invalid ' .. Quote(wc))
            elseif not wc == 'Defense' then
                if not weapon.TargetPriorities then
                   LogIssue(Severity.HIGH, bp, info .. '.TargetPriorities is missing')
                elseif table.empty(weapon.TargetPriorities) then
                   LogIssue(Severity.HIGH, bp, info .. '.TargetPriorities is empty')
                end
            end

            local dt = weapon.DamageType
            RegisterValue(dt, 'bp.Weapon.DamageType') 
            if IsMissing(dt) then 
               LogIssue(Severity.HIGH, bp, info .. '.DamageType is missing')
            elseif not ValidEnums.Weapon.DamageTypes[dt] then    
                LogIssue(Severity.HIGH, bp, info .. '.DamageType has invalid ' .. Quote(dt) .. ' value')
            end
            

            if not BPA.IsWeaponTorpedo(weapon) and 
               not BPA.IsWeaponTorpedoDefense(weapon) and
               not BPA.IsWeaponWithStunEffect(weapon) then
                if table.empty(weapon.Audio) then
                    LogIssue(Severity.LOW, bp, info .. '.Audio table is missing')
                else
                     for name, sound in weapon.Audio do
                         if type(name) ~= 'string' then
                            LogIssue(Severity.LOW, bp, info .. '.Audio.'..name..' must be a string')
                         end
                         local cue, bank = GetCueBank(sound)
                         if not cue then 
                            LogIssue(Severity.LOW, bp, info .. '.Audio.'..name..' has unknown cue')
                         elseif not bank then 
                            LogIssue(Severity.LOW, bp, info .. '.Audio.'..name..' has unknown bank')
                         end
                     end
                end
            end
        end
    end
end

-- this table defines rules for verifying most of values of bp.Categories table
-- however the following categories have different verification methods:
-- TECH* categories are checked in VerifyCategoriesWithTech()
-- SIZE* categories are checked in VerifyCategoriesWithSize()
-- SORT* categories are checked in VerifyCategoriesWithSort()
local CategoryRules = {
    { 
        Name = 'Commands', -- specifies a name for the rule
        Severity = Severity.HIGH, -- specifies severity of this rule when bp has categories but do not match Conditions
        Active = true, -- specifies whether or not to activate a rule in verification process
        AutoCorrect = false, -- specifies whether to auto-inserts missing categories from the Conditions table
        -- this table defines categories and functions that check if a blueprint should have those categories
        Conditions = {
--            CAPTURE = function(bp) return BPA.IsUnitWithCommandCapture(bp) end,
--            RECLAIM = function(bp) return BPA.IsUnitWithCommandReclaim(bp) end,
--            REPAIR  = function(bp) return BPA.IsUnitWithCommandRepair(bp) end,
        }
    },
    { 
        Name = 'Engineering', Active = true, AutoCorrect = false,
        Severity = Severity.HIGH,
        Conditions = {
--            FACTORY = function(bp) return BPA.IsUnitWithFactorySuite(bp) end,
--            ENGINEER = function(bp) return BPA.IsUnitWithEngineeringSuite(bp) end,
--            CONSTRUCTION = function(bp) return BPA.IsUnitWithConstructionSuite(bp) end,
--            ENGINEERSTATION = function(bp) return BPA.IsUnitWithEngineeringStation(bp) end,
--            STATIONASSISTPOD = function(bp) return BPA.IsUnitWithAssistingDroneOrStation(bp) end,
--            POD = function(bp) return BPA.IsUnitWithEngineeringDrone(bp) end,
--            DRAGBUILD = function(bp) return BPA.IsUnitBuildByDraggingMouse(bp) end,
--            SHOWQUEUE = function(bp) return BPA.IsUnitWithBuildingQueue(bp) end,
--            RALLYPOINT = function(bp) return BPA.IsUnitWithFactoryRallyPoint(bp) end,
--            RESEARCH = function(bp) return BPA.IsUnitWithFactoryHQ(bp) end,
--            SUPPORTFACTORY = function(bp) return BPA.IsUnitWithFactorySupport(bp) end,
--            ORBITALSYSTEM = function(bp) return BPA.IsUnitWithFactorySatellite(bp) end,
        }
    }, 
    { 
        Name = 'Economy', Active = false, AutoCorrect = false,
        Severity = Severity.HIGH,
        Conditions = {
            ENERGYPRODUCTION = function(bp) return BPA.IsUnitWithEnergyProdution(bp) end,
            ENERGYSTORAGE    = function(bp) return BPA.IsUnitWithEnergyStorage(bp) and not BPA.IsUnitWithFactorySuite(bp) end,
            ECONOMIC         = function(bp) return BPA.IsUnitWithBonusEconomic(bp) end,
            MASSPRODUCTION   = function(bp) return BPA.IsUnitWithMassProdution(bp) end,
            MASSFABRICATION  = function(bp) return BPA.IsUnitWithMassFabrication(bp) end,
            MASSEXTRACTION   = function(bp) return BPA.IsUnitWithMassExtraction(bp) end,
            MASSSTORAGE      = function(bp) return BPA.IsUnitWithMassStorage(bp) and not BPA.IsUnitWithFactorySuite(bp) end,
            HYDROCARBON      = function(bp) return BPA.IsUnitBuildOnDepositHydro(bp) end,
        },
    },
    { 
        Name = 'FactionNames', Active = true, AutoCorrect = false,
        Severity = Severity.HIGH,
        Conditions = {
            AEON      = function(bp) return BPA.GetUnitFactionName(bp) == 'AEON' end,
            UEF       = function(bp) return BPA.GetUnitFactionName(bp) == 'UEF' end,
            CYBRAN    = function(bp) return BPA.GetUnitFactionName(bp) == 'CYBRAN' end,
            SERAPHIM  = function(bp) return BPA.GetUnitFactionName(bp) == 'SERAPHIM' end,
            NOMADS    = function(bp) return BPA.GetUnitFactionName(bp) == 'NOMADS' end,
        }
    },
    { 
        Name = 'PhysicsMotion', Active = true, AutoCorrect = false,
        Severity = Severity.HIGH,
        Conditions = {
            --STRUCTURE   = BPA.IsUnitStructure,--(bp)
            STRUCTURE   = function(bp) return BPA.IsUnitStructure(bp) end,
            LAND        = function(bp) return BPA.IsUnitTypeLand(bp) end,
            NAVAL       = function(bp) return BPA.IsUnitTypeNaval(bp) end,
            AIR         = function(bp) return BPA.IsUnitTypeAir(bp) end,
            SUBMERSIBLE = function(bp) return BPA.IsUnitSubmersible(bp) end,
            SATELLITE   = function(bp) return BPA.IsUnitMobileOrbital(bp) end,
            HOVER       = function(bp) return BPA.IsUnitMobileHover(bp) end,
            MOBILE      = function(bp) return BPA.IsUnitMobile(bp) end,
            T1SUBMARINE = function(bp) return BPA.IsUnitMobileSub(bp) and bp.CategoriesHash.TECH1 end,
            T2SUBMARINE = function(bp) return BPA.IsUnitMobileSub(bp) and bp.CategoriesHash.TECH2 end,
        }
    },
    { 
        Name = 'Transport', Active = true, AutoCorrect = false,
        Severity = Severity.HIGH,
        Conditions = {
            CARRIER = function(bp) return BPA.IsUnitTransportingInside(bp) end,
            NAVALCARRIER = function(bp) return BPA.IsUnitTransportingBySea(bp) end,
            TRANSPORTATION = function(bp) return BPA.IsUnitTransportingByAir(bp) end,
            AIRSTAGINGPLATFORM = function(bp) return BPA.IsUnitWithAirStaging(bp) end,
        }
    }, 
    {
        Name = 'Defense', Active = true, AutoCorrect = false,
        Severity = Severity.LOW,
        Conditions = { 
--            SHIELD = function(bp) return BPA.IsUnitWithShield(bp) end,
--            DEFENSE = function(bp) return BPA.IsUnitDefensive(bp) end, 
--            DEFENSIVEBOAT = function(bp) return BPA.IsUnitMobileNaval(bp) and BPA.IsUnitDefensive(bp) end,
        }
    },
    {
        Name = 'Weapons', Active = true, AutoCorrect = false,
        Severity = Severity.HIGH,
        Conditions = { 
--        NUKE = function(bp) return BPA.GetWeaponsWithSML(bp) and not bp.CategoriesHash.COMMAND end,
--        NUKESUB = function(bp) return BPA.GetWeaponsWithSML(bp) and BPA.IsUnitMobileSub(bp) end,
--        BOMBER = function(bp) return BPA.GetWeaponsWithBombs(bp) end,
--        GROUNDATTACK = function(bp) return BPA.GetWeaponsWithGunship(bp) end,
--        TACTICALMISSILEPLATFORM = function(bp) return BPA.IsUnitWithTacticalPlatform(bp) end,
--          SNIPER = function(bp) return BPA.GetWeaponsWithSniperDamage(bp) end,
--        SILO = function(bp) return BPA.GetWeaponsWithSiloStorage(bp) end,
--         DIRECTFIRE = function(bp) return BPA.GetWeaponsWithDirectFire(bp) end,
--       INDIRECTFIRE = function(bp) return BPA.GetWeaponsWithRange(bp, 'UWRC_IndirectFire') end,
--        ARTILLERY = function(bp) return BPA.GetWeaponsWithArtillery(bp) end,
--      ANTINAVY = function(bp) return BPA.GetWeaponsWithTorpedoes(bp) end,
--        ANTIAIR = function(bp) return BPA.GetWeaponsWithAntiAir(bp) end, 
--       ANTIMISSILE = function(bp) return BPA.IsUnitWithTacticalDefense(bp) end,
        }
    },
    { 
        Name = 'Intel', Active = true, AutoCorrect = false,
        Severity = Severity.LOW,
        Conditions = {
            --SCOUT = function(bp) return BPA.IsUnitWithIntelScout(bp) end,
            --OMNI = function(bp) return BPA.IsUnitWithIntelOmni(bp) end,
            --RADAR = function(bp) return BPA.IsUnitWithIntelRadar(bp) end,
            --OPTICS = function(bp) return BPA.IsUnitWithIntelOpticVision(bp) end,
            --SONAR = function(bp) return BPA.IsUnitWithIntelSonar(bp) end,
            --MOBILESONAR = function(bp) return BPA.IsUnitWithIntelSonarMobile(bp) end,
            --COUNTERINTELLIGENCE = function(bp) return BPA.IsUnitWithIntelCounter(bp) end,
            --INTELLIGENCE = function(bp) return BPA.IsUnitWithIntelSensor(bp) end,
        }
    },
    {   -- this rule safely assumes that above Intel conditions were auto corrected and added if missing to blueprints
        Name = 'Overlays', Active = true, AutoCorrect = false, 
        Severity = Severity.MIN,
        Conditions = {
--            OVERLAYDIRECTFIRE = function(bp) return bp.CategoriesHash.DIRECTFIRE end,
--            OVERLAYINDIRECTFIRE = function(bp) return bp.CategoriesHash.INDIRECTFIRE end,
--            OVERLAYANTIAIR = function(bp) return bp.CategoriesHash.ANTIAIR == true end,
--            OVERLAYANTINAVY = function(bp) return bp.CategoriesHash.ANTINAVY end,
--            OVERLAYRADAR = function(bp) return bp.CategoriesHash.RADAR end,
--            OVERLAYSONAR = function(bp) return bp.CategoriesHash.SONAR end,
--            OVERLAYOMNI = function(bp) return bp.CategoriesHash.OMNI end,
--            OVERLAYDEFENSE = function(bp) return bp.CategoriesHash.DEFENSE end,
--            OVERLAYCOUNTERINTEL = function(bp) return bp.CategoriesHash.COUNTERINTELLIGENCE end,
        },
    }
}

-- verify a blueprint for SIZE categories, e.g. SIZE6, SIZE8, SIZE10, SIZE12, etc.
function VerifyCategoriesWithSize(bp, logChanges)
    if not BPA.IsUnitStructure(bp) then return end
    if BPA.IsUnitCrabEgg(bp) then return end

    local sizeCategories = BPA.GetUnitCategoriesWith(bp, 'SIZE')
    local sizeCount = table.size(sizeCategories)
    if sizeCount > 1 then
        LogIssue(Severity.LOW, bp, 'bp.Categories has too many SIZE categories ' .. table.concat(sizeCategories, ', ')) 
        return
    end

    -- all SIZE categories should equal to double of math.min(bp.Physics.SkirtSizeX, bp.Physics.SkirtSizeZ) 
    local ruleConditions = {
        SIZE24 = function(bp) return BPA.GetUnitPhysicsSize(bp) == 12 end,
        SIZE20 = function(bp) return BPA.GetUnitPhysicsSize(bp) == 10 end,
        SIZE16 = function(bp) return BPA.GetUnitPhysicsSize(bp) == 8 end,
        SIZE12 = function(bp) return BPA.GetUnitPhysicsSize(bp) == 6 end,
        SIZE8  = function(bp) return BPA.GetUnitPhysicsSize(bp) == 4 end,
        SIZE6  = function(bp) return BPA.GetUnitPhysicsSize(bp) == 3 end,
        SIZE4  = function(bp) return BPA.GetUnitPhysicsSize(bp) == 2 end,
      --SIZE2  = function(bp) return BPA.GetUnitPhysicsSize(bp) == 1 end,
    }

    for category, isMatching in ruleConditions do 

        if isMatching(bp) then
            if bp.CategoriesHash[category] then
                table.insert(logChanges.matched, category)
            else
                if sizeCount == 0 then
                    --table.insert(logChanges.added, category)
                    local msg = 'bp.Categories is missing ' .. Quote(category) .. ' in ' .. currentBp
                    LogIssue(Severity.HIGH, nil, msg) 
                end
            end
        elseif bp.CategoriesHash[category] then
            local actualSize = BPA.GetUnitPhysicsSize(bp) 
            local expectCategory = 'SIZE' .. (actualSize * 2)
            local msg = 'bp.Categories has ' .. Quote(category) .. ' instead of ' .. Quote(expectCategory) .. ' in ' .. currentBp
            msg = msg .. 'because bp.Physics.SkirtSize (' .. actualSize.. ') * 2 = '.. expectCategory .. ' category'
            LogIssue(Severity.HIGH, nil, msg) 
            -- TODO-HUSSAR decide if SIZE categories should be auto-corrected 
            -- with below code instead of logged as an issue (above):
            -- LogCategoryRemoved(Severity.LOW, bp, category, logChanges)
            -- LogCategoryAdded(Severity.LOW, bp, expectCategory, logChanges)
        end 
    end

end

-- verify a blueprint for only one SORT* category that is use to
-- group/place similar blueprints next to each other in the construction menu
function VerifyCategoriesWithSort(bp, logChanges)

    local isBuildable = BPA.IsUnitBuildable(bp)
    local isBuiltByFactory = BPA.IsUnitBuildByFactory(bp)
    
    local is = bp.CategoriesHash
    -- some units do not require checking for SORT* categories:
    if is.COMMAND then return end
    if is.SUBCOMMANDER then return end
    if is.EXPERIMENTAL then return end
    if is.POD then return end
    if is.MOBILE and isBuiltByFactory then return end
    if BPA.IsUnitCrabEgg(bp) then return end

    -- check if the blueprint has any SORT* categories
    local sortCategories = BPA.GetUnitCategoriesWith(bp, 'SORT')
    local sortCategoriesStr = table.concat(sortCategories, ', ')
    local sortCount = table.size(sortCategories)
    
    -- check if the blueprint has some known categories
    local isMassEco = is.MASSEXTRACTION or is.MASSSTORAGE or is.MASSFABRICATION
    local isEngyEco = is.ENERGYPRODUCTION or is.ENERGYSTORAGE 
    local isStrategic = is.STRATEGIC or is.SILO or is.ARTILLERY or is.GATE or is.MINE or
                        is.TACTICALMISSILEPLATFORM or is.AIRSTAGINGPLATFORM
    local isDefense = is.WALL or is.DEFENSE or is.DIRECTFIRE or is.INDIRECTFIRE or 
                      is.AIR or is.ANTIAIR or is.ANTINAVY or is.ANTISUB or is.ANTIMISSILE
    local isIntel = is.ANTITELEPORT or is.OPTICS or is.SONAR or is.OMNI or 
                    is.RADAR or is.INTELLIGENCE or is.COUNTERINTELLIGENCE
    
    -- a function for asserting a category in bp.Categories
    local function AssertCategory(category)
        if sortCount == 0 then
            LogIssue(Severity.HIGH, bp, 'bp.Categories is missing '.. Quote(category))
        elseif not bp.CategoriesHash[category] then
            local wrongCategory = Quote(sortCategories[1])
            LogIssue(Severity.HIGH, bp, 'bp.Categories is missing ' .. Quote(category) .. ' instead of ' .. sortCategoriesStr)
        else
            table.insert(logChanges.matched, category)
        end
    end

    if sortCount > 1 then
        LogIssue(Severity.LOW, bp, 'bp.Categories has too many SORT* categories: ' .. sortCategoriesStr) 
    elseif (is.FACTORY or is.ENGINEERSTATION) and not is.GATE then
        AssertCategory("SORTCONSTRUCTION")
    elseif isBuiltByFactory and is.TRANSPORTATION and bp.ID ~= 'uea0203' then -- Stinger Gunship
        AssertCategory("SORTOTHER")
    elseif (isMassEco or isEngyEco) and not is.SUBCOMMANDER then
        AssertCategory("SORTECONOMY")
    elseif isStrategic and not is.ANTIMISSILE then
        AssertCategory("SORTSTRATEGIC")
    elseif isDefense then
        AssertCategory("SORTDEFENSE")
    elseif isIntel and not (is.SUBCOMMANDER or is.DRONE or is.CARRIER) then
        AssertCategory("SORTINTEL")
    elseif not isBuiltByFactory and is.MOBILE then
        AssertCategory("SORTOTHER")
    else 
        LogIssue(Severity.LOW, bp, 'bp.Categories has no SORT* category')
    end
end

local TechLevels = {
    TECH1 = 'RULEUTL_Basic',
    TECH2 = 'RULEUTL_Advanced',
    TECH3 = 'RULEUTL_Secret',
    EXPERIMENTAL = 'RULEUTL_Experimental',
}

-- verify a blueprint for TECH categories by matching with bp.General.TechLevel and vice versa
-- using the TechLevels lookup table defined above
function VerifyCategoriesWithTech(bp)

    if not IsValid(bp, 'General', 'TechLevel', ValidEnums.General.TechLevels) then
        return -- skip rest of verification
    end

    if not BPA.IsUnitBuildByEngineer(bp) and not BPA.IsUnitUpgradeLevel(bp) and
       not BPA.IsUnitBuildByFactory(bp) and not BPA.IsUnitCrabEgg(bp) and 
       not BPA.IsUnitCommander(bp) and not BPA.IsUnitWithEngineeringDrone(bp) and
       not BPA.IsUnitSatellite(bp) then
        LogIssue(Severity.CRITICAL, bp, 'bp.Categories is missing "BUILTBYTIER(#)(FACTORY or ENGINEER)"')
    end

    -- some units do not have tech level!
    if bp.CategoriesHash.COMMAND or bp.CategoriesHash.POD then return end
    
    -- check if multiple tech categories are set in the blueprint
    local techCategories = {}
    for tech, _ in ValidEnums.Categories.TechLevels do
        if bp.CategoriesHash[tech] then
            table.insert(techCategories, tech)
        end
    end
     
    local techCount = table.size(techCategories)
    if techCount == 0 then
        local msg = 'bp.Categories is missing TECH category'
        local fix = 'add one of these categories: ' .. table.concatkeys(ValidEnums.Categories.TechLevels, ', ')
        LogIssue(Severity.CRITICAL, bp, msg, fix)
    elseif techCount > 1 then
        local msg = 'bp.Categories has too many TECH categories'
        local fix = 'remove one of these categories: ' .. table.concat(techCategories, ', ')
        LogIssue(Severity.CRITICAL, bp, msg, fix)
    elseif techCount == 1 then
        local categoryTech = techCategories[1]
        local expectTech = TechLevels[categoryTech]
        local actualTech = bp.General.TechLevel or 'nil'
        
        local msg = 'bp.Categories has '.. Quote(categoryTech)

        if actualTech ~= expectTech then
            local fix = 'but bp.General.TechLevel is ' .. Quote(actualTech) .. ' instead of ' .. Quote(expectTech)
            --LogIssue(Severity.HIGH, bp, msg, fix)
        end
        
        -- some units do not have to match categoryTech with BUILTBY the same tech level
        if not bp.CategoriesHash.RESEARCH and -- HQ/Support factories
           not bp.CategoriesHash.ENGINEERSTATION and
           not BPA.IsUnitUpgradeLevel(bp) and
           not BPA.IsUnitCrabEgg(bp) then
           --not Categories.MINE

            if categoryTech == 'TECH1' and not BPA.IsUnitBuildByTech1(bp) then
                local fix = 'but it cannot be built by BUILTBYTIER1ENGINEER, BUILTBYTIER1FACTORY, or BUILTBYTIER1COMMANDER'
                LogIssue(Severity.CRITICAL, bp, msg, fix)
            elseif categoryTech == 'TECH2' and not BPA.IsUnitBuildByTech2(bp) then
                local fix = 'but it cannot be built by BUILTBYTIER2ENGINEER, BUILTBYTIER2FACTORY, or BUILTBYTIER2COMMANDER'
                LogIssue(Severity.CRITICAL, bp, msg, fix)
            elseif categoryTech == 'TECH3' and not BPA.IsUnitBuildByTech3(bp) then
                local fix = 'but it cannot be built by BUILTBYTIER3ENGINEER, BUILTBYTIER3FACTORY, BUILTBYTIER3COMMANDER, or BUILTBYQUANTUMGATE'
                LogIssue(Severity.CRITICAL, bp, msg, fix)
            elseif categoryTech == 'EXPERIMENTAL' and not BPA.IsUnitBuildByTech3(bp) then
                local fix = 'but it cannot be built by BUILTBYTIER3ENGINEER, BUILTBYTIER3FACTORY, BUILTBYTIER3COMMANDER, or BUILTBYQUANTUMGATE'
                LogIssue(Severity.CRITICAL, bp, msg, fix)
            end
        end 
    end
end

-- verify
function VerifyCategories(bp)
    -- skipping pre-enhanced units since they are the same as base units
    if bp.CategoriesHash.ISPREENHANCEDUNIT then return end
    
    RegisterValuesIn(bp.Categories, 'bp.Categories')

    bp.CategoriesHash = table.hash(bp.Categories)
    bp.CategoriesHash_CORRECTED = {}
    
    local logChanges = { added = {}, matched = {}, removed = {}, }

    -- some categories require more complex verification:
    VerifyCategoriesWithSort(bp, logChanges)
    --TODO-HUSSAR VerifyCategoriesWithSize(bp, logChanges)

    -- defining condition for extra categories
    local extraCategories = {
        T3SUBMARINE = function(bp) return BPA.IsUnitMobileSub(bp) and bp.CategoriesHash.TECH3 end,
        AMPHIBIOUS = function(bp) return BPA.IsUnitAmphibious(bp) end,
        CRABEGG = function(bp) return BPA.IsUnitCrabEgg(bp) end,
        VOLATILE = function(bp) return BPA.IsUnitVolatile(bp) end,
        MASSIVE = function(bp) return BPA.IsUnitMassive(bp) end,
        TECH4 = function(bp) return bp.CategoriesHash.EXPERIMENTAL end,
    }
    -- setting some extra categories to help filter units in the game
    for category, IsMatching in extraCategories do
        if IsMatching(bp) then
            LogCategoryAdded(Severity.NONE, bp, category, logChanges)
        end
    end

    -- loop over all categories rules and check if the blueprint matches conditions in the rule
    for _, rule in CategoryRules do
        for category, condition in rule.Conditions or {} do
            if not rule.Active then break end 

            rule.IsMatching = condition(bp)
            if rule.IsMatching then
                if bp.CategoriesHash[category] then
                    table.insert(logChanges.matched, category)
                else 
                    -- we found missing category in bp.Categories so we will resolve it
                    -- either by adding it or logging it as an issue
                    local msg = 'bp.Categories is missing ' .. Quote(category)
                    if rule.AutoCorrect then
                        LogCategoryAdded(Severity.LOW, bp, category, logChanges)
                    elseif rule.Name == 'Weapons' then
                        local fix = 'because bp.Weapon has ' .. category .. ' weapon'
                        LogIssue(rule.Severity, bp, msg, fix) 
                    else
                        LogIssue(rule.Severity, bp, msg) 
                    end 
                end
            elseif bp.CategoriesHash[category] then
                   -- we found wrong category in bp.Categories so we will log it as an issue
                   -- with some additional info how to fix it
                   local msg = 'bp.Categories has ' .. Quote(category)
                   local fix = false
                   if rule.Name == 'FactionNames' then
                       local current = Quote(bp.General.FactionName)
                       if not bp.General.FactionName then
                           local expected = Quote(StringCapitalize( string.lower(category)))
                           fix = 'but bp.General.FactionName = ' .. current .. ' ... FIX: change it to ' .. expected
                       else 
                           local expected = string.upper(current)
                           fix = 'but bp.General.FactionName = ' .. current .. ' ... FIX: replace ' .. category .. ' with ' .. expected
                       end
                   elseif rule.Name == 'Economy' then
                       fix = 'but bp.Economy does not match it'
                   elseif rule.Name == 'Engineering' then
                       fix = 'but bp.Economy does not match it'
                   elseif rule.Name == 'Intel' then
                       fix = 'but bp.Intel does not match it'
                   elseif rule.Name == 'Transport' then
                       fix = 'but bp.Transport does not match it'
                   elseif rule.Name == 'PhysicsMotion' then
                       local motion = Quote(bp.Physics.MotionType)
                       fix = 'but bp.Physics.MotionType = ' .. string.gsub(motion, 'RULEUMT_', '')
                   elseif rule.Name == 'Weapons' then
                       fix = 'but bp.Weapon has no ' .. category .. ' weapons'
                   elseif rule.Name == 'Commands' then
                       fix = 'but bp.General is missing ' .. category .. ' command'
                   elseif rule.Name == 'Overlays' then
                       -- overlay categories must also have a category without the 'OVERLAY' prefix
                       -- for example, RADAR and RADAROVERLAY
                       local expected = string.gsub(category, 'OVERLAY', '')
                       expected = string.gsub(expected, 'COUNTERINTEL', 'COUNTERINTELLIGENCE')
                       expected = Quote(expected)
                       fix = 'but it is missing ' .. expected .. ' category'
                   else
                       fix = 'but ' .. rule.Name .. ' rule do not match it'
                   end

                   if msg then 
                       LogIssue(rule.Severity, bp, msg, fix)
                   end
            end
        end 
    end

    if Stats.Categories.logging then
        -- collect basic stats in non-debugging mode
        local countAdded = table.size(logChanges.added)
        local countMatched = table.size(logChanges.matched)
        local countRemoved = table.size(logChanges.removed)
        Stats.Categories.added = Stats.Categories.added + countAdded
        Stats.Categories.matched = Stats.Categories.matched + countMatched
        Stats.Categories.removed = Stats.Categories.removed + countRemoved
        -- collect more detailed stats when in debugging mode
        if Stats.Categories.debugging then
            logChanges.added   = countAdded > 0 and table.concat(logChanges.added, ', ') or nil
            logChanges.removed = countRemoved > 0 and table.concat(logChanges.removed, ', ') or nil
            logChanges.matched = countMatched > 0 and table.concat(logChanges.matched, ', ') or nil
            Stats.Categories.changes[bp.Source] = logChanges
        end
    end
     
    --TODO-HUSSAR apply changes in bp.CategoriesHash to bp.Categories
    --bp.Categories = table.unhash(bp.CategoriesHash)
end

LOG('BlueprintsVerifier.lua ... loaded')
