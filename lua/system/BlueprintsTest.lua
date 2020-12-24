LOG('BlueprintsTest.lua ... ')
 
 
-- table for storing issue found in blueprints
-- this table is logged at end of verification process
local issues = {}

function testFrom(caller)
    if not caller then caller = '' end
    WARN('BlueprintsTest.lua test2(' .. caller ..  ')'  )
end

function Verify(blueprints)
    issues = {}
    LOG('Blueprints verification...') 
    
    --local BA = import('/lua/system/BlueprintsAnalyzer.lua')
    --local units = BA.GetUnitsFrom(blueprints)
    --table.sort(units, function(a, b)
    --    if a.ID >= b.ID then
    --        return false
    --    else
    --        return true
    --    end
    --end)
     

    LOG('Blueprints verification... Done and found ' .. table.size(issues) .. ' issues' ) 
end
 
LOG('BlueprintsTest.lua ... loaded')
