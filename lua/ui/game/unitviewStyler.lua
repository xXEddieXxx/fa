
local Overlays = import('/lua/ui/game/rangeoverlayparams.lua').RangeOverlayParams
local UIUtil = import('/lua/ui/uiutil.lua')

local fontBold = "Arial Bold"
local fontBubl = "Butterbelly"
local fontBody = UIUtil.bodyFont()
--local fontBold = 'Courier New Bold' --"Courier Bold"
local fontSize = 14 -- 15
--local fontBold = "Consolas" size = 14, 
--local fontColor = UIUtil.fontColor()
--local bodyColor = UIUtil.bodyColor()

local textturePath = ''
-- creating a table for looking up high definition textures
Textures = {} 
Textures['Time']   = '/textures/ui/common/game/unit_view_icons/ecoBuildTime.dds'
Textures['Rate']   = '/textures/ui/common/game/unit_view_icons/ecoBuildRate.dds'
Textures['Mass']   = '/textures/ui/common/game/unit_view_icons/ecoMass.dds'
Textures['Energy'] = '/textures/ui/common/game/unit_view_icons/ecoEnergy.dds'
Textures['Health'] = '/textures/ui/common/game/unit_view_icons/defenseHealth.dds'
Textures['Shield'] = '/textures/ui/common/game/unit_view_icons/defenseShield.dds'
 
-- creating a table for looking up styles of text controls
Styles = {}
Styles['Default']   = { hasNumbers = false, color = UIUtil.fontColor(), size = 14 }  
-- NOTE these styles are used when displaying data in Unit View tooltip 
Styles['Rate']      = { hasNumbers = true,  color = 'FFD0D1CF' } -- #FFD0D1CF
Styles['Time']      = { hasNumbers = true,  color = 'FFD0D1CF' } -- #FFD0D1CF
Styles['Mass']      = { hasNumbers = true,  color = 'FF7bc700' } -- #FF7bc700
Styles['Energy']    = { hasNumbers = true,  color = 'FFFCCA28' } -- #FFFCCA28
Styles['Health']    = { hasNumbers = true,  color = 'FF0DEF5F' } -- #FF0DEF5F
Styles['Shield']    = { hasNumbers = true,  color = 'FF20C0F7' } -- #FF20C0F7
-- style for column headers, Build Cost (Rate), Yields, Defense (Per Mass)
-- NOTE headers are not resizable so they must have fixed size
Styles['Header']       = { hasNumbers = false, color = UIUtil.fontColor(), size = 12 }
-- NOTE these styles are used when displaying data in Unit Description box
Styles['Abilities']    = { hasNumbers = false, color = 'FFFA7777' } -- #FFFA7777  
Styles['Description']  = { hasNumbers = false, color = UIUtil.fontColor() }   
Styles['Physics']      = { hasNumbers = true,  color = 'FFA7A8A6' } -- #FFD0D1CF
Styles['Intel']        = { hasNumbers = true,  color = 'FFD0D1CF' } -- #FFD0D1CF
Styles['Weapon']       = { hasNumbers = true,  color = 'FFF74C4C' } -- #FFF74C4C
Styles['Stun']         = { hasNumbers = true,  color = 'FFF74C4C' } -- #FFF74C4C
Styles['WeaponTitle']  = { hasNumbers = false, color = UIUtil.fontColor() }  
-- styles for weapon specs hashed by their range category
Styles['UWRC_AntiAir']        = { hasNumbers = true, color = Overlays.AntiAir.SelectColor } -- #FF20C0F7
Styles['UWRC_AntiNavy']       = { hasNumbers = true, color = Overlays.AntiNavy.SelectColor } -- #FF46C93A
Styles['UWRC_DirectFire']     = { hasNumbers = true, color = Overlays.DirectFire.SelectColor } -- #FFF74C4C
Styles['UWRC_IndirectFire']   = { hasNumbers = true, color = Overlays.IndirectFire.SelectColor } -- #FFF7E54C
Styles['UWRC_Countermeasure'] = { hasNumbers = true, color = Overlays.Defense.SelectColor } -- #FFF7A34C
Styles['UWRC_Undefined']      = { hasNumbers = true, color = 'FFC479F7' } -- #FFC479F7

function GetTextures(key)
    local texture = Textures[key] 
    if not texture then
        WARN('UVD GetTextures cannot find texture for "' .. tostring(key) .. '"')
        texture = Textures['Time'] -- defaulting to Build Time texture
    end
    return texture
end

-- get font style based on a key and game options
function GetStyle(key, useBoldFontForNumbers)
    local style = Styles[key]
    if not style then
        WARN('UVD GetStyle cannot find style for "' .. tostring(key) .. '"')
        style = Styles.Default 
    end
    -- default to the Default style if some setting are not set
    if not style.size then style.size = Styles.Default.size end
    if not style.color then style.color = Styles.Default.color end

    -- use bold font if style has numbers and it is enabled in game options
    if style.hasNumbers and useBoldFontForNumbers then
       style.font = "Arial Bold"
    else 
       style.font = UIUtil.bodyFont()
    end

    return style
end

function SetStyle(textBlock, key, text)
    local font = GetStyle(key)
     
    if textBlock then
        textBlock:SetFont(font.name, font.size)
        textBlock:SetColor(font.color) 
--        if textBlock:IsHidden() then
--            textBlock:Show()
--        end
        if text then
            textBlock:SetText(text)
        end
    else
        WARN('UVD SetStyle cannot find textBlock ' .. tostring(key))
    end
end