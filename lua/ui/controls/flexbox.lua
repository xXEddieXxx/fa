local Text = import('/lua/maui/text.lua').Text 
local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap

local UIUtil = import('/lua/ui/uiutil.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Prefs = import('/lua/user/prefs.lua')

-- This class implements flexible UI that does NOT depend on one big bitmap with fixed dimensions
-- but rather it is divided into smaller bitmaps than automatically re-scale to size of this control:
-- A. 9 bitmaps for Boarders:
--      TL (TopLeft,     TM (TopMiddle,     TR (TopRight)
--      ML (MiddleLeft), MC (MiddleCenter), MR (MiddleRight)
--      BL (BottomLeft), BM (BottomMiddle), BR (BottomRight)
-- B. 6 bitmaps for Brackets:
--      LT (LeftTop),    RT (RightTop),
--      LM (LeftMiddle), RM (RightMiddle),
--      LB (LeftBottom), RB (RightBottom)
-- C. 6 bitmaps for Highlights:
--      LT (LeftTop),    RT (RightTop),
--      LM (LeftMiddle), RM (RightMiddle),
--      LB (LeftBottom), RB (RightBottom)
-- With these bitmaps, this UI is scalable and does not require re-designing .dds files
-- to increase width/height of the UI elements. For example, you can use this control as 
-- a background for Unit Orders panel, Unit View panel, Unit Details panel, and Economy panel.
-- Also, you can use this control to create new UI elements in your mods.

-- This control is similar to window.lua, border.lua, and ninepatch.lua but it automatically 
-- creates and loads required bitmaps that match design for all 4 factions.
FlexBox = Class(Group) { 

    -- constructor for the FlexBox
    __init = function(self, parent, width, height, debugName)
        Group.__init(self, parent)
        
        debugName = debugName or ''
        self.LOG = function(msg)
            LOG('FlexBox... ' .. debugName .. ' ' .. msg) 
        end
        self.LOG('__init')

        self:SetName(debugName or "FlexBox")
        self:SetEvents(parent) -- keeping content of this control in sync with skin and its parent
         
        self.Depth:Set(function() return parent.Depth() + 10 end)
        self.Height:Set(height or 100)
        self.Width:Set(width or 300)
        
        -- a function for creating skinnable bitmaps used for boarders, brackets, and highlights
        self.SkinBitmap = function(texture)
            local bmp = Bitmap(self)
            bmp:SetTexture(UIUtil.SkinnableFile(texture))
            bmp.Depth:Set(function() return self.Depth() - 1 end)
            return bmp
        end
        -- creating quick lookup table for parts of all boarder bitmaps
        self.Boarders = {
            TL = self.SkinBitmap('/game/panel/panel_brd_ul.dds'),
            TM = self.SkinBitmap('/game/panel/panel_brd_horz_um.dds'),
            TR = self.SkinBitmap('/game/panel/panel_brd_ur.dds'),
            ML = self.SkinBitmap('/game/panel/panel_brd_vert_l.dds'),
            MC = self.SkinBitmap('/game/panel/panel_brd_m.dds'),
            MR = self.SkinBitmap('/game/panel/panel_brd_vert_r.dds'),
            BL = self.SkinBitmap('/game/panel/panel_brd_ll.dds'),
            BM = self.SkinBitmap('/game/panel/panel_brd_lm.dds'),
            BR = self.SkinBitmap('/game/panel/panel_brd_lr.dds'),
        } 
        -- creating quick lookup table for parts of all Bracket bitmaps
        self.Brackets = {
            -- parts of left bracket
            LT = self.SkinBitmap('/game/bracket-left/bracket_bmp_t.dds'),
            LM = self.SkinBitmap('/game/bracket-left/bracket_bmp_m.dds'),
            LB = self.SkinBitmap('/game/bracket-left/bracket_bmp_b.dds'),
            -- parts of right bracket
            RT = self.SkinBitmap('/game/bracket-right/bracket_bmp_t.dds'),
            RM = self.SkinBitmap('/game/bracket-right/bracket_bmp_m.dds'),
            RB = self.SkinBitmap('/game/bracket-right/bracket_bmp_b.dds'),
        } 
        -- creating quick lookup table for parts of brackets based on their orientation
        self.BracketsRight = { self.Brackets.RT, self.Brackets.RM, self.Brackets.RB }
        self.BracketsLeft = { self.Brackets.LT, self.Brackets.LM, self.Brackets.LB }

        -- creating quick lookup table for parts of all Highlight bitmaps
        self.Highlights = {
            -- parts of left Highlight
            LT = self.SkinBitmap('/game/bracket-left-energy/bracket_bmp_t.dds'),
            LM = self.SkinBitmap('/game/bracket-left-energy/bracket_bmp_m.dds'),
            LB = self.SkinBitmap('/game/bracket-left-energy/bracket_bmp_b.dds'),
            -- parts of right Highlight
            RT = self.SkinBitmap('/game/bracket-right-energy/bracket_bmp_t.dds'),
            RM = self.SkinBitmap('/game/bracket-right-energy/bracket_bmp_m.dds'),
            RB = self.SkinBitmap('/game/bracket-right-energy/bracket_bmp_b.dds'),
        } 
        -- creating quick lookup table for parts of Highlights based on their orientation
        self.HighlightsRight = { self.Highlights.RT, self.Highlights.RM, self.Highlights.RB }
        self.HighlightsLeft = { self.Highlights.LT, self.Highlights.LM, self.Highlights.LB }

        local bgOffset = 5
        self.Fill = Bitmap(self)
        self.Fill:SetSolidColor('FF121212') -- #FF121212
--        self.Fill:SetSolidColor('white')  
        self.Fill.Top:Set(function() return self.Top() + bgOffset end)
        self.Fill.Left:Set(function() return self.Left() + bgOffset end)
        self.Fill.Right:Set(function() return self.Right() - bgOffset end)
        self.Fill.Bottom:Set(function() return self.Bottom() - bgOffset end)
        self.Fill.Width:Set(function()  return self.Right() - self.Left() - (2 * bgOffset) end)
        self.Fill.Height:Set(function() return self.Bottom() - self.Top() - (2 * bgOffset) end)
        self.Fill.Depth:Set(function() return self.Depth() - 2 end)
--        self.Fill:SetAlpha(0.0)
        self.Fill:SetAlpha(0.15)

        self.BG = Bitmap(self)
        self.BG.Top:Set(function() return self.Top() + bgOffset end)
        self.BG.Left:Set(function() return self.Left() + bgOffset end)
        self.BG.Right:Set(function() return self.Right() - bgOffset end)
        self.BG.Bottom:Set(function() return self.Bottom() - bgOffset end)
        self.BG.Width:Set(function()  return self.Right() - self.Left() - (2 * bgOffset) end)
        self.BG.Height:Set(function() return self.Bottom() - self.Top() - (2 * bgOffset) end)
        self.BG.Depth:Set(function() return self.Depth() + 1 end)

--        -- ######## TitleFill ######## 
--        self.TitleFill = Bitmap(self)
--        self.TitleFill:SetSolidColor(UIUtil.bodyColor)  
--        self.TitleFill.Depth:Set(function() return self.Depth() + 1 end)
--        self.TitleFill.Top:Set(function() return self.Top() + 5 end)
--        self.TitleFill.Left:Set(function() return self.Left() + 5 end)
--        self.TitleFill.Right:Set(function() return self.Right() - 5 end)
--        self.TitleFill.Width:Set(function() return self.Right() - self.Left() end)
--        self.TitleFill:SetAlpha(0.35)
--        self.TitleFill.Height:Set(35) 
--        self.TitleFill.Bottom:Set(function() return self.TitleFill.Top() + self.TitleText.Height() + 5 end)

--        -- ######## TitleText ######## 
--        self.TitleText = UIUtil.CreateText(self.TitleFill, "UnitTester", 12, "Arial")
--        self.TitleText.Depth:Set(function() return self.Depth() + 10 end)
--        self.TitleText:SetFont('Arial', 15) 
--        LayoutHelpers.AtLeftIn(self.TitleText, self.TitleFill, 10)
--        LayoutHelpers.AtVerticalCenterIn(self.TitleText, self.TitleFill) 
--        self.TitleText:SetCenteredVertically(true)

--        -- ######## Content ######## 
--        self.Content = Bitmap(self)
----        self.Content:SetSolidColor('FF6FD615') -- #FF6FD615
--        self.Content.Top:Set(self.TitleFill.Bottom)
--        self.Content.Left:Set(function() return self.Left() + 10 end)
--        self.Content.Right:Set(function() return self.Right() - 10 end)
--        self.Content.Bottom:Set(function() return self.Bottom() - 10 end)
--        self.Content.Width:Set(function() return self.Right() - self.Left() end)
--        self.Content.Height:Set(function() return self.Bottom() - self.Top() - self.TitleFill.Bottom() end)
--        self.Content.Depth:Set(function() return self.Depth() + 1 end)

        self:SetOrientation('left')

        self:SetLayout()
        self:SetTitleFont(12)
        self:SetFillVisibility()

--        -- checking for UEF skin because UEF textures already have extra dark background 
--        -- so we cannot overlay semi-transparent fill texture
--        if self.SkinName() == 'uef' then
--           self.Fill:Hide()
--        else 
--           self.Fill:Show()
--        end
    end,

    SetTitleFont = function(self, fontSize, fontFamily)
--        LOG('self.TitleText.Height1 '.. tostring(self.TitleText.Height()))
--        self.TitleText:SetFont(fontFamily or 'Arial', fontSize or 13)
--        LOG('self.TitleText.Height2 '.. tostring(self.TitleText.Height()))

--        self.TitleText.Top:Set(
--        function()
--            return math.floor(self.TitleFill.Top() + (((self.TitleText.Height() + 4) / 2 - (self.TitleText.Height() / 2)) ))
--        end)
    end,

    OnDestroy = function(self)
        self.LOG('OnDestroy ' )
        for _, bmp in self.Highlights do
            bmp:Destroy()
        end
        for _, bmp in self.Boarders do
            bmp:Destroy()
        end 
        for _, bmp in self.Brackets do
            bmp:Destroy()
        end

        self.Highlights = nil
        self.Boarders = nil
        self.Brackets = nil
    end,
    
    OnShow = function(self)
        self.LOG('OnShow ') 
        self:RestoreHiddenBitmaps()
    end,

    OnShowParent = function(self)
        self.LOG('OnShowParent ') 
        self:RestoreHiddenBitmaps()
    end,

    -- set fill visibility based on current skin name
    -- because UEF textures already have extra dark background
    -- so we cannot overlay additional semi-transparent fill texture
    SetFillVisibility = function(self)
        if not self.Fill then return end
        if not self.SkinName then return end
        -- we can comment out this if condition only when UEF textures
        -- are updated to match background opacity of other faction textures
        if self.SkinName() == 'uef' then
           self.Fill:Hide()
        else 
           self.Fill:Show()
        end
    end,

    OnSkinChanged = function(self)
--        self.LOG('OnSkinChanged ' ..tostring(UIUtil.bodyColor()))
        self.LOG('OnSkinChanged ' ..tostring(self.SkinName()))  
        self.LOG('OnSkinChanged ' ..tostring(UIUtil.factionSkinName()))  
--        self.LOG('OnSkinChanged ' ..tostring(Prefs.GetFromCurrentProfile('skin')))  
--        self.LOG('GetAlpha ' ..tostring(self.Fill:GetAlpha()))  
        
--        if self.Fill then
--            -- checking for UEF skin because UEF textures already have extra dark background 
--            -- so we cannot overlay semi-transparent fill texture
--            if self.SkinName() == 'uef' then
--               self.Fill:Hide()
--            else 
--               self.Fill:Show()
--            end
--        end
        self:SetFillVisibility()
        self:SetLayout()
    end,

    -- sets opacity of the fill texture in this UI
    SetOpacity = function(self, opacity)
        -- validating opacity between 0 and 100
        if opacity > 1 then
           opacity = opacity / 100
        end
        -- validating opacity between 0 and 1
        opacity = math.max(opacity, 0)
        opacity = math.min(opacity, 1)
        self.Fill:SetAlpha(opacity)
        self:SetFillVisibility()
    end,

    SetLayout = function(self)

        self.LOG('SetLayout') 
--        self.Boarders.TM:SetTiled(true)
--        self.Boarders.BM:SetTiled(true)
--        self.Boarders.ML:SetTiled(true)
--        self.Boarders.MR:SetTiled(true)

        if not table.empty(self.Boarders) then 
            self.Boarders.TL.Top:Set(self.Top)
            self.Boarders.TL.Left:Set(self.Left)

            self.Boarders.TR.Top:Set(self.Top)
            self.Boarders.TR.Right:Set(self.Right)

            self.Boarders.BL.Bottom:Set(self.Bottom)
            self.Boarders.BL.Left:Set(self.Left)

            self.Boarders.BR.Bottom:Set(self.Bottom)
            self.Boarders.BR.Right:Set(self.Right)

    --        self.Boarders.TM.Top:Set(function() return self.Top() + 4 end)
            self.Boarders.TM.Top:Set(self.Top)
            self.Boarders.TM.Left:Set(self.Boarders.TL.Right)
            self.Boarders.TM.Right:Set(self.Boarders.TR.Left)

    --        self.Boarders.BM.Bottom:Set(function() return self.Bottom() - 4 end)
            self.Boarders.BM.Bottom:Set(self.Bottom)
            self.Boarders.BM.Left:Set(self.Boarders.BL.Right)
            self.Boarders.BM.Right:Set(self.Boarders.BR.Left)

            self.Boarders.ML.Left:Set(self.Left)
            self.Boarders.ML.Top:Set(self.Boarders.TL.Bottom)
            self.Boarders.ML.Bottom:Set(self.Boarders.BL.Top)

            self.Boarders.MR.Right:Set(self.Right)
            self.Boarders.MR.Top:Set(self.Boarders.TR.Bottom)
            self.Boarders.MR.Bottom:Set(self.Boarders.BR.Top)
        
            self.Boarders.MC.Left:Set(self.Boarders.ML.Right)
            self.Boarders.MC.Right:Set(self.Boarders.MR.Left)
            self.Boarders.MC.Top:Set(self.Boarders.TM.Bottom)
            self.Boarders.MC.Bottom:Set(self.Boarders.BM.Top)
        end
         
        -- these values create a gap/space between brackets and boarders
        local bracketGapHorizontal = 20
        local bracketGapVertical = 10
        
        -- these values create a gap/space between highlights and boarders
        local highlightGapHorizontal = 10
        local highlightGapVertical = 3

        -- adjusting offsets based on current skin because sinkable images 
        -- for highlights and brackets do not have the same sizes across all factions
        if self.SkinName() == 'aeon' then -- Aeon
            highlightGapHorizontal = 5 bracketGapHorizontal = 15 
            highlightGapVertical = 0   bracketGapVertical = 2
        elseif self.SkinName() == 'seraphim' then -- Seraphim
            highlightGapHorizontal = 5 bracketGapHorizontal = 18
            highlightGapVertical = 0   bracketGapVertical = 5
        elseif self.SkinName() == 'uef' then -- UEF
            highlightGapHorizontal = 10  bracketGapHorizontal = 22
            highlightGapVertical = 3     bracketGapVertical = 5
        end
        
        if not table.empty(self.Brackets) then 
            -- arranging parts of left bracket slightly outside of boarders of this control
            self.Brackets.LT.Left:Set(function() return self.Left() - bracketGapHorizontal end)
            self.Brackets.LT.Top:Set(function()  return self.Top() - bracketGapVertical end)
            self.Brackets.LB.Left:Set(function() return self.Left() - bracketGapHorizontal end)
            self.Brackets.LB.Bottom:Set(function() return self.Bottom() + bracketGapVertical end)
            self.Brackets.LM.Left:Set(function() return self.Brackets.LB.Left() + 7 end)
            self.Brackets.LM.Top:Set(self.Brackets.LT.Bottom)
            self.Brackets.LM.Bottom:Set(self.Brackets.LB.Top)

            -- arranging parts of right bracket slightly outside of boarders of this control
            self.Brackets.RT.Right:Set(function() return self.Right() + bracketGapHorizontal end)
            self.Brackets.RT.Top:Set(function()  return self.Top() - bracketGapVertical end)
            self.Brackets.RB.Right:Set(function() return self.Right() + bracketGapHorizontal end)
            self.Brackets.RB.Bottom:Set(function() return self.Bottom() + bracketGapVertical end)
            self.Brackets.RM.Right:Set(function() return self.Brackets.RB.Right() - 7 end)
            self.Brackets.RM.Top:Set(self.Brackets.RT.Bottom)
            self.Brackets.RM.Bottom:Set(self.Brackets.RB.Top)
        end
        
        if not table.empty(self.Highlights) then 
            -- arranging parts of left highlight slightly outside of boarders of this control
            self.Highlights.LT.Left:Set(function() return self.Left() - highlightGapHorizontal end)
            self.Highlights.LT.Top:Set(function()  return self.Top() - highlightGapVertical end)
            self.Highlights.LB.Left:Set(function() return self.Left() - highlightGapHorizontal end)
            self.Highlights.LB.Bottom:Set(function() return self.Bottom() + highlightGapVertical end)
            self.Highlights.LM.Left:Set(function() return self.Highlights.LB.Left() end)
            self.Highlights.LM.Top:Set(self.Highlights.LT.Bottom)
            self.Highlights.LM.Bottom:Set(self.Highlights.LB.Top)
        
            -- arranging parts of right highlight slightly outside of boarders of this control
            self.Highlights.RT.Right:Set(function() return self.Right() + highlightGapHorizontal end)
            self.Highlights.RT.Top:Set(function()  return self.Top() - highlightGapVertical end)
            self.Highlights.RB.Right:Set(function() return self.Right() + highlightGapHorizontal end)
            self.Highlights.RB.Bottom:Set(function() return self.Bottom() + highlightGapVertical end)
            self.Highlights.RM.Right:Set(function() return self.Highlights.RB.Right() end)
            self.Highlights.RM.Top:Set(self.Highlights.RT.Bottom)
            self.Highlights.RM.Bottom:Set(self.Highlights.RB.Top)
        end

        -- update visibility of brackets in case parent.Show() was called

    end,
    
    -- overrides default SetHidden() and calls Show()
    -- function that will also restore already hidden bitmaps
    SetHidden = function(self, isHidden)
        if isHidden then
            self:Hide()
        else
            self:Show() -- this calls RestoreHiddenBitmaps
        end
    end,

    SetHiddenOn = function(self, elements, isHidden)
        for _, control in elements or {} do
            control:SetHidden(isHidden)
        end
    end,

    SetHiddenBrackets = function(self, isHidden)
        self:SetHiddenBracketRight(isHidden)
        self:SetHiddenBracketLeft(isHidden)
    end,
    SetHiddenBracketRight = function(self, isHidden)
        self.IsHiddenBracketsRight = isHidden
        self:SetHiddenOn(self.BracketsRight, isHidden)
    end,
    SetHiddenBracketLeft = function(self, isHidden)
        self.IsHiddenBracketsLeft = isHidden
        self:SetHiddenOn(self.BracketsLeft, isHidden)
    end,
    
    SetHiddenHighlights = function(self, isHidden)
        self:SetHiddenHighlightRight(isHidden)
        self:SetHiddenHighlightLeft(isHidden)
    end,
    SetHiddenHighlightRight = function(self, isHidden)
        self.IsHiddenHighlightsRight = isHidden
        self:SetHiddenOn(self.HighlightsRight, isHidden)
    end,
    SetHiddenHighlightLeft = function(self, isHidden)
        self.IsHiddenHighlightsLeft = isHidden
        self:SetHiddenOn(self.HighlightsLeft, isHidden)
    end,

    SetHiddenBoarders = function(self, isHidden)
        self.IsHiddenBoarders = isHidden
        self:SetHiddenOn(self.Boarders, isHidden)
    end, 
 
    -- sets orientation of this control which changes visibility of Brackets and Highlight
    SetOrientation = function(self, newOrientation)
--        if self.crrOrientation == newOrientation then return end

        self.LOG('SetOrientation ' .. newOrientation) 
        self.crrOrientation = newOrientation
        if newOrientation == 'left' then
            self:SetHiddenBracketRight(true)
            self:SetHiddenBracketLeft(false)
            self:SetHiddenHighlightRight(false)
            self:SetHiddenHighlightLeft(true)

        elseif newOrientation == 'right' then
            self:SetHiddenBracketRight(false)
            self:SetHiddenBracketLeft(true)
            self:SetHiddenHighlightRight(true)
            self:SetHiddenHighlightLeft(false)

        elseif newOrientation == 'float' then
            self:SetHiddenBracketRight(true)
            self:SetHiddenBracketLeft(true)
            self:SetHiddenHighlightRight(false)
            self:SetHiddenHighlightLeft(false)

        elseif newOrientation == 'window' then
            self:SetHiddenBracketRight(false)
            self:SetHiddenBracketLeft(false)
            self:SetHiddenHighlightRight(true)
            self:SetHiddenHighlightLeft(true)
        end
        self:SetLayout()
    end,
    
    SetWidth = function(self, width)
        if width then
            self.Width:Set(width)
        end
    end,
    SetHeight = function(self, height)
        if height then
            self.Height:Set(height)
        end
    end,
    SetSize = function(self, width, height)
        self:SetWidth(width)
        self:SetHeight(height) 
    end,
    
    -- set up event to keep content of this control in sync with skin and its parent
    SetEvents = function(self, parent)
        
        self.parent = parent
        -- calling parent.Show(), self.Show(), or self.SetHidden() 
        -- might override visibility of bitmaps in this control
        -- so we create an event handlers for them and then restore already hidden bitmaps
        self.parent.ShowOrg = parent.Show
        self.parent.Show = function()
            self.parent:ShowOrg()
            self:OnShowParent() -- this calls RestoreHiddenBitmaps
        end
        
        self.Show = function()
            Group.Show(self)
            self:OnShow() -- this calls RestoreHiddenBitmaps
        end

        -- creating even handler that fires when UI skin is changed (e.g. ALT + Left Arrow)
        self.SkinName = UIUtil.factionSkinName
        self.SkinName.OnDirty = function(var)
            self:OnSkinChanged()
        end
    end,

    -- restores visibility of bitmaps to their previous state
    -- this is important to prevent overriding them by parent.Show() or self.Show()
    RestoreHiddenBitmaps = function(self)

        self:SetHiddenBracketRight(self.IsHiddenBracketsRight)
        self:SetHiddenBracketLeft(self.IsHiddenBracketsLeft)

        self:SetHiddenHighlightRight(self.IsHiddenHighlightsRight)
        self:SetHiddenHighlightLeft(self.IsHiddenHighlightsLeft)

        self:SetHiddenBoarders(self.IsHiddenBoarders)
    end,

     -- layout this control around a given control 
    Surround = function(self, control, horizontalPadding, verticalPadding)
        self.Left:Set(function() return control.Left() + horizontalPadding end)
        self.Right:Set(function() return control.Right() - horizontalPadding end)
        self.Top:Set(function() return control.Top() + verticalPadding end)
        self.Bottom:Set(function() return control.Bottom() - verticalPadding end)
    end,
}