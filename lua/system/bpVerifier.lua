LOG("bpVerifier.lua Loading...")

doscript '/lua/system/bpAnalyzer.lua'

local function TestLocalFunt()

    LOG("bpVerifier.lua TestLocalFunt")
end
 
function Verify(blueprints)
    LOG("bpVerifier.lua VerifyBlueprints")

    TestLocalFunt()
    GetWeaponStats()
end

