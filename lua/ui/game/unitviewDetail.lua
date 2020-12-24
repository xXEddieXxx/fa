local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Group = import('/lua/maui/group.lua').Group
local Text = import('/lua/maui/text.lua').Text
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local UIUtil = import('/lua/ui/uiutil.lua')

local GameCommon = import('/lua/ui/game/gamecommon.lua')
local Prefs = import('/lua/user/prefs.lua')
--local options = Prefs.GetFromCurrentProfile('options')
local UnitDescriptions = import('/lua/ui/help/unitdescription.lua').Description

local BPA = import('/lua/system/BlueprintsAnalyzer.lua')
local BPV = import('/lua/system/BlueprintsVerifier.lua') 
local UVS = import('/lua/ui/game/unitviewStyler.lua')
--local UVS = '/lua/ui/game/unitviewStyler.lua'

local controls = import('/lua/ui/controls.lua').Get()

View = controls.View or false
MapView = controls.MapView or false
ViewState = "full"

local showColumns = { 
    Defense = nil, 
    Upkeep = nil, 
    BuildCost = nil, 
    BuildRate = nil, 
    Abilities = nil
}

GUI = {}
GUI.MaxWidth = 590 --540
GUI.MinWidth = 400 
   
 --TODO-HUSSAR-DONE combine stats of preset SCUs see bp.EnhancementPresets https://github.com/FAForever/fa/issues/1204
 --TODO-HUSSAR check if battleship weapons have correct DPS https://github.com/FAForever/fa/issues/1214
 --TODO-HUSSAR-DONE fix https://github.com/FAForever/fa/issues/1184
 --TODO-HUSSAR-DONE fix unit abilities https://github.com/FAForever/fa/issues/1841
 
 --TODO-HUSSAR move to BlueprintsAnalyzer.lua
local Blueprints = { Units = {}, Projectiles = {}  } 
 
function InitBlueprints()
    --LOG('_VERSION '.. tostring(_VERSION))
    --if table.size(Blueprints) > 0 then return end
    
    Blueprints = { Units = {}, Projectiles = {}  } 
 
    local bpTypes = { }
    local bpSources = { missing = {}, empty = {}, dup = {}, org = {} }
    
    local bpProjectiles = { }
    --TODO-HUSSAR move for loop to BPA.Init(__blueprints)
    -- blueprints are store by index and by unique ID or bp.Source 
    -- we need only those with UID to look them up later
    for bid, bp in __blueprints or {} do
         
        local hasUID = not tonumber(bid) 

        if hasUID and bp.SourceType then
            if not bpTypes[bp.SourceType] then
                bpTypes[bp.SourceType] = {}
            end
            bpTypes[bp.SourceType][bid] = true
        end
        if not bp.Source then
            bpSources.missing[bid] = true
        elseif bp.Source == '' then
            bpSources.empty[bid] = true
        end

        if hasUID and bp.SourceType == 'Projectile' then
            if not bpSources.org[bid] then
                bpSources.org[bp.Source] = true 
            elseif not bpSources.dup[bp.Source] then
                bpSources.dup[bp.Source] = 1
            else
                bpSources.dup[bp.Source] = bpSources.dup[bp.Source] + 1
            end
        end

        local hasProj = string.find(bid,'_proj.bp') 
        local hasUnit = string.find(bp.Source,'_unit.bp') 
        --if bp.General and bp.General.UnitWeight then
        --    Blueprints.Proj[bid] = bp.Source
        --    eco = eco + 1
        --end
        if hasUID and hasProj and string.find(bid,'projectiles') then
            Blueprints.Projectiles[bid] = bp
        end
        if hasUID and hasUnit and bp.CategoriesHash 
            and not bp.CategoriesHash['CIVILIAN'] 
            and not bp.CategoriesHash['OPERATION']  then 
            bp.ID = bid
            --TODO-HUSSAR call local bp = BPA.InitBlueprint(bp)
            Blueprints.Units[bid] = bp 
        end
    end
    LOG('Projectiles ' .. table.size(Blueprints.Projectiles) .. ' vs ' .. table.size(bpTypes.Projectile))

    --bpSources.org = nil
    --table.print(bpSources,'bpSources') 
    --table.print(bpTypes.Projectile,'bpTypes.Projectile') 

    --table.print(bpTypes.Unit,'bpGroupings')
      

    --LOG('Blueprints.e='.. table.size(Blueprints.effects)  )
    
    BPA.Init(__blueprints)
          
end

 --TODO-HUSSAR move to BlueprintsAnalyzer.lua
-- define order or lines with info about weapons in tooltip
local weaponsOrder = {
    'Death', 'Defense', 'Teleport', 'Experimental', -- GC's tractor claws
    'Anti Air', 'Bomb', 'Kamikaze',
    'Indirect Fire', 'Artillery', 'Missile',
    'Anti Navy',
    'DirectFire', 'Direct Fire', 
    'Direct Fire Experimental', 
    'Direct Fire Naval', 
}
  
 --TODO-HUSSAR move to BlueprintsAnalyzer.lua
function AddWeaponSpecs(weapon1, weapon2) 
    weapon1.Count = weapon1.Count + weapon2.Count
    weapon1.PPF = weapon1.PPF + weapon2.PPF
    weapon1.DOT = weapon1.DOT + weapon2.DOT
    weapon1.FireCycle = weapon1.FireCycle + weapon2.FireCycle
    weapon1.BuildCycle = weapon1.BuildCycle + weapon2.BuildCycle
    weapon1.DPS = weapon1.DPS + weapon2.DPS
    weapon1.DPM = weapon1.DPM + weapon2.DPM 
    weapon1.Damage = weapon1.Damage + weapon2.Damage
    weapon1.DamageTotal = weapon1.DamageTotal + weapon2.DamageTotal
    -- distance and area do not stack up so just get smallest value
    weapon1.DamageRadius = math.min(weapon1.DamageRadius, weapon2.DamageRadius)
    weapon1.DamageArea = math.min(weapon1.DamageArea, weapon2.DamageArea)
    weapon1.Range = math.min(weapon1.Range, weapon2.Range)
    weapon1.Specs = LOCF("<LOC gameui_0001>Damage: %d, Rate: %0.2f (DPS: %d) Range: %d", 
        weapon1.DamageTotal, weapon1.FireCycle, weapon1.DPS, weapon1.Range)
end
  

function Contract()
    View:Hide()
end

