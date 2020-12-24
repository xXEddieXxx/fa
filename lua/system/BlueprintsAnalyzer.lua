
-- ==========================================================================================
-- * Authors: HUSSAR
-- * Summary: 
-- This module analyzes blueprints (Units, Structures, Enhancements) and calculates some statistics,
-- such as weapon's DPS, DPM (Damage per Mass cost). 
-- However, this module does not affect game mechanics because other modules and game engine is
-- responsible for running the game simulation. 

-- IMPORTANT!
-- Most functions do not use bp.Categories because this table is not always accurate.
-- However, these functions can be used to check if bp.Categories table is correctly set 
-- by evaluating values in other tables, e.g. AEON category if bp.General.FactionName == 'Aeon'

-- NOTE this module must be initialized by calling Init() and passing a table with all blueprints
-- otherwise calculating stats for projectile-based weapons will not be correct

-- Some functions take portion of a blueprint as argument, e.g. IsWeaponTML(bp.Weapon[1])
-- Most functions take a blueprint table as argument, e.g. 
-- bp = __blueprints['UEA0003']
-- IsUnitDrone(bp)

-- Some calculations were based on this code https://github.com/spooky/unitdb/blob/master/app/js/dps.js
-- However, these function were greatly improved for accuracy of DPS based on actual game simulation.

-- ==========================================================================================

LOG('BlueprintsAnalyzer.lua ... ')

local Cache = {
    -- enable to generate unit stats faster OR disable to always re-generate unit stats form blueprints
    -- NOTE this option should be disable when editing blueprints at runtime and you want to verify changes in UI
    IsEnabled = false,
    Images = {}, -- cache table with path to images
    Tooltips = {}, -- cache table with tooltips
    Enhancements = {}, -- cache table with enhancements
    Abilities = {}, -- cache table with a list of abilities for a given blueprint ID
}
 -- Manages logs messages based on their type/importance/source
local logsTypes = {
    ["WARNING"] = true,  -- Recommend to keep it always true
    ["CACHING"] = false, -- Enable only for debugging
    ["PARSING"] = false, -- Enable only for debugging
    ["DEBUG"] = false, -- Enable only for debugging
    ["STATUS"] = true,
}

local Blueprints = { 
    Initialized = false,  
    Projectiles = {},
    Units = {}, 
}

local ValidBots = { -- used in IsUnitMobileBot()
    xsl0101 = true, dalk003 = true, xel0305 = true, xrl0305 = true,
}

-- Blueprints with these categories will be always loaded
-- even when they have other categories Skipped
local AllowCategories  = {
    ["SATELLITE"] = true, -- SATELLITEs are also UNTARGETABLE!
}

-- Blueprints with these categories will not be analyzed
-- unless other categories are allowed in the CategoriesAllowed table
local SkipCategories  = {
    "HOLOGRAM", "FERRYBEACON", "UNSELECTABLE",
    "CIVILIAN", "NOFORMATION", "UNTARGETABLE",
    "OPERATION",
}
SkipCategories = table.hash(SkipCategories)
 
-- Blueprints with these IDs will not be analyzed
local SkipBlueprints = {
    -- Gateway Beacon blueprints:
    "uab5103", "ueb5103", "urb5103", "ueb5208",
    -- Transport Beacon blueprints:
    "uab5102", "ueb5102", "urb5102", "xsb5102",
    -- Wall Segment Extra blueprints:
    "xec9001", "xec9002", "xec9003", "xec9002", "xec9004", 
    "xec9005", "xec9006", "xec9007", "xec9008", "xec9009", 
    "xec9009", "xec9009", "xec9010", "xec9011", 
    -- Concrete blueprints:
    "uab5204", "ueb5204", "urb5204", 
    -- Crystal blueprints:
    "xsc9010", "xsc9011", 
    "urb5206", -- Tracking Device
    "urb3103", -- Scout-Deployed Land Sensor
    "uxl0021", -- Test Unit Arc Projectile
    "ura0001", -- Build Bot Effect"
    -- unspecified blueprints:
    "brmgrnd1", "brmgrnd2", "brpgrnd1", "brpgrnd2",
    "brngrnd1", "brngrnd2", "brogrnd1", "brogrnd2",
    "xsl0402" -- SERA T4 Bolt Lighting
}
SkipBlueprints = table.hash(SkipBlueprints)

function Init(allBlueprints)
 
    -- blueprints are duplicated in the __blueprints table because
    -- they are stored by index and by Unique ID (units) or bp.Source (projectiles)
    -- we need only those with UID and bp.Source to look them up later
    for id, bp in allBlueprints or {} do 
        
        -- skip blueprints stored by index
        local hasUID = not tonumber(id) 
        
        if hasUID and bp.SourceType == 'Projectile' then
            Blueprints.Projectiles[id] = bp
        elseif hasUID and bp.SourceType == 'Unit' and IsUnitValid(bp, id) then
            bp.Info = bp.Source and bp.Source or ''
            --bp.ID = bp.BlueprintId
            bp.Faction = GetUnitFactionName(bp)
            bp.Type = GetUnitType(bp)
            bp.Tech = GetUnitTechSymbol(bp)
            bp.Name = GetUnitName(bp)
            bp.Color = GetUnitFactionBackground(bp)
            Blueprints.Units[id] = bp 
        end 
    end

    LOG('SetBlueprints Units='.. table.size(Blueprints.Units).. ' Projectiles=' .. table.size(Blueprints.Projectiles))
   -- table.print(invalidUnits, 'invalidUnits')

    if table.size(Blueprints.Units) > 0 and 
       table.size(Blueprints.Projectiles) > 0 then
       Blueprints.Initialized = true
    else
       Blueprints.Initialized = false
    end
     

    --BV.Verify(Blueprints.Units)
   -- Printer.OutputCsv(Blueprints.Units)
end

-- checks if a blueprint is of projectile type
function IsProjectile(bp)
    return bp.SourceType == 'Projectile'
end

-- checks if a blueprint is of unit type
function IsUnit(bp)
    return bp.SourceType == 'Unit'
end

--function IsUnitBuildable(bp)
--    return not bp.CategoriesHash.COMMAND
--       and not bp.CategoriesHash.POD
--end

function IsUnitBuildable(bp)
    for _, category in bp.Categories or {} do
        if string.find(category, 'BUILTBY') then
            return true
        end
    end
    if IsUnitCrabEgg(bp) or 
      -- IsUnitUpgradeLevel(bp) or 
       IsUnitSatellite(bp) then
       return true
    end
    return false
end

function IsUnitBuildByFactory(bp)
    local is = bp.CategoriesHash
    -- checking for standard Tier 1-3 Factory as well as some modded Tier 4 Factories
    return IsUnitBuildByFactoryTech(1, bp) or IsUnitBuildByFactoryTech(2, bp) or
           IsUnitBuildByFactoryTech(3, bp) or IsUnitBuildByFactoryTech(4, bp) or
           is.BUILTBYRIFTGATE or is.BUILTBYARTEMIS -- or is.BUILTBYQUANTUMGATE
end

function IsUnitBuildByFactoryTech(level, bp)
    local is = bp.CategoriesHash
    return is['BUILTBYTIER' .. level .. 'FACTORY'] or 
           is['BUILTBYLANDTIER' .. level .. 'FACTORY'] or 
           is['BUILTBYTIER' .. level .. 'ORBITALFACTORY'] or 
           is['TRANSPORTBUILTBYTIER' .. level .. 'FACTORY']
end

function IsUnitBuildOnDepositMass(bp)
    return bp.Physics and 
           bp.Physics.BuildRestriction == 'RULEUBR_OnMassDeposit'
end

function IsUnitBuildOnDepositHydro(bp)
    return bp.Physics and 
           bp.Physics.BuildRestriction == 'RULEUBR_OnHydrocarbonDeposit'
end

function IsUnitBuildOnDeposit(bp)
    return IsUnitBuildOnDepositMass(bp) or 
           IsUnitBuildOnDepositHydro(bp)
end

-- checks if unit's blueprint is built on Air, Land, Water, Sub, Seabed, or Orbit layer
function IsUnitBuildOnLayer(bp, layerName)
    -- using BuildOnLayerHash lookup table generated in Blueprints.lua
    -- because BuildOnLayerHash holds all enabled/disabled layers
    -- while BuildOnLayerCaps holds only enabled layers that
    -- are converted to number (if multiple layers) or a string (if single layer)
    return bp.Physics and 
           bp.Physics.BuildOnLayerHash and 
           bp.Physics.BuildOnLayerHash[layerName]
end

-- checks if unit can build by dragging mouse
-- note that this excludes intermediate building upgrades 
-- that cannot be build by engineers
function IsUnitBuildByDraggingMouse(bp)
    if IsUnitBuildOnDeposit(bp) then return false end
    return bp.CategoriesHash.RESEARCH or
           IsUnitCrabEgg(bp) or
           IsUnitWithEngineeringStation(bp) or
           IsUnitBuildByEngineer(bp)
end

function IsUnitBuildByTech1(bp)
    if not bp.CategoriesHash then return false end
    return bp.CategoriesHash.BUILTBYTIER1ENGINEER or 
           bp.CategoriesHash.BUILTBYTIER1FACTORY or 
           bp.CategoriesHash.BUILTBYTIER1COMMANDER or 
           bp.CategoriesHash.BUILTBYTIER1ORBITALFACTORY or 
           bp.CategoriesHash.BUILTBYLANDTIER1FACTORY or 
           bp.CategoriesHash.TRANSPORTBUILTBYTIER1FACTORY or 
           bp.CategoriesHash.BUILTBYARTEMIS
end

function IsUnitBuildByTech2(bp)
    if not bp.CategoriesHash then return false end
    return bp.CategoriesHash.BUILTBYTIER2ENGINEER or 
           bp.CategoriesHash.BUILTBYTIER2FACTORY or 
           bp.CategoriesHash.BUILTBYTIER2COMMANDER or 
           bp.CategoriesHash.BUILTBYTIER2ORBITALFACTORY or 
           bp.CategoriesHash.BUILTBYLANDTIER2FACTORY or 
           bp.CategoriesHash.TRANSPORTBUILTBYTIER2FACTORY
end

function IsUnitBuildByTech3(bp)
    if not bp.CategoriesHash then return false end
    return bp.CategoriesHash.BUILTBYTIER3ENGINEER or 
           bp.CategoriesHash.BUILTBYTIER3FACTORY or 
           bp.CategoriesHash.BUILTBYTIER3COMMANDER or 
           bp.CategoriesHash.BUILTBYTIER3ORBITALFACTORY or 
           bp.CategoriesHash.BUILTBYLANDTIER3FACTORY or 
           bp.CategoriesHash.TRANSPORTBUILTBYTIER3FACTORY or 
           bp.CategoriesHash.BUILTBYQUANTUMGATE or 
           bp.CategoriesHash.BUILTBYRIFTGATE or 
           bp.CategoriesHash.SATELLITE
end

function IsUnitBuildByCommander(bp)
    if not bp.CategoriesHash then return false end
    return bp.CategoriesHash.BUILTBYTIER1COMMANDER or  
           bp.CategoriesHash.BUILTBYTIER2COMMANDER or 
           bp.CategoriesHash.BUILTBYTIER3COMMANDER or 
           bp.CategoriesHash.BUILTBYTIER4COMMANDER -- for some mods
end

--function IsUnitBuildByEngineer(bp)
--    if not bp.CategoriesHash then return false end
--    return bp.CategoriesHash.BUILTBYTIER1ENGINEER or  
--           bp.CategoriesHash.BUILTBYTIER2ENGINEER or 
--           bp.CategoriesHash.BUILTBYTIER3ENGINEER
--end

function IsUnitBuildByEngineer(bp)
    local is = bp.CategoriesHash
    -- checking for standard Tier 1-3 Engineers as well as some modded Tier 4 Engineers
    return is.BUILTBYTIER1COMMANDER or is.BUILTBYTIER1ENGINEER or 
           is.BUILTBYTIER2COMMANDER or is.BUILTBYTIER2ENGINEER or 
           is.BUILTBYTIER3COMMANDER or is.BUILTBYTIER3ENGINEER or 
           is.BUILTBYTIER4COMMANDER or is.BUILTBYTIER4ENGINEER or 
           is.BUILTBYCOMMANDER
end

function IsUnitSatellite(bp)
    return bp.CategoriesHash.SATELLITE
end

function IsUnitDrone(bp)
    return bp.CategoriesHash.POD and IsUnitMobileAir(bp)
end

function IsUnitCommander(bp)
    return bp.CategoriesHash.COMMAND or
           bp.CategoriesHash.SUBCOMMANDER
end

-- checks it unit's blueprint can transform to single unit, e.g. crab egg
function IsUnitCrabEgg(bp)
    return bp.Economy and bp.Economy.BuildUnit
end


function IsUnitKamikaze(bp)
    local weapons = GetWeaponsWithCategory(bp, 'Kamikaze')
    return table.size(weapons) > 0
end

function IsUnitDefensive(bp)
    if IsUnitStructure(bp) then
       return bp.General.Category == 'Defense'
    end
    
    if bp.General.Classification == 'RULEUC_Sensor' then
        return false
    end

    if  IsUnitMobileNaval(bp) and IsUnitWithStealthField(bp) then
        return true
    end

    if IsUnitMobileNaval(bp) or IsUnitMobileLand(bp) then 
        --local dmgWeapons = table.size(GetWeaponsWithDamage(bp))
        local offWeapons = table.size(GetWeaponsWithOffense(bp))
        local defWeapons = table.size(GetWeaponsWithDefense(bp)) 
         
        -- check for offensive weapons
        if offWeapons > 0 then 
            return false 
        end

        return defWeapons > 0 or IsUnitWithShield(bp) 
         
--        for _, w in weapons or {} do
--            if not IsWeaponDefensive(w) then
--                return false
--            end 
--        end
--        if IsUnitWithShield(bp) then
--            return true
--        end
        --return true
    end
    return false
end

function IsUnitNotCapturable(bp)
    return bp.CategoriesHash.COMMAND or 
           bp.CategoriesHash.SUBCOMMANDER or 
           bp.ID == 'uaa0310' or -- Tzar
           bp.ID == 'xea0002' -- Defense Satellite
end

-- checks if unit's blueprint has huge footprint
function IsUnitHuge(bp)
    if IsUnitMobile(bp) and
      (bp.SizeX > 5 or
       bp.SizeY > 5) then
        return true 
    elseif IsUnitStructure(bp) and
       bp.Footprint and
      (bp.Footprint.SizeX > 5 or
       bp.Footprint.SizeY > 5) then
        return true 
    end
    return false
end

-- checks if unit's blueprint will damage nearby units when walking on top of them
function IsUnitMassive(bp)
    if not IsUnitMobile(bp) then return false end
    -- not using MovementEffects because it is transformed when loading blueprint
    -- but Blueprints.lua creates MovementHash with a copy of all values of MovementEffects table
    local movement = bp.Display.MovementHash
    return movement and
           movement.Land and 
           movement.Land.Footfall and 
           movement.Land.Footfall.Damage and 
           movement.Land.Footfall.Damage.Amount > 0 and 
           movement.Land.Footfall.Damage.Radius > 0
end

-- checks if unit's blueprint can be built on land/seabed or move from land to water
function IsUnitAmphibious(bp)
    return IsUnitMobileAmphibious(bp) or 
           IsUnitStructureAmphibious(bp)
end 

-- checks if unit's blueprint can hover, fly or move on land, on water, or under water
function IsUnitMobile(bp)
    return not IsUnitStructure(bp)
end 

-- checks if unit's blueprint can move from land to water and vice versa
function IsUnitMobileAmphibious(bp)
    if not bp.Physics then return false end

    return bp.Physics.MotionType == 'RULEUMT_Amphibious' or 
           bp.Physics.MotionType == 'RULEUMT_AmphibiousFloating'
end

function IsUnitMobileAir(bp)
    return bp.Physics and bp.Physics.MotionType == 'RULEUMT_Air'
end

function IsUnitMobileAirWinged(bp)
    return bp.Physics and bp.Physics.MotionType == 'RULEUMT_Air' and
           bp.Air.CanFly and bp.Air.Winged
end

function IsUnitMobileAirGunship(bp)
    return IsUnitMobileAirCircling(bp) and table.size(GetWeaponsWithGunship(bp)) > 0
end

function IsUnitMobileAirFighter(bp)
    return IsUnitMobileAirWinged(bp) and table.size(GetWeaponsWithAntiAir(bp)) > 0
end

function IsUnitMobileAirCircling(bp)
    return bp.Physics and bp.Physics.MotionType == 'RULEUMT_Air' and
           bp.Air.CanFly and not bp.Air.Winged and 
           bp.Air.CirclingTurnMult > 0
end

function IsUnitMobileBot(bp)
    if not IsUnitMobileLand(bp) then return false end
    --local isQuare = bp.Physics.StandUpright
    return bp.CategoriesHash.BOT or ValidBots[bp.ID]
end

function IsUnitMobileOrbital(bp)
    return bp.Physics and bp.Physics.MotionType == 'RULEUMT_Air' and
           bp.Physics.Elevation > 50
end

function IsUnitMobileHover(bp)
    return bp.Physics and bp.Physics.MotionType == 'RULEUMT_Hover'
end

function IsUnitMobileSub(bp)
    return bp.Physics and 
           bp.Physics.MotionType == 'RULEUMT_SurfacingSub'
end

function IsUnitMobileLand(bp)
    if not bp.Physics then return false end
    if bp.Physics.MotionType == 'RULEUMT_Amphibious' or 
       bp.Physics.MotionType == 'RULEUMT_AmphibiousFloating' or 
       bp.Physics.MotionType == 'RULEUMT_Hover' or 
       bp.Physics.MotionType == 'RULEUMT_Land' or 
       bp.Physics.AltMotionType == 'RULEUMT_Land' then
         return true
    end 
    return false
end

function IsUnitMobileLandOnly(bp)
    if not bp.Physics then return false end
    if bp.Physics.MotionType == 'RULEUMT_Amphibious' or 
       bp.Physics.MotionType == 'RULEUMT_Hover' or 
       bp.Physics.MotionType == 'RULEUMT_Land' or 
       bp.Physics.AltMotionType == 'RULEUMT_Land' then
         return true
    end 
    return false
end
function IsUnitMobileNaval(bp)
    if not bp.Physics then return false end
    if bp.Physics.MotionType == 'RULEUMT_SurfacingSub' or 
       bp.Physics.MotionType == 'RULEUMT_Water' or 
       bp.Physics.AltMotionType == 'RULEUMT_Water' then
         return true
    end 
    return false
end 

-- checks if unit's blueprint is moving fast depending on motion layer
function IsUnitMobileFast(bp)
    if bp.CategoriesHash.ENGINEER then return false end
    if IsUnitMobileAir(bp) then
        return bp.Air and bp.Air.MaxAirspeed >= 20 -- air scout
    elseif IsUnitMobileNaval(bp) then
        return bp.Physics and bp.Physics.MaxSpeed >= 6 -- frigate
    elseif IsUnitMobileLand(bp) then
        return bp.Physics and bp.Physics.MaxSpeed >= 3.8 -- Loyalist
    else 
        return false
    end
end

-- checks if unit's blueprint is moving slow depending on motion layer
function IsUnitMobileSlow(bp)
    if bp.CategoriesHash.ENGINEER then return false end
    if IsUnitMobileAir(bp) then
        return bp.Air and bp.Air.MaxAirspeed < 10
    elseif IsUnitMobileNaval(bp) then
        return bp.Physics and bp.Physics.MaxSpeed < 3
    elseif IsUnitMobileLand(bp) then
        return bp.Physics and bp.Physics.MaxSpeed < 2
    else 
        return false
    end
end

function IsUnitSubmersible(bp)
    return IsUnitMobileSub(bp) or
           IsUnitStructureSubmerged(bp)
end

function IsUnitStructure(bp)
    return bp.Physics and bp.Physics.MotionType == 'RULEUMT_None'
end

function IsUnitStructureT1(bp)
    return IsUnitStructure(bp) and bp.CategoriesHash.TECH1
end

function IsUnitStructureT2(bp)
    return IsUnitStructure(bp) and bp.CategoriesHash.TECH2
end

function IsUnitStructureT3(bp)
    return IsUnitStructure(bp) and bp.CategoriesHash.TECH3
end

function IsUnitStructureT4(bp)
    return IsUnitStructure(bp) and bp.CategoriesHash.EXPERIMENTAL
end

-- checks if unit's blueprint can be built in air
function IsUnitStructureAir(bp)
    if not IsUnitStructure(bp) then return false end
    return IsUnitBuildOnLayer(bp, 'LAYER_Air') or 
           IsUnitWithFactoryAir(bp) -- not really air but that's exception
end 

-- checks if unit's blueprint can be built on orbit
function IsUnitStructureOrbital(bp)
    if not IsUnitStructure(bp) then return false end
    return IsUnitBuildOnLayer(bp, 'LAYER_Orbit')
end

-- checks if unit's blueprint can be built on land
function IsUnitStructureLand(bp)
    if not IsUnitStructure(bp) then return false end
    return IsUnitBuildOnLayer(bp, 'LAYER_Land')
end 

-- checks if unit's blueprint can be built on surface of water or underwater
function IsUnitStructureNaval(bp)
    if not IsUnitStructure(bp) then return false end
    return IsUnitBuildOnLayer(bp, 'LAYER_Water') or 
           IsUnitBuildOnLayer(bp, 'LAYER_Sub')
end

-- checks if unit's blueprint can be built on land and seabed
function IsUnitStructureAmphibious(bp)
    if not IsUnitStructure(bp) then return false end
    -- BuildOnLayerCaps table is converted to a number when loading blueprints so using 
    -- BuildOnLayerHash table generated in Blueprints.lua
    return bp.Physics.BuildOnLayerHash and 
           bp.Physics.BuildOnLayerHash.LAYER_Land and 
           bp.Physics.BuildOnLayerHash.LAYER_Seabed
end

-- checks if unit's blueprint can be built on seabed
function IsUnitStructureSeabed(bp)
    if not IsUnitStructure(bp) then return false end
    return IsUnitBuildOnLayer(bp, 'LAYER_Seabed')
