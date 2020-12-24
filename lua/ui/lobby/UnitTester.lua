
local UIUtil        = import('/lua/ui/uiutil.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Window        = import('/lua/maui/window.lua').Window
--local FlexBox       = import('/lua/ui/controls/flexbox.lua').FlexBox

local UVD = '/lua/ui/game/unitviewDetail.lua'

local GUI = {}
--buttonFont = "Zeroes Three",
--bodyFont = "Arial",
--fixedFont = "Andale Mono",
--titleFont = "Zeroes Three",
--fixedFont = "Andale Mono",
function CreateUI()

    WARN('UnitTester.CreateUI') 
       
    if GUI.bg then
       WARN('UnitTester.OnClose') 
       GUI.bg.OnClose()
    end
    local location = {
        Top = function() return GetFrame(0).Bottom() - 400 end,
        Left = function() return GetFrame(0).Left() + 8 end,
        Right = function() return GetFrame(0).Left() + 430 end,
        Bottom = function() return GetFrame(0).Bottom() - 200 end}
    
    WARN('UnitTester.Window') 
    GUI.bg = Window(GetFrame(0), 'UnitTester', nil, true, true, nil, nil, 'UnitTester', location)
    GUI.bg.Depth:Set(200)
    
    local width = 240
    GUI.bg.OnConfigClick = function(self, checked)
        WARN('UnitTester.OnConfigClick') 
        width = width + 30
        GUI.box.Width:Set(width)
    end

    GUI.bg.OnClose = function(self)
        WARN('UnitTester.Destroy') 
        --for id, _ in GUI.TextLines or {} do
        --    GUI.bg.TextLines[id]:Destroy()
        --    GUI.bg.TextLines[id] = nil
        --end
        if GUI.box then
--           GUI.box:Destroy()
           GUI.box = nil
        end

        GUI.bg:Destroy()
        GUI.bg = nil
    end
        WARN('UnitTester.TextLines {}') 
    --local fontName = 'Arial Bold' --UIUtil.bodyFont
    --local fontName = 'Andale Mono' --UIUtil.bodyFont
    local fontName = 'Lucida Console' --UIUtil.bodyFont
    --local fontName = 'Courier New' --UIUtil.bodyFont
    local fontSize = 16 --UIUtil.bodyFont

    local texts = {
"    30 Range    1.0 AOE       570 Damage     285 DPS    0.03 DPM    2.0s Reload",
"    60 Range    1.0 AOE       300 Damage     120 DPS    0.01 DPM    2.5s Reload",
"    30 Range    3.0 AOE       750 Damage    1.1k DPS     1.7 DPM    0.7s Reload",
"    64 Range    2.0 AOE      1.5k Damage    1.2k DPS    0.49 DPM    1.3s Reload",
--"   150 Range    5.0 AOE      8.0k Damage     696 DPS     3.6 DPM       12s Reload
--"    80 Range    1.5 AOE      2.1k Damage     420 DPS    0.35 DPM    5.0s Reload
--"    45 Range    1.0 AOE         6 Damage       6 DPS    0.00 DPM    1.0s Reload
--INFO: weapon.Specs    64 Range    2.0 AOE      1.5k Damage    1.2k DPS    0.49 DPM    1.3s Reload
--INFO: weapon.Specs    64 Range    1.0 AOE       400 Damage     308 DPS    0.03 DPM    1.3s Reload
--INFO: weapon.Specs    25 Range    1.0 AOE         12 Damage    1.6 DPS    0.00 DPM    7.7s Reload
--INFO: weapon.Specs    40 Range    2.0 AOE         18 Damage    30.0 DPS    0.01 DPM    0.6s Reload
--INFO: weapon.Specs    30 Range    0.5 AOE      4.0k Damage    4.0k DPS    0.20 DPM    1.0s Reload
--INFO: weapon.Specs    64 Range    1.0 AOE       150 Damage     214 DPS    0.01 DPM    0.7s Reload
--INFO: weapon.Specs    64 Range    1.0 AOE       150 Damage     214 DPS    0.01 DPM    0.7s Reload
--INFO: weapon.Specs    64 Range    1.0 AOE         80 Damage       40 DPS    0.00 DPM    2.0s Reload
--INFO: weapon.Specs    64 Range    1.0 AOE         80 Damage       40 DPS    0.00 DPM    2.0s Reload
--INFO: weapon.Specs    45 Range    1.0 AOE       200 Damage       50 DPS    0.01 DPM    4.0s Reload
    }


    WARN('UnitTester.Content') 
--    GUI.bg.TextLines = {}
--    for i, text in texts do
--        GUI.bg.TextLines[i] = UIUtil.CreateText(GUI.bg, i .. " " .. text, fontSize, fontName )
--    end    
--    for i, _ in GUI.bg.TextLines do
--        if i == 1 then 
--            LayoutHelpers.AtTopIn(GUI.bg.TextLines[i], GUI.bg, 30 )
--            LayoutHelpers.AtLeftIn(GUI.bg.TextLines[i], GUI.bg, 10 )
--        else
--            LayoutHelpers.Below(GUI.bg.TextLines[i], GUI.bg.TextLines[i-1], 5 )
--        end
--    end
    
--    GUI.box = import(UVD).CreateFlexBox(GUI.bg) 
--        LOG('FlexBox... ') 
    local box2 = import('/lua/ui/controls/flexbox.lua').FlexBox 
--        LOG('FlexBox... imported') 
    GUI.box = box2(GUI.bg) 
--        LOG('FlexBox... create') 

--    GUI.box = import('/lua/ui/controls/flexbox.lua').FlexBox(GUI.bg) 

--    GUI.box = import('/lua/maui/bitmap.lua').Bitmap(GUI.bg) 
--    GUI.box = import('/lua/ui/controls/FlexBox2.lua').FlexBox(GUI.bg) 
--    GUI.box = FlexBox(GUI.bg) 

--     GUI.box:SetSolidColor('FF6FD615') -- #FF6FD615
        GUI.box.Height:Set(105)
        GUI.box.Width:Set(305)
        if GUI.box.BracketPartsRight then 
            WARN('UnitTester  GUI.box.BracketPartsRight ' .. table.size(GUI.box.BracketPartsRight) ) 
        end
        
--        GUI.box:SetOrientation('left')
        GUI.box:SetOrientation('left')
        GUI.box:SetOpacity(0)

--        GUI.bg:Show()
        GUI.box:Hide()
        GUI.box:Show()

--        GUI.box:SetOrientation('float')
--        GUI.box:SetBracketLeftHidden(true)
--        GUI.box:SetBoardersHidden(true)

    LayoutHelpers.AtLeftTopIn(GUI.box, GUI.bg, 2, 25)
--    import(UVD).LayoutFlexBox(GUI.box)
end