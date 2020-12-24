
 --TODO complete before committing

    local weaponColumns = { 
        DisplayName = { name = 'WeaponName', desc = '' }, 
        Category = {  desc = '(weapon)' }, 
        Type = {  desc = '(weapon)' }, 
        ProjectileId = {  desc = '' }, 
        Range = { precision = 0, desc = '(weapon)' }, 
        DamageRadius = { name = 'Radius', precision = 0, desc = '(weapon)' }, 
        DamageArea = { name = 'Area', precision = 0, desc = 'math.pow(DamageRadius / 2) * PI' }, 
        Damage = { precision = 0, desc = '(weapon)' }, 
        DamageTotal = { name = 'Total', precision = 0, desc = '= Damage * (number of projectiles or duration of weapon firing cycle)' }, 
        DamagePotential = { name = 'Potential', precision = 0, desc = '= Damage * damage area' }, 
        DPS = { precision = 0, desc = '(damage per second)' }, 
        --DPST = { precision = 0, desc = '(total damage per second)' }, 
        --DPSP = { precision = 0, desc = '(potential damage per second)' }, 
 
        DPM = { precision = 3, desc = '= DPS / BuildCostMass' }, 
        --DPSPM = { precision = 1, desc = '= DPSP / BuildCostMass' }, 
        BuildCostMass = { name = 'Mass', precision = 0, desc = '' }, 
        BuildCostEnergy = { name = 'Energy', precision = 0, desc = '' }, 
        BuildRate = { precision = 0, desc = '(aka build power)' }, 
        BuildTime = { precision = 0, desc = '(in game ticks)' }, 
        BuildDuration = { desc = '= BuildTime / BuildRate (in mm:ss)' },  
        RPS = { precision = 1, desc = 'is weapon rate per second (duration between firing cycles)' }, 
    }
    
    local weaponColumnsOrder = { 
    'DisplayName','Category','Type',
    'ProjectileId',
    'Range',
    'DamageRadius',
    'DamageArea',
    'Damage',
    'DamageTotal',
    'DamagePotential',
    'DPS',
    --'DPST',
    --'DPSP',
    'DPM',
    --'DPSPM',
    'BuildCostMass',
    'BuildCostEnergy',
    'BuildRate',
    'BuildTime',
    'BuildDuration',
    'RPS',
    }

    local unitColumns = {
    'Faction','Type','Tech','WeaponCount','Unit ID','UnitName',
    'Mass','Energy',
    'BuildTime (in game ticks)','BuildRate','HealthHP','ShieldHP',
 --   'WeaponName','Category','Type',
 --   'Range - weapon range',
 --   'Radius - weapon damage radius',
 --   'Area - weapon damage area = math.pow(radius / 2) * PI',
 --   'Damage - weapon damage (includes damage in both inner/outer rings of nukes)',
 --   'Total - weapon damage * (number of projectiles or duration of weapon firing cycle)',
 --   'Potential - weapon damage * weapon damage area',
 --   'DPS - weapon damage per second',
 --   'DPST',
 --   'DPSP',
 --   'DPSM',
 --   'DPSPM',  
 --   'Mass - cost of using weapon or building cost of the unit',
 --   'Energy - cost of using weapon or building cost of the unit',
 --   'BuildRate - build rate of this weapon',
 --   'BuildTime - in game ticks',
 --   'BuildDuration - (BuildTime / BuildRate) in minutes and seconds',
 --   'RPS - weapon rate between firing cycles in seconds',
 --   'ProjID'
    }

local appendLabels = false
local csvSeperator = ';'
local csvLines = {}

--local UA = import('/lua/ui/lobby/UnitsAnalyzer.lua') 
local BA = import('/lua/system/BlueprintsAnalyzer.lua')

