
local UIUtil = import('/lua/ui/uiutil.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local GameCommon = import('/lua/ui/game/gamecommon.lua')
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local Prefs = import('/lua/user/prefs.lua')

LOG('unitviewDetail_mini.lua loaded')

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
    group.Value[1] = UIUtil.CreateText( group, "", 12, UIUtil.bodyFont)
    
    return group
end

--local UVD = import('/lua/ui/game/unitviewDetail.lua')
local UVD = '/lua/ui/game/unitviewDetail.lua'

function Create(parent)
    LOG('unitviewDetail_mini.lua - Create')
    
    local View = import(UVD).View
    if not View then -- import(UVD).View then
--        import(UVD).View = Group(parent)
--        import(UVD).View = import('/lua/ui/controls/flexbox.lua').FlexBox(parent)
--        import(UVD).View = import(UVD).CreateView(parent)
   
        LOG('unitviewDetail_mini.lua - CreateView')
        View = import(UVD).CreateView(parent)
    end
    
--    local View = import(UVD).View
    View.Depth:Set(200) 
    View.Height:Set(130)
    View.Width:Set(445)
    View:SetOrientation('left')

--    if not View.BG then
--        View.BG = Bitmap(View)
--    end
--    View.BG:SetTexture(UIUtil.UIFile('/game/unit-build-over-panel/unit-over-back_bmp.dds'))
--    View.BG.Depth:Set(200)

    if View.BG == nil then
--       View.BG = View.Content
--        View.BG = import('/lua/ui/controls/flexbox.lua').FlexBox(View)
--        View.BG = View.SupremeBox.BG
    end
--    View.BG.Depth:Set(200) 
--    View.BG.Height:Set(130)
--    View.BG.Width:Set(430)
--    View.BG:SetOrientation('left')
    
--    if not View.Bracket then
--        View.Bracket = Bitmap(View)
--    end
--    View.Bracket:DisableHitTest()
--    View.Bracket:SetTexture(UIUtil.UIFile('/game/unit-build-over-panel/bracket-unit_bmp.dds'))

    -- Avatar with unit icon, background and strategic icon
    if View.UnitAvatar == nil then
--       View.UnitAvatar = import(UVD).CreateUnitAvatar(View.BG)
    end

    -- Unit Name
--    if not View.UnitName then
--        View.UnitName = UIUtil.CreateText(View.BG, "", 10, UIUtil.bodyFont)
--    end
--    View.UnitName:SetColor("FFFF9E06") -- #FFFF9E06

    if View.UnitName == nil then
--       View.UnitName = import(UVD).CreateUnitName(View.BG)
    end
    if View.FactionIcon == nil then
--       View.FactionIcon = import(UVD).CreateUnitFaction(View.BG)
    end

    -- Unit Cost
    if View.EconomyColumn == nil then
--       View.EconomyColumn = import(UVD).CreateColumnCost(View.BG)
    end

    -- Unit Upkeep
    if View.UpkeepColumn == nil then
--       View.UpkeepColumn = import(UVD).CreateColumnUpkeep(View.BG)
    end

    -- Unit Defense
    if View.DefenseColumn == nil then
--       View.DefenseColumn = import(UVD).CreateColumnDefense(View.BG)
    end

--    if Prefs.GetOption('uvd_format') == 'full' then
--        -- Description  "<LOC uvd_0003>Description"
--        if not View.Description then
--            View.Description = CreateTextbox(View.BG, nil, true)
--        end
--    else
--        if View.Description then 
--           View.Description:Destroy() 
--           View.Description = false 
--        end
--    end
    
--    View.BG:DisableHitTest(true)
    return View
end

function SetLayout()
    LOG('unitviewDetail_mini.lua - SetLayout')
    local mapGroup = import(UVD).MapView
    import(UVD).ViewState = Prefs.GetOption('uvd_format')
    
    local control = Create(mapGroup)
    
--    local control = import(UVD).View

    local OrderGroup = false
    if not SessionIsReplay() then
        OrderGroup = import('/lua/ui/game/orders.lua').controls.bg
    end

    if OrderGroup then
        LayoutHelpers.Above(control, OrderGroup, 7)
        LayoutHelpers.AtLeftIn(control, OrderGroup)
    else
        LayoutHelpers.AtBottomIn(control, control:GetParent(), 145)
        LayoutHelpers.AtLeftIn(control, control:GetParent(), 0)
    end
--    control.Width:Set( control.BG.Width )
--    control.Height:Set( control.BG.Height )
    
    -- Main window background
--    LayoutHelpers.AtLeftTopIn( control.BG, control )
    
--    LayoutHelpers.AtLeftTopIn(control.Bracket, control.BG, -18, 0)
--    control.Bracket:SetTexture(UIUtil.UIFile('/game/unit-build-over-panel/bracket-unit_bmp.dds'))
    
--    if control.bracketMid then
--       control.bracketMid:Destroy()
--       control.bracketMid = false
--    end
--    if control.bracketMax then
--       control.bracketMax:Destroy()
--       control.bracketMax = false
--    end
    
    -- Unit Name with tech level
--    LayoutHelpers.AtLeftTopIn( control.UnitName, control.BG, 15, 13 )
--    control.UnitName:SetClipToWidth(true)
--    control.UnitName.Right:Set(function() return control.BG.Right() - 15 end)
--    import(UVD).LayoutUnitName()
   
    -- Unit Icon, movement background, and strategic icon
--    import(UVD).LayoutUnitAvatar()
    
    -- Build Resource Group
    import(UVD).LayoutEconomyColumn()

    -- Upkeep Resource Group
    import(UVD).LayoutUpkeepColumn() 

    -- health/shield stat 
    import(UVD).LayoutDefenseColumn()
    
    import(UVD).LayoutDescription()

--    if control.Description then
----       control.Description.Left:Set(function() return control.BG.Right() - 3 end)
--       control.Description.Left:Set(function() return control.BG.Right() + 60 end)
--       control.Description.Bottom:Set(function() return control.BG.Bottom() - 20 end)
--       control.Description.Width:Set(import(UVD).GUI.MaxWidth) -- 400
--       control.Description.Height:Set(20)
--       LayoutTextbox(control.Description)
--    end
end

--TODO-HUSSAR remove 
--function SetLayoutOn(control)
--    -- health stat
--    control.HealthStat.Label:SetTexture('/textures/ui/common/game/unit_view_icons/healthIcon.dds')
--    LayoutHelpers.RightOf( control.HealthStat, control.UpkeepColumn, 20 )
--    LayoutHelpers.AtTopIn( control.HealthStat, control.UpkeepColumn, 22 )
--    control.HealthStat.Height:Set(control.HealthStat.Label.Height)
--    LayoutStatGroup( control.HealthStat )

--    -- shield stat
--    control.ShieldStat.Label:SetTexture('/textures/ui/common/game/unit_view_icons/shieldIcon.dds')
--    control.ShieldStat.Label.Width:Set(15)
--    control.ShieldStat.Label.Height:Set(15)
--    LayoutHelpers.RightOf( control.ShieldStat, control.UpkeepColumn, 20 )
--    LayoutHelpers.AtTopIn( control.ShieldStat, control.UpkeepColumn, 42 )
--    control.ShieldStat.Height:Set(control.ShieldStat.Label.Height)
--    LayoutStatGroup( control.ShieldStat )
--end

    --TODO-HUSSAR remove
function LayoutResourceGroup(group)
    
    LayoutHelpers.AtTopIn( group.Label, group )
    LayoutHelpers.AtLeftIn( group.Label, group )

    LayoutHelpers.Below( group.MassIcon, group.Label, 5 )
    group.EnergyIcon.Left:Set( function() return group.Label.Left() - 4 end )

    LayoutHelpers.RightOf( group.EnergyValue, group.EnergyIcon, 1 )
    group.EnergyValue.Top:Set( function() return group.EnergyIcon.Top() + 1 end )

    LayoutHelpers.RightOf( group.MassValue, group.MassIcon, 1 )
    group.MassValue.Right:Set( function() return group.Label.Right() end )
    group.MassValue.Top:Set( function() return group.MassIcon.Top() + 1 end )

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