function Expand()
    View:Show()
end

function CheckFormat()
    if ViewState ~= Prefs.GetOption('uvd_format') then
        SetLayout()
    end
    if ViewState == "off" then
        return false
    else
        return true
    end
end

local Options = {}

-- checks for changes and safely update options of this GUI
function CheckOptions()
    -- updates the Options table with current values 
    -- in game preferences or use default value
    local function UpdateOptions(key, defaultValue)
        local currentValue = Prefs.GetOption(key)
        if currentValue == nil then
           Options[key] = defaultValue
        else
           Options[key] = currentValue
        end
    end

    UpdateOptions('uvd_show_abilities', true)
    UpdateOptions('uvd_show_description', true)
    UpdateOptions('uvd_show_intel_stats', true)
    UpdateOptions('uvd_show_movement_stats', true) 
    UpdateOptions('uvd_show_upgrade_stats', true)
    UpdateOptions('uvd_show_weapon_stats', true)
    UpdateOptions('uvd_show_weapon_dpm', false)
    UpdateOptions('uvd_show_weapon_aoe', false)
    UpdateOptions('uvd_show_weapon_cost', false)
    UpdateOptions('uvd_show_hitpoints_per_mass', false)
    UpdateOptions('uvd_show_buildrate_per_mass', false)
    UpdateOptions('uvd_font_bold', false)
    UpdateOptions('uvd_font_size', 12)
    UpdateOptions('uvd_background_opacity', 30)

    Options['uvd_font_name'] = Options['uvd_font_bold'] and 'Arial Bold' or UIUtil.bodyFont()

end
 
function ShowView(enhancement)

--    LOG('ShowView '  .. tostring(View.UnitAvatar.Fill:IsHidden()))
    import('/lua/ui/game/unitview.lua').ShowROBox(false, false)
    View:Show()
    View.UnitAvatar.Strat:SetHidden(enhancement)
    View.UnitAvatar.Fill:SetHidden(View.UnitAvatar.showAsUpgrade)

    View.EconomyColumn:SetHidden(not showColumns.BuildCost)

    View.UpkeepColumn:SetHidden(not showColumns.Upkeep)

--    showColumns.Defense = not enhancement
    View.DefenseColumn:SetHidden(enhancement)

    if View.Description and table.size(View.Description.Lines) > 0 then
       local isViewEmpty = true
       for i, line in View.Description.Lines or {} do 
           if line:GetText() ~= "" then
              isViewEmpty = false
              break
           end
       end
--       local isViewEmpty = View.Description.isEmpty -- View.Description.Lines[1]:GetText() == ""
       local isViewLimited = ViewState == "limited"
       View.Description:SetHidden(isViewLimited or isViewEmpty)

       LayoutDescription() 
    end
end

function ShowEnhancement(upgrade, bpID, iconID, iconPrefix, builderUnit)

    CheckOptions()

    if not CheckFormat() then
        View:Hide()
        return
    end
    upgrade.UnitID = bpID

    local bp = __blueprints[bpID]

    LOG('UnitViewDetails ShowEnh ' .. bpID .. ' ' .. upgrade.Name)
    InitBlueprints() -- TODO-HUSSAR call it only once!

    --table.print(upgrade, 'ShowEnhancement ' .. bpID)

    View.UnitAvatar.Icon:SetTexture(UIUtil.UIFile(iconPrefix .. '_btn_up.dds'))
    View.UnitAvatar.showAsUpgrade = true
    
    -- Name / Description
--    LayoutHelpers.AtTopIn(View.UnitName, View, 10)
--    View.UnitName:SetFont(UIUtil.bodyFont, 16)
    View.FactionIcon:SetTexture(BPA.GetUnitFactionIcon(bp, true))
    View.FactionIcon.Height:Set(18)
    View.FactionIcon.Width:Set(18)
    View.FactionColor:SetSolidColor(BPA.GetUnitFactionForeground(bp))
    LayoutHelpers.FillParent(View.FactionColor, View.FactionIcon)
    LayoutUnitName()
    LayoutUnitAvatar()

    View.UnitName:SetText(BPA.GetUpgradeName(upgrade))
--    FitInText(View.UnitName, View.BG, { 18, 17, 16, 15, 14, 13, 12, 11, 10, 9 })
--    FitInText(View.UnitName, View.BG, { 26, 22, 20, 16, 15, 14, 13, 12, 11, 10, 9 })

    showColumns.BuildCost = true
    showColumns.Upkeep = true
    showColumns.Defense = false

    local showAbilities = false
    local time, energy, mass = 0, 0, 0

    -- hide UI for upgrades that remove/undo upgrades
    if upgrade.Icon == nil or string.find(upgrade.Name, 'Remove') then
        showColumns.BuildCost = false
        showColumns.Upkeep = false

        if View.Description then
           View.Description:Hide()
           for i, v in View.Description.Lines do
               v:SetText("")
           end
        end
    else -- update UI for icons that can not be built
        time, energy, mass = import('/lua/game.lua').GetConstructEconomyModel(builderUnit, upgrade)
        time = math.max(time, 1)
        DisplayResources(upgrade, time, energy, mass)
         
        -- If SubCommander enhancement, then remove extension. (ual0301_Engineer --> ual0301)
        if string.find(bpID, '0301_') then
            bpID = string.sub(bpID, 1, string.find(bpID, "_[^_]*$")-1)
        end
        local upgradeDescKey = bpID.."-"..iconID
        local upgradeDesc = UnitDescriptions[upgradeDescKey] 
        if upgradeDesc then
           upgradeDesc = LOC(upgradeDesc)
        else
           upgradeDesc = "No description found for " .. upgrade.ID.. " upgrade with '" .. upgradeDescKey .. "' key" 
           WARN(upgradeDesc) 
        end
         
        WrapAndPlaceText(bp, upgradeDesc, View.Description, upgrade)
    end
     
--    local def = BPA.GetSpecsForDefense(bp)
--    if def.ShieldArmor > 0 then
--        showColumns.Defense = true
--        --View.ShieldStat.Value:SetText(upgrade.ShieldMaxHealth)

--        UVS.SetStyle(View.DefenseColumn.Shield.Text, 'Shield', def.ShieldInfo)
--    end

    ShowView(true)
     
end