-- this table defines rules for checking weapon.RangeCategory field in blueprints
local RangeCategoryRules = {
    ["UWRC_Undefined"] = function(w) return false end,
  --["UWRC_AntiNavy"] = function(w) return w.WeaponCategory == 'Anti Navy' end,
    ["UWRC_AntiNavy"] = function(w) return BA.IsWeaponWithTarget(w, 'Seabed|Sub|Water') end,
  --["UWRC_AntiAir"] = function(w) return w.WeaponCategory == 'Anti Air' end,
    ["UWRC_AntiAir"] = function(w) return BA.IsWeaponWithTarget(w, 'Air') end,
  --["UWRC_Countermeasure"] = function(w) return w.WeaponCategory == 'Defense' end,
    ["UWRC_Countermeasure"] = function(w) return
        BA.IsWeaponWithRestriction(w, 'TORPEDO') or
        BA.IsWeaponWithRestriction(w, 'MISSILE,STRATEGIC') or
        BA.IsWeaponWithRestriction(w, 'MISSILE,TACTICAL') or 
        BA.IsWeaponBeamTractor(w) -- GC tractor claw
    end,
    ["UWRC_DirectFire"] = function(w) return 
        w.WeaponCategory == 'Direct Fire' or 
        w.WeaponCategory == 'Direct Fire Naval' or 
        w.WeaponCategory == 'Direct Fire Experimental' or 
        w.WeaponCategory == 'Kamikaze' 
    end,
    ["UWRC_IndirectFire"] = function(w) return 
        w.WeaponCategory == 'Indirect Fire' or 
        w.WeaponCategory == 'Missile' or 
        w.WeaponCategory == 'Artillery' or 
        w.WeaponCategory == 'Bomb' 
    end,
}

-- this table defines rules for checking weapon.RangeCategory field in blueprints
local WeaponCategoryRules = {
    ["Teleport"] = function(w) return w.DisplayName == 'Teleport in' end,
    ["Defense"] = function(w) return w.RangeCategory == 'UWRC_Countermeasure' end,
    ["Anti Navy"] = function(w) return w.RangeCategory == 'UWRC_AntiNavy' end,
    ["Anti Air"] = function(w) return w.RangeCategory == 'UWRC_AntiAir' end,
    ["Direct Fire"] = function(w) return w.RangeCategory == 'UWRC_DirectFire' end,
    ["Death"] = function(w) return 
        w.DisplayName == 'Death Weapon'  or
        w.DisplayName == 'Death Nuke' or
        w.DisplayName == 'Collossus Death' or
        w.DisplayName == 'Air Crash' 
    end, 
    --TODO: 
    -- Bomb 
    -- Defense
    -- Direct Fire
    -- Direct Fire Experimental
    -- Direct Fire Naval
    -- Experimental
    -- Indirect Fire
    -- Kamikaze
    ["Missile"] = function(w) return w.RangeCategory == 'UWRC_IndirectFire' end,
  --["Artillery"] = function(w) return w.RangeCategory == 'UWRC_IndirectFire' end,
    ["Artillery"] = function(w) return 
        w.Turreted and (w.BallisticArc == 'RULEUBA_LowArc' or BallisticArc == 'RULEUBA_HighArc')
    end,
}

 
function VerifyWeapons(bp)

    local bpInfo = bp.ID .. '_unit.bp'

    -- check only weapons with damage and skip all dummy/insignificant weapons
    local weapons = table.filter(bp.Weapon or {}, 
        function(v) return BA.GetWeaponDamage(w) > 0 end)
    
    for i, w in weapons or {} do
        local weaponInfo = 'weapon with ' .. i .. ' index and name:' .. (w.DisplayName or '')
        -- check if a weapon has correct RangeCategory
        for expected, isRuleMatching in RangeCategoryRules do
            if expected ~= w.RangeCategory and isRuleMatching(w) then
                local issue = not w.RangeCategory and ' is missing ' or ' should have '
                WARN(bpInfo .. issue .. '"'.. expected .. '" RangeCategory in ' .. weaponInfo)
                break -- skip checking other RangeCategory rules
            end
        end
        -- check if a weapon has correct WeaponCategory
        for expected, isRuleMatching in WeaponCategoryRules do
            if expected ~= w.WeaponCategory and isRuleMatching(w) then
                local issue = not w.WeaponCategory and ' is missing ' or ' should have '
                WARN(bpInfo .. issue .. '"'.. expected .. '" WeaponCategory in ' .. weaponInfo)
                break -- skip checking other WeaponCategory rules
            end
        end

    end
