
local UIUtil = import('/lua/ui/uiutil.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local GameCommon = import('/lua/ui/game/gamecommon.lua')
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local Prefs = import('/lua/user/prefs.lua')

LOG('unitviewDetail_left.lua loaded')

function CreateResourceGroup(parent, groupLabel)
    local group = Group(parent)
    
    -- Group label
    group.Label = UIUtil.CreateText(group, groupLabel, 12, "Arial Bold")
    group.Label:SetColor("FFBEBEBE") -- #FFBEBEBE
    group.Label:SetDropShadow(true)

    -- Energy Icon
    group.EnergyIcon = Bitmap(group)
    group.EnergyIcon:SetTexture(UIUtil.UIFile('/game/unit-over/icon-energy_bmp.dds'))

    -- Energy Value
    group.EnergyValue = UIUtil.CreateText(group, "0", 12, UIUtil.bodyFont)
    group.EnergyValue:SetColor("FFFCCA28") -- #FFFCCA28
    group.EnergyValue:SetDropShadow(true)

    -- Mass Icon
    group.MassIcon = Bitmap(group)
    group.MassIcon:SetTexture(UIUtil.UIFile('/game/unit-over/icon-mass_bmp.dds'))

    -- Mass Value
    group.MassValue = UIUtil.CreateText(group, "0", 12, UIUtil.bodyFont)
    group.MassValue:SetColor("FF7bc700") -- #FF7bc700
    group.MassValue:SetDropShadow(true)

    return group
end

-- A 'Stat Group' is an icon or text label with a value on the right
-- e.g.  Health 3000
--       Shield 6000
--       <icon> 24
function CreateStatGroup(parent, labelIcon)
    local group = Group(parent)
    
    group.Label = Bitmap(group)
    group.Label:SetTexture(labelIcon)

    group.Value = UIUtil.CreateText(group, "", 14, UIUtil.bodyFont)
    group.Value:SetColor("FF00F000")
    group.Value:SetDropShadow(true)

    return group
end

function CreateTextbox(parent, label, bigBG)
    local group = Group(parent)
    
    if bigBG then
        group.TL = Bitmap(group)
        group.TM = Bitmap(group)
        group.TR = Bitmap(group)
        group.ML = Bitmap(group)
        group.M = Bitmap(group)
        group.MR = Bitmap(group)
        group.BL = Bitmap(group)
        group.BM = Bitmap(group)
        group.BR = Bitmap(group)
        group.TL:SetTexture(UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_ul.dds'))
        group.TM:SetTexture(UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_horz_um.dds'))
        group.TR:SetTexture(UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_ur.dds'))
        group.ML:SetTexture(UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_vert_l.dds'))
        group.M:SetTexture(UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_m.dds'))
        group.MR:SetTexture(UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_vert_r.dds'))
        group.BL:SetTexture(UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_ll.dds'))
        group.BM:SetTexture(UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_lm.dds'))
        group.BR:SetTexture(UIUtil.SkinnableFile('/game/filter-ping-list-panel/panel_brd_lr.dds'))
        group.TL:DisableHitTest()
        group.TM:DisableHitTest()
        group.TR:DisableHitTest()
        group.ML:DisableHitTest()
        group.M:DisableHitTest()
        group.MR:DisableHitTest()
        group.BL:DisableHitTest()
        group.BM:DisableHitTest()
        group.BR:DisableHitTest()
    end

    group.Value = {}
    group.Value[1] = UIUtil.CreateText(group, "", 12, UIUtil.bodyFont)
    
    return group
end

local UVD = '/lua/ui/game/unitviewDetail.lua'

function Create(parent)
    if not import(UVD).View then
        import(UVD).View = Group(parent)
    end
    
    LOG('unitviewDetail_left.lua Create')
    local View = import(UVD).View
    
    if not View.BG then
        View.BG = Bitmap(View)
    end
    View.BG:SetTexture(UIUtil.UIFile('/game/unit-build-over-panel/unit-over-back_bmp.dds'))
    View.BG.Depth:Set(200)
    
    if not View.Bracket then
        View.Bracket = Bitmap(View)
    end
    View.Bracket:DisableHitTest()
    View.Bracket:SetTexture(UIUtil.UIFile('/game/unit-build-over-panel/bracket-unit_bmp.dds'))
    
    -- Unit icon
    if false then
        View.UnitIcon = Bitmap(View)
    end
    
    if not View.UnitImg then
        View.UnitImg = Bitmap(View.BG)
    end
    
    -- Unit Description
    if not View.UnitName then
        View.UnitName = UIUtil.CreateText(View.BG, "", 10, UIUtil.bodyFont)
    end
    View.UnitName:SetColor("FFFF9E06") -- #FFFF9E06

    -- Cost
    if not View.EconomyColumn then
        View.EconomyColumn = CreateResourceGroup(View.BG, "<LOC uvd_0000>Build Cost (Rate)")
    end

    -- Upkeep
    if not View.UpkeepColumn then
--         View.UpkeepColumn = import(UVD).CreateColumnUpkeep(View.BG)
--      View.UpkeepColumn = CreateResourceGroup(View.BG, "<LOC uvd_0002>Yield")
    end
    
    -- Health stat
    if not View.HealthStat then
--        View.HealthStat = import(UVD).CreateStatGroup( View.BG, UIUtil.UIFile('/textures/ui/common/game/unit_view_icons/healthIcon.dds') )
        --View.HealthStat = CreateStatGroup(View.BG, UIUtil.UIFile('/game/unit_view_icons/redcross.dds'))
    end
    
    if not View.ShieldStat then
--        View.ShieldStat = import(UVD).CreateStatGroup( View.BG, UIUtil.UIFile('/textures/ui/common/game/unit_view_icons/shieldIcon.dds') )
        --View.ShieldStat = CreateStatGroup(View.BG, UIUtil.UIFile('/game/unit_view_icons/shield.dds'))
    end
    -- Time stat
    if not View.TimeStat then
        View.TimeStat = CreateStatGroup(View.BG, UIUtil.UIFile('/game/unit-over/icon-clock_bmp.dds'))
    end
    
    if not View.TechLevel then
        View.TechLevel = UIUtil.CreateText(View.BG, '', 10, UIUtil.bodyFont)
    end
    View.TechLevel:SetColor("FFFF9E06") -- #FFFF9E06
    
    if Prefs.GetOption('uvd_format') == 'full' then
        -- Description  "<LOC uvd_0003>Description"
        if not View.Description then
            View.Description = CreateTextbox(View.BG, nil, true)
        end
    else
        if View.Description then View.Description:Destroy() View.Description = false end
    end
    
    View.BG:DisableHitTest(true)
end

function SetLayout()
    LOG('unitviewDetail_left.lua - SetLayout')
    local mapGroup = import(UVD).MapView
    import(UVD).ViewState = Prefs.GetOption('uvd_format')
    
    Create(mapGroup)
    
    local control = import(UVD).View

    local OrderGroup = false
    if not SessionIsReplay() then
        OrderGroup = import('/lua/ui/game/orders.lua').controls.bg
    end

    LayoutHelpers.AtBottomIn(control, control:GetParent(), 0)
    LayoutHelpers.AtLeftIn(control, control:GetParent(), 207)
    control.Width:Set(control.BG.Width)
    control.Height:Set(control.BG.Height)
    
    -- Main window background
    LayoutHelpers.AtLeftTopIn(control.BG, control)
    
    LayoutHelpers.AtLeftTopIn(control.Bracket, control.BG, -6, 3)
    control.Bracket:SetTexture(UIUtil.UIFile('/game/bracket-left-energy/bracket_bmp_t.dds'))
    
    if not control.bracketMax then
        control.bracketMax = Bitmap(control.BG)
    end
    control.bracketMax:SetTexture(UIUtil.UIFile('/game/bracket-left-energy/bracket_bmp_b.dds'))
    LayoutHelpers.AtLeftIn(control.bracketMax, control.BG, -6)
    LayoutHelpers.AtBottomIn(control.bracketMax, control.BG, 3)
    
    if not control.bracketMid then
        control.bracketMid = Bitmap(control.BG)
    end
    control.bracketMid:SetTexture(UIUtil.UIFile('/game/bracket-left-energy/bracket_bmp_m.dds'))
    LayoutHelpers.AtLeftIn(control.bracketMid, control.BG, -6)
    control.bracketMid.Top:Set(control.Bracket.Bottom)
    control.bracketMid.Bottom:Set(control.bracketMax.Top)

    -- Unit Image
    LayoutHelpers.AtLeftTopIn(control.UnitImg, control.BG, 12, 36)
    control.UnitImg.Height:Set(46)
    control.UnitImg.Width:Set(48)
    
    -- Tech Level Text
    LayoutHelpers.CenteredBelow(control.TechLevel, control.UnitImg)
    
    -- Unit Description
    LayoutHelpers.AtLeftTopIn(control.UnitName, control.BG, 20, 13)
    control.UnitName:SetClipToWidth(true)
    control.UnitName.Right:Set(function() return control.BG.Right() - 15 end)

    -- Time stat
    import(UVD).LayoutTimeStat()
    --TODO-HUSSAR remove
--    LayoutHelpers.Below(control.TimeStat, control.UnitImg, 4)
--    LayoutHelpers.AtLeftIn(control.TimeStat, control.UnitImg, -2)
--    control.TimeStat.Height:Set(control.TimeStat.Label.Height)
--    LayoutStatGroup(control.TimeStat)
    
    -- Build Resource Group
    import(UVD).LayoutEconomyColumn()
    --TODO-HUSSAR remove
--    LayoutHelpers.AtLeftTopIn(control.EconomyColumn, control.BG, 70, 34)
--    control.EconomyColumn.Width:Set(115)
--    LayoutResourceGroup(control.EconomyColumn)
--    control.EconomyColumn.Bottom:Set(function() return control.EconomyColumn.MassValue.Bottom() + 1 end)

    -- Upkeep Resource Group
--    import(UVD).LayoutUpkeepColumn()
--    import(UVD).LayoutUpkeepColumn()
    --TODO-HUSSAR remove
--    LayoutHelpers.RightOf(control.UpkeepColumn, control.EconomyColumn)
--    control.UpkeepColumn.Width:Set(55)
--    control.UpkeepColumn.Bottom:Set(control.EconomyColumn.Bottom)
--    LayoutResourceGroup(control.UpkeepColumn)
    
    -- health stat
--    import(UVD).LayoutHealthStat()
    --TODO-HUSSAR remove
--    LayoutHelpers.RightOf(control.HealthStat, control.UpkeepColumn)
--    LayoutHelpers.AtTopIn(control.HealthStat, control.UpkeepColumn, 22)
--    control.HealthStat.Height:Set(control.HealthStat.Label.Height)
--    LayoutStatGroup(control.HealthStat)
    
    -- shield stat
--    import(UVD).LayoutShieldStat()
    --TODO-HUSSAR remove
--    LayoutHelpers.RightOf(control.ShieldStat, control.UpkeepColumn, -2)
--    LayoutHelpers.AtTopIn(control.ShieldStat, control.UpkeepColumn, 42)
--    control.ShieldStat.Height:Set(control.ShieldStat.Label.Height)
--    LayoutStatGroup(control.ShieldStat)
    
    if control.Description then
        -- Description
        control.Description.Left:Set(function() return control.BG.Right() - 2 end)
        control.Description.Bottom:Set(function() return control.BG.Bottom() - 2 end)
        control.Description.Width:Set(import(UVD).GUI.MaxWidth)
        --control.Description.Width:Set(400)
        control.Description.Height:Set(20)
        LayoutTextbox(control.Description)
    end
end

    --TODO-HUSSAR remove
function LayoutResourceGroup(group)
    
    LayoutHelpers.AtTopIn(group.Label, group)
    LayoutHelpers.AtLeftIn(group.Label, group)

    LayoutHelpers.Below(group.MassIcon, group.Label, 5)
    group.EnergyIcon.Left:Set(function() return group.Label.Left() - 4 end)

    LayoutHelpers.RightOf(group.EnergyValue, group.EnergyIcon, 1)
    group.EnergyValue.Top:Set(function() return group.EnergyIcon.Top() + 1 end)

    LayoutHelpers.RightOf(group.MassValue, group.MassIcon, 1)
    group.MassValue.Right:Set(function() return group.Label.Right() end)
    group.MassValue.Top:Set(function() return group.MassIcon.Top() + 1 end)

    LayoutHelpers.Below(group.EnergyIcon, group.MassIcon, 5)
end

    --TODO-HUSSAR remove
function LayoutStatGroup(group)
    group.Width:Set(function() return group.Label.Width() + group.Value.Width() end)
    group.Label.Left:Set(group.Left)
    group.Label.Top:Set(group.Top)
    group.Value.Left:Set(function() return group.Label.Right() + 4 end)
    LayoutHelpers.AtVerticalCenterIn(group.Value, group.Label)
end  

function LayoutTextbox(group)
    group.TL.Top:Set(group.Top)
    group.TL.Left:Set(group.Left)
    
    group.TR.Top:Set(group.Top)
    group.TR.Right:Set(group.Right)
    
    group.BL.Bottom:Set(group.Bottom)
    group.BL.Left:Set(group.Left)
    
    group.BR.Bottom:Set(group.Bottom)
    group.BR.Right:Set(group.Right)
    
    group.TM.Top:Set(function() return group.Top() + 4 end)
    group.TM.Left:Set(group.TL.Right)
    group.TM.Right:Set(group.TR.Left)
    
    group.BM.Bottom:Set(function() return group.Bottom() - 4 end)
    group.BM.Left:Set(group.BL.Right)
    group.BM.Right:Set(group.BR.Left)
    
    group.ML.Left:Set(group.Left)
    group.ML.Top:Set(group.TL.Bottom)
    group.ML.Bottom:Set(group.BL.Top)
    
    group.MR.Right:Set(group.Right)
    group.MR.Top:Set(group.TR.Bottom)
    group.MR.Bottom:Set(group.BR.Top)
    
    group.M.Left:Set(group.ML.Right)
    group.M.Right:Set(group.MR.Left)
    group.M.Top:Set(group.TM.Bottom)
    group.M.Bottom:Set(group.BM.Top)
    
    group.TL.Depth:Set(function() return group.Depth() - 1 end)
    group.TM.Depth:Set(group.TL.Depth)
    group.TR.Depth:Set(group.TL.Depth)
    group.ML.Depth:Set(group.TL.Depth)
    group.M.Depth:Set(group.TL.Depth)
    group.MR.Depth:Set(group.TL.Depth)
    group.BL.Depth:Set(group.TL.Depth)
    group.BM.Depth:Set(group.TL.Depth)
    group.BR.Depth:Set(group.TL.Depth)
    
    LayoutHelpers.AtLeftTopIn(group.Value[1], group, 24, 14)
    group.Value[1].Right:Set(function() return group.Right() - 15 end)
    group.Value[1].Width:Set(function() return group.Right() - group.Left() - 14 end)
    group.Value[1]:SetClipToWidth(true)
end