--function WrapAndPlaceText(air, physics, weapons, abilities, text, control, upgrade)
function WrapAndPlaceText(unitBp, desc, control, upgrade)
    --table.print(bp.CategoriesHash, 'bp.CategoriesHash ' )
    
    if not control then return end

    local fontSize = Options['uvd_font_size']
    local fontName = Options['uvd_font_name']
    local useBoldFontForNumbers = Options['uvd_font_bold'] 

    local air = false
    local physics = false
    local weapons = false
    local abilities = false
    local intel = false
    local economy = false
    local bp = unitBp 
    
    if not upgrade then
        --bp = unitBp
    --else
        --bp = BPA.GetEnhancedBlueprint(unitBp) 
        abilities = bp.Display.Abilities
        --LOG('enhancing bp .... ' ..bp.Economy['ProductionPerSecondMass'])
        air = bp.Air
        physics = bp.Physics
--        economy = bp.Economy
        intel = bp.Intel
        weapons = bp.Weapon
    end
    
    -- find max width of a line based on max string and font size selected in game options
    local testParent = View.Description.BG  
    local testStr = '1000 Range     4.0 AOE     1.0k Damage      500 DPS      5.00 DPM      3.0s Reload'
    View.Description.TestBox = UIUtil.CreateText(testParent, testStr, fontSize, "Arial Bold")
    LayoutHelpers.AtLeftIn(View.Description.TestBox, testParent, 0)
    LayoutHelpers.AtBottomIn(View.Description.TestBox, testParent, 0)
    local maxWidth = View.Description.TestBox.Width() + 10
    -- clean up test box after calculating max width of a line
    View.Description.TestBox:Hide()
    View.Description.TestBox:Destroy()
    View.Description.TestBox = nil

    -- layout description/details control
    control.Left:Set(function() return View.BG.Right() + 10 end)
--    control.Width:Set(function() return GUI.MaxWidth - 5 end)
    control.Width:Set(function() return maxWidth + 20 end)
    control.Right:Set(function() return control.Left() + control.Width() end)
    control.Bottom:Set(function() return View.BG.Bottom() - 15 end)
       
    local lines = {}
    local showBlankLine = false -- enable only for debugging 
    local function InsertBlankLine(from)
        if showBlankLine then
            table.insert(lines, { style = 'Default', text = from })
        else
            table.insert(lines, { style = 'Default', text = '' })
        end
    end

    if abilities and Options['uvd_show_abilities'] then
        -- concatenate all abilities 
        local abilitiesLoc = table.map(LOC, abilities)
        local abilitiesStr = table.concat(abilitiesLoc, ', ')
        -- wrap abilities based on width of UI
        local abilitiesLines = import('/lua/maui/text.lua').WrapText(abilitiesStr, control.Lines[1].Width(),
            function(txt) return control.Lines[1]:GetStringAdvance(txt) end)
        for _, v in abilitiesLines do
            table.insert(lines, { style = 'Abilities', text = v })
        end
    end
     
    if desc and Options['uvd_show_description'] then
        -- wrap description string based on width of UI
        local descLines = import('/lua/maui/text.lua').WrapText(desc, control.Lines[1].Width(),
            function(desc) return control.Lines[1]:GetStringAdvance(desc) end)
        for _, v in descLines do
            table.insert(lines, { style = 'Description', text = v })
        end
    end
    
    --TODO-HUSSAR add options.gui_tooltips.show_upgrade
    if upgrade and Options['uvd_show_upgrade_stats'] and __blueprints[upgrade.UnitID] then
        InsertBlankLine('Upgrades')  
         
        local specs = BPA.GetUpgradeSpecs(bp, upgrade) 
        for key, spec in specs.changes do
            if not spec.Info then
                WARN('GetUpgradeSpecs is missing info for ' .. key)
            else
                table.insert(lines, { style = spec.Style, text = spec.Info })
            end
        end
        for key, addon in specs.addons do
            table.insert(lines, { style = 'Rate', text = addon })
        end
         
        if table.size(specs.weapons) > 0 then 
            weapons = specs.weapons
        end
    end
    
    --TODO-HUSSAR add options.gui_tooltips.show_weapons
--    if options.gui_render_armament_detail == 1 then 
         
        if table.size(weapons) > 0 then
            local weaponSpecs = {}
            --local AirWeapons = {} 

            --TODO-HUSSAR move to BPA.GetSpecsForWeapons()
            for i, weapon in weapons do      
             
                if BPA.IsWeaponValid(weapon) then
                    local specs = BPA.GetSpecsForWeapons(bp, weapon, i) 
                    --TODO-HUSSAR add options.gui_tooltips.combine_weapons similar weapons
                    local key = specs.Title .. specs.UniqueId
                    if not weaponSpecs[key] then
                         weaponSpecs[key] = specs
                    else
                        --local w1 = weapons[specs.WeaponId]
                        --local w2 = weapon
                        --LOG('w1 '.. weaponSpecs[key].uid .. ' ' .. weaponSpecs[key].WeaponId) 
                       -- LOG('w2 '.. specs.uid .. ' ' .. specs.WeaponId) 
                         AddWeaponSpecs(weaponSpecs[key], specs)
                    end
                end
            end
            --table.print(t2,'t2')
            --table.print(t2,'t2')
            --table.print( table.delta(t1, t2),'delta')

            -- soring weapons based on the Category field
            weaponSpecs = table.sortBy(weaponSpecs, 'UniqueId', 'Group', weaponsOrder)
            --table.print(weaponSpecs, 'weaponSpecs2')
            
          --  local w1 = weapons[8]
          --  local w2 = weapons[8]
        --  --          local delta = table.delta(w1, w2)
        --  table.print(table.delta(w1,w2), 'weapons delta', WARN)
        --   for key, w2 in weapons do
        --       if key ~= 1 and key ~= 2 then
        --           local delta = table.delta(w1, w2, 'w1', 'w'.. key)
        --            table.print(delta,'w'.. key, WARN)
        --       end
        --   end
        
            if table.getn(weaponSpecs) > 0 then
               InsertBlankLine('weapons') 
            end

            local weaponCost = { Title = '', Mass = 0, Energy = 0}
            for i, w in weaponSpecs do
--                LOG('weaponSpecs ' .. w.Title .. ' ' .. w.RangeCategory)
                local title = w.Title 
                if w.Count > 1 then 
                   title = title .. ' (' ..w.Count .. ')'
                end

                if Options['uvd_show_weapon_stats'] then
                    table.insert(lines, { style = 'WeaponTitle', text = title })