end

function ShowWeapons(blueprints)
    local weapons = {}

    
    --local valid2 = table.filter(blueprints[2].Weapon or {}, BA.IsWeaponSignificant(w) )
    --LOG('valid2=' .. table.getsize(valid1))
    
    local allRC = {}
    local allWC = {}
    local allTargetLayers = {}
    local allTargetRestrictions = {}
    local allArtillery = {}
    local allArcs = {}
    for bid, bp in blueprints do

   -- local valid = table.filter(bp.Weapon or {}, function(w) return BA.GetWeaponDamage(w) > 0 end)
    --LOG(bid .. ' valid=' .. table.getsize(valid))
    
        for wid, w in bp.Weapon or {} do
            local range = w.RangeCategory or 'nil'
            local cat = w.WeaponCategory or 'nil'  
            local name = w.DisplayName or 'nil' 
            local info = 'r=' .. range ..' c=' .. cat..'   ' .. bid .. ' name=' .. name
            
            if BA.GetWeaponDamage(w) <= 0 then
                range = 'NO_DAMAGE'
            end
            if not weapons[range] then
                weapons[range] = {}
            end
            
            if range == 'UWRC_Countermeasure' then
                info = ' Allow=' .. w.TargetRestrictOnlyAllow .. ' ' .. info
            end

            if not allWC[cat] then allWC[cat] = true end
            if not allRC[range] then allRC[range] = true end
            
            local rest = w.TargetRestrictOnlyAllow or 'nil' 
            if not allTargetRestrictions[rest] then allTargetRestrictions[rest] = true end
            
            for source, target in w.FireTargetLayerCapsTable or {} do
                local key = source .. '=' ..  target
                if not allTargetLayers[key] then allTargetLayers[key] = true end
            end 
             
           --  if range == 'UWRC_IndirectFire'  then
                local U = w.WeaponUnpacks and 'T' or 'F'
                local T = w.Turreted and 'T' or 'F'
                local awt = w.AboveWaterTargetsOnly and 'T' or 'F'
                local key = bp.ID .. ' w=' .. wid
                -- if  not allArtillery[key] then
                     local val = cat .. 
                     ' unp=' ..U  ..
                     ' tur=' ..T  ..
                     ' awt=' ..awt  ..
                     ' a=' ..tostring(w.BallisticArc) .. 
                     ' dr=' ..tostring(w.DamageRadius).. 
                     ' pl=' ..tostring(w.ProjectileLifetime).. 
                     ' rc=' ..tostring(w.RackSalvoSize) .. 
                     ' ms=' ..tostring(w.MuzzleSalvoSize) .. 
                     ' mr=' ..tostring(w.MaxRadius) .. 
                     ' mc=' ..tostring(w.MuzzleChargeDelay) 
                     
                    table.insert(allArtillery, val ..' '.. key)
                -- end
            -- end
             local arc = w.BallisticArc or 'nil'
             if not allArcs[arc] then allArcs[arc] = true end
            
            table.insert(weapons[range], info)
        end
    end
    for _, w in weapons do
        table.sort(w)
    end
  --  table.print(weapons,'weapons')

    table.sort(allWC)
    table.sort(allRC)
    table.sort(allTargetLayers)
    table.sort(allWC)
    table.sort(allArtillery)
    table.sort(allArcs)
 --  table.print(allTargetRestrictions,'allTargetRestrictions')
  -- table.print(allTargetLayers,'allTargetLayers')

   -- table.print(allArtillery,'allArtillery')
    --table.print(allArcs,'allArcs')
    --table.print(allWC,'allWC')
    --table.print(allRC,'allRC')
end


local function comma(label)
    if not label then return csvSeperator end
    return appendLabels and label .. csvSeperator or csvSeperator
end

local function csvFormat(number, precision)
    if not number then return 0 end
    local ret = 0
    if not precision then
        ret = math.floor(number+.5)
    else
        ret = string.format("%." .. (precision or 0) .. "f", number)
        --ret = tonumber(str)
    end 
    ret = StringComma(ret) 
    return ret
