
-- upvalue for performance (prevent global + table operation)
local TableGetn = table.getn

-- upvalue for performance (prevent global)
local CreateEmitterAtEntity = CreateEmitterAtEntity

--- Attaches effects to an entity.
-- @entity The entity to attach the effects to.
-- @army The army that caused the effects.
-- @effects The effects to attach.
-- @accumulator A table that will be appended to, if defined. Useful for 
-- performance if you need to attach various effects.
-- @accCount The current number of elements in the output table.
function CreateEffectsOpti(entity, army, effects, accumulator, accCount)

    local next

    -- if we provided an accumulator then append to it
    if accumulator then 
        next = (accCount or TableGetn(accumulator)) + 1

    -- otherwise, create it
    else 
        accumulator = { }
        next = 1
    end

    -- add to the table. The upperbound is cached
    for k = 1, TableGetn(effects) do 
        accumulator[next] = CreateEmitterAtEntity(entity, army, effects[k])
        next = next + 1
    end

    -- return table and new count
    return accumulator, next - 1
end