--                    table.insert(lines, { style = w.Group, text = w.Specs }) 
                    table.insert(lines, { style = w.RangeCategory, text = w.Specs }) 
                end 

                if Options['uvd_show_weapon_cost'] and weaponCost.Mass < w.BuildCostMass then
                   weaponCost.Mass = 'Mass: '.. BPA.FormatNumber(w.BuildCostMass)  
                   weaponCost.Energy = 'Energy: '.. BPA.FormatNumber(w.BuildCostEnergy)
                   weaponCost.Title = 'Missile Cost (' .. w.DisplayName .. ')'
                end
            end

            if weaponCost.Mass > 0 then 
                table.insert(lines, { style = 'Default', text = '' })
                table.insert(lines, { style = 'Default', text = weaponCost.Title })
                table.insert(lines, { style = 'Mass', text = weaponCost.Mass })
                table.insert(lines, { style = 'Energy', text = weaponCost.Energy })
            end
        end
        
        --TODO-HUSSAR add options.gui_tooltips.show_eco
        if economy and bp and Options['uvd_show_buildrate_per_mass'] then
            local isFactory = bp.CategoriesHash['FACTORY'] and not bp.CategoriesHash['MOBILE']
            local isEngineer = bp.CategoriesHash['ENGINEER']  
            
            local buildItems = {}
            local massItems = {} 
            local energyItems = {}

            local function append(tbl, label, value)
                if value ~= nil and value ~= 0 then
                    table.insert(tbl, BPA.FormatNumber(value, true) .. ' ' .. label)
                end
            end
            
            if isEngineer or isFactory then
                local bpm = economy.BuildRate / economy.BuildCostMass
                append(buildItems, 'Build Power', economy.BuildRate)--TODO-HUSSAR localize
                append(buildItems, 'BPM', bpm)--TODO-HUSSAR localize
            end
            if isEngineer then 
                append(buildItems, 'Build Range', economy.MaxBuildDistance)--TODO-HUSSAR localize
            end

            local massYield = economy.ProductionPerSecondMass or 0
            if economy.MaxMass > 0 then
               massYield = massYield + economy.MaxMass
            end
            append(massItems, 'Mass Yield', massYield)--TODO-HUSSAR localize
            append(massItems, 'Mass Storage', economy.StorageMass)--TODO-HUSSAR localize

            local energyYield = economy.ProductionPerSecondEnergy or 0
            if economy.MaintenanceConsumptionPerSecondEnergy > 0 then
               energyYield = energyYield - economy.MaintenanceConsumptionPerSecondEnergy
            end
            if economy.MaxEnergy > 0 then
               energyYield = energyYield + economy.MaxEnergy
            end
            append(energyItems, 'Energy Yield', energyYield)--TODO-HUSSAR localize
            append(energyItems, 'Energy Storage', economy.StorageEnergy)--TODO-HUSSAR localize
            
            if table.size(massItems) > 0 then
               table.insert(lines, { style = 'Mass', text = table.concat(massItems, ', ')})
            end
            if table.size(energyItems) > 0 then
               table.insert(lines, { style = 'Energy', text = table.concat(energyItems, ', ')})
            end
            if table.size(buildItems) > 0 then
               table.insert(lines, { style = 'Rate', text = table.concat(buildItems, ', ')})
            end
        end

        local physicsSpecs = {}
        if not upgrade and Options['uvd_show_movement_stats'] then
            physicsSpecs = BPA.GetSpecsForPhysics(bp)
        end

        local intelSpecs = {}
        if not upgrade and Options['uvd_show_intel_stats'] then
            intelSpecs = BPA.GetSpecsForIntel(bp)
        end

        -- combines intel and physics specs so it's easier to compared them for similar units
        local summarySpecs = {} 
        if bp.CategoriesHash.MOBILE and not bp.CategoriesHash.MOBILESONAR then
            -- order intel specs after physics specs for mobile units expects for mobile sonars
            if physicsSpecs.Info then
                table.insert(summarySpecs, physicsSpecs.Info) 
            end 
            if intelSpecs.Info then 
                table.insert(summarySpecs, intelSpecs.Info)
            end
        else
            -- order physics specs after intel specs for structures and sonars
            if intelSpecs.Info then 
                table.insert(summarySpecs, intelSpecs.Info)
            end
            if physicsSpecs.Info then
                table.insert(summarySpecs, physicsSpecs.Info) 
            end 
        end

        if table.size(summarySpecs) > 0 then
           local summary =  table.concat(summarySpecs, '     ')
           InsertBlankLine('Intel') 
           table.insert(lines, { style = 'Intel', text = summary})
        end
--    end

    for i, line in lines do 
        local index = i
        if control.Lines[index] then
           control.Lines[index]:SetText(line.text or '')
--           control.Lines[index].Left:Set(function() return control.Left() + 18 end)
--           control.Lines[index].Right:Set(function() return control.Right() - 10 end) 
--           control.Lines[index].Width:Set(function() return control.Right() - control.Left() - 24 end)

            --control.Lines[index].Width:Set(function() return control.Right() - control.Left() - 54 end)
            control.Lines[index]:SetClipToWidth(true)
        else 
            control.Lines[index] = UIUtil.CreateText(control, line.text, 12, UIUtil.bodyFont)
            LayoutHelpers.Below(control.Lines[index], control.Lines[index - 1])
--            control.Lines[index].Left:Set(function() return control.Left() + 18 end)
--            control.Lines[index].Right:Set(function() return control.Right() - 7 end)
--            control.Lines[index].Width:Set(function() return control.Right() - control.Left() - 18 end)
--            control.Lines[index]:SetClipToWidth(true)
--            control.Lines[index]:DisableHitTest()
        end
        control.Lines[index].Left:Set(function() return control.Left() + 15 end)
        control.Lines[index].Right:Set(function() return control.Right() - 10 end) 
        control.Lines[index].Width:Set(function() return control.Right() - control.Left() - 24 end)
        control.Lines[index]:SetClipToWidth(true)
        control.Lines[index]:DisableHitTest()

        local style = UVS.GetStyle(line.style, useBoldFontForNumbers)
        -- setting stying for each line 
        control.Lines[index]:SetColor(style.color)
        control.Lines[index]:SetFont(style.font, fontSize)
    end

    -- adjusting height of description UI to fit all lines with unit's statistics
    control.Height:Set(function() 
        local lineHeight = control.Lines[1].Height()
        local lineCount = math.max( table.size(lines), 3)
--        LOG('control.Height ' .. tostring(lineHeight) .. ' count=' .. tostring(lineCount))
        return (lineCount * lineHeight) + 25 -- offsetting by UI bottom border
    end)

    -- clearing all lines that are not in use
    for i, v in control.Lines do
        local index = i
        if index > table.size(lines) then
            v:SetText("")
        end
    end

