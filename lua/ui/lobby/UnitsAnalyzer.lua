-- ==========================================================================================
-- * File       : lua/modules/ui/lobby/UnitsAnalyzer.lua
-- * Authors    : FAF Community, HUSSAR
-- * Summary    : Provides logic on UI/lobby side for analyzing blueprints (Units, Structures, Enhancements)
-- *              using their IDs, CATEGORIES, TECH labels, FACTION affinity, etc.
-- *              Note this file is not used in by SIM to calculate any values.
-- ==========================================================================================

-- Some calculation based on this code
-- https://github.com/spooky/unitdb/blob/master/app/js/dps.js
-- TODO create tests based on https://github.com/spooky/unitdb/blob/master/test/spec/dps.js

-- Holds info about a blueprint that is being loaded
local bpInfo = { ID = nil , Source = nil, Note = ''}
local bpIndex = 1

local BPA = import('/lua/system/BlueprintsAnalyzer.lua')

local Cache = {
    -- enable to generate unit stats faster OR disable to always re-generate unit stats form blueprints
    -- NOTE this option should be disable when editing blueprints at runtime and you want to verify changes in UI
    IsEnabled = false,
    Images = {}, -- cache table with path to images
    Tooltips = {}, -- cache table with tooltips
    Enhancements = {}, -- cache table with enhancements
    Abilities = {}, -- cache table with a list of abilities for a given blueprint ID
}

-- Stores blueprints of units and extracted enhancements
-- Similar to Sim's __blueprints but accessible only in UnitsManager
local blueprints = { All = {}, Original = {}, Modified = {}, Skipped = {} }
local projectiles = { All = {}, Original = {}, Modified = {}, Skipped = {} }
 
 -- Manages logs messages based on their type/importance/source
local logsTypes = {
    ["WARNING"] = true,  -- Recommend to keep it always true
    ["CACHING"] = false, -- Enable only for debugging
    ["PARSING"] = false, -- Enable only for debugging
    ["DEBUG"] = false, -- Enable only for debugging
    ["STATUS"] = true,
}

function Show(msgType, msg)
    if not logsTypes[msgType] then return end

    msg = 'UnitsAnalyzer ' .. msg
    if msgType == 'WARNING' then
        WARN(msg)
    else
        LOG(msg)
    end
end

  


--TODO remove in UnitsTooltip.lua
-- Gets weapons stats in given blueprint, more accurate than in-game unitviewDetails.lua
function GetWeaponsStats(bp)
    local weapons = {}
    LOG('GetWeaponsStats')
    -- TODO fix bug: SCU weapons (rate, damage, range) are not updated with values from enhancements!
    -- TODO fix bug: SCU presets for SERA faction, have all weapons from all enhancements!
    -- Check bp.EnhancementPresetAssigned.Enhancements table to get accurate stats
    for id, w in bp.Weapon or {} do
        local damage = GetWeaponDamage(w)
        -- Skipping not important weapons, e.g. UEF shield boat fake weapon
        if w.WeaponCategory and
           w.WeaponCategory ~= 'Death' and
           w.WeaponCategory ~= 'Teleport' and
           damage > 0 then

           local weapon = GetSpecsForWeapons(bp, w, id)
           --weapon.DPSM = weapon.DPS / weapon.BuildCostMass * 100
           --weapon.DPSE = weapon.DPS / weapon.BuildCostEnergy * 100
           --weapon.Damage = math.round(weapon.Damage)
           weapons[id] = weapon
          
        end
    end

    -- Grouping weapons based on their name/category
    local groupWeapons = {}
    for i, weapon in weapons do
        local id = weapon.DisplayName .. '' .. weapon.Target
        if groupWeapons[id] then -- Count duplicated weapons
           groupWeapons[id].Count = groupWeapons[id].Count + 1
           groupWeapons[id].Damage = groupWeapons[id].Damage + weapon.Damage
           groupWeapons[id].DPS = groupWeapons[id].DPS + weapon.DPS
           --groupWeapons[id].DPSM = groupWeapons[id].DPSM + weapon.DPSM
        else
           groupWeapons[id] = table.deepcopy(weapon)
        end
    end

    -- Sort weapons by category (Defense weapons first)
    weapons = table.indexize(groupWeapons)
    table.sort(weapons, function(a, b)
        if a.WeaponCategory == 'Defense' and
           b.WeaponCategory ~= 'Defense' then
            return true
        elseif a.WeaponCategory ~= 'Defense' and
               b.WeaponCategory == 'Defense' then
            return false
        else
            return tostring(a.WeaponCategory) > tostring(b.WeaponCategory)
        end
    end)

    return weapons