end

local function csv(bp)
        local name = LOCF(bp.Name)
        local weapons = BA.GetWeaponsWithDamage(bp)
        local eco = BA.GetSpecsForEconomy(bp)

        local key = csvSeperator.. bp.Faction .. comma()
        key = key .. bp.Type .. comma()
        key = key .. bp.Tech .. comma()
        key = key .. 'W'.. table.getsize(weapons) .. comma()
        key = key .. bp.ID .. comma()
        if string.find(name,',')  then
            --key = key .. '???' .. comma()
            key = key .. '"'.. name.. '"'.. comma()
        else
            key = key .. name .. comma()
        end
        --key = key .. 'eco, '
        key = key .. csvFormat(eco.BuildCostMass) .. comma('m')
        key = key .. csvFormat(eco.BuildCostEnergy) .. comma('e')
        key = key .. csvFormat(eco.BuildTime) .. comma('bt')
        key = key .. csvFormat(eco.BuildRate) .. comma('br')
        key = key .. csvFormat(bp.Defense.Health or 0) .. comma('hp')
        key = key .. csvFormat(bp.Defense.Shield.ShieldMaxHealth or 0) .. comma('sp')
         
        -- LOG(key)
        --table.print(bp.Weapon, bp.ID) 
        if table.getsize(weapons) == 0 then
           -- table.insert(csvLines, key )  
        else
            for id, w in weapons do
                local weapon = BA.GetSpecsForWeapons(bp, w)
                if id == 2 then --not weapon.BuildDuration then
                    weapon.Shots = BA.GetWeaponShots(bp, w)
                   table.print(weapon, bp.ID) 
                end
                --TODO remove
                if weapon.ECO_PRO then 
                     
                    local wi = ''

                    for _, parameter in weaponColumnsOrder do
                        local column = weaponColumns[parameter]
                        if not column then
                            wi = wi .. tostring(weapon[parameter])
                        else
                            if column.precision then
                                wi = wi .. csvFormat(weapon[parameter], column.precision)
                            else
                                wi = wi .. tostring(weapon[parameter])
                            end
                        end
                        wi = wi ..  comma()
                    end

                    table.insert(csvLines, key .. wi)
                     
            --    wi = wi .. weapon.RPS .. comma('rps')
            --    wi = wi .. tostring(weapon.ProjectileId) .. comma()
                    --WARN(key .. wi)
             --       table.insert(csvLines, key .. wi)
                end
            end
        end 
    end


function OutputCsv(unitBlueprint)

    --local pro = projectiles.All['/projectiles/siflaansetacticalmissile02/siflaansetacticalmissile02_proj.bp']
    --table.print(pro, 'pro')

    LOG('sep=' .. csvSeperator )  

    local csvHeader = 'LOG ' ..csvSeperator .. table.concat(unitColumns , csvSeperator)
    for _, name in weaponColumnsOrder do
        csvHeader = csvHeader .. csvSeperator
        local column = weaponColumns[name]
        
        if column and column.name then
            csvHeader = csvHeader .. column.name
        else
            csvHeader = csvHeader .. name
        end

        if column and column.desc then
            csvHeader = csvHeader .. ' '.. column.desc
        end
    end
     
    LOG(csvHeader )   
     
    local tmlUnits = {}
    csvLines = {}
    
   --  WARN(num .. ' >> '.. round(num, 2) )
   -- if bp then 
    local id = string.lower('XSS0303') -- ueb2204 xaa0202  ueb2305 xaa0202
    local bp = unitBlueprint[id]   
    --if bp then  csv(bp) end
   --     --table.print(bp.CategoriesHash, bp.ID)
   -- end 
   --csv(table.firstValue(csvLines))
   --table.firstValue(csvLines)
     --  WARN( table.firstValue(csvLines)  )

    --for bid, bp in unitBlueprint or {} do
    --      csv(bp)
    --end
  
     table.sort(csvLines)
     for _, v in csvLines or {} do
        WARN(v)
     end
      

end