--     LayoutUnitAvatar() -- TODO remove
--     LayoutDefenseColumn() -- TODO remove
--     LayoutUpkeepColumn() -- TODO remove
end

--TODO remove
function FitInText(textBlock, parent, fontSizes) 
    for _, font in fontSizes do
--        textBlock:SetFont(UIUtil.bodyFont, font)
        local textCrrWidth = textBlock:GetStringAdvance(textBlock:GetText())     
        
        WARN('FitInText ' .. ' crr='.. tostring(textCrrWidth).. ' max=' .. tostring(textCrrWidth) )
       
--        local textMaxWidth = textBlock.Width()
        local textMaxWidth = parent:GetParent().Width()
        if textCrrWidth < textMaxWidth then
--            WARN('FitInText break ' .. font)
            break
        else
           textBlock:SetFont(UIUtil.bodyFont, font)
           LayoutHelpers.AtTopIn(textBlock, parent, 25 - font)
--            WARN('FitInText SetFont ' .. font)
        end
    end
end

function Show(unitBp, builderUnit, unitBpID)

    CheckOptions()

    if not CheckFormat() then
        View:Hide()
        return
    end

    local opacity = Options['uvd_background_opacity']
--    LOG('SetOpacity ' ..tostring(opacity))  
    View:SetOpacity(opacity)
    View.Description:SetOpacity(opacity)

    LOG('----------------------------------------')
    LOG('UnitViewDetails Show ' .. unitBpID .. ' ' .. type(unitBp).. ' ' .. type(builderUnit) )
    unitBp.ID = unitBpID
       
    BPV.VerifyDisplaysAbilities(unitBp)
      
    -- use verified blueprint for preset upgrades, missing abilities
    --LOG('enhancing bp .... ' ..unitBp.Defense['MaxHealth'])
    local bp = BPA.GetVerifiedBlueprint(unitBp)  
    --LOG('enhancing bp .... ' ..bp.Defense['MaxHealth'])
         
    InitBlueprints() -- TODO-HUSSAR call it only once!
     

    --SetupUnitViewLayout(MapView)
     
    -- Name / Description 
--    View.UnitName.Top:Set(function() return View.BG.Top() + 6 end)
--    View.UnitName.Left:Set(function() return View.BG.Left() + 30 end)
--    View.UnitName.Right:Set(function() return View.BG.Right() - 5 end)
--    View.UnitName:SetClipToWidth(true)
    LayoutUnitName()

--    View.UnitName:SetFont(UIUtil.bodyFont, 16) -- 14
    View.UnitName:SetText(BPA.GetUnitTitle(bp))
--    FitInText(View.UnitName, View.BG, { 16, 15, 14, 13, 12, 11, 10, 9 })
--    FitInText(View.UnitName, View.BG, { 20, 16, 15, 14, 13, 12, 11, 10, 9 })

    View.FactionIcon:SetTexture(BPA.GetUnitFactionIcon(bp, true))
    View.FactionIcon.Height:Set(18)
    View.FactionIcon.Width:Set(18)
    View.FactionColor:SetSolidColor(BPA.GetUnitFactionForeground(bp))
    LayoutHelpers.FillParent(View.FactionColor, View.FactionIcon)

    showColumns.BuildCost = false
    showColumns.Upkeep = false
    showColumns.Abilities = false

    local showAbilities = false

    if builderUnit == nil then
        showColumns.BuildCost = false
        showColumns.Upkeep = true

--        local time, energy, mass = import('/lua/game.lua').GetConstructEconomyModel(builderUnit, bp.Economy)
        
--        time = math.max(time, 1)
        DisplayResources(bp, 0, 0, 0)
    else
        -- Differential upgrading. Check to see if building this would be an upgrade
        local targetBp = bp
        local builderBp = builderUnit:GetBlueprint()

        local isUpgrading = false

        if targetBp.General.UpgradesFrom == builderBp.BlueprintId then
            isUpgrading = true
        elseif targetBp.General.UpgradesFrom == builderBp.General.UpgradesTo then
            isUpgrading = true
        elseif targetBp.General.UpgradesFromBase ~= "none" then
            -- try testing against the base
            if targetBp.General.UpgradesFromBase == builderBp.BlueprintId then
                isUpgrading = true
            elseif targetBp.General.UpgradesFromBase == builderBp.General.UpgradesFromBase then
                isUpgrading = true
            end
        end

        local time, energy, mass
        if isUpgrading then
            time, energy, mass = import('/lua/game.lua').GetConstructEconomyModel(builderUnit, bp.Economy, builderBp.Economy)
        else
            time, energy, mass = import('/lua/game.lua').GetConstructEconomyModel(builderUnit, bp.Economy)
        end

        time = math.max(time, 1)
        DisplayResources(bp, time, energy, mass)
    end
     
    WrapAndPlaceText(bp,
        --bp.Air,
        --bp.Physics,
        --bp.Weapon,
        --bp.Display.Abilities,
        LOC(UnitDescriptions[bp.ID]),
        View.Description, false) -- without upgrade
  
    
    local eco = BPA.GetSpecsForEconomy(bp)
    local def = BPA.GetSpecsForDefense(bp)
    showColumns.Defense = def.HealthArmor > 0 or def.ShieldArmor > 0
      
    View.DefenseColumn.Health.Text:SetText(def.HealthInfo)
    View.DefenseColumn.Shield.Text:SetText(def.ShieldInfo)
--    View.DefenseColumn.Rate.Text:SetText(eco.BuildInfo)

    local iconName = GameCommon.GetCachedUnitIconFileNames(bp)
    
    local iconFill = BPA.GetUnitIconBackground(bp)
    View.UnitAvatar.Icon:SetTexture(iconName)
    View.UnitAvatar.Fill:SetTexture(iconFill)
    View.UnitAvatar.showAsUpgrade = bp.CategoriesHash.ISPREENHANCEDUNIT
    
    local iconStrat = BPA.GetUnitIconStrat(bp)
    View.UnitAvatar.Strat:SetTexture(iconStrat)

    ShowView(false)

    LayoutUnitAvatar()
    LayoutEconomyColumn() 
    LayoutUpkeepColumn()
    LayoutDefenseColumn()
      
    --LayoutHelpers.AtLeftTopIn(View.Bracket, View.BG, -18, 0) 
         
    --TODO-HUSSAR remove:
    --View.BG:SetTexture(UIUtil.UIFile('/game/unit-build-over-panel/unit-over-back_bmp.dds'))