end

-- checks if unit's blueprint can be built underwater
function IsUnitStructureSubmerged(bp)
    if not IsUnitStructure(bp) then return false end
    return IsUnitBuildOnLayer(bp, 'LAYER_Sub')
end
  
-- checks if unit's blueprint can be built on surface of water and on land
function IsUnitStructureAquatic(bp)
    if not IsUnitStructure(bp) then return false end
    if bp.Physics.BuildOnLayerCaps == '9' or -- LayerCaps in binary 
      (bp.Physics.BuildOnLayerCaps and
       bp.Physics.BuildOnLayerCaps.LAYER_Land and 
       bp.Physics.BuildOnLayerCaps.LAYER_Water) then
           return true
    end
    return false
end

-- checks if unit is T1 (Basic)
-- note assuming all blueprints have correct TechLevel (currently not true)
function IsUnitTech1(bp)
    return bp.General.TechLevel == 'RULEUTL_Basic'
end

-- checks if unit is T2 (Advanced)
-- note assuming all blueprints have correct TechLevel (currently not true)
function IsUnitTech2(bp)
    return bp.General.TechLevel == 'RULEUTL_Advanced'
end

-- checks if unit is T3 (Secret) 
-- note assuming all blueprints have correct TechLevel (currently not true)
function IsUnitTech3(bp)
    return bp.General.TechLevel == 'RULEUTL_Secret'
end

-- checks if unit is T4 (Experimental) 
-- note assuming all blueprints have correct TechLevel (currently not true)
function IsUnitTech4(bp)
    if bp.CategoriesHash.COMMAND then return false end
    return bp.General.TechLevel == 'RULEUTL_Experimental'
end

function IsUnitTypeAir(bp)
    return IsUnitMobileAir(bp) or
           IsUnitWithFactoryAir(bp)
end

function IsUnitTypeLand(bp)
    if IsUnitWithFactoryAir(bp) then return false end
    
    if bp.Physics.AltMotionType == 'RULEUMT_Water' then 
        return false -- CYRBAN destroyer
    end

    return IsUnitMobileLand(bp) or 
           IsUnitCrabEgg(bp) or 
           IsUnitWithFactoryLand(bp)
end

function IsUnitTypeNaval(bp)
    return IsUnitMobileNaval(bp) or 
           IsUnitWithFactoryNaval(bp)
end


function IsUnitTransportingInside(bp)
    return bp.Transport and bp.Transport.StorageSlots > 0
       and IsUnitWithCommandTransport(bp) -- deploy/drop command
end

function IsUnitTransportingBySea(bp)
    return IsUnitTransportingInside(bp)
       and IsUnitTypeNaval(bp)
end

function IsUnitTransportingByAir(bp)
    return IsUnitMobileAir(bp)
       and IsUnitWithCommandTransport(bp)
       and IsUnitWithCommandFerry(bp)
       and bp.Transport
       and bp.Transport.Class2AttachSize > 0
       and bp.Transport.Class3AttachSize > 0
       and bp.Air
       and bp.Air.AutoLandTime > 0
       and bp.Air.TransportHoverHeight > 0
end

function IsUnitWithTeleporter(bp)
    local teleport = GetUpgradeFrom(bp, 'Teleporter')
    return teleport
end

-- checks if unit's blueprint is untargetable by other units, e,g. Satellites 
function IsUnitUntargetable(bp)
    return bp.CategoriesHash.UNTARGETABLE
end

-- checks if unit's blueprint is upgradable to a new unit, e.g. Mass Extractors
function IsUnitUpgradable(bp)
    return bp.General and 
           bp.General.UpgradesTo and 
           bp.General.UpgradesTo ~= '' and 
           bp.General.UpgradesTo ~= 'none'
end

-- checks if unit's blueprint is an upgrade for another unit's blueprint
function IsUnitUpgradeLevel(bp)
    return bp.General and 
           bp.General.UpgradesFrom and 
           bp.General.UpgradesFrom ~= '' and
           bp.General.UpgradesFrom ~= 'none'
end

-- Checks for valid unit blueprints (not projectiles/effects)
function IsUnitValid(bp)
    --local id = bp.BlueprintId or bp.ID
    if not bp or not bp.ID then return false end
    if bp.SourceType ~= 'Unit' then return false end
    
    -- check for unique identifier which is string and not a number
    local isUniqueID = not tonumber(bp.ID)

    if not isUniqueID or SkipBlueprints[bp.ID] then
        return false
    end

    if bp.Categories then
        for _, category in bp.Categories do
            if AllowCategories[category] then
                return true
            elseif SkipCategories[category] then
                return false
            end
        end
    end
    return true
end

-- checks if unit's blueprint will significantly damage nearby units
-- when it dies or detonates is EMP weapon
function IsUnitVolatile(bp)
    -- checking for EMP weapons 
    for _, w in GetWeaponsWithCategory(bp, 'Direct Fire') or {} do
        if w.DamageRadius > 1 and w.DamageType == 'EMP' then
            return true
        end 
    end
    -- checking for death weapons 
    for _, w in GetWeaponsWithCategory(bp, 'Death') or {} do
        if w.DamageRadius > 1 and w.Damage > 100 then
            return true
        end
        if w.NukeOuterRingRadius > 1 and 
           w.NukeOuterRingDamage > 100 then
            return true
        end
        if w.NukeInnerRingRadius > 1 and 
           w.NukeInnerRingDamage > 100 then
            return true
        end
    end
    return false
end

function IsUnitWithBonusEconomic(bp)
    if IsUnitWithFactorySuite(bp) then return false end
    return IsUnitWithMassProdution(bp) or 
           IsUnitWithMassStorage(bp) or 
           IsUnitWithEnergyProdution(bp) or 
           IsUnitWithEnergyStorage(bp)
end

function IsUnitWithBonusAdjacency(bp)
    if not IsUnitStructure(bp) then return false end 
    return bp.Adjacency
end

-- checks if unit's blueprint has UI command with specified name, e.g. 'RULEUCC_Teleport'
-- these UI commands are defined in CommandMode.lua file
function IsUnitWithCommand(bp, commandName)
    -- using CommandHash table generated in Blueprints.lua
    -- because it holds all enabled/disabled commands
    -- while CommandCaps holds only enabled commands that
    -- are converted to a number (if multiple commands) or a string (if single command)
    return bp.General and 
           bp.General.CommandHash and 
           bp.General.CommandHash[commandName]
end