end

--TODO remove in UnitsTooltip.lua
function GetWeaponsTotal(weapons)
    local total = {}
    total.Range = 100000
    total.Count = 0
    total.Damage = 0
    total.DPM = 0
    total.DPS = 0

    for i, weapon in weapons or {} do
        -- Including only important weapons
        if weapon.Category and
            weapon.Category ~= 'Death' and
            weapon.Category ~= 'Defense' and
            weapon.Category ~= 'Teleport' then
            total.Damage = total.Damage + weapon.Damage
            total.DPM = total.DPM + weapon.DPM
            total.DPS = total.DPS + weapon.DPS
            total.Count = total.Count + 1
            total.Range = math.min(total.Range, weapon.Range)
        end
    end

    total.Category = 'All Weapons'
    total.DisplayName = 'Total'
    total.Title = string.format("%s (%s)", total.DisplayName, total.Category)

    return total
end
 

function InitBlueprint(unitBp)
    local bp = {}
    
    if unitBp.cloned then
        bp = unitBp
    else
        -- copy unit blueprint to prevent changing its original values
        bp = table.deepcopy(unitBp)
        bp.cloned = true
    end
    bp.Economy = GetSpecsForEconomy(bp) 

end

 
--TODO remove
-- Creates basic tooltip for a given blueprint based on its categories, name, and source
function GetTooltip(bp)
    -- Create unique key for caching tooltips
    local key = bp.Source .. ' {' .. bp.Name .. '}'

    if Cache.IsEnable and Cache.Tooltips[key] then
        return Cache.Tooltips[key]
    end

    local tooltip = { fallback = '', body = '' }

    tooltip.text = LOCF(bp.Name)
    if bp.Tech then
        tooltip.text = bp.Tech .. ' ' .. tooltip.text
    end

    --for category, _ in bp.CategoriesHash or {} do
    --    if not CategoriesHidden[category] then
    --        tooltip.body = tooltip.body .. category .. ' \n'
    --    end
    --end

    if bp.Source then
        tooltip.body = tooltip.body .. ' \n BLUEPRINT: ' .. bp.Source .. ' \n'
    end

    if bp.ID then
        tooltip.body = tooltip.body .. ' \n ID: ' .. bp.ID .. ' \n'
    end

    if bp.ImagePath then
        tooltip.body = tooltip.body .. ' \n : ' .. bp.ImagePath .. ' \n'
    end

    if bp.Mod then
        tooltip.body = tooltip.body .. ' \n --------------------------------- '
        tooltip.body = tooltip.body .. ' \n MOD: ' .. bp.Mod.name
        tooltip.body = tooltip.body .. ' \n --------------------------------- '
    end

    tooltip.text = tooltip.text or ''
    tooltip.body = tooltip.body or ''
    -- Save tooltip for re-use
    Cache.Tooltips[key] = tooltip

    return tooltip
end