--    View.Description.Width:Set(GUI.MaxWidth) -- 400

    -- check if an unit has construction tabs
    if builderUnit then
        -- offset position of Description box by height of T1-T4 construction tabs
        View.Description.Bottom:Set(function() return View.BG.Bottom() - 22 end)
    else
        -- don't offset position of Description box
        View.Description.Bottom:Set(function() return View.BG.Bottom() end)
    end

    --TODO-HUSSAR remove:
--    local OrderGroup = false
--    if not SessionIsReplay() then
--        OrderGroup = import('/lua/ui/game/orders.lua').controls.Fill
--    end
--    if OrderGroup then
--        --LayoutHelpers.Above(control, OrderGroup, 2)
--        LayoutHelpers.Above(View, OrderGroup, 5)
--        LayoutHelpers.AtLeftIn(View, OrderGroup)
--    else
--        LayoutHelpers.AtBottomIn(View, View:GetParent(), 140)
--        LayoutHelpers.AtLeftIn(View, View:GetParent(), 0)
--    end
end



function LayoutRowsIn(column)
    LayoutHelpers.AtTopIn(column.Header, column)
    LayoutHelpers.AtLeftIn(column.Header, column)
    
    local size = Options['uvd_font_size']
    -- stack each row on top of each other
    for i, row in column.rows or {} do
        if i == 1 then
           LayoutHelpers.Below(row.Icon, column.Header, 4)
           LayoutHelpers.AtLeftIn(row.Icon, column)
           row.Icon.Height:Set(size)
           row.Icon.Width:Set(size)
           LayoutHelpers.CenteredRightOf(row.Text, row.Icon, 4)
        else 
           LayoutHelpers.Below(row.Icon, column.rows[i-1].Icon, 6)
           row.Icon.Height:Set(size)
           row.Icon.Width:Set(size)
           LayoutHelpers.CenteredRightOf(row.Text, row.Icon, 4)
        end
    end
end
 
function LayoutEconomyColumn()
    local fontSize = Options['uvd_font_size']
    local fontName = Options['uvd_font_name'] 
    View.EconomyColumn.Time.Text:SetFont(fontName, fontSize)
    View.EconomyColumn.Mass.Text:SetFont(fontName, fontSize)
    View.EconomyColumn.Energy.Text:SetFont(fontName, fontSize)
    View.EconomyColumn.Width:Set(130)
    LayoutHelpers.RightOf(View.EconomyColumn, View.UnitAvatar, 4)
    LayoutHelpers.AtTopIn(View.EconomyColumn, View.UnitAvatar, -2)
    LayoutRowsIn(View.EconomyColumn)
end

function LayoutUpkeepColumn()
    local fontSize = Options['uvd_font_size']
    local fontName = Options['uvd_font_name'] 
    View.UpkeepColumn.Mass.Text:SetFont(fontName, fontSize)
    View.UpkeepColumn.Energy.Text:SetFont(fontName, fontSize)
    View.UpkeepColumn.Rate.Text:SetFont(fontName, fontSize)
    View.UpkeepColumn.Width:Set(70) 
--    View.UpkeepColumn.Top:Set(function() return View.UnitAvatar.Top() -2 end)
--    View.UpkeepColumn.Left:Set(function() return View.EconomyColumn.ActualRight() + 20 end)
    LayoutHelpers.RightOf(View.UpkeepColumn, View.EconomyColumn, 15)
    LayoutRowsIn(View.UpkeepColumn)
end

function LayoutDefenseColumn()
    local fontSize = Options['uvd_font_size']
    local fontName = Options['uvd_font_name'] 
    View.DefenseColumn.Health.Text:SetFont(fontName, fontSize)
    View.DefenseColumn.Shield.Text:SetFont(fontName, fontSize)
    View.DefenseColumn.Width:Set(130)
--    LayoutHelpers.AtTopIn(View.DefenseColumn, View.BG, 30)
--    LayoutHelpers.AtRightIn(View.DefenseColumn, View.BG, 14)
    LayoutHelpers.RightOf(View.DefenseColumn, View.UpkeepColumn, 15)
   
--    View.DefenseColumn.Top:Set(function() return View.UnitAvatar.Top() end)
--    View.DefenseColumn.Left:Set(function()  
--        local right = View.UpkeepColumn.ActualRight() 
--        LOG('LayoutDefenseColumn right ' .. right)
--        return right + 20 end)
        
--        LOG('LayoutDefenseColumn GetRight ' .. tostring(View.UpkeepColumn.GetRight()))
    LayoutRowsIn(View.DefenseColumn)
end

function LayoutDescription() 
    if not View.Description then return end

--        View:SetOrientation('right')
--        View:SetOrientation('left') 
--    View.Width:Set(420) 
    local offset = 20
--    View:SetLayout()
    local skinColor = string.upper(UIUtil.bodyColor())
    if skinColor == 'FF927B00' or skinColor == 'FF18D606' then
        offset = 10
    end 
    View.Description.Left:Set(function() return View.Right() + offset end)
    View.Description.Bottom:Set(function() return View.BG.Bottom() - 15 end)
--    View.Description.Width:Set(GUI.MaxWidth) -- 400
--    View.Description.Height:Set(20)
        
    LayoutHelpers.AtLeftTopIn(View.Description.Lines[1],  View.Description.BG, 10, 4)
    View.Description.Lines[1].Right:Set(function() return View.Description.BG.Right() - 15 end)
    View.Description.Lines[1].Width:Set(function() return View.Description.BG.Right() - View.Description.BG.Left() - 14 end)
    View.Description.Lines[1]:SetClipToWidth(true)

    LayoutHelpers.AtBottomIn(View, View:GetParent(), 125)
    
end


function CreateView(parent)
    CheckOptions()

    View = import('/lua/ui/controls/flexbox.lua').FlexBox(parent, nil, nil, 'UVD_COST') 