-- checks if unit's blueprint has Attack command
function IsUnitWithCommandAttack(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Attack')
end
-- checks if unit's blueprint has Capture command
function IsUnitWithCommandCapture(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Capture') and
           bp.Economy.BuildRate > 0
end
-- checks if unit's blueprint has Dive/Surface command
function IsUnitWithCommandDive(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Dive')
end
-- checks if unit's blueprint has Dock command
function IsUnitWithCommandDock(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Dock')
end
-- checks if unit's blueprint has Ferry command
function IsUnitWithCommandFerry(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Ferry')
end
-- checks if unit's blueprint has Guard/Assist command
function IsUnitWithCommandGuard(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Guard')
end
-- checks if unit's blueprint has Launch Nuke command
function IsUnitWithCommandLaunchNuke(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Nuke')
end
-- checks if unit's blueprint has Launch Tactical command
function IsUnitWithCommandLaunchTactical(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Tactical')
end
-- checks if unit's blueprint has Move command
function IsUnitWithCommandMove(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Move')
end
-- checks if unit's blueprint has Overcharge command
function IsUnitWithCommandOvercharge(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Overcharge')
end
-- checks if unit's blueprint has Patrol command
function IsUnitWithCommandPatrol(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Patrol')
end
-- checks if unit's blueprint has Pause command
function IsUnitWithCommandPause(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Pause')
end
-- checks if unit's blueprint has Reclaim command
function IsUnitWithCommandReclaim(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Reclaim') and
           bp.Economy.BuildRate > 0
end
-- checks if unit's blueprint has Repair command
function IsUnitWithCommandRepair(bp)
    if bp.Transport and 
       bp.Transport.RepairRate > 0 then 
        return true 
    end
    if bp.Economy and 
       bp.Economy.BuildRate > 0 and
       IsUnitWithCommand(bp, 'RULEUCC_Repair') then 
       return true 
    end
    return false
end
-- checks if unit's blueprint has Retaliate command
function IsUnitWithCommandRetaliate(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_RetaliateToggle')
end
-- checks if unit's blueprint has Sacrifice command
function IsUnitWithCommandSacrifice(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Sacrifice')
end
-- checks if unit's blueprint has Script command
function IsUnitWithCommandScript(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Script')
end
-- checks if unit's blueprint has Special command
function IsUnitWithCommandSpecialAction(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_SpecialAction')
end
-- checks if unit's blueprint has SiloBuildTactical command
function IsUnitWithCommandSiloBuildTactical(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_SiloBuildTactical')
end
-- checks if unit's blueprint has SiloBuildNuke command
function IsUnitWithCommandSiloBuildNuke(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_SiloBuildNuke')
end
-- checks if unit's blueprint has Stop command
function IsUnitWithCommandStop(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Stop')
end 
-- checks if unit's blueprint has Transport command
function IsUnitWithCommandTransport(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Transport')
end
-- checks if unit's blueprint has CallTransport command
function IsUnitWithCommandTransportCall(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_CallTransport')
end
-- checks if unit's blueprint has Teleport command
function IsUnitWithCommandTeleport(bp)
    return IsUnitWithCommand(bp, 'RULEUCC_Teleport')
end

-- checks if unit's blueprint has UI toggle with specified name, e.g. 'RULEUTC_StealthToggle'
-- these UI toggles are defined in CommandMode.lua file
function IsUnitWithToggle(bp, toggleName)
    -- using ToggleHash table generated in Blueprints.lua
    -- because it holds all enabled/disabled toggles
    -- while ToggleCaps holds only enabled toggles that
    -- are converted to a number (if multiple toggles) or a string (if single toggles)
    return bp.General and 
           bp.General.ToggleHash and 
           bp.General.ToggleHash[toggleName]
end

-- checks if unit's blueprint has Cloak toggle
function IsUnitWithToggleCloak(bp)
    return IsUnitWithToggle(bp, 'RULEUTC_CloakToggle')
end
-- checks if unit's blueprint has Intel toggle
function IsUnitWithToggleIntel(bp)
    return IsUnitWithToggle(bp, 'RULEUTC_IntelToggle')
end
-- checks if unit's blueprint has Jamming toggle
function IsUnitWithToggleJamming(bp)
    return IsUnitWithToggle(bp, 'RULEUTC_JammingToggle')
end
-- checks if unit's blueprint has Generic toggle
function IsUnitWithToggleGeneric(bp)
    return IsUnitWithToggle(bp, 'RULEUTC_GenericToggle')
end
-- checks if unit's blueprint has Production toggle
function IsUnitWithToggleProduction(bp)
    return IsUnitWithToggle(bp, 'RULEUTC_ProductionToggle')
end
-- checks if unit's blueprint has Shield toggle
function IsUnitWithToggleShield(bp)
    return IsUnitWithToggle(bp, 'RULEUTC_ShieldToggle')
end
-- checks if unit's blueprint has Stealth toggle
function IsUnitWithToggleStealth(bp)
    return IsUnitWithToggle(bp, 'RULEUTC_StealthToggle')
end
-- checks if unit's blueprint has Special toggle
function IsUnitWithToggleSpecial(bp)
    return IsUnitWithToggle(bp, 'RULEUTC_SpecialToggle')
end
-- checks if unit's blueprint has Weapon toggle
function IsUnitWithToggleWeapon(bp)
    return IsUnitWithToggle(bp, 'RULEUTC_WeaponToggle')
end

-- checks if unit's blueprint has some Intel stealth or jamming
function IsUnitWithIntelCounter(bp)
    return IsUnitWithStealthField(bp) or
           IsUnitWithStealthSuite(bp) or
           IsUnitWithIntelJamming(bp)
end

-- checks if unit's blueprint has some Intel sensor
function IsUnitWithIntelSensor(bp)
    return IsUnitWithIntelOmni(bp) or
           IsUnitWithIntelRadar(bp) or
           IsUnitWithIntelSonar(bp) or
           IsUnitWithIntelOpticVision(bp)
end

-- checks if unit's blueprint has some Intel sensor and no weapons
function IsUnitWithIntelAndNoWeapons(bp)
    local weapons = table.size(GetWeaponsWithDamage(bp))
    if weapons > 0 then return false end
    return IsUnitWithIntelOmni(bp) or
           IsUnitWithIntelRadar(bp) or
           IsUnitWithIntelSonar(bp) or
           IsUnitWithIntelOpticVision(bp)
           --or IsUnitWithStealth(bp) 
end

-- checks if unit's blueprint has Intel Cloak
function IsUnitWithIntelCloak(bp)
    return bp.Intel and bp.Intel.Cloak
end

-- checks if unit's blueprint has Intel Jamming
function IsUnitWithIntelJamming(bp)
    return bp.Intel and 
           bp.Intel.JamRadius and 
           bp.Intel.JamRadius.Max > 0 
end

-- checks if unit's blueprint has Intel Omni
function IsUnitWithIntelOmni(bp)
    return bp.Intel and bp.Intel.OmniRadius > 0 
end

-- checks if unit's blueprint has Intel Radar
function IsUnitWithIntelRadar(bp)
    return bp.Intel and bp.Intel.RadarRadius > 0 
end

-- checks if unit's blueprint has Intel Sonar
function IsUnitWithIntelSonar(bp)
    return bp.Intel and bp.Intel.SonarRadius > 0 
end


-- checks if unit's blueprint has Intel Sonar mobile
function IsUnitWithIntelSonarMobile(bp)
    return bp.General.Category == 'Intelligence' and 
           IsUnitWithIntelSonar(bp) and 
           IsUnitMobileNaval(bp) 
end

-- checks if unit's blueprint has Intel Large Vision
function IsUnitWithIntelLargeVision(bp)
    return bp.Intel and bp.Intel.MaxVisionRadius > 150 
end

-- checks if unit's blueprint has Intel Remote Vision
function IsUnitWithIntelRemoteVision(bp)
    return bp.Intel and bp.Intel.RemoteViewingRadius > 0
end

function IsUnitWithIntelOpticVision(bp)
    return IsUnitWithIntelLargeVision(bp) or
           IsUnitWithIntelRemoteVision(bp)
end

-- checks if unit's blueprint has Intel Scout
function IsUnitWithIntelScout(bp)
    if not bp.Intel then return false end
    if not IsUnitMobileFast(bp) then return false end

    -- check for weapons of combat scouts
    local weapons = GetWeaponsWithDamage(bp, 5)
    if table.size(weapons) > 0 then return false end

    local hasGoodRadar = bp.Intel.RadarRadius > bp.Intel.VisionRadius
    local hasGoodSonar = bp.Intel.SonarRadius > bp.Intel.VisionRadius
    local hasGoodOmni = bp.Intel.OmniRadius > bp.Intel.VisionRadius

    return hasGoodSonar or hasGoodRadar or hasGoodOmni
end

-- checks if unit's blueprint has stealth armor or stealth field
function IsUnitWithStealth(bp)
    return IsUnitWithStealthSuite(bp) or
           IsUnitWithStealthField(bp)
end

-- checks if unit's blueprint has Stealth Armor
function IsUnitWithStealthSuite(bp)
    return bp.Intel and bp.Intel.RadarStealth and bp.Intel.RadarStealthField ~= true
end

-- checks if unit's blueprint has Stealth Field
function IsUnitWithStealthField(bp)
    return bp.Intel and bp.Intel.RadarStealthField or 
           bp.Intel.RadarStealthFieldRadius > 0 or
           bp.Intel.SonarStealthFieldRadius > 0
end

-- checks if unit's blueprint has shield armor or shield dome
function IsUnitWithShield(bp)
    return IsUnitWithShieldSuite(bp) or
           IsUnitWithShieldDome(bp)
end

-- checks if unit's blueprint has shield armor
function IsUnitWithShieldSuite(bp)
    return bp.Defense and
           bp.Defense.Shield and
          (bp.Defense.Shield.PersonalShield or 
           bp.Defense.Shield.PersonalBubble or
           bp.Defense.Shield.ShieldSize > 0 and 
           bp.Defense.Shield.ShieldSize <= 3)
end

-- checks if unit's blueprint has shield bubble/dome
function IsUnitWithShieldDome(bp)
    return bp.Defense and
           bp.Defense.Shield and
           bp.Defense.Shield.ShieldSize > 3 and
           bp.Defense.Shield.PersonalShield ~= true
end




-- checks if unit's blueprint has Air Staging
function IsUnitWithAirStaging(bp)
    if IsUnitTransportingInside(bp) then
        return true
    end
    return bp.Transport and 
           bp.Transport.DockingSlots > 0 --and 
          -- bp.Transport.RepairRate > 0
end


function IsUnitWithAssistingStation(bp)
    return bp.General.Category == 'Construction' and
           IsUnitStructure(bp) and 
--           IsUnitWithCommandRepair(bp) and 
           IsUnitWithEngineeringFromDistance(bp) and 
           IsUnitWithBuildingBones(bp) and
       not IsUnitWithBuildingSuite(bp) and
       not IsUnitWithFactorySuite(bp)
end

function IsUnitWithAssistingDroneOrStation(bp)
    return IsUnitWithAssistingDrone(bp) or
           IsUnitWithAssistingStation(bp)
end

function IsUnitWithAssistingDrone(bp)
    return IsUnitMobileAir(bp) and
--           IsUnitWithCommandRepair(bp) and 
           IsUnitWithEngineeringFromDistance(bp) and 
           IsUnitWithBuildingBones(bp) and
       not IsUnitWithBuildingSuite(bp)
end

function IsUnitWithBuildingBones(bp)
    local bones = bp.General.BuildBones
    if bones and bones.BuildEffectBones then
       return table.size(bones.BuildEffectBones) > 0
    end
    return false
end

function IsUnitWithBuildingQueue(bp)
    return IsUnitWithFactorySuite(bp)
        or IsUnitWithConstructionSuite(bp)
        or IsUnitUpgradable(bp)
end
-- checks if units can build other units or structures
function IsUnitWithBuildingSuite(bp)
    -- e.g. 'BUILTBYTIER3ENGINEER UEF'
    return IsUnitWithBuildingCategory(bp, ' ')
end

function IsUnitWithBuildingRate(bp)
    return bp.Economy.BuildRate > 0
end

function IsUnitWithBuildingCategory(bp, category)
    if not bp.Economy.BuildRate > 0 then return false end
    for _, buildExpression in bp.Economy.BuildableCategory or {} do
        if string.find(buildExpression, category) then
            return true
        end
    end
    return false
end

function IsUnitWithEngineeringDrone(bp)
    return bp.General.Category == 'Utility' and
           IsUnitMobileAir(bp) and 
--           IsUnitWithCommandRepair(bp) and 
           IsUnitWithBuildingBones(bp) and 
           IsUnitWithEngineeringFromDistance(bp) 
end

function IsUnitWithEngineeringFromDistance(bp)
    -- strangely units without Engineering suite (e.g. airplanes)
    -- have bp.Economy.MaxBuildDistance set to 5 by default!
    return bp.Economy and 
           bp.Economy.MaxBuildDistance > 1
end

function IsUnitWithEngineeringPods(bp)
    return table.size(bp.Economy.EngineeringPods) > 0
end

function IsUnitWithEngineeringStation(bp)
    return IsUnitWithEngineeringPods(bp) or 
           IsUnitWithAssistingStation(bp)
end

function IsUnitWithEngineeringSuite(bp)
    if bp.CategoriesHash.UEF and
       IsUnitWithEngineeringStation(bp) then
       return false 
    end

    return IsUnitWithEngineeringPods(bp) or
          (IsUnitWithCommandRepair(bp) and
           IsUnitWithCommandReclaim(bp) and
           IsUnitWithCommandCapture(bp))
end

function IsUnitWithEnhancements(bp)
    return table.size(bp.Enhancements) > 0
end

function IsUnitWithConstructionSuite(bp)
    -- gateways are really teleporters rather construction sites
    if bp.CategoriesHash.GATE then return false end
    if IsUnitMobileNaval(bp) then return false end
    if IsUnitTransportingInside(bp) then return false end

    return IsUnitWithEngineeringStation(bp) or 
           table.size(bp.Economy.BuildableCategory) > 2 or
           IsUnitWithBuildingCategory(bp, 'CONSTRUCTION') or 
           IsUnitWithBuildingCategory(bp, 'NAVAL') or
           IsUnitWithBuildingCategory(bp, 'LAND') or
           IsUnitWithBuildingCategory(bp, 'AIR') or
           IsUnitWithBuildingCategory(bp, 'ENGINEER') or
           IsUnitWithBuildingCategory(bp, 'COMMANDER')  or
           IsUnitWithBuildingCategory(bp, 'SATELLITE') or
           IsUnitWithBuildingCategory(bp, 'QUANTUMGATE') or
           IsUnitWithFactorySuite(bp)
end

function IsUnitWithFactorySuite(bp)
    if not bp.Economy.BuildRate > 0 then return false end

    return bp.Economy.MaxBuildDistance == 1 or -- Megalith
           bp.General.Classification == 'RULEUC_Factory' or 
           IsUnitWithBuildingCategory(bp, 'FACTORY') or 
           IsUnitWithBuildingCategory(bp, 'QUANTUMGATE') or 
           IsUnitWithBuildingCategory(bp, 'SATELLITE')
end

function IsUnitWithFactoryStructure(bp)
    return IsUnitStructure(bp) and 
           IsUnitWithFactorySuite(bp) and 
          (IsUnitUpgradable(bp) or IsUnitUpgradeLevel(bp))
end

function IsUnitWithFactoryHQ(bp)
    return bp.CategoriesHash.RESEARCH and not
           bp.CategoriesHash.SUPPORTFACTORY and
           IsUnitWithFactoryStructure(bp)
end

function IsUnitWithFactorySupport(bp)
    return bp.CategoriesHash.SUPPORTFACTORY and not
           bp.CategoriesHash.RESEARCH and
           IsUnitWithFactoryStructure(bp)
end

function IsUnitWithFactoryAir(bp)
    if not bp.Economy.BuildRate > 0 then return false end
    if not IsUnitStructure(bp) then return false end
    return IsUnitWithBuildingCategory(bp, 'AIR') or
           IsUnitWithBuildingCategory(bp, 'SATELLITE')
end

function IsUnitWithFactoryNaval(bp)
    if not bp.Economy.BuildRate > 0 then return false end
    return IsUnitStructure(bp) and 
           IsUnitWithBuildingCategory(bp, 'NAVAL')
end

function IsUnitWithFactoryLand(bp)
    if not bp.Economy.BuildRate > 0 then return false end
    return IsUnitStructure(bp) 
       and IsUnitWithBuildingCategory(bp, 'LAND')
end

function IsUnitWithFactorySatellite(bp)
    if not bp.Economy.BuildRate > 0 then return false end
    return IsUnitStructure(bp) 
       and IsUnitWithBuildingCategory(bp, 'SATELLITE')
end

function IsUnitWithFactoryRallyPoint(bp)
    if not IsUnitStructure(bp) then return false end
    return IsUnitWithFactorySuite(bp) or
           IsUnitCrabEgg(bp)
end

function IsUnitWithFuelLimited(bp)
    return IsUnitMobileAir(bp) and
           bp.Physics and
           bp.Physics.FuelRechargeRate == 0 and
           bp.Physics.FuelUseTime > 0 and
           bp.Physics.FuelUseTime < 150
end

-- checks if unit's blueprint has Energy Production pack (except commanders)
function IsUnitWithEnergyProdution(bp)
    if IsUnitStructure(bp) and bp.Economy then
       return bp.Economy.ProductionPerSecondEnergy > 0 or
              bp.Economy.MaxEnergy > 0 -- paragon
    end

    if IsUnitMobile(bp) and bp.Economy then
       return bp.Economy.ProductionPerSecondEnergy > 0
    end
    return false
end

function IsUnitWithEnergyStorage(bp)
    if not IsUnitStructure(bp) then return false end
    if IsUnitWithMassProdution(bp) then return false end
    if IsUnitWithEnergyProdution(bp) then return false end
    return bp.Economy and 
           bp.Economy.StorageEnergy > 0
end

function IsUnitWithEnergyConsumption(bp)
    return bp.Economy and 
           bp.Economy.MaintenanceConsumptionPerSecondEnergy > 0
end

-- checks if unit's blueprint has Mass Production pack (except commanders)
function IsUnitWithMassProdution(bp)
    if IsUnitStructure(bp) and bp.Economy then
       return bp.Economy.ProductionPerSecondMass > 0 or
              bp.Economy.MaxMass > 0 -- paragon
    end

    if IsUnitMobile(bp) and bp.Economy then
       return bp.Economy.ProductionPerSecondMass > 0
    end
    return false
end

function IsUnitWithMassStorage(bp)
    if not IsUnitStructure(bp) then return false end
    if IsUnitWithMassProdution(bp) then return false end
    if IsUnitWithEnergyProdution(bp) then return false end
    return bp.Economy and bp.Economy.StorageMass > 0
end

function IsUnitWithMassFabrication(bp)
    if IsUnitStructure(bp) and
       IsUnitWithMassProdution(bp) and
       IsUnitWithEnergyConsumption(bp) and not 
       IsUnitWithMassExtraction(bp) then
       return true
    end

    if IsUnitMobile(bp) and
       IsUnitWithMassProdution(bp) then
       return true
    end
    return false
end

function IsUnitWithMassExtraction(bp)
    if IsUnitStructure(bp)  and
       IsUnitBuildOnDepositMass(bp) and
       IsUnitWithMassProdution(bp) and
       IsUnitWithEnergyConsumption(bp)then
       return true
    end
    return false
end

function IsUnitWithMassConsumption(bp)
    return bp.Economy and 
           bp.Economy.MaintenanceConsumptionPerSecondMass > 0
end

function IsUnitWithNoOffensiveWeapons(bp)
    local weapons = table.size(GetWeaponsWithOffense(bp))
    return weapons == 0
end

-- checks if unit's blueprint has missile deflection
function IsUnitWithTacticalDeflection(bp)
    return bp.Defense.AntiMissile and 
           bp.Defense.AntiMissile.Radius > 1 and 
           bp.Defense.AntiMissile.RedirectRateOfFire > 0
end

-- checks if unit's blueprint has missile defense or deflection
function IsUnitWithTacticalDefense(bp)
    local weapons = table.size(GetWeaponsWithAntiMissile(bp))
    return weapons > 0 or IsUnitWithTacticalDeflection(bp)
end

function IsUnitWithTacticalPlatform(bp)
    local weapons = table.size(GetWeaponsWithTML(bp)) 
    return weapons > 0 and IsUnitStructure(bp) 
end

function IsUnitWithStrategicPlatform(bp)
    local weapons = table.size(GetWeaponsWithSML(bp)) 
    return weapons > 0 and IsUnitStructure(bp)
end

function IsUnitWithStrategicDefense(bp)
    local weapons = table.size(GetWeaponsWithSMD(bp)) 
    return weapons > 0
end

-- gets a path to an image representing a given blueprint and faction
-- Improved version of UIUtil.UIFile() which does not checks in mods
function GetImagePath(bp, faction)
    local root = ''
    local bid = bp.ID or ''
    local icon = bp.Icon or ''
    local iconID = faction .. bid
    -- Check if image was cached already
    if Cache.IsEnabled and Cache.Images[iconID] then
        return Cache.Images[iconID]
    end

    if Cache.IsEnabled and Cache.Images[faction .. icon] then
        return Cache.Images[faction..icon]
    end

    if icon and DiskGetFileInfo(icon) then
        return icon
    end

    local paths = {
        '/textures/ui/common/icons/units/',
        '/textures/ui/common/icons/',
        '/textures/ui/common/faction_icon-lg/',
        '/icons/units/',
        '/units/'..bid..'/',
    }

    if bp.Type == 'UPGRADE' then
        paths = {'/textures/ui/common/game/'..faction..'-enhancements/'}
    end

    local name = ''
    -- First check for icon in game textures
    for _, path in paths do
        name = path .. bid .. '_icon.dds'
        if DiskGetFileInfo(name) then
            Cache.Images[iconID] = name
            return name
        end

        name = path .. icon
        if not string.find(icon,'.dds') then
            name = name .. '_btn_up.dds'
        end

        if DiskGetFileInfo(name) then
            Cache.Images[iconID] = name
            return name
        end
    end
    -- Next find an icon if one exist in mod's textures folder
    if bp.Mod then
        root = bp.Mod.location
        for _,path in paths do
            name = root .. path .. bid .. '_icon.dds'
            if DiskGetFileInfo(name) then
                Cache.Images[iconID] = name
                return name
            end
            name = root .. path .. icon
            if not string.find(icon,'.dds') then
                name = name .. '_btn_up.dds'
            end
            if DiskGetFileInfo(name) then
                Cache.Images[iconID] = name
                return name
            end
        end
    end
    -- Default to unknown icon if not found icon for the blueprint
    local unknown = '/textures/ui/common/icons/unknown-icon.dds'
    Cache.Images[iconID] = unknown

    return unknown
end

-- this table defines faction background colors used in the unit manager
local Factions = {
    UEF      = { ID = 1, Name = 'UEF',      Icon = 'uef_ico.dds',      Foreground = 'FF00BEFF', Background = 'FF006CD9' }, --#FF00BEFF #FF006CD9
    AEON     = { ID = 2, Name = 'AEON',     Icon = 'aeon_ico.dds',     Foreground = 'FF35C106', Background = 'FF238C00' }, --#FF35C106 #FF238C00
    CYBRAN   = { ID = 3, Name = 'CYBRAN',   Icon = 'cybran_ico.dds',   Foreground = 'FFFC0303', Background = 'FFB32D00' }, --#FFFC0303 #FFB32D00
    SERAPHIM = { ID = 4, Name = 'SERAPHIM', Icon = 'seraphim_ico.dds', Foreground = 'FFFFBF00', Background = 'FFFFBF00' }, --#FFFFBF00 #FFFFBF00
    NOMADS   = { ID = 5, Name = 'NOMADS',   Icon = 'nomads_ico.dds',   Foreground = 'FFFF7200', Background = 'FFFF7200' }, --#FFFF7200 #FFFF7200
    UNKNOWN  = { ID = 6, Name = 'UNKNOWN',  Icon = 'random_ico.dds',   Foreground = 'FFD619CE', Background = 'FFD619CE' }, --#FFD619CE #FFD619CE
}

-- gets unit's background color based on faction of given blueprint
function GetUnitFactionBackground(bp)
    local name = GetUnitFactionName(bp)

    if Factions[name] then return Factions[name].Background end

    return Factions.UNKNOWN.Background
end
-- gets unit's foreground color based on faction of given blueprint
function GetUnitFactionForeground(bp)
    local name = GetUnitFactionName(bp)
    if Factions[name] then return Factions[name].Foreground end
    return Factions.UNKNOWN.Foreground
end

-- gets unit's faction icon based on faction of given blueprint
function GetUnitFactionIcon(bp, useAlpha)
    local name = GetUnitFactionName(bp)

    local icon = ''
    if Factions[name] then 
        icon = Factions[name].Icon
    else 
        icon = Factions.UNKNOWN.Icon
    end
    -- check whether return semi-transparent icon or already colored icon
    if useAlpha then
        return '/textures/ui/common/widgets/faction-icons-alpha_bmp/' .. icon
    else 
        return '/textures/ui/common/faction_icon-sm/' .. icon
    end
end

function GetUnitFactionID(bp)
    local name = GetUnitFactionName(bp)

    if Factions[name] then return Factions[name].ID end
    return Factions.UNKNOWN.ID
end

-- gets unit's faction based on categories of given blueprint
function GetUnitFactionName(bp)
    if not bp.General then return 'UNKNOWN' end
    if not bp.General.FactionName then return 'UNKNOWN' end
    if not bp.General.FactionName == '' then return 'UNKNOWN' end

    return string.upper(bp.General.FactionName)
end

-- gets unit's localizable name of given blueprint
function GetUnitName(bp)
    local name = ''
    if bp.General.UnitName then
        name = LOC(bp.General.UnitName)
    end
    return name
end

-- gets unit's localizable description of given blueprint
function GetUnitDescription(bp)
    local desc = ''
    if bp.Description then
        desc = LOC(bp.Description)
    elseif bp.Interface and bp.Interface.HelpText then
        desc = LOC(bp.Interface.HelpText)
    end

--    desc = string.gsub(desc, 'Support Armored Command Unit', 'SCU')
--    desc = string.gsub(desc, 'Armored Command Unit', 'ACU')
    -- removing Experimental because it is replaced with 'T4' 
    -- in GetUnitTechSymbol function
    desc = string.gsub(desc, 'Experimental ', '')

    return desc
end

-- gets unit's title including tech level, description, and name if the unit has it
function GetUnitTitle(bp)
    local name = GetUnitName(bp)
    local ret = GetUnitTechAndDescription(bp)
    if name ~= '' and not bp.CategoriesHash.ISPREENHANCEDUNIT then
        ret = ret .. ' (' .. name .. ')'
    end
    return ret
end

-- gets unit's tech level and short description
function GetUnitTechAndDescription(bp)
    local tech = GetUnitTechSymbol(bp)
    local desc = GetUnitDescription(bp)
    if tech == '' then
        return desc
    else
        return tech .. ' ' .. desc
    end
end

-- gets unit's tech level based on categories of given blueprint
function GetUnitTechSymbol(bp)
    -- assuming tech categories are more correct then bp.General.TechLevel
    if bp.CategoriesHash['TECH2'] then return 'T2' end
    if bp.CategoriesHash['TECH3'] then return 'T3' end
    if bp.CategoriesHash['COMMAND'] then return '' end
    if bp.CategoriesHash['EXPERIMENTAL'] then return 'T4' end
    if bp.CategoriesHash['TECH1'] then return 'T1' end
    return ''
end

-- gets unit's tech based on categories of given blueprint
function GetUnitTechCategory(bp)
    if bp.CategoriesHash['TECH1'] then return 'TECH1' end
    if bp.CategoriesHash['TECH2'] then return 'TECH2' end
    if bp.CategoriesHash['TECH3'] then return 'TECH3' end
    if bp.CategoriesHash['COMMAND'] then return '' end
    if bp.CategoriesHash['EXPERIMENTAL'] then return 'EXPERIMENTAL' end
    return ''
end

-- gets unit's type based on categories of given blueprint
function GetUnitType(bp)
    if bp.CategoriesHash['ORBITALSYSTEM'] then return 'ORBITAL' end
    --if bp.CategoriesHash['STRUCTURE'] then return 'BASE' end
    if bp.CategoriesHash['HOVER'] then return 'HOVER' end
    if bp.CategoriesHash['AIR'] then return 'AIR' end
    if bp.CategoriesHash['LAND'] then return 'LAND' end
    if bp.CategoriesHash['NAVAL'] then return 'NAVAL' end
     
    return "UNKNOWN"
end

-- gets unit's background icon
function GetUnitIconBackground(bp)
    local validBackgrounds = {land = true, air = true, sea = true, amph = true}
    if validBackgrounds[bp.General.Icon] then
        return '/textures/ui/common/icons/units/' .. bp.General.Icon .. '_up.dds'
    else 
        return '/textures/ui/common/icons/units/land_up.dds'
    end  
end

function GetUnitIconStrat(bp)
    local stratIcons = import('/lua/ui/game/straticons.lua')
    local name = bp.StrategicIconName
    local icon = 'structure_generic'

    if stratIcons.aSpecificStratIcons[bp.ID] then
       icon = stratIcons.aSpecificStratIcons[bp.ID]
    elseif stratIcons.aStratIconTranslationFull[name] then
       icon = stratIcons.aStratIconTranslationFull[name]
    end
        
--         straticonsfile.aSpecificStratIcons[control.Data.id] or 
--         straticonsfile.aStratIconTranslation[iconName]
    return '/textures/ui/icons_strategic/' .. icon .. '.dds'
    
end

function GetUnitDefenseShield(bp)
    if bp.Defense and bp.Defense.Shield then
       return bp.Defense.Shield.ShieldMaxHealth or 0
    end
    return 0
end
function GetUnitDefenseArmor(bp)
    if bp.Defense then
       return bp.Defense.MaxHealth or 0
    end
    return 0
end

-- gets unit's strategic group based its blueprint's categories and abilities
function GetUnitStrategicGroup(bp)
    local group = 'unknown'
      
    if IsUnitWithIntelSonarMobile(bp) then
        group = 'structure' -- mobile sonars as structures
    elseif IsUnitStructure(bp) then
        if bp.CategoriesHash.EXPERIMENTAL then
            group = 'experimental'
        elseif bp.CategoriesHash.GATE then
            group = 'structure'
        elseif IsUnitCrabEgg(bp) then
            group = 'structure'
        elseif IsUnitWithFactorySuite(bp) and bp.CategoriesHash.RESEARCH then
            group = 'factoryHQ'
        elseif IsUnitWithFactorySuite(bp) then
            group = 'factory'
        else
            group = 'structure'
        end
    elseif IsUnitMobile(bp) then
        if IsUnitCommander(bp) then
            group = 'commander'
        elseif bp.CategoriesHash.EXPERIMENTAL then
            group = 'experimental'
        elseif IsUnitMobileBot(bp) then
            group = 'bot' 
        elseif IsUnitMobileNaval(bp) then
            if IsUnitMobileSub(bp) and not bp.CategoriesHash.DESTROYER then
                group = 'sub'
            else
                group = 'ship'
            end
        elseif IsUnitMobileLand(bp) or IsUnitWithEngineeringSuite(bp) then
            group = 'land'
        elseif IsUnitTransportingByAir(bp) then
            group = 'gunship'
        elseif IsUnitMobileAir(bp) then
            local damages = GetWeaponsDamages(bp)
            if GetWeaponsWithGunship(bp) then 
                group = 'gunship'
            elseif damages.AntiNavy > 0 then
                group = 'bomber'
            elseif damages.Bomb > 0 then
                 if damages.AntiAir > 0 and bp.CategoriesHash.TECH2 then
                    group = 'fighter'
                 else
                    group = 'bomber'
                 end
            else
                 group = 'fighter'
            end
        end
    end

    -- for now T1 storages do not need tech level
    -- unless T2 and T3 storages are added to FAF game
    local isStorage = IsUnitWithEnergyStorage(bp) or IsUnitWithMassStorage(bp)
    if isStorage and IsUnitStructureT1(bp) and not IsUnitWithFactorySuite(bp) then
        return group
    end

    -- some units do not require tech level for the strategic group
    if not bp.CategoriesHash.EXPERIMENTAL and
       not bp.CategoriesHash.WALL and
       not IsUnitCommander(bp) and
       not IsUnitCrabEgg(bp) then
        local tech = GetUnitTechCategory(bp)
        tech = string.gsub(tech, 'TECH', '')
        group = group .. tech
    end
     
    return string.lower(group)
end
-- gets unit strategic purpose based on its weapon stats and abilities
function GetUnitStrategicPurpose(bp)
    local purpose = 'unknown'
    local damages = GetWeaponsDamages(bp)

    if bp.CategoriesHash.GATE then
        purpose = 'transport'
    elseif bp.CategoriesHash.WALL then
        purpose = 'wall'
    elseif IsUnitCrabEgg(bp) then
        purpose = 'generic'
    elseif IsUnitCommander(bp) then
        purpose = 'generic'
    elseif bp.CategoriesHash.EXPERIMENTAL then
        purpose = 'generic'
    elseif IsUnitStructure(bp) and IsUnitWithFactorySuite(bp) then
        purpose = string.lower(GetUnitType(bp))
    elseif IsUnitWithIntelSonarMobile(bp) then
        purpose = 'intel'
    elseif IsUnitWithEngineeringSuite(bp) then
        purpose = 'engineer'
    elseif IsUnitWithEngineeringPods(bp) then
        purpose = 'engineer'
    elseif IsUnitWithAssistingStation(bp) then
        purpose = 'engineer'
    elseif IsUnitWithAssistingDrone(bp) then
        purpose = 'engineer'

    elseif damages.Total == 0 then 
        if IsUnitWithEngineeringSuite(bp) then
            purpose = 'engineer'
        elseif IsUnitTransportingByAir(bp) then
            purpose = 'transport'
        elseif IsUnitWithAirStaging(bp) then
            purpose = 'air'
        elseif IsUnitWithShield(bp) then
            purpose = 'shield'
        elseif IsUnitWithIntelSensor(bp) then
            purpose = 'intel'
        elseif IsUnitWithIntelCounter(bp) then
            purpose = 'counterintel'
        elseif IsUnitWithMassProdution(bp) or IsUnitWithMassStorage(bp) then
            purpose = 'mass'
        elseif IsUnitWithEnergyProdution(bp) or IsUnitWithEnergyStorage(bp) then
            purpose = 'energy'
        else
            purpose = 'unknown_NoDamage'
        end
    -- based on damage of weapons
    elseif damages.Total > 0 then
        -- some units have special purpose even thought they have weapons
        if bp.ID == 'xel0305' or bp.ID == 'xrl0305' then
            purpose = 'armored' -- T3 Armored Assault Bots
        elseif bp.CategoriesHash.SCOUT or bp.CategoriesHash.FRIGATE then
            purpose = 'intel'
        elseif IsUnitWithEngineeringSuite(bp) then
            purpose = 'engineer'
        elseif IsUnitTransportingByAir(bp) and bp.ID ~= 'uea0203' then
            purpose = 'transport'
        elseif IsUnitTransportingInside(bp) and IsUnitMobileNaval(bp) then
            purpose = 'air' -- naval aircraft carriers
        -- determine unit's purpose using damage of weapons
        elseif damages.Kamikaze > 0 then
            purpose = 'bomb'
        elseif damages.AntiAir > 0 and damages.TML > 0 then
            purpose = 'antiair'
        elseif damages.Direct > 0 and damages.SML > 0 then
            purpose = 'directfire' -- SERAPHIM battleship
        elseif damages.TML > 0 or damages.SML > 0 then
            purpose = 'missile'
        elseif damages.Artillery > 0 then
            purpose = 'artillery' 
        elseif damages.Sniper > 0 then
            purpose = 'sniper' 
        elseif damages.AntiShield > 0 then
            purpose = 'antishield'
        elseif damages.Bomb > 0 then
            purpose = 'directfire'
        -- suggest antinavy if it is significant portion of direct fire
        elseif damages.AntiNavy > damages.AntiAir and 
               damages.AntiNavy > damages.Direct * 0.3 then
            purpose = 'antinavy' -- AEON T2 Destroyer
        -- suggest antiair if it is significant portion of direct fire
        elseif damages.AntiAir > damages.AntiNavy and 
               damages.AntiAir > damages.Direct * 0.5 then
            purpose = 'antiair' -- CYBRAN T2 Cruiser
        elseif damages.Direct > damages.AntiNavy and 
               damages.Direct > damages.AntiAir then
            purpose = 'directfire'
        elseif damages.AntiNavy > 0 then
            purpose = 'antinavy'
        elseif damages.Direct > 0 then
            purpose = 'directfire'
        elseif damages.AntiAir > 0 then
            purpose = 'antiair'
        elseif damages.TMD > 0 or damages.SMD > 0 then
            purpose = 'antimissile'
        elseif IsUnitWithIntelCounter(bp) then
            purpose = 'counterintel'
        elseif IsUnitWithIntelSensor(bp) then
            purpose = 'intel'
        else
            purpose = 'unknown_SomeDamage'
        end
    end

    return purpose
end

-- gets unit's categories that contain specified string
function GetUnitCategoriesContaining(bp, str)
    local ret = {}
    for i, cateogry in bp.Categories or {} do
        if string.find(cateogry, str) then
            table.insert(ret, cateogry)
        end
    end
    return ret
end

-- gets unit's categories that start with specified string
function GetUnitCategoriesWith(bp, str)
    local ret = {}
    for i, cateogry in bp.Categories or {} do
        if StringStarts(cateogry, str) then
            table.insert(ret, cateogry)
        end
    end
    return ret
end

-- gets unit's physical/terrain size
function GetUnitPhysicsSize(bp)
    if not bp.Physics then return 0 end
    local x = bp.Physics.SkirtSizeX or 0
    local z = bp.Physics.SkirtSizeZ or 0
    return math.min(x, z)
end

-- gets unit's hitbox size
function GetUnitSize(bp)
    local x = bp.SizeX or 0
    local y = bp.SizeY or 0
    local z = bp.SizeZ or 0
    return math.max(x, math.max(y, z))
end


TechLevels = {
    TECH1 = 'RULEUTL_Basic',
    TECH2 = 'RULEUTL_Advanced',
    TECH3 = 'RULEUTL_Secret',
    EXPERIMENTAL = 'RULEUTL_Experimental',
}

--CategoryLevels = {
--    RULEUTL_Basic = 'TECH1',
--    RULEUTL_Advanced = 'TECH2',
--    RULEUTL_Secret = 'TECH3',
--    RULEUTL_Experimental = 'EXPERIMENTAL',
--}

--TransportLevels = {
--    TECH1 = 1,
--    TECH2 = 2,
--    TECH3 = 3,
--    EXPERIMENTAL = 'RULEUTL_Experimental',
--}


--FromRangeCategory = {
--    UWRC_AntiAir = 'TECH1',
--    UWRC_AntiAir = 'TECH1',
--    UWRC_AntiNavy = 'TECH1',
--    UWRC_Countermeasure = 'TECH1',
--    UWRC_DirectFire = 'DIRECTFIRE',
--    UWRC_IndirectFire = 'INDIRECTFIRE',
--    UWRC_Undefined = 'TECH1',
--}

function IsWeaponPrimary(w)
    if w.WeaponCategory and 
       w.WeaponCategory ~= 'Death' and 
       w.WeaponCategory ~= 'Teleport' and 
       w.WeaponCategory ~= 'Defense' and 
       w.WeaponCategory ~= 'Experimental' and -- skipping GC claws
       w.DamageType ~= 'Overcharge' then -- skipping OC weapon
       return true
    end
    return false
end

function IsWeaponOvercharge(w)
    return w.DamageType == 'Overcharge'
end

function IsWeaponDeath(weapon)
    if weapon.WeaponCategory == 'Death' then
       return true
    end
    -- 'Death Nuke', 'Death Weapon', 'Collossus Death', 'Megalith Death'
    if weapon.DisplayName and string.find(weapon.DisplayName, 'Death') then
       return true
    end
    return false
end


function IsWeaponWithMultipleShots(w)
    if (w.ProjectileId or w.ProjectileLifetimeUsesMultiplier) and 
        not w.ForceSingleFire then
        return true
    end
    return false
end

function IsWeaponTML(weapon)
    return weapon.RangeCategory  == 'UWRC_IndirectFire' and
           weapon.WeaponCategory == 'Missile' and 
           not weapon.NukeWeapon
end
function IsWeaponTMD(weapon)
    if not IsWeaponWithTarget(weapon, 'Air') then return false end
    return weapon.TargetRestrictOnlyAllow == 'TACTICAL,MISSILE' or 
           weapon.TargetRestrictOnlyAllow == 'TACTICAL MISSILE'
end

function IsWeaponSML(w)
    return w.NukeWeapon and
           w.WeaponCategory == 'Missile' and 
          (w.RangeCategory == 'UWRC_IndirectFire' or
           w.RangeCategory == 'UWRC_DirectFire')
end
function IsWeaponSMD(weapon)
    if not IsWeaponWithTarget(weapon, 'Air') then return false end
    return weapon.TargetRestrictOnlyAllow == 'STRATEGIC,MISSILE' or 
           weapon.TargetRestrictOnlyAllow == 'STRATEGIC MISSILE'
end


function IsWeaponAntiMissile(weapon)
    if not IsWeaponWithTarget(weapon, 'Air') then return false end
    return IsWeaponSMD(weapon) or IsWeaponTMD(weapon)
end

function IsWeaponDirectFire(w)
    if w.WeaponCategory == 'Direct Fire Experimental' then
        return true
    end
    return w.Damage > 0  and
           w.RangeCategory == 'UWRC_DirectFire' and
           (IsWeaponWithTarget(w, 'Land') or 
            IsWeaponWithTarget(w, 'Land|Water') or 
            IsWeaponWithTarget(w, 'Land|Seabed|Water') or 
            IsWeaponWithTarget(w, 'Land|Water|Seabed'))
--    return w.RangeCategory  == 'UWRC_DirectFire' or 
--           w.WeaponCategory == 'Direct Fire' or
--           w.WeaponCategory == 'Direct Fire Experimental' or
--           w.WeaponCategory == 'Direct Fire Naval'  or
--           w.WeaponCategory == 'Kamikaze'
end

function IsWeaponIndirectFire(w)
    return w.RangeCategory  == 'UWRC_IndirectFire' or 
           w.WeaponCategory == 'Indirect Fire' or
           w.WeaponCategory == 'Artillery' or
           w.WeaponCategory == 'Bomb'
end

function IsWeaponKamikaze(w)
    return w.WeaponCategory == 'Kamikaze' -- cannot miss
end
-- checks if a weapon is beam tractor, e.g. GC (ual0401) Left/Right Tractor Claw
function IsWeaponBeamTractor(w)
    return w.WeaponCategory == 'Experimental' and
           w.BeamLifetime == 0 
end
 
function IsWeaponMissile(w)
    return w.WeaponCategory == 'Missile'
end

function IsWeaponArtillery(w)
    return w.WeaponCategory == 'Artillery'
end

function IsWeaponDefensive(w)
    return w.RangeCategory  == 'UWRC_Countermeasure' or
           w.WeaponCategory == 'Defense' or
           IsWeaponBeamTractor(w) or 
           IsWeaponSMD(w) or
           IsWeaponTMD(w) or
           IsWeaponTorpedoDefense(w)
end

function IsWeaponDepthCharge(w)
    if not w.ProjectileId then return false end
    local projectile = string.lower(w.ProjectileId)
    return string.find(projectile, 'charge') and
           IsWeaponWithTarget(w, 'Sub')
end

function IsWeaponAntiAir(weapon)
    if not IsWeaponWithTarget(weapon, 'Air') then return false end
    return weapon.WeaponCategory ~= 'Kamikaze' and
           weapon.RangeCategory == 'UWRC_AntiAir'
end

function IsWeaponAntiShield(w)
    return w.DamageToShields > 0
end

function IsWeaponAntiNavy(w)
    return w.RangeCategory  == 'UWRC_AntiNavy' or
           w.WeaponCategory == 'Anti Navy' or
           w.WeaponCategory == 'AntiNavy'
end

function IsWeaponTorpedo(weapon)
    if not IsWeaponWithTarget(weapon, 'Sub') then return false end
    return weapon.WeaponCategory == 'Anti Navy' and -- == 'UWRC_AntiNavy' 
           weapon.Damage > 1
end

function IsWeaponTorpedoDefense(weapon)
    --if not IsWeaponWithTarget(weapon, 'Sub') then return false end
    return weapon.TargetType == 'RULEWTT_Projectile' and
           weapon.RangeCategory == 'UWRC_Countermeasure' and
           weapon.TargetRestrictOnlyAllow == 'TORPEDO'
end

function IsWeaponWithStunEffect(weapon)
    if weapon.DamageType == 'EMP' then
        return true
    elseif weapon.Buffs then
        for k, buff in weapon.Buffs or {} do
            if buff.BuffType and buff.BuffType == 'STUN' then
                return true
            end
        end
    else
        return false
    end
end

-- checks for dummy/insignificant weapons that are added in blueprints as hacks for missing weapon ranges
function IsWeaponDummyOrInsignificant(w)
    return GetWeaponDamage(w) <= 0
end

function IsWeaponSignificant(w)
    return GetWeaponDamage(w) > 0
end

function IsWeaponSniper(w)
    return w.MaxRadius >= 70 and
           w.Damage >= 500 and
           w.WeaponCategory == 'Direct Fire' and
           (w.RangeCategory == 'UWRC_DirectFire' or
            w.RangeCategory == 'UWRC_IndirectFire')
end

function IsWeaponDirectBomb(w)
    return IsWeaponWithTarget(w, 'Land') and
           w.RackReloadTimeout > 0 and
          (w.Label == 'GroundMissile' or 
           w.WeaponCategory == 'Kamikaze' or 
           w.WeaponCategory == 'Bomb')
           --w.BombDropThreshold > 0  
end

function IsWeaponTorpedoBomb(w)
    return w.RackReloadTimeout > 0 and
           w.WeaponCategory == 'Anti Navy' and 
           IsWeaponWithTarget(w, 'Sub')
end

function IsWeaponValid(w)
    -- skipping not important weapons, e.g. UEF shield boat fake weapon
    if w.WeaponCategory and
       w.WeaponCategory ~= 'Death' and
       w.WeaponCategory ~= 'Teleport' and
       w.Label ~= 'DeathImpact' and
       w.Label ~= 'HackPegLauncher' and -- skip megalith weapon used in missions
       w.Label ~= 'TargetPainter' and -- skip  targeting weapon in mobile AA weapon
       w.Label ~= 'AutoOverCharge' and -- skip duplicate OverCharge weapon
       GetWeaponDamage(w) > 0 then
        return true
    else
        return false
    end
end

-- checks if a weapon has target restriction, e.g. 'TORPEDO' or 'STRATEGIC,MISSILE' or 'TACTICAL,MISSILE'
function IsWeaponWithRestriction(w, csv)
    if not w.TargetRestrictOnlyAllow then return false end
    
    local restrictions = StringSplit(csv, ',')
    for _, str in restrictions or {} do
        if string.find(w.TargetRestrictOnlyAllow, str) then
            return true
        end
    end
    return false
end

-- checks if a weapon has target layer, e.g. 'Air' or Land|Water or 'Land|Water|Seabed' or 'Seabed|Sub|Water'
function IsWeaponWithTarget(w, layer)
    for k, caps in w.FireTargetLayerCapsTable or {} do
        if string.find(caps, layer) then
            return true
        end
    end
    return false
end

-- gets a list of Enhancements that are assigned while an unit is built, preset SCUs
function GetPresetEnhancements(bp)
    local ret = {} 
    if bp and bp.EnhancementPresetAssigned then 
        ret = bp.EnhancementPresetAssigned.Enhancements
    end
    return ret 
end
-- gets weapon damages based on types of weapons and delivery method
function GetWeaponsDamages(bp)
    local damages = {
        Artillery = 0,
        AntiAir = 0,
        AntiShield = 0,
        AntiNavy = 0,
        Direct = 0,
        Bomb = 0,
        TorpDef = 0,
        Defense = 0,
        Kamikaze = 0, 
        Sniper = 0,
        TML = 0, TMD = 0,
        SML = 0, SMD = 0,
        Total = 0, Other = 0,
    }
    for _, w in GetWeaponsWithDamage(bp, 1) do
        local weaponDamge = GetWeaponDamage(w)
        damages.Total = damages.Total + weaponDamge

        if IsWeaponArtillery(w) then
            damages.Artillery = damages.Artillery + weaponDamge
        elseif IsWeaponSniper(w) then
            damages.Sniper = damages.Sniper + weaponDamge
        elseif IsWeaponAntiShield(w) then
            damages.AntiShield = damages.AntiShield + weaponDamge
        elseif IsWeaponAntiAir(w) then
            damages.AntiAir = damages.AntiAir + weaponDamge
        elseif IsWeaponKamikaze(w) then
            damages.Kamikaze = damages.Kamikaze + weaponDamge
        elseif IsWeaponDirectBomb(w) then
            damages.Bomb = damages.Bomb + weaponDamge
        elseif IsWeaponTML(w) then
            damages.TML = damages.TML + weaponDamge
        elseif IsWeaponSML(w) then
            damages.SML = damages.SML + weaponDamge
        elseif IsWeaponTMD(w) then
            damages.TMD = damages.TMD + weaponDamge
        elseif IsWeaponSMD(w) then
            damages.SMD = damages.SMD + weaponDamge
        elseif IsWeaponTorpedo(w) then
            damages.AntiNavy = damages.AntiNavy + weaponDamge
        elseif IsWeaponTorpedoDefense(w) then
            damages.TorpDef = damages.TorpDef + weaponDamge
        elseif IsWeaponAntiMissile(w) then
            damages.Defense = damages.Defense + weaponDamge
        elseif IsWeaponDirectFire(w) or IsWeaponIndirectFire(w) then
            damages.Direct = damages.Direct + weaponDamge
        else
            damages.Other = damages.Other + weaponDamge
        end
    end
    return damages
end

-- gets weapons with target layer, e.g. 'Air' or Land|Water or 'Land|Water|Seabed' or 'Seabed|Sub|Water'
function GetWeaponsWithTargetLayer(bp, layer)
    if not layer then return false end
    local ret = {}
    for _, w in bp.Weapon or {} do
        if IsWeaponWithTarget(w, layer) then
            table.insert(ret, w)
        end
    end
    return ret
end

-- gets all weapons that can throw bombs only to water (torpedoes)
function GetWeaponsWithBombsTorpedo(bp)
    local ret = {} 
    if not IsUnitMobileAirWinged(bp) then return end
    if IsUnitMobileOrbital(bp) then return end
    
    -- finding torpedo bombs:
    for id, w in bp.Weapon or {} do
        if IsWeaponTorpedoBomb(w) then
            table.insert(ret, w)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets all weapons that can throw bombs only to surface only
function GetWeaponsWithBombsSurface(bp)
    local ret = {} 
    if not IsUnitMobileAirWinged(bp) then return end
    if IsUnitMobileOrbital(bp) then return end
    
    -- finding surface bombs:
    for id, w in bp.Weapon or {} do
        if IsWeaponDirectBomb(w) then
            table.insert(ret, w)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets all weapons that can throw bombs to surface or water (torpedoes)
function GetWeaponsWithBombs(bp)
    local ret = {} 
    if not IsUnitMobileAirWinged(bp) then return end
    if IsUnitMobileOrbital(bp) then return end

    for id, w in bp.Weapon or {} do
        if IsWeaponDirectBomb(w) or IsWeaponTorpedoBomb(w) then
            table.insert(ret, w)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets all weapons that have direct fire (no arc projectiles)
function GetWeaponsWithDirectFire(bp)
    local ret = {}
    if IsUnitMobileAir(bp) then return end

    for id, w in bp.Weapon or {} do
        if IsWeaponDirectFire(w) then 
            table.insert(ret, w) 
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets all weapons that can fire from air to ground while hover/circle above a target
function GetWeaponsWithGunship(bp, minDamage)
    local ret = {}
    if not IsUnitMobileAirCircling(bp) then return end
    if IsUnitMobileOrbital(bp) then return end

    if not minDamage then minDamage = 1 end
    for id, w in bp.Weapon or {} do
        if w.Damage > minDamage and IsWeaponDirectFire(w) then 
            table.insert(ret, w) 
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets all weapons that have artillery/indirect/arc projectiles
function GetWeaponsWithArtillery(bp)
    local ret = {}
    if IsUnitMobileAir(bp) then return end
    
     for _, w in bp.Weapon or {} do
          --    LOG('GetWeaponsWithArtillery Turreted' .. tostring(w.Turreted) )
   
        if w.Turreted and 
           w.WeaponCategory == 'Artillery' then
        --   LOG('GetWeaponsWithArtillery Artillery' )
            table.insert(ret, w)
        elseif w.Turreted  and
               w.RangeCategory == 'UWRC_IndirectFire'and 
               w.BallisticArc == 'RULEUBA_HighArc' then
         --  LOG('GetWeaponsWithArtillery RULEUBA_HighArc' )
            table.insert(ret, w)
        elseif w.Turreted and 
               w.RangeCategory == 'UWRC_IndirectFire' and 
               w.BallisticArc == 'RULEUBA_LowArc' and
               w.TurretPitch >= 30 then
        --   LOG('GetWeaponsWithArtillery RULEUBA_LowArc' )
            table.insert(ret, w)
        end 
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets all weapons with specified minimum damage or any damage
function GetWeaponsWithDamage(bp, minDamage)
    if not minDamage then minDamage = 0 end
    local weapons = {}
    for id, w in bp.Weapon or {} do
        if IsWeaponValid(w) and GetWeaponDamage(w) >= minDamage then
            table.insert(weapons, w)
        end
    end

    table.sort(weapons, function(a,b) return a.Damage > b.Damage end)
    return weapons
end


function GetWeaponsWithOvercharge(bp)
    local ret = {}
    for _, w in GetWeaponsWithDamage(bp) do 
        if IsWeaponOvercharge(w) then
            table.insert(ret, w)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

function GetWeaponsWithSniperDamage(bp)
    local ret = {}
    for _, w in GetWeaponsWithDamage(bp) do 
        if IsWeaponSniper(w) then
            table.insert(ret, w)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

function GetWeaponsWithAutoToggleAirAndLand(bp)
    local ret = {}
    for _, w in GetWeaponsWithDamage(bp) do 
        if (w.PreferPrimaryWeaponTarget or w.ToggleWeapon) and 
           (w.RangeCategory == 'UWRC_AntiAir' or
            w.RangeCategory == 'UWRC_DirectFire') then
            table.insert(ret, w)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets weapons that have area damage
function GetWeaponsWithAreaDamage(bp)
    local ret = {}
    for _, weapon in GetWeaponsWithDamage(bp) do 
        if weapon.WeaponCategory ~= 'Death' and 
           weapon.WeaponCategory ~= 'Teleport' and
           weapon.DamageRadius >= 1.5 and
           weapon.Damage > 1 then
            table.insert(ret, weapon)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets weapons that have special shield damage or can break shields 
function GetWeaponsWithShieldDamage(bp)
    local ret = {}
    for _, w in bp.Weapon or {} do 
        if IsWeaponValid(w) and not IsWeaponTML(w) and
           w.MaxRadius >= 70 and
          (w.RangeCategory == 'UWRC_DirectFire' and w.DamageToShields >= 200 or 
           w.RangeCategory == 'UWRC_IndirectFire' and w.DamageRadius >= 2) then
            table.insert(ret, w)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

function GetWeaponsWithTorpedoes(bp)
    local ret = {}
    for _, w in bp.Weapon or {} do
        if IsWeaponTorpedo(w) then
            table.insert(ret, w)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

function GetWeaponsWithTorpedoDefense(bp)
    local ret = {}
    for _, w in bp.Weapon or {} do 
        if IsWeaponTorpedoDefense(w) then
            table.insert(ret, w)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

function GetWeaponsWithDepthCharges(bp)
    local ret = {}
    for _, w in bp.Weapon or {} do 
        if IsWeaponDepthCharge(w) then
            table.insert(ret, w)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets weapons that have anti-air attack
function GetWeaponsWithAntiAir(bp)
    local ret = {}
    for _, weapon in bp.Weapon or {} do 
        if IsWeaponAntiAir(weapon) then
            table.insert(ret, weapon)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

function GetWeaponsWithKamikaze(bp)
    return GetWeaponsWithCategory(bp, 'Kamikaze')
end

-- gets weapons that require deployment before firing first shot
function GetWeaponsWithDeployment(bp)
    --if not bp.CategoriesHash.MOBILE then return false end
    local ret = {}
    for _, weapon in bp.Weapon or {} do 
        if weapon.WeaponUnpackLocksMotion == true then
            table.insert(ret, weapon)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

function GetWeaponsWithDefense(bp)
    local ret = {}
    for _, weapon in bp.Weapon or {} do 
        if IsWeaponValid(weapon) and
           IsWeaponDefensive(weapon) then
            table.insert(ret, weapon)
        end
    end 
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

function GetWeaponsWithOffense(bp)
    local ret = {}
    for _, weapon in bp.Weapon or {} do 
        if IsWeaponValid(weapon) and not 
           IsWeaponDefensive(weapon) then
            table.insert(ret, weapon)
        end
    end 
    -- return only if found some weapons
    if table.size(ret) > 0 then
        table.sort(ret, function(a,b) return a.Damage > b.Damage end)
        return ret 
    end
end

-- gets weapons that have tactical missile launcher (TML)
function GetWeaponsWithTML(bp)
    local ret = {}
    for _, weapon in bp.Weapon or {} do 
        if IsWeaponTML(weapon) then
            table.insert(ret, weapon)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets weapons that have tactical missile defense (TMD)
function GetWeaponsWithTMD(bp)
    local ret = {}
    for _, weapon in bp.Weapon or {} do 
        if IsWeaponTMD(weapon) then
            table.insert(ret, weapon)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets weapons that have strategic missile defense (SMD)
function GetWeaponsWithSMD(bp)
    local ret = {}
    for _, weapon in bp.Weapon or {} do 
        if IsWeaponSMD(weapon) then
            table.insert(ret, weapon)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets weapons that have anti missiles (SMD and TMD)
function GetWeaponsWithAntiMissile(bp)
    local ret = {}
    for _, weapon in bp.Weapon or {} do 
        if IsWeaponTMD(weapon) or
           IsWeaponSMD(weapon) then
            table.insert(ret, weapon)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets weapons that have strategic missile launcher (SML)
function GetWeaponsWithSML(bp)
    local ret = {}
    for _, weapon in bp.Weapon or {} do 
        if IsWeaponSML(weapon) then
            table.insert(ret, weapon)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets weapons that require manual launch from an user (SML)
function GetWeaponsWithManualLaunch(bp)
    local ret = {}
    for _, w in bp.Weapon or {} do
        if w.ManualFire and w.WeaponCategory == 'Missile' then
            table.insert(ret, w)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets weapons that can store projectiles in silo, e.g. SMD, SML, TML
function GetWeaponsWithSiloStorage(bp)
    local ret = {}
    for _, weapon in GetWeaponsWithDamage(bp) or {} do 
        if weapon.MaxProjectileStorage > 0 then
            table.insert(ret, weapon)
        end
    end 
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets weapons with weapon category ('Direct Fire') or nil
function GetWeaponsWithCategory(bp, category)
    local ret = {}
    for _, w in bp.Weapon or {} do
        if w.WeaponCategory == category then
            table.insert(ret, w)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

-- gets weapons with range category ('UWRC_DirectFire') or nil
function GetWeaponsWithRange(bp, category)
    local ret = {}
    for _, w in bp.Weapon or {} do 
        if w.RangeCategory == category then
            table.insert(ret, w)
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end

function GetWeaponsCategories(bp)
    local ret = {}
    for _, w in bp.Weapon or {} do 
        if w.WeaponCategory ~= 'Death' then
            table.insert(ret, w.WeaponCategory or 'nil')
        end
    end
    return table.concat(ret, ', ')
end
 
function GetWeaponsRanges(bp)
    local ret = {}
    for _, weapon in bp.Weapon or {} do 
        if weapon.WeaponCategory ~= 'Death' then
            table.insert(ret, weapon.RangeCategory)
        end
    end
    return table.concat(ret, ', ')
end


function GetWeaponsWithStunEffect(bp)
    local ret = {}
    for _, weapon in bp.Weapon or {} do 
        if IsWeaponWithStunEffect(weapon) then
            table.insert(ret, weapon)
        -- elseif weapon.Buffs then
        --     for k, buff in weapon.Buffs or {} do
        --         if buff.BuffType and buff.BuffType == 'STUN' then
        --             table.insert(ret, weapon)
        --             break -- and continue with other weapons
        --         end
        --     end
        end
    end
    -- return only if found some weapons
    if table.size(ret) > 0 then return ret end
end


-- gets primary weapon in a given blueprint (excludes Overcharge weapon)
function GetWeaponPrimary(bp)
    for id, w in bp.Weapon or {} do
        if IsWeaponPrimary(w) then
           return w
        end
    end
    return bp.Weapon and bp.Weapon[1] or nil
end
-- gets a weapon by with specified display name
function GetWeaponWithName(bp, name)
    if not bp then return end
    if not name then return end
    for _, w in bp.Weapon or {} do
        -- not matching localization key in DisplayName
        if w.DisplayName and StringEnds(w.DisplayName, name) then
            return w
        end
    end
end
-- gets a weapon with specified label
function GetWeaponWithLabel(bp, label)
    if not bp then return end
    if not label then return end
    for _, w in bp.Weapon or {} do
        if w.Label == label then
            return w
        end
    end
end
-- gets a weapon enabled by upgrade ID
function GetWeaponEnabledByUpgrade(bp, upgradeID)
    if not bp then return end
    if not upgradeID then return end
    local id = string.lower(upgradeID)
    for _, w in bp.Weapon or {} do
        if string.lower(w.EnabledByEnhancement or '') == id or
           string.lower(w.DamageType or '') == id or
           string.lower(w.Label or '') == id then
            return w
        end
    end
end
-- gets a list of installed weapons including default weapons and preset weapons if any
function GetWeaponsInstalled(bp)
    if not bp then return end

    local weaponsWithDamage = GetWeaponsWithDamage(bp)
    local weaponsAdded = {} -- track IDs of already added weapons to avoid duplicates
    local weaponsInstaled = {}
     
    if not bp.Enhancements then 
        -- WARN('GetWeaponsInstalled all ' .. table.size(weaponsWithDamage))
        return weaponsWithDamage
    else  
        -- first, check for regular, main, or non-preset weapons
        for id, w in weaponsWithDamage do 
            if not bp.Enhancements[w.EnabledByEnhancement] and
               not bp.Enhancements[w.DamageType] and
               not bp.Enhancements[w.Label] then
               if not weaponsAdded[id] then
                    weaponsAdded[id] = true
                    table.insert(weaponsInstaled, w)
                    -- WARN('GetWeaponsInstalled regular ' .. w.DisplayName)
               end
            end
        end
        -- secondly, check for preset weapons, e.g. 'url0301_AntiAir' SCU
        -- this way, preset weapons are added after regular weapons
        local presets = table.hash(GetPresetEnhancements(bp))
        for id, w in weaponsWithDamage do
            if presets[w.EnabledByEnhancement] or
               presets[w.DamageType] or
               presets[w.Label] then 
               if not weaponsAdded[id] then
                    weaponsAdded[id] = true
                    table.insert(weaponsInstaled, w)
                    -- WARN('GetWeaponsInstalled preset ' .. w.DisplayName)
               end
            end
        end 
    end
    return weaponsInstaled
end



function GetWeaponDisplayTitle(bp, weapon)

    return string.format("%s (%s)", weapon.Category, weapon.DisplayName)
    
end
 

-- gets weapon's defaults that are common to all types of weapons defaults from passed blueprint and weapon table
function GetWeaponDefaults(bp, w)
    local category = w.WeaponCategory or '<MISSING_WeaponCategory>'
    local range = w.RangeCategory or '<MISSING_RangeCategory>'
    -- copying weapons stats to prevent modification of values
    local weapon = table.deepcopy(w)
    
    local name = w.DisplayName or '<MISSING_DisplayName>'
     
    if IsWeaponAntiShield(w) then
       weapon.Group = 'Anti Shield'
    elseif IsWeaponAntiNavy(w) then
       weapon.Group = 'Anti Navy'
    elseif IsWeaponAntiAir(w) then
       weapon.Group = 'Anti Air'
    elseif IsWeaponIndirectFire(w) then
       weapon.Group = 'Indirect Fire'
    elseif IsWeaponDirectFire(w) or IsWeaponSML(w) or IsWeaponKamikaze(w) then
       weapon.Group = 'Direct Fire'
    elseif IsWeaponDefensive(w) then
       weapon.Group = 'Defense'
    else
       WARN('Cannot find a group for a weapon category: '.. category  .. ' (' .. name  .. ')')
       weapon.Group = 'Unknown'
    end
    
    weapon.Title = string.format("%s (%s)", weapon.Group, weapon.DisplayName)
    --if IsWeaponKamikaze(w) or IsWeaponIndirectFire(w) then 
    --   weapon.Title = string.format("%s (%s)", w.WeaponCategory, weapon.DisplayName)
    --else
    --   weapon.Title = string.format("%s (%s)", w.Group, weapon.DisplayName)
    --end

    
    -- initializing specs that will be calculated based on weapon's type
    weapon.Specs = ''
    weapon.DPS = 0 -- damage per shot per second
    weapon.DPM = 0 -- damage potential per mass
    weapon.DamageTotal = 0
    weapon.StunRadius = 0
    weapon.BuildCycle = 0 

--    -- commanders are not buildable so default to 1 for build costs
--    if bp.CategoriesHash.COMMAND then
--        weapon.BuildCostEnergy = 1 -- using 1 to prevent division by 0
--        weapon.BuildCostMass = 1 -- using 1 to prevent division by 0
--        weapon.BuildRate = bp.Economy.BuildRate or 0
--        weapon.BuildTime = 0 -- not including built time of the unit
--    else
--        weapon.BuildCostEnergy = bp.Economy.BuildCostEnergy or 1
--        weapon.BuildCostMass = bp.Economy.BuildCostMass or 1
--        weapon.BuildRate = bp.Economy.BuildRate or 0
--        weapon.BuildTime = 0 -- not including built time of the unit
--    end
    
    weapon.BuildCostEnergy = 0
    weapon.BuildCostMass = 0
    weapon.BuildRate = 0
    weapon.BuildTime = 0

    weapon.FireShots = GetWeaponShots(weapon)
    weapon.FireCycle = GetWeaponCycle(weapon)
    weapon.Count = 1
    weapon.Range = math.round(w.MaxRadius or 0)
    weapon.Multi = GetWeaponMultiplier(weapon)
    weapon.Damage = GetWeaponDamage(w)
    weapon.DamageRadius = GetWeaponDamageRadius(w)
    -- calculate area of circle PI * R * R but first divide radius by smallest unit size
    -- because units do not usually stack on top of each other
    --weapon.DamageArea = math.pi * math.pow(weapon.DamageRadius / 2, 2)

    --weapon.DamageArea = weapon.Multi * math.pow(weapon.DamageRadius, 3)
     
    if weapon.DamageRadius <= 1 then 
       weapon.DamageArea = 1 
    else
        --weapon.DamageArea = 3.14 * math.pow(weapon.DamageRadius, 2)
        weapon.DamageArea = math.pow(weapon.DamageRadius, 3)
        --weapon.DamageArea = math.pow(weapon.DamageRadius, 2)
    end
    
    -- some weapons have multiple projectiles so damage area is multiplied
    -- e.g. T4 Aeon Rapid Arty (Salvation) has 36 projectiles
    weapon.DamageArea = weapon.FireShots * weapon.DamageArea
     
    --if weapon.Multi > 1 then
    --    LOG('GetWeaponDefaults '.. weapon.DisplayName .. ' weapon.Multiplier ' .. weapon.Multi)
    --end
    --if weapon.FireShots > 1 then
    --    LOG('GetWeaponDefaults '.. weapon.DisplayName .. ' weapon.FireShots ' .. weapon.FireShots)
    --end

--    if weapon.FireCycle > 1 then
--        LOG('Defaults '.. weapon.DisplayName .. ' weapon.FireCycle ' .. weapon.FireCycle)
--    end
--    LOG( ' R=' .. string.format("%01.1f", weapon.DamageRadius) ..
--         ' A=' .. string.format("%01.1f", math.pi * math.pow(weapon.DamageRadius, 2)) ..
--         ' A=' .. string.format("%01.1f", math.pi * math.pow(weapon.DamageRadius / 2, 2)) ..
--         ' A=' .. string.format("%01.1f", weapon.DamageArea) )

    --weapon.TotalCycle = weapon.FireCycle
    --weapon.RPS = GetWeaponCycle(w)
    --weapon.RPS = GetWeaponRatePerSecond(w)
    --LOG(weapon.Title.. ' weapon.Cycle ' .. weapon.Cycle .. ' weapon.RPS ' .. weapon.RPS)
    return weapon
end

-- gets weapon's damage amount for standard weapon or nuke weapon
function GetWeaponDamage(weapon)
    local damage = 0
    if weapon.NukeWeapon or weapon.NukeInnerRingDamage > 0 then
        -- stack nuke damages from inner and outer rings
        damage = (weapon.NukeInnerRingDamage or 0)
        damage = (weapon.NukeOuterRingDamage or 0) + damage
    elseif weapon.DamageToShields > 0 then 
        damage = weapon.DamageToShields or 0
    elseif weapon.Damage > 0 then 
        damage = weapon.Damage or 0
    end
    return damage
end
-- gets weapon's damage radius or area of effect (AOE)
function GetWeaponDamageRadius(weapon)
    local radius = 0
    if weapon.NukeWeapon then 
        -- nuke stack damages so use inner radius
        radius = weapon.NukeInnerRingRadius or 1
    elseif weapon.DamageRadius > 0 then -- weapon with AOE
        radius = weapon.DamageRadius
    else 
        radius = 1
       -- WARN('GetWeaponDamageRadius ' .. tostring(weapon.DamageRadius))
    end
    return radius
end

-- Multipliers table is needed to properly calculate split projectiles.
-- Unfortunately, these numbers are not available in the blueprints
-- because they are hard-coded in .lua files of corresponding projectiles.
local ProjMultipliers = { }
-- these projectiles have hard-coded multipliers in .lua files
ProjMultipliers['/projectiles/SIFThunthoArtilleryShell01/SIFThunthoArtilleryShell01_proj.bp'] = 6 -- Zthuee
ProjMultipliers['/projectiles/TIFFragmentationSensorShell01/TIFFragmentationSensorShell01_proj.bp'] = 5 -- Lobo
ProjMultipliers['/projectiles/CIFBrackmanHackPegs01/CIFBrackmanHackPegs01_proj.bp'] = 9  -- Megabot's campaign weapon
ProjMultipliers['/projectiles/CIFBrackmanHackPegs01/CIFBrackmanHackPegs02_proj.bp'] = 50 -- some unit?
ProjMultipliers['/projectiles/AIFFragmentationSensorShell01/AIFFragmentationSensorShell01_proj.bp'] = 36 -- Salvation
ProjMultipliers['/projectiles/AIFFragmentationSensorShell02/AIFFragmentationSensorShell02_proj.bp'] = 5 -- used by some unit?
ProjMultipliers['/projectiles/AIFQuanticCluster01/AIFQuanticCluster01_proj.bp'] = 9 -- which unit?
ProjMultipliers['/projectiles/AIFQuanticCluster02/AIFQuanticCluster02_proj.bp'] = 4 -- which unit?
-- these projectiles have damage divided among number of projectiles but total damage is the same
ProjMultipliers['/projectiles/SANHeavyCavitationTorpedo01/SANHeavyCavitationTorpedo01_proj.bp'] = 1 -- 3
ProjMultipliers['/projectiles/SANHeavyCavitationTorpedo02/SANHeavyCavitationTorpedo02_proj.bp'] = 1 -- 3
ProjMultipliers['/projectiles/AIFGuidedMissile01/AIFGuidedMissile01_proj.bp'] = 1 -- 8

-- gets weapon's projectile multiplier or default to one
-- note that weapon.ProjectilesPerOnFire is not used at all in FA game!
function GetWeaponMultiplier(weapon) 
    local multiplier = 1 -- default multiplier
    if not weapon.ProjectileId then return 1 end

    for key, value in ProjMultipliers do
        if string.lower(key) == string.lower(weapon.ProjectileId) then
            multiplier = value 
            break
        end
    end
    -- checks if a weapon has multiple projectiles shot at same time
    --if weapon.MuzzleSalvoSize > 1 then
    --   multiplier = multiplier * weapon.MuzzleSalvoSize
    --end

    return multiplier 
end

-- gets weapon's number of shots
function GetWeaponShots(weapon)
    local salvoSize  = weapon.MuzzleSalvoSize or 1
    local salvoDelay = weapon.MuzzleSalvoDelay or 1
    
    if salvoDelay > 0 then
       salvoDelay = salvoDelay - 0.1 -- offsetting by game tick delay
    end

    salvoDelay = math.round(salvoDelay * 10) / 10
    salvoSize  = math.round(salvoSize  * 10) / 10
      -- LOG('shots salvoDelay  ' .. salvoDelay)
      -- LOG('shots salvoSize  ' .. salvoSize)

    local rackCount  = table.size(weapon.RackBones)
    local rackMuzzles = 0
    if weapon.RackBones and 
       weapon.RackBones[1] and 
       weapon.RackBones[1].MuzzleBones then
       rackMuzzles = table.size(weapon.RackBones[1].MuzzleBones)
    end

    local shots = 1 --weapon.ManualFire and 1 or 0
    if weapon.ManualFire then
        shots = 1
    elseif weapon.MuzzleSalvoDelay == 0 then
       --LOG('shots rackMuzzles  ' .. rackMuzzles)
       --shots = shots + rackMuzzles
       shots = rackMuzzles
    end

    if IsWeaponWithMultipleShots(weapon) then
        --LOG('shots IsWeaponWithMultipleShots')
        if salvoDelay == 0 then
            --LOG('shots rackMuzzles  ' .. rackMuzzles)
            shots = rackMuzzles
            if weapon.RackFireTogether then
                shots = shots * rackCount
                --LOG('shots *rackCount RackFireTogether ' .. rackCount)
            end
        else 
            --LOG('shots salvoSize  ' .. rackMuzzles)
            shots = salvoSize
            if weapon.RackFireTogether then
                --LOG('shots *rackCount salvoSize  ' .. rackCount)
                shots = shots * rackCount
            end
        end
        
        --LOG('shots ProjectileId ' .. weapon.ProjectileId)
        local multiplier = GetWeaponMultiplier(weapon)
        if multiplier > 1 then
            shots = multiplier
            --LOG('shots ProjectileId ' .. weapon.ProjectileId .. ' = ' .. shots)
            --table.print(ProjMultipliers,'ProjMultipliers')
        end
        --LOG('shots IsWeaponWithMultipleShots ' .. shots)
    end
    --LOG('GetWeaponShots ' .. shots)
    return shots
end
-- gets weapon's shots per second (inverse of RateOfFire)
function GetWeaponRatePerSecond(weapon)
    local rate = weapon.RateOfFire or 1
    return math.round(10 / rate) / 10 -- Ticks per second
end
-- gets weapon's fire cycle time (in seconds) between shots
function GetWeaponCycle(weapon)

    local shots = weapon.FireShots or GetWeaponShots(weapon)
    local rate = weapon.RateOfFire or 1
    --local cycle = 1 / rate 
    local cycle = 1 / rate 

    if IsWeaponWithMultipleShots(weapon) then
        --LOG('cycle IsWeaponWithMultipleShots ' .. weapon.Title)
        if weapon.RateOfFire ~= 1 then
            if weapon.WeaponCategory == 'Kamikaze' then
                cycle = 1;
            end

        elseif weapon.RackSalvoReloadTime and 
               weapon.RackSalvoReloadTime ~= 0 then
            --LOG('cycle RackSalvoReloadTime ' .. tostring(weapon.RackSalvoReloadTime))
            local salvoCharge = 0
            if weapon.RackSalvoChargeTime ~= 0 then
                --LOG('cycle RackSalvoChargeTime ' .. tostring(weapon.RackSalvoChargeTime))
                salvoCharge = math.floor(weapon.RackSalvoReloadTime / weapon.RackSalvoChargeTime)
                --LOG('cycle salvoCharge ' .. tostring(salvoCharge))
            end

            local salvoReload = 0
            if weapon.RackSalvoChargeTime > weapon.RackSalvoReloadTime then
                salvoReload = weapon.RackSalvoChargeTime
            else
                salvoReload = weapon.RackSalvoReloadTime + salvoCharge
            end 
            --LOG('cycle salvoReload ' .. tostring(salvoReload))
            local salvoDelay = weapon.MuzzleSalvoDelay or 1
            if salvoDelay > 0 then
               salvoDelay = salvoDelay - 0.1 -- offsetting by game tick delay
            end
            salvoDelay = math.round(salvoDelay * 10) / 10
            --LOG('cycle salvoDelay ' .. tostring(salvoDelay))
            --LOG('cycle rate ' .. tostring(rate))
            --cycle = salvoReload + salvoDelay + (rate * shots)

            -- calculate duration of projectiles salvo for all shots
            local salvoDuration = salvoDelay * shots
            --cycle = rate + salvoReload + salvoDuration
            cycle = cycle + salvoReload + salvoDuration
            --LOG('cycle ' .. tostring(cycle))
        elseif weapon.RackSalvoChargeTime > 0 then
            --LOG('cycle RackSalvoChargeTime ' .. tostring(weapon.RackSalvoChargeTime))
            cycle = cycle + weapon.RackSalvoChargeTime
        end
    end 
     
    -- check if a weapon needs to unpack - play/spin weapon animation before firing, e.g. TML, Nuke
    if weapon.WeaponUnpacks and (IsWeaponTML(weapon) or IsWeaponSML(weapon)) then  
        local repackTime = weapon.WeaponRepackTimeout or 0
        local repackRate = weapon.WeaponUnpackAnimationRate or 1
        local repackDuration = repackTime * repackRate
        cycle = cycle + repackDuration
        --cycle = cycle + 2.5 -- repack delay 
        --LOG('cycle WeaponUnpacks ' .. cycle .. ' repackDuration ' .. repackDuration)
    end
    
    -- check if a weapon needs adjustment by MuzzleChargeDelay 
    if weapon.MuzzleChargeDelay > 0 then
        cycle = cycle + weapon.MuzzleChargeDelay
        --LOG('cycle MuzzleChargeDelay ' .. weapon.MuzzleChargeDelay)
    end

    -- round to the smallest game tick (0.1 seconds) because game ignores
    -- weapons with firing cycle that has fraction smaller than 0.1 seconds
    cycle = math.round(10 * cycle) / 10

    --LOG('GetWeaponCycle ' .. cycle)
    return cycle
end
  
-- gets weapon's specs of projectile type
function GetWeaponProjectile(bp, weapon)

    -- lookup projectile's multiplier that are hard coded in lua files
    weapon.Multi = GetWeaponMultiplier(weapon)
     
    -- these projectiles have eco cost but the game is not using them so
    -- we need to skip them when calculating Damage Per Mass
    local skipProjectiles = {
        -- xss0202 SERA T2 Cruiser
        ['/projectiles/siflaansetacticalmissile02/siflaansetacticalmissile02_proj.bp'] = true,
        -- xss0303 SERA Aircraft Carrier
        ['/projectiles/siflaansetacticalmissile03/siflaansetacticalmissile03_proj.bp'] = true
    }

    local projID = string.lower(weapon.ProjectileId or '')
   -- WARN('GetWeaponProjectile ' .. projID)
    local proj = Blueprints.Projectiles[projID]
    --LOG('Blueprints.Projectiles '.. table.size(Blueprints.Projectiles) )
       -- table.print(bp.CategoriesHash, 'bp.CategoriesHash ' )
       
    -- table.print(proj.Economy, 'proj ' )

    -- check if weapon's projectile costs some resources to use, e.g. Nukes
    -- and if so then update weapon's rate of fire base on projectile built time
    if proj and proj.Economy then
      --  WARN('GetWeaponProjectile proj.Economy ' )
 
        --table.print(bp.Economy, 'bp ' )
  -- table.print(bp.CategoriesHash, 'bp.CategoriesHash ' )
   
        -- get 
        if bp.CategoriesHash['STRUCTURE'] or bp.CategoriesHash['COMMAND'] then
          --   WARN('GetWeaponProjectile STRUCTURE   ' .. bp.ID)
         --     WARN('GetWeaponProjectile STRUCTURE   ' .. tostring(weapon.BuildCostMass))
          --       WARN('GetWeaponProjectile STRUCTURE   ' .. tostring(proj.Economy.BuildCostMass))
--WARN('GetWeaponProjectile  EnergyDrainPerSecond ' .. tostring(weapon.EnergyDrainPerSecond) )
            --table.print(proj.Economy, bp.Type ..' ' .. (proj.Description or ' '))
         --   weapon.BuildCostEnergy = proj.Economy.BuildCostEnergy or 1
         --   weapon.BuildCostMass = proj.Economy.BuildCostMass or 1
         --   weapon.BuildTime = proj.Economy.BuildTime or 0
         --   weapon.BuildRate = bp.Economy.BuildRate or 0
        
            if proj.Economy.BuildCostMass > 0 then
                weapon.BuildCostMass = proj.Economy.BuildCostMass 
            end
            if proj.Economy.BuildCostEnergy > 0 then
                weapon.BuildCostEnergy = proj.Economy.BuildCostEnergy
            end
            if proj.Economy.BuildTime > 0 then
                weapon.BuildTime = proj.Economy.BuildTime
                weapon.BuildRate = bp.Economy.BuildRate
                -- calculating drain of resources for building nukes/TML etc.
                weapon.DrainPerSecondRate = weapon.BuildTime / weapon.BuildRate
                weapon.DrainPerSecondMass = weapon.BuildCostMass / weapon.DrainPerSecondRate
                weapon.DrainPerSecondEnergy = weapon.BuildCostEnergy / weapon.DrainPerSecondRate
            end
             
           
        elseif not skipProjectiles[projID] then

          --WARN('GetWeaponProjectile UNIT   ' .. bp.ID)
            if proj.Economy.BuildCostMass > 0 then
                weapon.BuildCostMass = proj.Economy.BuildCostMass 
            end
            if proj.Economy.BuildCostEnergy > 0 then
                weapon.BuildCostEnergy = proj.Economy.BuildCostEnergy
            end
            
            if proj.Economy.BuildTime > 0 then
                weapon.BuildTime = proj.Economy.BuildTime
                weapon.BuildDuration = proj.Economy.BuildTime / (bp.Economy.BuildRate or 1)
            end  
             --  table.print(proj.Economy, bp.Type ..' ' .. (proj.Description or ' '))
            --weapon.BuildCostEnergy = proj.Economy.BuildCostEnergy or 0
            --weapon.BuildCostMass = proj.Economy.BuildCostMass or 0
             
        --    weapon.BuildCostEnergy = weapon.BuildCostEnergy + (proj.Economy.BuildCostEnergy or 0)
        --    weapon.BuildCostMass = weapon.BuildCostMass + (proj.Economy.BuildCostMass or 0)
        end

        -- check if weapon's projectiles require build time
        if proj.Economy.BuildCostMass > 0 and
           proj.Economy.BuildTime and bp.Economy.BuildRate then
            -- calculate rate per second based on unit's build rate and projectile build time
            -- weapon.RPS = proj.Economy.BuildTime / bp.Economy.BuildRate
            weapon.BuildCycle = proj.Economy.BuildTime / bp.Economy.BuildRate
            -- append rate per second with weapon's firing cycle
            weapon.FireCycle = weapon.FireCycle + weapon.BuildCycle
            --LOG('weapon.BuildCost FireCycle ' .. weapon.FireCycle ..'s') 
            --LOG('weapon.BuildCost BuildCycle ' .. weapon.BuildCycle ..'s')
        end
    end
    
    --weapon.DamageTotal = weapon.Multi * weapon.Damage
    weapon.DamageTotal = weapon.FireShots * weapon.Damage
    weapon.DPS = weapon.DamageTotal / weapon.FireCycle
 
    return weapon
end

-- gets weapon's specs with beam pulses, e.g. CYBRAN TMD Zapper (urb4201), SERA T2 destroyer (xss0201)
-- note this function is more correct than spooky's DPS calculation
function GetWeaponBeamPulse(bp, weapon)
    --LOG('GetWeaponBeamPulse ' .. bp.ID .. ' ' .. weapon.Title )
    
    -- fire rate is always rounded to 1 decimal place because 
    -- game runs in 0.1 ticks per second and any fraction (0.05) is rounded
    local rate = weapon.RateOfFire or 1
    rate = math.round(rate * 10) / 10
    -- weapon.FireCycle = 1 / rate
    --LOG(' GetWeaponBeamPulse rate ' .. rate .. '  rr ' .. rr  .. '  cycle2 ' .. cycle2 )

    if not weapon.BeamLifetime then
        WARN('GetWeaponBeamPulse cannot find weapon.BeamLifetime ' .. bp.ID .. ' ' .. weapon.Title)
    elseif weapon.BeamCollisionDelay > 0 then
       -- example: CYBRAN TMD Zapper (urb4201)
       --LOG('GetWeaponBeamPulse '.. weapon.Title .. ' Delay collision=' .. tostring(weapon.BeamCollisionDelay) )

       -- calculating number of beam pulses
       local duration  = weapon.BeamLifetime or 1 -- in seconds
       duration = duration + 0.1 -- adjust for BeamLifetimeThread delay
       --LOG('GetWeaponBeamPulse '.. weapon.Title .. ' Delay duration=' .. tostring(duration) )

       local interval = weapon.BeamCollisionDelay or 1 -- in seconds
       interval = interval + 0.1 -- adjust for thread delay
       --LOG('GetWeaponBeamPulse '.. weapon.Title .. ' Delay interval=' .. tostring(interval) )
       
       --LOG('GetWeaponBeamPulse '.. weapon.Title .. ' Delay d/i=' .. tostring(duration / interval) )
       local pulses = math.floor(duration / interval)
       --LOG('GetWeaponBeamPulse '.. weapon.Title .. ' Delay pulses=' .. tostring(pulses) )
       weapon.Multi = pulses * weapon.FireShots 

       --LOG('GetWeaponBeamPulse '.. weapon.Title .. ' Delay pulses ' .. tostring(weapon.Multi) .. '  TD ' .. tostring(weapon.DamageTotal))
    elseif weapon.BeamLifetime > 0 then
       -- example: SERA T2 PD (xsb2301), SERA destroyer (xss0201)

       -- calculating number of beam pulses 
       local duration = weapon.BeamLifetime or 1 -- in seconds
       duration = duration + 0.1 -- adjust for BeamLifetimeThread delay
       local pulses = duration * 10 -- 10 ticks per second

       -- there is one tick before stopping beam in BeamLifetimeThread in DefaultWeapon.lua
       -- so we need to add on pulse for the beam
       --pulses = pulses + 1 
       --pulses = pulses * weapon.FireShots
       weapon.Multi = pulses * weapon.FireShots  
       --LOG('GetWeaponBeamPulse '.. weapon.Title .. ' beam ' .. tostring(weapon.BeamLifetime) .. '  pulses ' .. tostring(pulses) .. '  shots ' .. tostring(weapon.FireShots))
    end

    weapon.DamageTotal = weapon.Multi * weapon.Damage
    weapon.DPS = weapon.DamageTotal / weapon.FireCycle
    weapon.DPS = math.round(weapon.DPS)
    
    --LOG('GetWeaponBeamPulse '.. weapon.Title .. ' Multi ' .. tostring(weapon.Multi) .. '  FS ' .. tostring(weapon.FireShots) .. '  D ' .. tostring(weapon.Damage) .. '  TD ' .. tostring(weapon.DamageTotal))
    --LOG('GetWeaponBeamPulse '.. weapon.Title .. ' DPS ' .. tostring(weapon.DPS) .. '  FC ' .. tostring(weapon.FireCycle))

    return weapon
end
-- gets weapon's specs with continuous beam, e.g. CYBRAN Microwave Laser, AEON GC EyeWeapon
function GetWeaponBeamContinuous(bp, weapon)
    --LOG('GetWeaponBeamContinuous ' .. bp.ID .. ' ' .. weapon.Title )
    if not weapon.ContinuousBeam then
        WARN('GetWeaponBeamContinuous cannot find weapon.ContinuousBeam ' .. weapon.Title)
    else 
       weapon.Multi = 10 -- ticks per second
       weapon.DamageTotal = weapon.Multi * weapon.Damage
       weapon.FireCycle = weapon.BeamCollisionDelay == 0 and 1 or 2
       weapon.DPS = weapon.DamageTotal / weapon.FireCycle
       weapon.DPS = math.round(weapon.DPS)
       
--       LOG(weapon.Title .. ' GetWeaponBeamContinuous Multi ' .. tostring(weapon.Multi) .. '  D ' .. tostring(weapon.Damage) .. '  TD ' .. tostring(weapon.DamageTotal))
--       LOG(weapon.Title .. ' GetWeaponBeamContinuous DPS ' .. tostring(weapon.DPS) .. '  FC ' .. tostring(weapon.FireCycle))
    end
    return weapon
end
-- gets specs for a weapon with dots per pulses, e.g. HARMS Nanite Torpedo, Emissary
function GetWeaponDOT(bp, weapon)
    if not weapon.DoTPulses then
        WARN('GetWeaponDOT cannot find weapon.DoTPulses ' .. weapon.Title)
    else
        weapon.Multi = weapon.FireShots * (weapon.DoTPulses or 1) 
        weapon.DamageTotal = weapon.Multi * weapon.Damage 
        weapon.DPS = weapon.DamageTotal / weapon.FireCycle 
        weapon.DPS = math.round(weapon.DPS)
        -- e.g. HARMS 375 DPS (22480 damage over 60s) 
        --LOG('GetWeaponDOT '.. weapon.Title .. ' Salvo ' .. tostring(weapon.MuzzleSalvoSize) .. '  DoTPulses ' .. tostring(weapon.DoTPulses) .. '  TD ' .. tostring(weapon.DamageTotal))
        --LOG('GetWeaponDOT '.. weapon.Title .. ' Multi ' .. tostring(weapon.Multi) .. '  D ' .. tostring(weapon.Damage) .. '  TD ' .. tostring(weapon.DamageTotal))
        --LOG('GetWeaponDOT '.. weapon.Title .. ' DPS ' .. tostring(weapon.DPS) .. '  FC ' .. tostring(weapon.FireCycle))
    end
    return weapon
end

-- gets specs for a weapon
function GetWeaponEMP(bp, weapon)
    if not weapon.DamageType == 'EMP' then
        WARN('GetWeaponEMP cannot find weapon.DamageType ' .. weapon.Title)
    else
       weapon.DamageTotal = weapon.Damage
       weapon.DPS = weapon.DamageTotal / weapon.FireCycle
       weapon.DPS = math.round(weapon.DPS)
       if not bp.Buffs or not bp.Buffs.Stun then
            WARN('GetWeaponEMP cannot find bp.Buffs.Stun table ' .. weapon.Title)
       else
            weapon.StunTime = bp.Buffs.Stun.Duration or 1
            weapon.StunRadius = bp.Buffs.Stun.Radius or 1
            weapon.StunRadius = math.max(weapon.StunRadius, weapon.DamageRadius)
       end
    end
    return weapon
end
 

-- gets specs for a given weapon and its index in bp.Weapon table
function GetSpecsForWeapons(bp, w, wIndex)
    local weapon = GetWeaponDefaults(bp, w)

    weapon.WeaponId = wIndex
    weapon.UniqueId = 'r_' .. weapon.Range .. '_d_' .. w.Damage .. '_id_' .. wIndex

    --LOG(' '..bp.ID .. ' weapon.DPS ' .. tostring(weapon.DPS) .. '   ' .. type(weapon.DPS))
    --LOG(' '..bp.ID .. ' weapon.MC ' .. tostring(weapon.BuildCostMass) .. '   ' .. type(weapon.BuildCostMass))
    --LOG('GetSpecsForWeapons '..bp.ID .. ' WeaponCategory ' .. tostring(weapon.WeaponCategory))
    
    if w.WeaponCategory == 'Kamikaze' then
        weapon.FireMode = 'Kamikaze'
        weapon.DamageTotal = w.Damage
        weapon.DPS = w.Damage --/ 1 --0 -- this will hide DPS for Kamikaze weapons
        if not weapon.RangeCategory or weapon.RangeCategory == 'UWRC_Undefined'  then
            weapon.RangeCategory = 'UWRC_DirectFire'
        end
    elseif w.DoTPulses then
        weapon = GetWeaponDOT(bp, weapon)
        weapon.FireMode = 'DoTPulses'
    elseif weapon.BeamLifetime == 0 and weapon.ContinuousBeam then
        weapon = GetWeaponBeamContinuous(bp, weapon)
        weapon.FireMode = 'BeamContinuous'
    elseif weapon.BeamLifetime == 0 and weapon.WeaponCategory == 'Experimental' then
        --weapon = GetWeaponEMP(bp, weapon)
        weapon.FireMode = 'BeamTractor'
        --LOG(weapon.Label.. ' ' .. weapon.FireMode)
    --else if weapon.BeamLifetime == 1 then
    elseif weapon.BeamLifetime > 0 then
        weapon = GetWeaponBeamPulse(bp, weapon)
        weapon.FireMode = 'BeamPulse'
    elseif weapon.DamageType == 'EMP' then
        weapon = GetWeaponEMP(bp, weapon)
        weapon.FireMode = 'EMP'
        if not weapon.RangeCategory or weapon.RangeCategory == 'UWRC_Undefined' then
            weapon.RangeCategory = 'UWRC_IndirectFire'
        end
    else
        weapon = GetWeaponProjectile(bp, weapon)
        weapon.FireMode = 'Projectile'       
        if not weapon.RangeCategory or weapon.RangeCategory == 'UWRC_Undefined' then
            weapon.RangeCategory = 'UWRC_DirectFire'
        end
    end


--    LOG(weapon.Title .. ' - ' ..weapon.FireMode)
--    LOG(weapon.Title.. ' weapon.FireMode ' .. weapon.FireMode )
    
    -- damage potential is Total Damage times weapon's impact area 
    weapon.DamagePotential = weapon.DamageTotal * weapon.DamageArea

    -- DPM is damage potential per unit's build cost and cost of weapon (e.g. TML/SML)
    -- this is one of best way to compare units using their cost and damage
    weapon.DPM = weapon.DPS * weapon.DamageArea / (weapon.BuildCostMass + bp.Economy.BuildCostMass)
--  weapon.DPM = weapon.DPS * weapon.DamageArea / weapon.BuildCostMass 
    
--      LOG(weapon.Title.. ' weapon.BuildRate ' .. tostring(weapon.BuildRate) )
    
    local duration = (weapon.BuildTime / math.init(weapon.BuildRate))
    weapon.BuildDuration = FormatTime(duration)
  
--    weapon.PPF = weapon.ProjectilesPerOnFire or 1
--    weapon.DOT = weapon.DoTPulses or 1
--    weapon.RPS = 1.0 / weapon.RateOfFire
--    weapon.DamageArea = weapon.DamageRadius or 1
--    weapon.DamageTotal = weapon.Damage * weapon.PPF * weapon.DOT
--    weapon.DPS = math.floor(weapon.DamageTotal * weapon.RateOfFire)
--    weapon.Range = weapon.MaxRadius
    --weapon.Specs = LOCF("<LOC gameui_0001>Damage: %d, Rate: %0.2f (DPS: %d) Range: %d", 
    --                  weapon.Damage, weapon.RPS, weapon.DPS, weapon.Range)
    --weapon.Specs = string.format("Range: %d, Damage: %d, Rate: %0.2f (DPS: %d) ", 
    --                  weapon.Range, weapon.DamageTotal, weapon.RPS, weapon.DPS)
 
    local aoe = ''
    local range = ''
    local damage = ''
    local rate = ''
    local dps = ''
    local dpm = ''
    local stun = ''
    local reload = ''

    if weapon.Range >= 1 then
       range =  FormatNumberAndPad(weapon.Range, 4) .. ' Range '
    end
     
    if weapon.FireMode == 'EMP' then
        weapon.Title  = weapon.Title .. ' on unit death'
        damage = FormatNumberAndPad(0, 8) .. ' Damage '
        dps = '' .. FormatNumberAndPad(0, 8) .. ' DPS '
        dpm = '' .. FormatNumberAndPad(0, 8, '%0.2f') .. ' DPM '
        if weapon.StunTime > 0 then
           reload = FormatNumberAndPad(weapon.StunTime, 6, '%0.1f') .. 's Stun'
        end
        if weapon.StunRadius >= 1 then
           aoe = FormatNumberAndPad(weapon.StunRadius, 4, '%0.1f') .. ' AOE '
        end
    elseif weapon.FireMode == 'BeamTractor' then
        damage = FormatNumberAndPad(0, 8) .. ' Damage '
        aoe = FormatNumberAndPad(0, 4, '%0.1f') .. ' AOE '
        dps = '' .. FormatNumberAndPad(0, 8) .. ' DPS '
        dpm = '' .. FormatNumberAndPad(0, 8, '%0.2f') .. ' DPM '
        reload = '     ' .. string.format('%0.1f', weapon.FireCycle) .. 's Reload'
    else
        if weapon.DamageTotal >= 1 then
           damage = FormatNumberAndPad(weapon.DamageTotal, 8) .. ' Damage '
        end

        if weapon.FireCycle > 0 then
            -- FireCycle already includes BuildCycle, e.g. Nuke weapons
--            if weapon.FireCycle >= 100 then
--                reload = FormatNumberAndPad(weapon.FireCycle, 7, '%0.0f')
--            else
--                reload = FormatNumberAndPad(weapon.FireCycle, 7, '%0.1f')
--            end    
            if weapon.FireCycle >= 60 then
                reload = StringPadLeft(FormatTime(weapon.FireCycle), 8)
            else
                reload = FormatNumberAndPad(weapon.FireCycle, 7, '%0.1f') .. 's'
            end
            reload = reload .. ' Reload'
        end

        if weapon.DamageRadius > 0 then
           aoe = FormatNumberAndPad(weapon.DamageRadius, 4, '%0.1f') .. ' AOE '
        end

        if weapon.DPS > 0 then
           dps = FormatNumberAndPad(weapon.DPS, 8) .. ' DPS '
        end
    
        if weapon.DPM > 0 then
            if weapon.DPM >= 1000 then
               dpm = ' '.. FormatNumberAndPad(weapon.DPM / 1000, 8, '%0.1fk') .. ' DPM '
            elseif weapon.DPM >= 10 then
               dpm = ' '.. FormatNumberAndPad(weapon.DPM, 8, '%0.0f') .. ' DPM '
            else
               dpm = FormatNumberAndPad(weapon.DPM, 8, '%0.2f') .. ' DPM '
            end 
        end
    end

    --LOG('' .. weapon.Specs)
    weapon.Specs = range ..'  ' .. aoe .. damage .. dps .. dpm .. reload
    --weapon.Specs = range .. damage .. reload .. aoe .. dps .. dpm
    --LOG('weapon.Specs ' .. weapon.Specs)

    return weapon
end


function GetSpecsForDefense(bp)
    local def = {}

    if bp.Defense then -- unit
        def.HealthArmor = math.init(bp.Defense.MaxHealth)
        def.HealthRegen = math.init(bp.Defense.RegenRate)
        def.ShieldArmor = math.init(bp.Defense.Shield.ShieldMaxHealth)
        def.ShieldRegen = math.init(bp.Defense.Shield.ShieldRegenRate)
    else -- Enhancement
        def.HealthArmor = math.init(bp.NewHealth)
        def.HealthRegen = math.init(bp.NewRegenRate)
        def.ShieldArmor = math.init(bp.ShieldMaxHealth)
        def.ShieldRegen = math.init(bp.ShieldRegenRate)
    end

    if bp.Economy.BuildCostMass > 0 then
        def.HPM = def.HealthArmor / bp.Economy.BuildCostMass
        def.SPM = def.ShieldArmor / bp.Economy.BuildCostMass
    else
        def.HPM = 0
        def.SPM = 0
    end
    
    if def.HealthArmor <= 0 then
       def.HealthInfo = '0.0     (0.0)' 
    else
       def.HealthInfo = FormatNumberAndPad(def.HealthArmor, 6, nil, 'right') 
       if def.HPM >= 10 then
          def.HealthInfo = def.HealthInfo .. string.format(" (%01.0f)", def.HPM) 
       else
          def.HealthInfo = def.HealthInfo .. string.format(" (%01.1f)", def.HPM) 
       end
    end
    
    if def.ShieldArmor <= 0 then
       def.ShieldInfo = '0.0     (0.0)' 
    else
       def.ShieldInfo = FormatNumberAndPad(def.ShieldArmor, 6, nil, 'right') 
       if def.SPM >= 10 then
          def.ShieldInfo = def.ShieldInfo .. string.format(" (%01.0f)", def.SPM) 
       else
          def.ShieldInfo = def.ShieldInfo .. string.format(" (%01.1f)", def.SPM) 
       end
    end
     
--    def.HealthInfo = FormatNumber(def.HealthArmor) .. ' (HPM ' .. FormatNumber(def.HPM) .. ')'
--    def.ShieldInfo = FormatNumber(def.ShieldArmor) .. ' (SPM ' .. FormatNumber(def.SPM) .. ')'

    return def
end

-- gets economy specs for unit blueprint or enhancement and calculates production yields
function GetSpecsForEconomy(bp)
    local eco = {}
    
    if not bp.Economy then  -- Enhancement blueprint
        eco.BuildCostMass = math.init(bp.BuildCostMass)
        eco.BuildCostEnergy = math.init(bp.BuildCostEnergy)

        eco.BuildTime = math.init(bp.BuildTime)
        eco.BuildRate = math.init(bp.NewBuildRate)

        eco.YieldMass = - math.init(bp.MaintenanceConsumptionPerSecondMass)
        eco.YieldMass = eco.YieldMass + math.init(bp.ProductionPerSecondMass)

        eco.YieldEnergy = - math.init(bp.MaintenanceConsumptionPerSecondEnergy)
        eco.YieldEnergy = eco.YieldEnergy + math.init(bp.ProductionPerSecondEnergy)

        eco.StorageMass = math.init(bp.StorageMass)
        eco.StorageEnergy = math.init(bp.StorageEnergy)

    else -- Unit blueprint
        eco.BuildCostEnergy = math.init(bp.Economy.BuildCostEnergy)
        eco.BuildCostMass = math.init(bp.Economy.BuildCostMass)

        eco.BuildTime = math.init(bp.Economy.BuildTime)
        eco.BuildRate = math.init(bp.Economy.BuildRate)

        local pods = table.size(bp.Economy.EngineeringPods)
        if pods > 1 then
             -- multiply by number of UEF engineering station pods
            eco.BuildRate = eco.BuildRate * pods
        end
        -- some units produce energy while consume some energy (e.g. SCU with stealth)
        eco.YieldEnergy = - math.init(bp.Economy.MaintenanceConsumptionPerSecondEnergy)
        eco.YieldEnergy = eco.YieldEnergy + math.init(bp.Economy.ProductionPerSecondEnergy)
        eco.YieldEnergy = eco.YieldEnergy + math.init(bp.Economy.MaxEnergy) -- Paragon

        eco.YieldMass = - math.init(bp.Economy.MaintenanceConsumptionPerSecondMass)
        eco.YieldMass = eco.YieldMass + math.init(bp.Economy.ProductionPerSecondMass)
        eco.YieldMass = eco.YieldMass + math.init(bp.Economy.MaxMass) -- Paragon

        eco.StorageMass = math.init(bp.Economy.StorageMass)
        eco.StorageEnergy = math.init(bp.Economy.StorageEnergy)
        
        eco.WeaponCostMass = 0
        eco.WeaponCostEnergy = 0
        eco.WeaponCostTime = 0

        eco.WeaponDrainMass = 0
        eco.WeaponDrainEnergy = 0

        if IsUnitStructure(bp) then
            for i, w in bp.Weapon or {} do
            
                -- check for weapons that drain energy when reloading, e.g. T3 Heavy Artillery Installation
                if w.EnergyDrainPerSecond > 0 then
                   eco.WeaponCostEnergy  = eco.WeaponCostEnergy + w.EnergyDrainPerSecond
                   eco.WeaponDrainEnergy = eco.WeaponDrainEnergy + w.EnergyDrainPerSecond
                end
                
                -- check for weapons that drain energy/mass when building missiles, e.g. TML/SML, SMD units 
                if IsWeaponSMD(w) or IsWeaponSML(w) or IsWeaponTML(w) then 
                    local ws = GetSpecsForWeapons(bp, table.deepcopy(w), i)

                    eco.WeaponCostTime = eco.WeaponCostTime + ws.BuildTime
                    
                    if ws.BuildCostMass > 0 then
                       eco.WeaponCostMass  = eco.WeaponCostMass + ws.BuildCostMass 
                    end
                    if ws.DrainPerSecondMass > 0 then
                       eco.WeaponDrainMass  = eco.WeaponDrainMass + ws.DrainPerSecondMass 
                    end

                    if ws.BuildCostEnergy > 0 then
                       eco.WeaponCostEnergy  = eco.WeaponCostEnergy + ws.BuildCostEnergy 
                    end
                    if ws.DrainPerSecondEnergy > 0 then 
                       eco.WeaponDrainEnergy = eco.WeaponDrainEnergy + ws.DrainPerSecondEnergy
                    end
                end 
            end
            -- updating eco.Yield stats by weapons' drain values
            eco.YieldMass = eco.YieldMass - eco.WeaponDrainMass
            eco.YieldEnergy = eco.YieldEnergy - eco.WeaponDrainEnergy
        end
    end

    -- BPM informs how a unit is cost-efficient to get build power/rate 
    eco.BPM = eco.BuildRate / eco.BuildCostMass
    eco.BuildInfo = FormatNumber(eco.BuildRate) --.. string.format(" (%01.3f)", eco.BPM)

    -- combine energy and mass cost to total cost using 1M = 100E conversion rate of mass fabricators
    eco.BuildCostTotal = math.round(eco.BuildCostMass + (eco.BuildCostEnergy / 100))

    return eco
end

-- gets intel specs for unit blueprint
function GetSpecsForIntel(bp)
    local specs = {}
    specs.Info = false

    if not bp.Intel then return specs end
     
    specs.Values = {}
    if bp.Intel.RadarRadius > 0 or bp.Intel.OmniRadius > 0 or 
       bp.Intel.SonarRadius > 0 or bp.Intel.MaxVisionRadius > 0 or 
       bp.Intel.SonarStealthFieldRadius > 0 or 
       bp.Intel.RadarStealthFieldRadius > 0 or 
       bp.Intel.RadarStealth or bp.Intel.SonarStealth or bp.Intel.Cloak then

        -- inserting intel values in an order that allows easier comparison of units
        
--        if bp.Intel.SonarRadius > 0 or bp.Intel.RadarRadius > 0 then
            table.insert(specs.Values, string.format('Sonar: %d', bp.Intel.SonarRadius or 0))
            table.insert(specs.Values, string.format('Radar: %d', bp.Intel.RadarRadius or 0))
--        end

        if bp.Intel.OmniRadius > 0 then
            table.insert(specs.Values, string.format('Omni: %d', bp.Intel.OmniRadius))
        end
        
        if bp.Intel.MaxVisionRadius > 0 then
            table.insert(specs.Values, string.format('Vision: %d', bp.Intel.MaxVisionRadius))
        end

        if bp.Intel.SonarStealthFieldRadius > 0 then
            table.insert(specs.Values, string.format('Stealth: %d', bp.Intel.SonarStealthFieldRadius))
        elseif bp.Intel.RadarStealthFieldRadius > 0 then
            table.insert(specs.Values, string.format('Stealth: %d', bp.Intel.RadarStealthFieldRadius))
        elseif bp.Intel.RadarStealth or bp.Intel.SonarStealth then
            table.insert(specs.Values, string.format('Stealth: %d', 1)) -- personal stealth
        end
        
        if bp.Intel.Cloak then
            table.insert(specs.Values, string.format('Cloak: %d', 1)) -- personal cloak
        end
    end

    if table.size(specs.Values) > 0 then
        specs.Info = table.concat(specs.Values, ' ')
    end

    return specs
end

-- gets physics specs for unit blueprint
function GetSpecsForPhysics(bp)
    local specs = {}
    specs.Info = false

    specs.Values = {}
    if bp.Air and bp.Air.MaxAirspeed and bp.Air.MaxAirspeed ~= 0 then
        --TODO-HUSSAR = LOCF("<LOC gameui_0002>Speed: %0.2f, Turning: %0.2f", air.MaxAirspeed, air.TurnSpeed)
        table.insert(specs.Values, string.format('Speed: %0.1f', bp.Air.MaxAirspeed or 0))
        table.insert(specs.Values, string.format('Turning: %0.1f', bp.Air.TurnSpeed or 0))

    elseif bp.Physics and bp.Physics.MaxSpeed and bp.Physics.MaxSpeed > 0 then
        table.insert(specs.Values, string.format('Speed: %0.1f', bp.Physics.MaxSpeed or 0))
        table.insert(specs.Values, string.format('Turning: %0.0f', bp.Physics.TurnRate or 0))
    else
        return specs
    end

    specs.Info = table.concat(specs.Values, ' ')

    return specs
end

--TODO-HUSSAR add to game options
local optionsAbbrivateStats = true

-- Format a number using abbreviated format if enabled in Game Options
function FormatNumber(num, showSign)
    if not num then return 0 end
    if optionsAbbrivateStats then
        local str = math.abbr(num, showSign)
        return str
    else
        local ret = string.format("%01.0f", num)
        if showSign and num > 0 then
            ret = "+" .. ret
        end
        return ret
    end
end

-- Formats a number using abbreviated format or custom format and pads it to specified final length
function FormatNumberAndPad(num, finalLength, customFormat, padding)
    local str = ''
    if customFormat then
        str = string.format(customFormat, num)
    else
        str = math.abbr(num, false)
    end
    
    local strHasM = string.find(str, 'm')
    local strHasK = string.find(str, 'k')
    local strHasDot = string.find(str, '%.')
    local strLength = string.len(str)

    -- adjusting final length to align strings with k/m multipliers and '.'
    -- this work the best with strings that are displayed with 'Arial Bold' font
    if strHasM then
        finalLength = finalLength + 1
    elseif strHasDot and not strHasK and num < 10 then
        finalLength = finalLength + 1
    elseif strHasDot and strHasK and num > 10000 then
        finalLength = finalLength - 1
    elseif strLength == 2 then
        finalLength = finalLength + 1
    elseif strLength == 1 then
        finalLength = finalLength + 2
    end

    if padding == 'right' then
        str = StringPadRight(str, finalLength)
    else
        str = StringPadLeft(str, finalLength)
    end
    return str
end 

-- Formats time specified in seconds using MM:SS string format
function FormatTime(seconds)
    if not seconds then return '00:00' end
    local mm = math.floor(seconds / 60)
    local ss = math.mod(seconds, 60)
    return string.format("%02d:%02d", mm, ss)
end

function FormatTicks(time)
    time = time / 60
    local mm =  math.floor(time / 60)
    local ss =  math.floor(math.mod(time, 60))
    return string.format("%02d:%02d", mm, ss)
end
 
-- gets verified blueprint for specified unit blueprint (e.g. url0301_RAS blueprint)
function GetVerifiedBlueprint(unitBp)
    -- copy unit blueprint to prevent changing its original values
    local bp = table.deepcopy(unitBp)
    
    -- use weapons that are installed and skip weapons enabled by upgrades
    bp.Weapon = GetWeaponsInstalled(bp)
   
    if not bp.EnhancementPresetAssigned then return bp end
     
    local primaryWeapon = GetWeaponPrimary(bp)
    local upgradeNames = GetPresetEnhancements(bp)

    -- apply upgrades and weapons enabled by preset enhancements (e.g. SCU presets)
    for _, upgradeName in upgradeNames do

        --LOG('enhancing bp with ' ..upgradeName)
        local upgradeBp = bp.Enhancements[upgradeName]
        upgradeBp.ID = upgradeName
        local upgradeSpecs = GetUpgradeSpecs(bp, upgradeBp)
        --table.print(upgradeSpecs, 'GetUpgradeSpecs')  
        
        -- apply upgrade's build rate, eco production, intel, etc.
        ApplyUpgradeTo(bp, upgradeSpecs)
        
        -- apply upgrade's stats changes to the primary weapon
        ApplyUpgradeToWeapon(primaryWeapon, upgradeSpecs)

--        for _, w in bp.Weapon or {} do
--            -- enable weapons by upgrade name
----            if w.EnabledByEnhancement == upgradeName then
----               w.EnabledByEnhancement = nil
----                LOG('GetEnhancedBlueprint weapon ' .. w.DisplayName .. ' added by ' .. upgradeName)
----            end

--            -- modify primary weapon by applying upgrade specs
--            if primaryWeapon and 
--               primaryWeapon.RangeCategory == w.RangeCategory then 
--                ApplyUpgradeToWeapon(w, upgradeSpecs)
----                if w.ModifiedByUpgrade == upgradeName then
----                     LOG('GetEnhancedBlueprint weapon ' .. w.DisplayName .. ' modded by ' .. upgradeName)
----                end
--            end
--        end
    end
    
    return bp
end
 
-- lookup table with styles for upgrade and labels
-- note that styles are defined in unitviewStyler.lua
local UpgradeLookup = {
    Default         = { Style = 'Default', Label = 'Unknown' },
    -- defenses upgrades
    NewRegenRate    = { Style = 'Health', Label = 'Armor Regen' },
    RegenCeiling    = { Style = 'Health', Label = 'Armor Regen' },
    Radius          = { Style = 'Health', Label = 'Armor Regen Range' },
    NewHealth       = { Style = 'Health', Label = 'Armor Hitpoints' },
    ACUAddHealth    = { Style = 'Health', Label = 'Armor Hitpoints' },
    ShieldMaxHealth = { Style = 'Shield', Label = 'Shield Hitpoints' },
    ShieldRegenRate = { Style = 'Shield', Label = 'Shield Regen' },
    ShieldSize      = { Style = 'Shield', Label = 'Shield Size' },
    -- weapon upgrades
    NewRateOfFire      = { Style = 'Weapon', Label = 'Weapon Rate of Fire' },
    AdditionalDamage   = { Style = 'Weapon', Label = 'Weapon Damage' },
    NewDamageMod       = { Style = 'Weapon', Label = 'Weapon Damage' },
    NewMaxRadius       = { Style = 'Weapon', Label = 'Weapon Range' },
    NewDamageRadiusMod = { Style = 'Weapon', Label = 'Weapon Area' },
    NewDamageRadius    = { Style = 'Weapon', Label = 'Weapon Area' },
    -- intel upgrades
    NewOmniRadius         = { Style = 'Intel', Label = 'Omni Range' },
    NewRadarRadius        = { Style = 'Intel', Label = 'Radar Range' },
    NewSonarRadius        = { Style = 'Intel', Label = 'Sonar Range' },
    NewVisionRadius       = { Style = 'Intel', Label = 'Vision Range' },
    NewWaterRadius        = { Style = 'Intel', Label = 'Water Range' },
    NewJammerRadius       = { Style = 'Intel', Label = 'Jammer Range' },
    NewJammerBlips        = { Style = 'Intel', Label = 'Jammer Blips' },
    NewRadarStealthRadius = { Style = 'Intel', Label = 'Stealth Range' },
    NewSonarStealthRadius = { Style = 'Intel', Label = 'Stealth Range' },
    -- economy upgrades
    NewBuildRate    = { Style = 'Rate', Label = 'Build Power', Group = 'Economy' },
    NewBuildRadius  = { Style = 'Rate', Label = 'Build Range', Group = 'Economy' },
    ProductionPerSecondMass = { Style = 'Mass', Label = 'Mass Rate', Group = 'Economy' },
    ProductionPerSecondEnergy = { Style = 'Energy', Label = 'Energy Rate', Group = 'Economy' },
}

-- gets upgrade changes for an upgrade key that changes unit by setting a value
function GetUpgradeChangeSet(UpgradeKey, upgrade, bpValue)
    if not UpgradeLookup[UpgradeKey] then
        WARN('BlueprintsAnalyzer is missing UpgradeLookup for ' .. UpgradeKey .. ' key') 
        UpgradeLookup[UpgradeKey] = UpgradeLookup.Default
    end
    local change = UpgradeLookup[UpgradeKey]
    --change.Group = UpgradeKey
    change.UpgradeBP = upgrade.BP
    change.UpgradeTo = upgrade.ID 
    change.UpgradeKey = UpgradeKey
    change.UpgradeType = change.Style
    change.ToValue = upgrade[UpgradeKey] or 0
    change.FromValue = bpValue 
    if upgrade.Chain and upgrade.Chain[1] then
        change.FromValue = upgrade.Chain[1][UpgradeKey] or 0
        change.UpgradeFrom = upgrade.Chain[1].ID or ''
    else 
        change.UpgradeFrom = "blueprint's base values"
    end
    change.Delta = change.ToValue - change.FromValue
    change.Info = GetUpgradeChangeInfo(change.Label, change)
    if change.FromValue > change.ToValue then 
        change.Info = change.Info .. ' ~~~ BUG in BP!'
        change.Sequence = change.UpgradeFrom .. ' to '.. change.UpgradeTo ..'.' .. UpgradeKey
        WARN('BlueprintsAnalyzer detected negative delta from ' .. change.UpgradeBP .. " BP's " .. change.Sequence )
        table.print(change, 'upgrade change', WARN)
    end
    -- skip upgrades that do not have any changes in values
    if change.FromValue ~= change.ToValue then
        return change
    else
        return nil
    end
end
-- gets upgrade changes for an upgrade key that changes unit by adding a value
function GetUpgradeChangeAdd(UpgradeKey, upgrade, bpValue)
    if not UpgradeLookup[UpgradeKey] then
        WARN('BlueprintsAnalyzer is missing UpgradeLookup for ' .. UpgradeKey .. ' key') 
        return nil
    end
    local change = UpgradeLookup[UpgradeKey]
    change.UpgradeBP = upgrade.BP
    change.UpgradeTo = upgrade.ID 
    change.UpgradeKey = UpgradeKey
    change.UpgradeType = change.Style
    change.Delta = upgrade[UpgradeKey] or 0
    change.FromValue = bpValue
    if upgrade.Chain and upgrade.Chain[1] then
        change.UpgradeFrom = upgrade.Chain[1].ID or ''
    else 
        change.UpgradeFrom = "blueprint's base values"
    end
    for id, old in upgrade.Chain or {} do
        if old[UpgradeKey] then
            change.FromValue = change.FromValue + old[UpgradeKey]
        end
    end
    change.ToValue = change.FromValue + change.Delta 
    change.Info = GetUpgradeChangeInfo(change.Label, change)
    if change.FromValue > change.ToValue then 
        change.Info = change.Info .. ' ~~~ BUG in BP!' 
        change.Sequence = change.UpgradeFrom .. ' to '.. change.UpgradeTo ..'.' .. UpgradeKey
        WARN('BlueprintsAnalyzer detected negative delta from ' .. change.UpgradeBP .. " BP's " .. change.Sequence )
        table.print(change, 'upgrade change', WARN)
    end
    -- skip upgrades that do not have any values
    if change.FromValue ~= change.ToValue then
        return change
    else
        return nil
    end
end 
-- gets upgrade change info formatted into readable string
function GetUpgradeChangeInfo(label, change, symbol)
    symbol = symbol or '' 
    -- always show sign for delta between changes
    local ret = FormatNumber(change.Delta, true) .. symbol
    ret = ret .. ' ' ..label 
    ret = ret .. ' (' .. FormatNumber(change.FromValue, false) .. symbol .. ' >>>'
    ret = ret .. ' '  .. FormatNumber(change.ToValue, false) .. symbol .. ')'
    return ret
end
-- gets upgrade chain with all prerequisite upgrades
function GetUpgradeChain(bp, upgrade)
    if not bp then return end
    local chain = {}
    local oldUpgrade = GetUpgradeFrom(bp, upgrade.Prerequisite)
    if oldUpgrade then 
        table.insert(chain, oldUpgrade)
        -- recursively find all other prerequisite upgrades
        for id, old in GetUpgradeChain(bp, oldUpgrade) do
            table.insert(chain, old)
        end
    end
    return chain
end
-- gets upgrade table from specified blueprint
function GetUpgradeFrom(bp, upgradeID)
    if not bp then return nil end
    if not upgradeID then return nil end
    for id, upgrade in bp.Enhancements or {} do
        if id == upgradeID then
            upgrade.ID = id
            return upgrade
        end
    end
end

local upgradeLocations =
{
    BACK = "<LOC uvd_0007>Back",
    LCH  = "<LOC uvd_0008>LCH",
    RCH  = "<LOC uvd_0009>RCH",
}

function GetUpgradeName(upgrade)
    local slot = string.upper(upgrade.Slot or 'nil')
    local location = upgradeLocations[slot] 

    if upgrade.Name == nil then
        return LOC(slotName)
    else
        return LOCF("%s (%s)", upgrade.Name, location)
    end
end

-- lookup table with blueprint IDs of drone because they are not in bp.Enhancements table
local DroneUpgrades = {
    Pod = 'uea0003',
    LeftPod = 'uea0001',
    RightPod = 'uea0001',
}

-- gets upgrade specs table with changes, add-ons, and enabled weapons
-- this function essentially tells what the blueprint will be after applying the upgrade
function GetUpgradeSpecs(bp, upgrade)
    --local bp = __blueprints[bpID]
    if not bp then return end
    upgrade.BP = bp.ID
     
    local specs = {}
    specs.upgrade = upgrade
    specs.changes = {}
    specs.addons = {}
    specs.weapons = {}
      
    local oldUpgrade = nil
    if upgrade.Prerequisite then
       oldUpgrade = GetUpgradeFrom(bp, upgrade.Prerequisite)
    end
    -- get upgrade chain in case the current upgrade depends on previous upgrade
    upgrade.Chain = GetUpgradeChain(bp, upgrade)

    -- check for drone upgrade
    local droneID = DroneUpgrades[upgrade.ID]
    local droneBp = __blueprints[droneID] 
    if droneID and droneBp then
        local change = {}
        change.Delta = table.item(droneBp.Economy, 'BuildRate')
        change.FromValue = table.item(bp.Economy, 'BuildRate')
        local chain = GetUpgradeChain(bp, upgrade)
        for id, old in chain do
            droneID = DroneUpgrades[old.ID]
            if not droneID then break end
            droneBp = __blueprints[droneID] 
            if not droneBp then break end
            change.FromValue = change.FromValue + table.item(droneBp.Economy, 'BuildRate')
        end
        change.ToValue = change.FromValue + change.Delta
        if change.FromValue ~= change.ToValue then
            change.Info = GetUpgradeChangeInfo('Build Rate', change)
            change.Style = 'Rate'
            change.Group = 'Economy'
            table.insert(specs.changes, change)
        end
    end

    -- Economy upgrades
    if upgrade['NewBuildRate'] then
        local bpValue = bp.Economy.BuildRate or 0
        local change = GetUpgradeChangeSet('NewBuildRate', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    if upgrade['ProductionPerSecondMass'] then
        local bpValue = bp.Economy and bp.Economy.ProductionPerSecondMass or 0
        local change = GetUpgradeChangeSet('ProductionPerSecondMass', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    if upgrade['ProductionPerSecondEnergy'] then
        local bpValue = bp.Economy and bp.Economy.ProductionPerSecondEnergy or 0
        local change = GetUpgradeChangeSet('ProductionPerSecondEnergy', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    -- health/armor hitpoints for non-ACU units
    if upgrade['NewHealth'] then
        local bpValue = bp.Defense and bp.Defense.Health or 0
        -- note that NewHealth is really addition to current health!
        local change = GetUpgradeChangeAdd('NewHealth', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    -- health/armor hitpoints for ACU units
    if upgrade['ACUAddHealth'] then
        local bpValue = bp.Defense and bp.Defense.Health or 0
        -- note that ACU AddHealth is really addition to current health!
        local change = GetUpgradeChangeAdd('ACUAddHealth', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    -- health/armor regen Rate
    if upgrade['NewRegenRate'] then
        local bpValue = bp.Defense and bp.Defense.RegenRate or 0
        -- note that NewRegenRate is really addition to current RegenRate!
        local change = GetUpgradeChangeAdd('NewRegenRate', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    -- health/armor regen aurora
    if upgrade['RegenCeiling'] then  
        local change = GetUpgradeChangeAdd('RegenCeiling', upgrade, 0)
        if change then table.insert(specs.changes, change) end
        
        if upgrade['Radius'] then
            local change = GetUpgradeChangeSet('Radius', upgrade, 0)
            if change then table.insert(specs.changes, change) end
        end
    end
    -- shields upgrades
    if upgrade['ShieldSize'] then
        local bpValue = bp.Defense and bp.Defense.Shield and
                        bp.Defense.Shield.ShieldSize or 0
        local change = GetUpgradeChangeSet('ShieldSize', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    if upgrade['ShieldRegenRate']  then
        local bpValue = bp.Defense and bp.Defense.Shield and
                        bp.Defense.Shield.ShieldRegenRate or 0
        local change = GetUpgradeChangeSet('ShieldRegenRate', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    if upgrade['ShieldMaxHealth']  then
        local bpValue = bp.Defense and bp.Defense.Shield and
                        bp.Defense.Shield.ShieldMaxHealth or 0
        local change = GetUpgradeChangeSet('ShieldMaxHealth', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    -- Intel upgrades
    if upgrade['NewOmniRadius'] then
        local bpValue = bp.Intel and bp.Intel.OmniRadius or 0
        local change = GetUpgradeChangeSet('NewOmniRadius', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    if upgrade['NewSonarRadius'] then
        local bpValue = bp.Intel and bp.Intel.SonarRadius or 0
        local change = GetUpgradeChangeSet('NewSonarRadius', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    if upgrade['NewRadarRadius'] then
        local bpValue = bp.Intel and bp.Intel.RadarRadius or 0
        local change = GetUpgradeChangeSet('NewRadarRadius', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    if upgrade['NewVisionRadius'] then
        local bpValue = bp.Intel and bp.Intel.VisionRadius or 0
        local change = GetUpgradeChangeSet('NewVisionRadius', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    if upgrade['NewWaterRadius'] then
        local bpValue = bp.Intel and bp.Intel.WaterVisionRadius or 0
        local change = GetUpgradeChangeSet('NewWaterRadius', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    -- Stealth upgrades
    if upgrade['NewRadarStealthRadius'] then
        local bpValue = bp.Intel and bp.Intel.RadarStealthFieldRadius or 0
        local change = GetUpgradeChangeSet('NewRadarStealthRadius', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    if upgrade['NewSonarStealthRadius'] then
        local bpValue = bp.Intel and bp.Intel.SonarStealthFieldRadius or 0
        local change = GetUpgradeChangeSet('NewSonarStealthRadius', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    -- Jammer upgrades
    if upgrade['NewJammerRadius'] then
        local bpValue = 0
        local change = GetUpgradeChangeSet('NewJammerRadius', upgrade, 0)
        if change then table.insert(specs.changes, change) end
    end
    if upgrade['NewJammerBlips'] then
        local change = GetUpgradeChangeSet('NewJammerBlips', upgrade, 0)
        if change then table.insert(specs.changes, change) end
    end

    local weapon = GetWeaponPrimary(bp) 
    -- getting changes for weapon's modifications
    if weapon and upgrade['NewMaxRadius'] then
        local bpValue = weapon and weapon.MaxRadius or 0
        local change = GetUpgradeChangeSet('NewMaxRadius', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    if weapon and upgrade['NewDamageRadiusMod'] then
        local bpValue = weapon and weapon.DamageRadius or 1
        local change = GetUpgradeChangeSet('NewDamageRadiusMod', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    if weapon and upgrade['NewDamageRadius'] then
        local bpValue = weapon and weapon.DamageRadius or 0
        local change = GetUpgradeChangeSet('NewDamageRadius', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    if weapon and upgrade['NewDamageMod'] then
        local bpValue = weapon.Damage or 0
        local change = GetUpgradeChangeAdd('NewDamageMod', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    if weapon and upgrade['AdditionalDamage'] then
        local bpValue = weapon.Damage or 0
        local change = GetUpgradeChangeSet('AdditionalDamage', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    if weapon and upgrade['NewRateOfFire'] then
        local bpValue = weapon.RateOfFire or 0
        local change = GetUpgradeChangeSet('NewRateOfFire', upgrade, bpValue)
        if change then table.insert(specs.changes, change) end
    end
    -- Weapon's buffs
    if weapon and upgrade.ID == 'EMPCharge' then
        for k, v in weapon.Buffs or {} do
            if v.BuffType == 'STUN' and v.TargetAllow and v.Duration then
                local id = 'Stun'..v.TargetAllow
                local change = {}
                change.target = v.TargetAllow .. ' units'
                change.Style = 'Stun'
                change.Value = string.format('%1.1fs', v.Duration)
                change.Info = '+'.. change.Value .. ' stun effect on ' ..change.target  
                table.insert(specs.changes, change)
            end
        end 
    end

    -- sort upgrade changes such that similar changes are grouped together 
    -- and easier to read when they are displayed in UI
    table.sort(specs.changes, function(a, b)
        if a.Group ~= b.Group then
            return a.Group < b.Group
        end
        if a.Style ~= b.Style then
            return a.Style > b.Style
        end
        if a.Delta and b.Delta then
            return a.Delta < b.Delta
        end
        return a.Info < b.Info
    end)

    --table.print(specs.changes ,'specs.changes2')
    --for k, v in specs.changes do
    --    LOG('specs.changes' .. v.Info)
    --end
    specs.weapons = { }

    weapon = GetWeaponEnabledByUpgrade(bp, upgrade.ID)
    if weapon then
--        LOG('GetUpgradeSpecs enables ' .. weapon.DisplayName)
        table.insert(specs.weapons, weapon) 
    end

    -- Upgrade's packs
    specs.addons = {}
    if upgrade.ID == 'StealthGenerator' then
        table.insert(specs.addons, 'Installs Stealth Generator') 
    elseif upgrade.ID == 'CloakingGenerator' then
        table.insert(specs.addons, 'Installs Cloaking Generator') 
    elseif upgrade.ID == 'Teleporter' then
        table.insert(specs.addons, 'Installs Teleportation Pack') 
    end
    
    if upgrade.BuildableCategoryAdds then
        local addon = upgrade.BuildableCategoryAdds
        if StringStarts(addon, 'BUILTBYTIER3') then
            table.insert(specs.addons, 'Installs T3 Engineering Suite')
        elseif StringStarts(addon, 'BUILTBYTIER2') then
            table.insert(specs.addons, 'Installs T2 Engineering Suite')
        end
    end
    
    return specs 
end

-- gets a list of blueprint IDs that the given blueprint can upgrade to
-- e.g. UEF Radar: ueb3101 -> ueb3201 -> ueb3104
function GetUpgradeBlueprints(bp)
    local chain = {}
    if IsUnitValid(bp) and IsUnitUpgradable(bp) then
        local upgrade = bp.General.UpgradesTo 
        local upgradeBp = __blueprints[upgrade]
        if upgradeBp then
            table.insert(chain, upgrade)
            for _, v in GetUpgradeBlueprints(upgradeBp) do
                table.insert(chain, v)
            end 
        end
    end
    return chain
end

-- applies upgrade specs to a given blueprint table
-- use this function only on table.deepcopy(bp)
function ApplyUpgradeTo(bp, upgradeSpecs)
 
    for _, change in upgradeSpecs.changes or {} do
        local key = change.UpgradeKey
        if bp.Economy and key == 'NewBuildRate' then
            bp.Economy['BuildRate'] = change.ToValue
        elseif bp.Economy and key == 'NewBuildRadius' then
            bp.Economy['MaxBuildDistance'] = change.ToValue
        elseif bp.Economy and key == 'ProductionPerSecondMass' then
            bp.Economy['ProductionPerSecondMass'] = change.ToValue
        elseif bp.Economy and key == 'ProductionPerSecondEnergy' then
            bp.Economy['ProductionPerSecondEnergy'] = change.ToValue
        elseif bp.Economy and key == 'NewStorageMass' then 
            bp.Economy['StorageMass'] = change.ToValue
        elseif bp.Economy and key == 'NewStorageEnergy' then
            bp.Economy['StorageEnergy'] = change.ToValue
        elseif bp.Economy and key == 'MaintenanceConsumptionPerSecondEnergy' then
            bp.Economy['MaintenanceConsumptionPerSecondEnergy'] = change.ToValue
        elseif bp.Defense and key == 'NewHealth' then
            bp.Defense['MaxHealth'] = change.ToValue 
        elseif bp.Defense and key == 'ACUAddHealth' then
            bp.Defense['MaxHealth'] = change.ToValue
        elseif bp.Defense and key == 'NewRegenRate' then
            bp.Defense['RegenRate'] = change.ToValue
        elseif bp.Defense.Shield and key == 'ShieldSize' then
            bp.Defense.Shield['ShieldSize'] = change.ToValue
        elseif bp.Defense.Shield and key == 'ShieldMaxHealth' then
            bp.Defense.Shield['ShieldMaxHealth'] = change.ToValue 
        elseif bp.Defense.Shield and key == 'ShieldRegenRate' then
            bp.Defense.Shield['ShieldRegenRate'] = change.ToValue
        elseif bp.Intel and key == 'NewOmniRadius' then
            bp.Intel['OmniRadius'] = change.ToValue
        elseif bp.Intel and key == 'NewSonarRadius' then
            bp.Intel['SonarRadius'] = change.ToValue 
        elseif bp.Intel and key == 'NewVisionRadius' then
            bp.Intel['VisionRadius'] = change.ToValue 
        elseif bp.Intel and key == 'NewWaterRadius' then
            bp.Intel['WaterVisionRadius'] = change.ToValue
        elseif bp.Intel and key == 'NewRadarRadius' then
            bp.Intel['RadarRadius'] = change.ToValue
        elseif bp.Intel and key == 'NewRadarStealthRadius' then
            bp.Intel['RadarStealthFieldRadius'] = change.ToValue
        elseif bp.Intel and key == 'NewSonarStealthRadius' then
            bp.Intel['SonarStealthFieldRadius'] = change.ToValue
        elseif bp.Intel and key == 'NewJammerBlips' then
            bp.Intel['JammerBlips'] = change.ToValue 
        elseif bp.Intel and key == 'NewJammerRadius' then
            if not bp.Intel.JamRadius then
                bp.Intel.JamRadius = {}
            end
            bp.Intel.JamRadius['Min'] = change.ToValue
            bp.Intel.JamRadius['Max'] = change.ToValue
        end
    end
end
-- applies upgrade specs to a given weapon table
-- use this function only on table.deepcopy(bp) to prevent actually changing original bp
function ApplyUpgradeToWeapon(weapon, upgradeSpecs)
    for _, change in upgradeSpecs.changes or {} do

        if change.UpgradeType == 'Weapon' then
            LOG('ApplyUpgradeToWeapon ' ..  tostring(change.UpgradeType) ..' '..  change.UpgradeKey .. ' '  .. change.FromValue .. ' ==> ' .. change.ToValue)
            weapon.ModifiedByUpgrade = upgradeSpecs.upgrade.ID
            if change.UpgradeKey == "NewMaxRadius" then 
                 weapon.MaxRadius = change.ToValue 
            elseif change.UpgradeKey == "NewRateOfFire" then 
                weapon.RateOfFire = change.ToValue 
            elseif change.UpgradeKey == "NewDamageRadiusMod" or
                   change.UpgradeKey == "NewDamageRadius" then
                weapon.DamageRadius = change.ToValue 
            elseif change.UpgradeKey == "NewDamageMod" or
                   change.UpgradeKey == "AdditionalDamage" then
                -- NewDamageMod and AdditionalDamage are actually final values
                -- instead of not an addition to existing damage of a weapon!
                weapon.Damage = change.ToValue 
            end
        end
    end
end

-- Checks if a unit blueprint contains specified ID
function ContainsID(bp, value)
    if not bp then return false end
    if not bp.ID then return false end
    if not value then return false end
    return string.upper(value) == string.upper(bp.ID)
end

-- Checks if a unit blueprint contains specified faction
function ContainsFaction(bp, value)
    if not bp then return false end
    if not value then return false end
    return string.upper(value) == bp.Faction
end

-- Checks if a unit blueprint contains specified categories
function ContainsCategory(bp, value)
    if not value then return false end
    if not bp then return false end
    if not bp.CategoriesHash then return false end
    return bp.CategoriesHash[value]
end

-- Checks if a unit blueprint contains categories in specified expression
-- e.g. Contains(unit, '(LAND * ENGINEER) + AIR')
-- this function is similar to ParseEntityCategoryProperly (CategoryUtils.lua)
-- but it works on UI/lobby side
function Contains(bp, expression)
    if not expression or expression == '' or
       not bp then
       return false
    end

    local OPERATORS = { -- Operations
        ["("] = true,
        [")"] = true,
        -- Operation on categories: a, b
        ["*"] = function(a, b) return a and b end, -- Intersection and category
        ["-"] = function(a, b) return a and not b end, -- Subtraction not category
        ["+"] = function(a, b) return a or  b end, -- Union or  category
    }

    expression = '('..expression..')'
    local tokens = {}
    local currentIdentifier = ""
    expression:gsub(".", function(c)
    -- If we were collecting an identifier, we reached the end of it.
        if (OPERATORS[c] or c == " ") and currentIdentifier ~= "" then
            table.insert(tokens, currentIdentifier)
            currentIdentifier = ""
        end

        if OPERATORS[c] then
            table.insert(tokens, c)
        elseif c ~= " " then
            currentIdentifier = currentIdentifier .. c
        end
    end)

    local numTokens = table.getn(tokens)
    local function explode(error)
        WARN("Category parsing failed for expression:")
        WARN(expression)
        WARN("Tokenizer interpretation:")
        WARN(repr(tokens))
        WARN("Error from parser:")
        WARN(debug.traceback(nil, error))
    end

    -- Given the token list and an offset, find the index of the matching bracket.
    local function getExpressionEnd(firstBracket)
        local bracketDepth = 1

        -- We're done when bracketDepth = 0, as it means we've just hit the closing bracket we want.
        local i = firstBracket + 1
        while (bracketDepth > 0 and i <= numTokens) do
            local token = tokens[i]

            if token == "(" then
                bracketDepth = bracketDepth + 1
            elseif token == ")" then
                bracketDepth = bracketDepth - 1
            end
            i = i + 1
        end

        if bracketDepth == 0 then
            return i - 1
        else
            explode("Mismatched bracket at token index " .. firstBracket)
        end
    end
    -- Given two categories and an operator token, return the result of applying the operator to
    -- the two categories (in the order given)
    local function getSolution(currentCategory, newCategory, operator)
        -- Initialization case.
        if not operator and not currentCategory then
            return newCategory
        end

        if OPERATORS[operator] then
            local matching = OPERATORS[operator](currentCategory, newCategory)
            return matching
        else
            explode('Cannot getSolution for operator: ' .. operator)
            return false
        end
    end

    local function ParseSubexpression(start, finish)
        local currentCategory = nil
        -- Type of the next token we expect (want alternating identifier/operator)
        local expectingIdentifier = true
        -- The last operator encountered.
        local currentOperator = nil
        -- We need to be able to manipulate 'i' while iterating, hence...
        local i = start
        while i <= finish do
            local token = tokens[i]

            if expectingIdentifier then
                -- Bracket expressions are effectively identifiers
                if token == "(" then
                    -- Scan to the matching bracket, parse that subexpression, and current-operator
                    -- the result onto the working category.
                    local subcategoryEnd = getExpressionEnd(i)
                    local subcategory = ParseSubexpression(i + 1, subcategoryEnd - 1)

                    currentCategory = getSolution(currentCategory, subcategory, currentOperator)

                    -- We want 'i' to end up beyond the bracket, and to end up *not* expecting indent,
                    -- as a bracket expression is effectively an indent.
                    i = subcategoryEnd
                elseif OPERATORS[token] then
                    explode("Expected category identifier, found OPERATOR " .. token)
                    return nil
                else
                    -- Match token with unit ID or unit categories
                    local matching = ContainsID(bp, token) or
                                     ContainsCategory(bp, token)
                    currentCategory = getSolution(currentCategory, matching, currentOperator)
                end
            else
                if not OPERATORS[token] then
                    explode("Expected operator, found category identifier: " .. token)
                    return nil
                end
                currentOperator = token
            end
            expectingIdentifier = not expectingIdentifier
            i = i + 1
        end

        return currentCategory
    end
    local isMatching = ParseSubexpression(1, numTokens)

    return isMatching
end

-- gets unit blueprints with categories/id/enhancement that match specified expression
function GetUnits(bps, expression)
    local matches = {}
    local index = 1
    for id, bp in bps do
        local isMatching = Contains(bp, expression)
        if isMatching then
            matches[id] = bp
            index = index + 1
        end
    end
    return matches
end

-- Groups units based on their categories
-- @param bps is table with blueprints
-- @param faction is table with { Name = 'FACTION' }
function GetUnitsGroups(bps, faction)
    -- NOTE these unit groupings are for visualization purpose only
    local TECH4ARTY = '(EXPERIMENTAL * ARTILLERY - FACTORY - LAND)' -- mobile factory (FATBOY)
    -- xrl0002 Crab Egg (Engineer)
    -- xrl0003 Crab Egg (Brick)
    -- xrl0004 Crab Egg (Flak)
    -- xrl0005 Crab Egg (Artillery)
    -- drlk005 Crab Egg (Bouncer)
    local CRABEGG = 'xrl0002 + xrl0003 + xrl0004 + xrl0005 + drlk005'
    -- Including crab eggs with factories so they are not confused with actual units built from crab eggs
    local FACTORIES = '((FACTORY * STRUCTURE) + ' .. CRABEGG .. ')'
    local ENGINEERS = '(ENGINEER - COMMAND - SUBCOMMANDER - UPGRADE)'
    local DRONES = '(POD - UPGRADE)'
    local DEFENSES = '(ANTINAVY + DIRECTFIRE + ARTILLERY + ANTIAIR + MINE + ORBITALSYSTEM + SATELLITE + NUKE)'

    if table.size(faction.Blueprints) == 0 then
        faction.Blueprints = GetUnits(bps, faction.Name)
    end
    faction.Units = {}
    -- Grouping ACU/SCU upgrades in separate tables because they have different cost/stats
    faction.Units.ACU       = GetUnits(faction.Blueprints, 'COMMAND + UPGRADE - SUBCOMMANDER - CIVILIAN')
    faction.Units.SCU       = GetUnits(faction.Blueprints, 'SUBCOMMANDER + UPGRADE - COMMAND - CIVILIAN')
    local mobileUnits       = GetUnits(faction.Blueprints, '('..faction.Name..' - UPGRADE - COMMAND - SUBCOMMANDER - STRUCTURE - CIVILIAN)')
    faction.Units.AIR       = GetUnits(mobileUnits, '(AIR - POD - SATELLITE)')
    faction.Units.LAND      = GetUnits(mobileUnits, '(LAND - ENGINEER - POD - '..TECH4ARTY..')')
    faction.Units.NAVAL     = GetUnits(mobileUnits, '(NAVAL - MOBILESONAR)')
    local buildings         = GetUnits(faction.Blueprints, '(STRUCTURE + MOBILESONAR + '..TECH4ARTY..' - CIVILIAN)')
    faction.Units.CONSTRUCT = GetUnits(faction.Blueprints, '('..FACTORIES..' + '..ENGINEERS..' + ENGINEERSTATION + '..DRONES..' - DEFENSE)')
    faction.Units.ECONOMIC  = GetUnits(buildings, '(STRUCTURE * ECONOMIC)')
    faction.Units.SUPPORT   = GetUnits(buildings, '(WALL + HEAVYWALL + INTELLIGENCE + SHIELD + AIRSTAGINGPLATFORM - ECONOMIC - ' ..DEFENSES..')')
    faction.Units.CIVILIAN  = GetUnits(faction.Blueprints, '(CIVILIAN - ' ..DEFENSES..')')

    faction.Units.DEFENSES  = GetUnits(buildings, DEFENSES)
    -- Collect not grouped units from above tables into the DEFENSES table
    -- This way we don't miss showing un-grouped units
    for ID, bp in faction.Blueprints do
        if not faction.Units.ACU[ID] and
           not faction.Units.SCU[ID] and
           not faction.Units.AIR[ID] and
           not faction.Units.LAND[ID] and
           not faction.Units.NAVAL[ID] and
           not faction.Units.CONSTRUCT[ID] and
           not faction.Units.ECONOMIC[ID] and
           not faction.Units.SUPPORT[ID] and
           not faction.Units.CIVILIAN[ID] and
           not faction.Units.DEFENSES[ID] then

           faction.Units.DEFENSES[ID] = bp
        end
    end

    if logsTypes.DEBUG then
        for group, units in faction.Units do
            LOG('BlueprintAnalyzer '..faction.Name..' faction has ' .. table.size(units)..' ' .. group .. ' units')
        end
    end
    return faction
end

-- gets ids of valid units
function GetUnitsFrom(blueprints)
    local units = {}
    for id, bp in blueprints do
        local hasUID = not tonumber(id) 
        if hasUID and IsUnitValid(bp) then
            units[id] = bp
        end
    end
    return units
end

-- gets ids of valid units
function GetUnitsIDs(blueprints)
    local units = GetUnitsFrom(blueprints)
    --for id, bp in units do
    --    if IsUnitValid(bp) then
    --        table.insert(units, id)
    --    end
    --end
    return table.keys(units)
end

-- gets blueprints that can be upgraded, e.g. MEX, Shield, Radar structures
function GetUnitsUpgradable(blueprints)
    local units = {}
     
    for id, bp in blueprints do 
        -- Check for valid/upgradeable blueprints
        if bp and bp.General and IsUnitValid(bp) and
            bp.General.UpgradesFrom ~= '' and 
            bp.General.UpgradesFrom ~= 'none' then

            if not bp.CategoriesHash['SUPPORTFACTORY'] then
               local unit = table.deepcopy(bp)
               --unit.id = id -- Save id for a reference
               table.insert(units, unit)
            end
        end
    end
    -- Ensure units are sorted in increasing order of upgrades
    -- This increase performance when checking for breaks in upgrade-chain
    table.sort(units, function(bp1, bp2)
        local v1 = bp1.BuildIconSortPriority or bp1.StrategicIconSortPriority
        local v2 = bp2.BuildIconSortPriority or bp2.StrategicIconSortPriority
        if v1 >= v2 then
            return false
        else
            return true
        end
    end)
    return units
end

LOG('BlueprintsAnalyzer.lua ... loaded')