-- Cache enhancements as new blueprints with Categories, Faction from their parent (unit) blueprints
local function CacheEnhancement(key, bp, name, enh)
    enh.CategoriesHash = {}
    Cache.Enhancements[name] = true

    if blueprints.All[key].CategoriesHash then
        enh.CategoriesHash = blueprints.All[key].CategoriesHash
    end

    local commanderType = ''
    enh.CategoriesHash['UPGRADE'] = true
    if bp.CategoriesHash['COMMAND'] then
        commanderType = 'ACU'
        enh.CategoriesHash['COMMAND'] = true
    elseif bp.CategoriesHash['SUBCOMMANDER'] then
        commanderType = 'SCU'
        enh.CategoriesHash['SUBCOMMANDER'] = true
    end

    -- Create some extra categories used for ordering enhancements in UI
    if enh.Slot then
        local slot = string.upper(enh.Slot)
        if slot == 'LCH' then
            enh.Slot = 'LEFT'
        elseif slot == 'RCH' then
            enh.Slot = 'RIGHT'
        elseif slot == 'BACK' then
            enh.Slot = 'BACK'
        end
        enh.CategoriesHash['UPGRADE '..enh.Slot] = true
    end

    enh.ID = name
    enh.Key = key
    enh.Faction = bp.Faction
    enh.Source = bp.Source
    enh.SourceID = StringExtract(bp.Source, '/', '_unit.bp', true)

    enh.Name = enh.Name or name
    enh.Type = 'UPGRADE'
    enh.Tech = enh.Slot
    enh.Mod = bp.Mod

    enh.CategoriesHash[bp.Faction] = true
    enh.CategoriesHash[name] = true

    if bp.Mod then
        blueprints.Modified[key] = enh
    else
        blueprints.Original[key] = enh
    end

    blueprints.All[key] = enh
end

-- Cache projectile blueprints
local function CacheProjectile(bp)
    if not bp then return end

    local id = string.lower(bp.Source)
    bp.Info = bp.Source or ''
    Show('CACHING', bp.Info .. '...')

    -- Converting categories to hash table for quick lookup
    if  bp.Categories then
        bp.CategoriesHash = table.hash(bp.Categories)
    end

    if bp.Mod then
        projectiles.Modified[id] = bp
    else
        projectiles.Original[id] = bp
    end

    projectiles.All[id] = bp
end

-- Cache unit blueprints and extract their enhancements as new blueprints
local function CacheUnit(bp)
    if not bp then return end

    bp.ID = bp.BlueprintId
    bp.Info = bp.Source or ''
    Show('CACHING', bp.Info .. '...')

    local id = bp.ID

    -- Skip processing of invalid units
    if not BPA.IsUnitValid(bp, id) then
        blueprints.Skipped[id] = bp
        return
    end

    bp.Faction = BPA.GetUnitFactionName(bp)
    bp.Type = BPA.GetUnitType(bp)
    bp.Tech = BPA.GetUnitTechSymbol(bp)
    bp.Name = BPA.GetUnitName(bp)
    bp.Color = BPA.GetUnitFactionBackground(bp)

    if bp.Mod then
        blueprints.Modified[id] = bp
    else
        blueprints.Original[id] = bp
    end

    blueprints.All[id] = bp

    -- Extract and cache enhancements so they can be restricted individually
    for name, enh in bp.Enhancements or {} do
        -- Skip slots or 'removable' enhancements
        if name ~= 'Slots' and not string.find(name, 'Remove') then
            -- Some enhancements are shared between factions, e.g. Teleporter
            -- and other enhancements have different stats and icons
            -- depending on faction or whether they are for ACU or SCU
            -- so store each enhancement with unique key:
            local id = StringExtract(bp.Source, '/', '_unit.bp', true)
            local key = bp.Faction ..'_' .. id .. '_' .. name

            CacheEnhancement(key, bp, name, enh)
        end
    end
end

local mods = { Cached = {}, Active = {}, Changed = false }

-- Checks if game mods have changed between consecutive calls to this function
-- Thus returns whether or not blueprints need to be reloaded
function DidModsChanged()
    mods.All = import('/lua/mods.lua').GetGameMods()
    mods.Active = {}
    mods.Changed = false

    for _, mod in mods.All do
        mods.Active[mod.uid] = true
        if not mods.Cached[mod.uid] then
            mods.Changed = true
        end
    end
    mods.CachedCount = table.getsize(mods.Cached)
    mods.ActiveCount = table.getsize(mods.Active)

    if mods.CachedCount ~= mods.ActiveCount then
       mods.Changed = true
    end

    if mods.Changed then
        Show('STATUS', 'game mods changed from ' .. mods.CachedCount .. ' to ' .. mods.ActiveCount)
        mods.Cached = table.deepcopy(mods.Active)
    else
        Show('STATUS', 'game mods cached = ' .. mods.CachedCount)
    end
    mods.Active = nil

    return mods.Changed
end