--    View.BG = View.Content

    View.FactionIcon = Bitmap(View.BG) 
    View.FactionColor = Bitmap(View.BG) 
    View.FactionColor.Depth:Set(function() return View.FactionIcon.Depth() - 1 end)

    View.UnitName = CreateUnitName(View.BG)
    View.UnitAvatar = CreateUnitAvatar(View.BG)
     
    View.EconomyColumn = CreateColumn(View.BG, '<LOC uvd_0000>Build Cost (Rate)', {'Mass', 'Energy', 'Time'})
    View.UpkeepColumn  = CreateColumn(View.BG, '<LOC uvd_0002>Yield',  {'Mass', 'Energy', 'Rate'})
    View.DefenseColumn = CreateColumn(View.BG, '<LOC uvd_0010>Hitpoints (Per Mass)', {'Health', 'Shield'})

    --TODO remove uvd_format option
--    if Prefs.GetOption('uvd_format') == 'full' then
        -- Description  "<LOC uvd_0003>Description"
        if not View.Description then
            View.Description = import('/lua/ui/controls/flexbox.lua').FlexBox(View, nil, nil, 'UVD_DESC')
--            View.Description.BG = View.Description.Content
            View.Description:SetOrientation('float')

            View.Description.Lines = {}
            View.Description.Lines[1] = UIUtil.CreateText(View.Description.BG, "", 12, UIUtil.bodyFont)
            
            LayoutHelpers.AtLeftTopIn(View.Description.Lines[1], View.Description.BG, 10, 4)
            View.Description.Lines[1].Right:Set(function() return View.Description.BG.Right() - 15 end)
            View.Description.Lines[1].Width:Set(function() return View.Description.BG.Right() - View.Description.BG.Left() - 14 end)
            View.Description.Lines[1]:SetClipToWidth(true)
        end
--    else
--        if View.Description then
--           View.Description:Destroy()
--           View.Description = false
--        end
--    end
    LayoutUnitName()
    LayoutUnitAvatar()

    View:DisableHitTest(true)
    View.Description:DisableHitTest(true)

    return View
end

function DisplayResources(bp, time, energy, mass)

    showColumns.BuildCost = false
    -- updating Economy column 
    if time > 0 then
        local consumeEnergy = -energy / time
        local consumeMass = -mass / time
        local strEnergy = BPA.FormatNumber(energy) .. ' (' .. BPA.FormatNumber(consumeEnergy) .. ')'
        local strMass = BPA.FormatNumber(mass) .. ' (' ..  BPA.FormatNumber(consumeMass) .. ')'
        local strTime = BPA.FormatTime(time)

        View.EconomyColumn.Energy.Text:SetText(strEnergy)
        View.EconomyColumn.Mass.Text:SetText(strMass)
        View.EconomyColumn.Time.Text:SetText(BPA.FormatTime(time))

        --View.EconomyColumn.EnergyValue:SetColor("FFDCAD15") --#FFDCAD15 #FFF72222
        --View.EconomyColumn.MassValue:SetColor("FF35C635") --#FF35C635 #FFF05050
        showColumns.BuildCost = true 
    end

    showColumns.Upkeep = false
    local eco = BPA.GetSpecsForEconomy(bp)
    
    -- updating Upkeep column
    if eco.YieldEnergy ~= 0 or eco.YieldMass ~= 0 then
        View.UpkeepColumn.Header:SetText(LOC("<LOC uvd_0002>Yield") ) --.. ' (Per Mass)')
        View.UpkeepColumn.Energy.Text:SetText(BPA.FormatNumber(eco.YieldEnergy))
        View.UpkeepColumn.Mass.Text:SetText(BPA.FormatNumber(eco.YieldMass)) 
        showColumns.Upkeep = true

    elseif eco.StorageEnergy > 0 or eco.StorageMass > 0 then
        View.UpkeepColumn.Header:SetText(LOC("<LOC uvd_0006>Storage") ) --.. ' (Per Mass)')
        View.UpkeepColumn.Energy.Text:SetText(BPA.FormatNumber(eco.StorageEnergy))
        View.UpkeepColumn.Mass.Text:SetText(BPA.FormatNumber(eco.StorageMass))
        showColumns.Upkeep = true
    else 
        View.UpkeepColumn.Energy.Text:SetText('0')
        View.UpkeepColumn.Mass.Text:SetText('0')
    end
    
--        WARN('DisplayResources eco.BuildRate ' .. eco.BuildRate)
    if eco.BuildRate > 2 then
        showColumns.Upkeep = true
--        View.UpkeepColumn.Build.Icon:SetHidden(false)
--        View.UpkeepColumn.Build.Text:SetHidden(false)
--        View.UpkeepColumn.Build.Icon:Show()
--        View.UpkeepColumn.Build.Text:Show()
--      View.UpkeepColumn.Build.Text:SetText(BPA.FormatNumber(eco.BuildRate))
--        View.UpkeepColumn.Build.Text:SetText( string.format("%01.0f", eco.BuildRate))
        View.UpkeepColumn.Rate.Text:SetText(eco.BuildInfo)
    else
        View.UpkeepColumn.Rate.Text:SetText('0')
    end

end
--TODO-HUSSAR remove
function GetUpkeep(bp)
    local plusEnergyRate = bp.Economy.ProductionPerSecondEnergy or bp.ProductionPerSecondEnergy
    local negEnergyRate = bp.Economy.MaintenanceConsumptionPerSecondEnergy or bp.MaintenanceConsumptionPerSecondEnergy
    local plusMassRate = bp.Economy.ProductionPerSecondMass or bp.ProductionPerSecondMass
    local negMassRate = bp.Economy.MaintenanceConsumptionPerSecondMass or bp.MaintenanceConsumptionPerSecondMass

    local upkeepEnergy = GetYield(negEnergyRate, plusEnergyRate)
    local upkeepMass = GetYield(negMassRate, plusMassRate)

    return upkeepEnergy, upkeepMass
end
--TODO-HUSSAR remove
function GetYield(consumption, production)
    if consumption then
        return -consumption
    elseif production then
        return production
    else
        return 0
    end
end

function OnNIS()
    if View then
       View:Hide()
    end
end

function Hide()
    View:Hide()
end

function SetLayout()
    import(UIUtil.GetLayoutFilename('unitviewDetail')).SetLayout()
end

function SetupUnitViewLayout(parent)
    if View then
       View:Destroy()
       View = nil
    end

    MapView = parent
    controls.MapView = MapView
    SetLayout()
    controls.View = View
    View:Hide()
    View:DisableHitTest(true)
end