local timer = CreateTimer()
-- Gets unit blueprints by loading them from the game and given active sim mods
function GetBlueprints(activeMods, skipGameFiles, taskNotifier)
    timer:Start('LoadBlueprints')

    blueprints.Loaded = false
    -- Load original FA blueprints only once
    local loadedGameFiles = table.getsize(blueprints.Original) > 0
    if loadedGameFiles then
         skipGameFiles = true
    end

    local state = 'LoadBlueprints...'
    Show('STATUS', state)

    if DidModsChanged() or not skipGameFiles then
        blueprints.All = table.deepcopy(blueprints.Original)
        blueprints.Modified = {}
        blueprints.Skipped = {}

        projectiles.All = table.deepcopy(projectiles.Original)
        projectiles.Modified = {}
        projectiles.Skipped = {}

        if taskNotifier then
            local filesCount = 0
            -- calculate total updates based on number of files that Blueprints.lua will load
            if not skipGameFiles then
                filesCount = filesCount + table.getsize(DiskFindFiles('/projectiles', '*_proj.bp'))
                filesCount = filesCount + table.getsize(DiskFindFiles('/units', '*_unit.bp'))
            end
            for i, mod in activeMods or {} do
                filesCount = filesCount + table.getsize(DiskFindFiles(mod.location, '*_proj.bp'))
                filesCount = filesCount + table.getsize(DiskFindFiles(mod.location, '*_unit.bp'))
            end
            taskNotifier.totalUpdates = filesCount
        end

        -- allows execution of LoadBlueprints()
        doscript '/lua/system/Blueprints.lua'

        -- Loading projectiles first so that they can be used by units
        local dir = {'/projectiles'}
        bps = LoadBlueprints('*_proj.bp', dir, activeMods, skipGameFiles, true, true, taskNotifier)
        for _, bp in bps.Projectile do
            CacheProjectile(bp)
        end

        -- Loading units second so that they can use projectiles
        dir = {'/units'}
        bps = LoadBlueprints('*_unit.bp', dir, activeMods, skipGameFiles, true, true, taskNotifier)
        for _, bp in bps.Unit do
            if not string.find(bp.Source,'proj_') then
                CacheUnit(bp)
            end
        end
        state = state .. ' loaded: '
    else
        state = state .. ' cached: '
    end
    info = state .. table.getsize(projectiles.All) .. ' total ('
    info = info .. table.getsize(projectiles.Original) .. ' original, '
    info = info .. table.getsize(projectiles.Modified) .. ' modified, and '
    info = info .. table.getsize(projectiles.Skipped) .. ' skipped) projectiles'
    Show('STATUS', info)

    info = state .. table.getsize(blueprints.All) .. ' total ('
    info = info .. table.getsize(blueprints.Original) .. ' original, '
    info = info .. table.getsize(blueprints.Modified) .. ' modified and '
    info = info .. table.getsize(blueprints.Skipped) .. ' skipped) units'
    Show('STATUS', info)
    Show('STATUS', state .. 'in ' .. timer:Stop('LoadBlueprints'))

    blueprints.Loaded = true

    return blueprints
end

-- Gets all unit blueprints that were previously fetched
function GetBlueprintsList()
    return blueprints
end

local fetchThread = nil
-- Fetch asynchronously all unit blueprints from the game and given active sim mods
function FetchBlueprints(activeMods, skipGameFiles, taskNotifier)
    local bps = {}

    StopBlueprints()

    fetchThread = ForkThread(function()
        Show('STATUS', 'FetchBlueprints...')
        timer:Start('FetchBlueprints')
        local start = CurrentTime()
        bps = GetBlueprints(activeMods, skipGameFiles, taskNotifier)
        -- check if blueprints loading  is complete
        while not blueprints.Loaded do
            Show('STATUS', 'FetchBlueprints... tick')
            WaitSeconds(0.1)
        end
        timer:Stop('FetchBlueprints', true)
        Show('STATUS', 'FetchBlueprints...done')
        fetchThread = nil
        -- notify UnitManager UI about complete blueprint loading
        if taskNotifier then
           taskNotifier:Complete()
        end
    end)
end
function StopBlueprints()
    if fetchThread then
        KillThread(fetchThread)
        fetchThread = nil
    end
end






 