function CreateUnitName(parent)
    local UnitName = UIUtil.CreateText(parent, "", 12, UIUtil.bodyFont)
    UnitName:SetColor("FFFF9E06") -- #FFFF9E06
    return UnitName
end
 
function CreateUnitAvatar(parent)
    local group = Group(parent)
    group.Height:Set(70)
    group.Width:Set(52) 
    group.Fill = Bitmap(group)
    group.Fill.Height:Set(46)
    group.Fill.Width:Set(48) 

    group.Icon = Bitmap(group)
    group.Icon.Height:Set(50)
    group.Icon.Width:Set(50) 
    
    group.Strat = Bitmap(group)
    group.Strat.Height:Set(40)
    group.Strat.Width:Set(20) 

--    group.Fill:SetSolidColor('black')

    return group
end
 
-- creates a column with a header title followed by configurable rows
function CreateColumn(parent, title, keys)
 
    local column = Group(parent)
    -- a header is text UI displayed above all rows in the column
    column.Header = UIUtil.CreateText(column, title, 12, "Arial")
    column.Header:SetColor(UIUtil.fontColor()) 
    column.Header:SetDropShadow(true)
    -- table for storing all rows for a given column
    -- this will make it easier to layout and stack rows
    column.rows = {}
    for i, key in keys or {} do 
        -- looking up font style and texture using predefined key
        local style = UVS.GetStyle(key)
        local texture = UVS.GetTextures(key)
        local row = {}
        row.key = key
        row.index = i 
        row.Icon = Bitmap(column)
        row.Icon:SetTexture(UIUtil.UIFile(texture))
        
        row.Text = Text(column, key)
        row.Text:SetFont(style.font, style.size)
        row.Text:SetColor(style.color)
        row.Text:SetDropShadow(true) 

        table.insert(column.rows, row)
        -- creating a reference to a row for quickly finding UI for the row
        -- this avoids looping over all rows when updating values of specific row
        column[row.key] = row
    end
    column.LayoutRowsIn = function() 
    end
    column.ActualRight = function()
        local right = column.Header.Right()
        for i, row in column.rows or {} do 
            right = math.max(right, row.Text.Right())
        end 
        return right 
    end
    column.ActualLeft = function()
        local left = column.Header.Left()
        for i, row in column.rows or {} do 
            left = math.max(left, row.Icon.Left())
        end 
        return left 
    end
    column.ActualWidth = function()
        local right = column.ActualRight()
        local left = column.ActualLeft() 
        return right - left
    end
    return column
end

function LayoutUnitName()
    if not View.UnitName then return end
    LayoutHelpers.AtTopIn(View.FactionIcon, View.BG, 5)
    LayoutHelpers.AtLeftIn(View.FactionIcon, View.BG, 8)
    -- both FactionIcon and FactionColor must be located at the same location
    LayoutHelpers.AtTopIn(View.FactionColor, View.BG, 5)
    LayoutHelpers.AtLeftIn(View.FactionColor, View.BG, 8)
    -- adjusting location of UnitName next to FactionIcon
    
--    LayoutHelpers.Reset(View.UnitName) 
    View.UnitName.Top:Set(function() return View.BG.Top() + 6 end)
    View.UnitName.Left:Set(function() return View.BG.Left() + 28 end)
    View.UnitName.Right:Set(function() return View.BG.Right() - 5 end)
    View.UnitName:SetFont(UIUtil.bodyFont, 14)
    View.UnitName:SetClipToWidth(true)
end


GUI.iconSize = 50
function LayoutUnitAvatar()
    if not View.UnitAvatar then return end
     
    View.UnitAvatar.Height:Set(80)
    View.UnitAvatar.Width:Set(GUI.iconSize)
    LayoutHelpers.AtTopIn( View.UnitAvatar, View.BG, 30)
    LayoutHelpers.AtLeftIn(View.UnitAvatar, View.BG, 6)
     
    View.UnitAvatar.Strat.Height:Set(View.UnitAvatar.Strat.BitmapHeight)
    View.UnitAvatar.Strat.Width:Set( View.UnitAvatar.Strat.BitmapWidth)
    LayoutHelpers.AtTopIn( View.UnitAvatar.Strat, View.UnitAvatar, -2)
    LayoutHelpers.AtLeftIn(View.UnitAvatar.Strat, View.UnitAvatar, -2)
    LayoutHelpers.ResetBottom(View.UnitAvatar.Strat)
    LayoutHelpers.ResetRight(View.UnitAvatar.Strat)

    LayoutHelpers.Reset(View.UnitAvatar.Fill) 
    LayoutHelpers.FillParent(View.UnitAvatar.Fill, View.UnitAvatar)
    LayoutHelpers.Reset(View.UnitAvatar.Icon)

    if View.UnitAvatar.showAsUpgrade then
--        WARN('LayoutAvatar upgrade ' .. tostring(View.UnitAvatar.Fill:IsHidden()))
       View.UnitAvatar.Icon.Height:Set(GUI.iconSize)
       View.UnitAvatar.Icon.Width:Set(GUI.iconSize)
       LayoutHelpers.AtTopIn( View.UnitAvatar.Icon, View.UnitAvatar, 0)
       LayoutHelpers.AtRightIn(View.UnitAvatar.Icon, View.UnitAvatar, 0)
    else
--        LOG('LayoutAvatar unit')
       View.UnitAvatar.Icon.Height:Set(GUI.iconSize)
       View.UnitAvatar.Icon.Width:Set(GUI.iconSize)
       LayoutHelpers.AtBottomIn(View.UnitAvatar.Icon, View.UnitAvatar, 0)
--     LayoutHelpers.AtTopIn( View.UnitAvatar.Icon, View.UnitAvatar, 2)
       LayoutHelpers.AtLeftIn( View.UnitAvatar.Icon, View.UnitAvatar, 0)
--       LayoutHelpers.AtRightIn( View.UnitAvatar.Icon, View.UnitAvatar, 0)
    end
     

--    LayoutHelpers.AtBottomIn( View.UnitAvatar.Strat, View.UnitAvatar, 2)
--    LayoutHelpers.AtLeftIn(View.UnitAvatar.Strat, View.UnitAvatar, 0)
--    LayoutHelpers.ResetTop(View.UnitAvatar.Strat)
--    LayoutHelpers.ResetRight(View.UnitAvatar.Strat)
    
--    View.UnitAvatar.Fill:SetSolidColor('black')
end