-- ==========================================================================================
-- * File       : lua/system/utils.lua
-- * Authors    : Gas Powered Games, FAF Community, HUSSAR
-- * Summary    : Contains global functions for working with tables and strings
-- ==========================================================================================

--- RandomIter(table) returns a function that when called, returns a pseudo-random element of the supplied table.
--- Each element of the table will be returned once. This is essentially for "shuffling" sets.
function RandomIter(someSet)
    local keyList = {}
    for key, val in someSet do
        table.insert(keyList, key)
    end

    return function()
        local size = table.getn(keyList)

        if size > 0 then
            local key = table.remove(keyList, Random(1, size))
            return key, someSet[key]
        else
            return
        end
    end
end

--- Calls the given function with the given args, and
--- catches any error and logs a warning including the given message.
--- Returns nil if the function failed, otherwise returns the function's result.
function safecall(msg, fn, ...)
    local ok, result = pcall(fn, unpack(arg))
    if ok then
        return result
    else
        WARN("Problem " .. tostring(msg) .. ":\n" .. result)
        return
    end
end

--- Returns a shallow copy of t.
function table.copy(t)
    if not t then return end -- prevents looping over nil table
    local r = {}
    for k,v in t do
        r[k] = v
    end
    return r
end

--- Returns the key for val if it is in t table.
--- Otherwise, return nil
function table.find(t,val)
    if not t then return end -- prevents looping over nil table
    for k,v in t do
        if v == val then
            return k
        end
    end
    -- return nil by falling off the end
end


--- Returns true iff every key/value pair in t1 is also in t2
function table.subset(t1,t2)
    if not t1 and not t2 then return true end  -- nothing is in nothing
    if not t1 then return true end  -- nothing is in something
    if not t2 then return false end -- something is not in nothing
    for k,v in t1 do
        if t2[k] ~= v then return false end
    end
    return true
end

--- Returns true iff t1 and t2 contain the same key/value pairs.
--- this function does not performs comparison on values of sub-tables while the table.identical() does
function table.equal(t1,t2)
    return table.subset(t1,t2) and table.subset(t2,t1)
end

--- Returns true iff t1 and t2 contain the same keys, values, and sub-tables
--- this function performs comparison on values of sub-tables while the table.equal() does not
function table.identical(t1,t2)
    return table.getsize(table.delta(t1,t2)) == 0
end

--- Removes a field by value instead of by index
function table.removeByValue(t,val)
    if not t then return end -- prevent looping over nil table
    for k,v in t do
        if v == val then
            table.remove(t,k)
            return
        end
    end
end

--- Returns a copy of t with all sub-tables also copied.
function table.deepcopy(t,backrefs)
    if type(t)=='table' then
        if backrefs==nil then backrefs = {} end

        local b = backrefs[t]
        if b then
            return b
        end

        local r = {}
        backrefs[t] = r
        for k,v in t do
            r[k] = table.deepcopy(v,backrefs)
        end
        return r
    else
        return t
    end
end

--- Returns a table in which fields from t2 overwrite
--- fields from t1. Neither t1 nor t2 is modified. The returned table may
--- share structure with either t1 or t2, so it is not safe to modify.
--- e.g.  t1 = { x=1, y=2, sub1={z=3}, sub2={w=4} }
---       t2 = { y=5, sub1={a=6}, sub2="Fred" }
---       merged(t1,t2) -> { x=1, y=5, sub1={a=6,z=3}, sub2="Fred" }
---       merged(t2,t1) -> { x=1, y=2, sub1={a=6,z=3}, sub2={w=4} }
function table.merged(t1, t2)

    if t1==t2 then
        return t1
    end

    if type(t1)~='table' or type(t2)~='table' then
        return t2
    end

    local copied = nil
    for k,v in t2 do
        if type(v)=='table' then
            v = table.merged(t1[k], v)
        end
        if t1[k] ~= v then
            copied = copied or table.copy(t1)
            t1 = copied
            t1[k] = v
        end
    end

    return t1
end

--- Writes all undefined keys from t2 into t1.
function table.assimilate(t1, t2)
    if not t2 then return t1 end -- prevent looping over nil table
    for k, v in t2 do
        if t1[k] == nil then
            t1[k] = v
        end
    end

    return t1
end

--- Remove all keys in t2 from t1.
function table.subtract(t1, t2)
    if not t2 then return t1 end -- prevent looping over nil table
    for k, v in t2 do
        t1[k] = nil
    end

    return t1
end

--- Performs a shallow "merge" of t1 and t2, where t1 and t2
--- are expected to be numerically keyed (existing keys are discarded).
--- e.g. table.cat({1, 2, 3}, {'A', 'House', 3.14})  ->  {1, 2, 3, 'A', 'House', 3.14}
function table.cat(t1, t2)
    -- handling nil tables before lopping
    if not t1 then return table.copy(t2) end
    if not t2 then return table.copy(t1) end
    local r = {}
    for i,v in t1 do
        table.insert(r, v)
    end

    for i,v in t2 do
        table.insert(r, v)
    end

    return r
end

--- Concatenate arbitrarily-many tables (equivalent to table.cat, but variable number of arguments
--- Slightly more overhead, but can constructively concat *all* the things)
function table.concatenate(...)
    local ret = {}

    for index = 1, table.getn(arg) do
        if arg[index] then
            for k, v in arg[index] do
                table.insert(ret, v)
            end
        end
    end

    return ret
end

--- Destructively concatenate two tables. (numerical keys only)
--- Appends the keys of t2 onto t1, returning it. The original t1 is destroyed,
--- but this avoids the need to copy the values in t1, saving some time.
function table.destructiveCat(t1, t2)
    for k, v in t2 do
        table.insert(t1, v)
    end
end

--- Returns a new table with keys equal to values from specified table and values equal to indexes of values
--- this is useful for sorting table by looking up index of values from sort table
--- input  = { [1] = 'A', [2] = 'B', [3] = 'C' }
--- output = { [A] = 1, [B] = 2, [C] = 3 }
function table.lookup(t)
    local r = {}
    for i, v in t or {} do
        r[v] = i
    end
    return r
end

--- Returns an item of the table at specified key or zero
--- this is useful for making arithmetic operations on values of tables with some uninitialized values
function table.item(t, key)
    if not t then return 0 end
    if not t[key] then return 0 end
    return t[key]
end

--- Returns a new table sorted by values of specified field name using order of values in lookup table
--- @param uniqueFieldName is a field name with unique value for each item, and used as secondary sorter
--- @param lookupFieldName is a field name used as primary sorter
--- @param lookupFieldsOrder is a table with all possible values of the lookupFieldName
--- e.g. table.sortBy(bp.Weapons, 'Damage', 'WeaponCategory', { 'Defense', 'Artillery', 'Missile' } )
function table.sortBy(t, uniqueFieldName, lookupFieldName, lookupFieldsOrder)
    if table.getsize(t) < 1 then return t end
    local list = table.indexize(t)
    local lookup = table.lookup(lookupFieldsOrder)
    local warning = false
    table.sort(list, function(a,b)
        -- find order index or default to last index
        local a_order = lookup[a[lookupFieldName]] or 10000
        local b_order = lookup[b[lookupFieldName]] or 10000
        if a_order ~= b_order then 
            return a_order < b_order
        else
            return a[uniqueFieldName] < b[uniqueFieldName]
        end
    end)
    return list
end

--- Returns a sorted copy of table leaving the original unchanged while table.sort(t, comp) changes the table
--- [comp] is an optional comparison function, defaulting to less-than.
function table.sorted(t, comp)
    local r = table.copy(t)
    table.sort(r, comp)
    return r
end

--- sort_by(field) provides a handy comparison function for sorting
--- a list of tables by some field.
---
--- For example,
---       my_list={ {name="Fred", ...}, {name="Wilma", ...}, {name="Betty", ...} ... }
---
---       table.sort(my_list, sort_by 'name')
---           to get names in increasing order
---
---       table.sort(my_list, sort_down_by 'name')
---           to get names in decreasing order
function sort_by(field)
    return function(t1,t2)
        return t1[field] < t2[field]
    end
end

function sort_down_by(field)
    return function(t1,t2)
        return t2[field] < t1[field]
    end
end

--- Returns a list of the keys of t, sorted.
--- [comp] is an optional comparison function, defaulting to less-than, e.g.
--- table.keys(t) -- returns keys in increasing order (low performance with large tables)
--- table.keys(t, function(a, b) return a > b end) -- returns keys in decreasing order (low performance with large tables)
--- table.keys(t, false) -- returns keys without comparing/sorting (better performance with large tables)
function table.keys(t, comp)
    local r = {}
    if not t then return r end -- prevents looping over nil table
    local n = 1
    for k,v in t do
        r[n] = k -- faster than table.insert(r,k)
        n = n + 1
    end
    if comp ~= false then table.sort(r, comp) end
    return r
end

--- Return a list of the values of t, in unspecified order.
function table.values(t)
    local r = {}
    if not t then return r end -- prevents looping over nil table
    local n = 1
    for k,v in t do
        r[n] = v -- faster than table.insert(r,v)
        n = n + 1
    end
    return r
end

--- Concatenate keys of a table into a string and separates them by optional string.
function table.concatkeys(t, sep)
    sep = sep or ", "
    local tt = table.keys(t)
    return table.concat(tt,sep)
end

--- Iterates over a table in key-sorted order
--- @param comp is an optional comparison function, defaulting to less-than.
function sortedpairs(t, comp)
    local keys = table.keys(t, comp)
    local i=1
    return function()
        local k = keys[i]
        if k~=nil then
            i=i+1
            return k,t[k]
        end
    end
end

--- Returns actual size of a table, including string keys
function table.getsize(t) 
    return table.size(t) -- calling shorter function for API compatibility 
end
--- Returns actual size of a table, including string keys
function table.size(t)
    -- handling nil table like empty tables so that no need to check
    -- for nil table and then size of table:
    -- if t and table.getsize(t) > 0 then
    -- do some thing
    -- end
    if type(t) ~= 'table' then return 0 end
    local size = 0
    for k, v in t do
        size = size + 1
    end
    return size
end

--- Returns a table with keys and values from t reversed.
--- e.g. table.inverse {'one','two','three'} => {one=1, two=2, three=3}
---      table.inverse {foo=17, bar=100}     => {[17]=foo, [100]=bar}
--- If t contains duplicate values, it is unspecified which one will be returned.
--- e.g. table.inverse {foo='x', bar='x'} => possibly {x='bar'} or {x='foo'}
function table.inverse(t)
    if not t then return {} end -- prevents looping over nil table
    local r = {}
    for k,v in t do
        r[v] = k
    end
    return r
end

--- Reverses order of values in a table using their index
--- table.reverse {'one','two','three'} => {'three', 'two', 'one'}
function table.reverse(t)
    if not t then return {} end -- prevents looping over nil table
    local r = {}
    local items = table.indexize(t) -- convert from hash table
    local itemsCount = table.getsize(t)
    for k, v in ipairs(items) do
        r[itemsCount + 1 - k] = v
    end
    return r
end

--- Converts hash table to a new table with keys from 1 to size of table and the same values
--- this is useful for preparing hash table before sorting its values
--- t1 = { 1 = '11', 2 = '22', 3 = '33' }
--- t2 = { A = 'AA', B = 'BB', C = 'CC' }
--- table.indexize(t1) => { 1 = '11', 2 = '22', 3 = '33' }
--- table.indexize(t2) => { 1 = 'AA', 2 = 'BB', 3 = 'CC' }
function table.indexize(t)
    if not t then return {} end -- prevents looping over nil table
    local r = {}
    local n = 1
    for k, v in t do
        r[n] = v -- faster than table.insert(r, v)
        n = n + 1
    end
    return r
end

--- Converts a table to a new table with values as keys and values equal to true, duplicated table values are discarded
--- it is useful for quickly looking up values in tables instead of looping over them
--- t1 = { 1 = '11', 2 = '22', 3 = '33' }
--- t2 = { A = 'AA', B = 'BB', C = 'CC' }
--- table.hash(t1) => { 11 = true, 22 = true, 33 = true }
--- table.hash(t2) => { AA = true, BB = true, CC = true }
function table.hash(t)
    if not t then return {} end -- prevents looping over nil table
    local r = {}
    for k, v in t do
        if type(v) ~= "string" and type(v) ~= 'number' then
            r[tostring(v)] = true
        else
            r[v] = true
        end
    end
    return r
end

--- Converts a table to a new table with values as keys only if their values are true
--- it is reverse logic of table.hash(t)
--- t1 = { 1 = true, 2 = true, 3 = false }
--- t2 = { A = true, B = true, C = false }
--- table.unhash(t1) => { 1 = 1, 2 = 2 } 
--- table.unhash(t2) => { 1 = A, 2 = B } 
function table.unhash(t)
    if not t then return {} end -- prevents looping over nil table
    local r = {}
    local n = 1
    for k, v in t do
        if v then
            r[n] = k -- faster than table.insert(r, k)
            n = n + 1
        end
    end
    return r
end

--- Gets keys of hash table if their values equal to specified boolean value, defaults to true
--- this is useful to check which keys are present or not in a hash table
--- t = { [A] = true, [B] = true, [C] = false }
--- table.hashkeys(t, true)  =>  { 'A', 'B' }
--- table.hashkeys(t, false) =>  { 'C' }
function table.hashkeys(t, value)
    if value == nil then value = true end -- defaulting to true
    local r = table.filter(t, function(v) return v == value end)
    return table.keys(r)
end

--- table.map(fn,t) returns a table with the same keys as t but with
--- fn function applied to each value.
function table.map(fn, t)
    if not t then return {} end -- prevents looping over nil table
    local r = {}
    for k,v in t do
        r[k] = fn(v)
    end
    return r
end

--- Returns true iff the table has no keys/values.
function table.empty(t)
    return table.getsize(t) == 0
end

--- Returns a shuffled table
function table.shuffle(t)
    local r = {}
    for key, val in RandomIter(t) do
        if type(key) == 'number' then
            table.insert(r, val)
        else
            r[key] = val
        end
    end
    return r
end

--- Binary insert value into table using cmp-func
function table.binsert(t, value, cmp)
      local cmp = cmp or (function(a,b) return a < b end)
      local start, stop, mid, state = 1, table.getsize(t), 1, 0
      while start <= stop do
         mid = math.floor((start + stop) / 2)
         if cmp(value, t[mid]) then
            stop, state = mid - 1, 0
         else
            start, state = mid + 1, 1
         end
      end

      table.insert(t, mid + state, value)
      return mid + state
   end

--- Pretty-print a table. Depressingly large amount of wheel-reinvention were required, thanks to
--- SC's LUA being a bit weird and the existing solutions to this problem being aggressively optimized
function printField(k, v, tblName, printer)
    if not printer then printer = WARN end
    if not tblName then tblName = "" end
    if "table" == type(k) then
        table.print(k, tblName .. " ", printer)
    else
        tblName = tblName .. '' .. tostring(k)
    end
    if "string" == type(v) then
        printer(tblName .. " = " .. "\"" .. v .. "\"")
    elseif "table" == type(v) then
        --printer(tblName .. k .. " = ")
        table.print(v, tblName .. "  ", printer)
    else
        printer(tblName .. " = " .. tostring(v))
    end
end

--- Prints keys and values of a table and sub-tables if present in alphabetical order of table's keys
--- @param tbl specifies a table to print
--- @param tblPrefix specifies optional table prefix/name
--- @param printer specifies optional message printer: LOG, WARN, error, etc.
--- e.g. table.print(categories)
---      table.print(categories, 'categories')
---      table.print(categories, 'categories', 'WARN')
function table.print(tbl, tblPrefix, printer)
    if not printer then printer = LOG end
    if not tblPrefix then tblPrefix = "" end
    if not tbl then
        printer(tblPrefix .." table is nil")
        return
    end
    if table.getsize(tbl) == 0 then
        printer(tblPrefix .." { }")
        return
    end
    printer(tblPrefix.." {")
    -- sort and print table values in alphabetical order
    for k, v in sortedpairs(tbl) do
        printField(k, v, tblPrefix .. "    ", printer)
    end

    printer(tblPrefix.." }")
end

--- Fills out all the values in a given table with specified item value
function table.fill(t, item)
    for k, v in t or {} do
        t[k] = item
    end
end

--- Returns the first valid (not false) value or nil in a given table 
--- t1 = { false, 'v1', 'v2', false }
--- t2 = { A = false, B = 'v1', C = 'v2', D = false }
--- table.firstValue(t1) => 'v1'
--- table.firstValue(t2) => 'v1'
function table.firstValue(t)
    for k, v in t or {} do
        if v then return v end
    end
    return nil
end

--- Returns the first valid (not false) key or nil in a given table
--- t1 = { 1 = false, 2 = 'v1', 3 = 'v2', 4 = false }
--- t2 = { A = false, B = 'v1', C = 'v2', D = false }
--- table.firstKey(t1) => '1'
--- table.firstKey(t2) => 'A'
function table.firstKey(t)
    for k, v in t or {} do
        if v then return k end
    end
    return nil
end

--- Returns the last valid (not false) value or nil in a given table
--- t1 = { 1 = false, 2 = 'v1', 3 = 'v2', 4 = false }
--- t2 = { A = false, B = 'v1', C = 'v2', D = false }
--- table.lastValue(t1) => 'v2'
--- table.lastValue(t2) => 'v2'
function table.lastValue(t)
    for k, v in table.reverse(t) do
        if v then return v end 
    end
    return nil
end

--- Returns the last valid (not false) key or nil in a given table
--- t1 = { 1 = false, 2 = 'v1', 3 = 'v2', 4 = false }
--- t2 = { A = false, B = 'v1', C = 'v2', D = false }
--- table.lastKey(t1) => '3'
--- table.lastKey(t2) => 'C'
function table.lastKey(t)
    for k, v in table.reverse(t) do
        if v then return k end
    end
    return nil
end

--- Pops the last valid value from by removing it from a given table and returns its value
--- t1 = { 1 = false, 2 = 'v1', 3 = 'v2', 4 = false }
--- t2 = { A = false, B = 'v1', C = 'v2', D = false }
--- table.pop(t1) => 'v2' and t1 = { 1 = false, 2 = 'v1', 3 = nil, 4 = false }
--- table.pop(t2) => 'v2' and t2 = { A = false, B = 'v1', C = nil, D = false }
function table.pop(t)
    if not t then return nil end
    local k = table.lastKey(t)
    if not k then return nil end
    local v = t[k]
    t[k] = nil
    return v
end

--- pushes a new item to the table only if this item is not already present
--- t1 = { 1 = 'v1', 2 = 'v2', 3 = 'v3'  }
--- t2 = { 1 = 'v1', 2 = 'v2' }
--- table.push(t1, 'v3') => t1 = { 1 = 'v1', 2 = 'v2', 3 = 'v3' }
--- table.push(t2, 'v3') => t2 = { 1 = 'v1', 2 = 'v2', 3 = 'v3' }
function table.push(t, item)
    if not t then return nil end

    local found = table.find(t, item)
    if found then return nil end

    table.insert(t, item)
end

--- Returns a new table with values and keys between indexes of a given table
--- t1 = { 1 = 'v1', 2 = 'v2', 3 = false }
--- t2 = { A = 'v1', B = 'v2', C = false }
--- table.slice(t1, 2, 3) => { 2 = 'v2', 3 = false }
--- table.slice(t2, 2, 3) => { B = 'v2', C = false }
function table.slice(t, fromIndex, toIndex)
    if not t then return {} end
    local size = table.getsize(t)
    -- check for valid range of indexes otherwise default to min/max index
    if size == 0 then return {} end
    if size < fromIndex then fromIndex = 1 end
    if size < toIndex then toIndex = size end
    if fromIndex == toIndex then return {} end

    local keys = table.keys(t) -- get original keys of the table
    local array = table.indexize(t) -- in case t is hash table

    local ret = {}
    for i = fromIndex, toIndex, 1 do
        local k = keys[i]
        local v = array[i]
        ret[k] = v
    end
    return ret
end

--- Initializes a table with arbitrarily-many keys by setting these keys to zero
--- as long as these keys do not have a value already in this table
--- this is useful to initialize tables in unit blueprints
--- t1 = { 1 = 'v1', 2 = 'v2' }
--- t2 = { A = 'v1', B = 'v2' }
--- table.init(t1, '2', '3', '4' ) => { 1 = 'v1', 2 = 'v2', 3 = 0, 4 = 0 }
--- table.init(t2, 'B', 'C', 'D' ) => { A = 'v1', B = 'v2', C = 0, D = 0 }
function table.init(t, ...)
    if table.getn(arg) == 0 then return end
    for _, k in arg or {} do
        if t[k] == nil then t[k] = 0 end
    end
end

--- Returns filtered table containing every mapping from table for which fn function returns true when passed the value.
--- @param t  - is a table to filter
--- @param fn - is decision function to use to filter the table, defaults checking if a value is true or exists in table
--- t1 = { 1 = 'one', 2 = 5, 3 = 10 }
--- t2 = { A = 'one', B = 5, C = 10 }
--- local function GreaterThan5(v) return v > 5 end
--- table.filter(t1, GreaterThan5) => { 3 = 10 }
--- table.filter(t2, GreaterThan5) => { C = 10 }
function table.filter(t, fn)
    local r = {}
    if not fn then fn = function(v, k) return v end end
    for k, v in t do
        if fn(v, k) then
            r[k] = v
        end
    end
    return r
end 
--- Perform an action function for each k,v pair in a given table
--- t1 = { 1 = 1, 2 = 2, 3 = 3, 4 = 4 }
--- t2 = { A = 1, B = 2, C = 3, D = 4 }
--- local function IncreaseBy1(k, v) return v + 1 end
--- table.foreach(t1, IncreaseBy1) => { 1 = 2, 2 = 3, 3 = 4, 4 = 5 }
--- table.foreach(t2, IncreaseBy1) => { A = 2, B = 3, C = 4, D = 5 }
function table.foreach(t, action)
    if not action then return end
    for k, v in t or {} do
        action(k, v)
    end
end

--- Returns total count of values that match fn function or if values exist in table
--- @param fn is optional filtering function that is applied to each value of the table
--- t1 = { 1 = 1, 2 = 2, 3 = 3, 4 = 4 }
--- t2 = { A = 1, B = 2, C = 3, D = 4 }
--- local GreaterThan3 = function(k, v) return v > 3 end
--- table.count(t1, GreaterThan3) => 1
--- table.count(t2, GreaterThan3) => 1
function table.count(t, fn)
    if not t then return 0 end -- prevents looping over nil table
    if not fn then fn = function(v) return v end end
    local r = table.filter(t, fn)
    return table.getsize(r)
end

--- Returns a new table with unique values stored using numeric keys and it does not preserve keys of the original table
--- t1 = { 1 = false, 2 = 'v2', 3 = 'v2', 4 = 'v3' }
--- t2 = { A = false, B = 'v2', C = 'v2', D = 'v3' }
--- table.unique(t1) => { 1 = false, 2 = 'v1', 3 = 'v3' }
--- table.unique(t2) => { 1 = false, 2 = 'v1', 3 = 'v3' }
function table.unique(t)
    if not t then return end -- prevents looping over nil table
    local unique = {}
    local inserted = {}
    local n = 0
    for k, v in t do
        if not inserted[v] then
            n = n + 1
            unique[n] = v -- faster than table.insert(unique, v)
            inserted[v] = true
        end
    end
    return unique
end

--- Returns differences between two specified tables by recursively comparing table's values and/or its sub-tables
--- @param t1key is optional string for annotating difference in 1st table
--- @param t2key is optional string for annotating difference in 2nd table
--- @param showDeltaType is optional boolean that specifies whether to insert a type of difference between two values
--- this function is useful for comparing large or complex tables (e.g. unit blueprints)
function table.delta(t1, t2, t1key, t2key, showDeltaType)
    if not t1key then t1key = 't1' end
    if not t2key then t2key = 't2' end
    local ret = {}
    if type(t1) ~= 'table' or
       type(t2) ~= 'table' then 
        ret[t1key] = t1 or 'nil'
        ret[t2key] = t2 or 'nil'
        if showDeltaType then ret['delta'] = 'table' end
        return ret 
    end
    -- local function for comparing two values of specified table key
    local function compare(v1, v2, key)
        -- skip comparing values if it was done on first pass
        if ret[key] then return end
        if type(v1) == 'table' and type(v1) == 'table' then
            -- recursive call on two sub-tables
            local differences = table.delta(v1, v2, t1key, t2key, showDeltaType)
            if table.getsize(differences) > 0 then
                ret[key] = differences
            end
        elseif v1 == nil or v2 == nil then 
            if not ret[key] then ret[key] = {} end 
            if v1 == nil then ret[key][t1key] = 'nil' else ret[key][t1key] = v1 end
            if v2 == nil then ret[key][t2key] = 'nil' else ret[key][t2key] = v2 end
            if showDeltaType then ret[key]['delta'] = 'nil' end
        elseif type(v1) ~= type(v2) then 
            if not ret[key] then ret[key] = {} end
            ret[key][t1key] = v1
            ret[key][t2key] = v2 
            if showDeltaType then ret[key]['delta'] = 'type' end
        elseif v1 ~= v2 then
            if not ret[key] then ret[key] = {} end 
            ret[key][t1key] = v1
            ret[key][t2key] = v2 
            if showDeltaType then ret[key]['delta'] = 'value' end
        end
    end 
    -- compare values from table 1 to table 2
    for k1,v1 in t1 do 
        local v2 = t2[k1]
        compare(v1, v2, k1)
    end
    -- compare values from table 2 to table 1
    for k2,v2 in t2 do 
        local v1 = t1[k2]
        compare(v1, v2, k2)
    end
    return ret
end

-- TODO refactor 'Strings*' functions into strings.FunctionName like we do for table, math, bin functions above

--- Returns items as a single string, separated by the delimiter
function StringJoin(items, delimiter)
    local str = "";
    for k,v in items do
        str = str .. v .. delimiter
    end
    return str
end

--- Splits a string into a series of tokens, using a separator character `sep`
function StringSplit(str, sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[table.getn(fields)+1] = c end)
    return fields
end

--- Returns true if the string starts with the specified value
function StringStartsWith(stringToMatch, valueToSeek)
    return string.sub(stringToMatch, 1, valueToSeek:len()) == valueToSeek
end

--- Extracts a string between two specified strings
--- e.g. StringExtract('/path/name_end.lua', '/', '_end', true) --> name
function StringExtract(str, str1, str2, fromEnd)
    local pattern = str1 .. '(.*)' .. str2
    if fromEnd then pattern = '.*' .. pattern end
    local i, ii, m = string.find(str, pattern)
    return m
end

--- Adds comma as thousands separator in specified value
--- e.g. StringComma(10000) --> 10,000
function StringComma(value)
    local str = value or 0
    while true do
      str, k = string.gsub(str, "^(-?%d+)(%d%d%d)", '%1,%2')
      if k == 0 then
        break
      end
    end
    return str
end

--- Prepends a string with specified symbol or one space
function StringPrepend(str, symbol)
    if not symbol then symbol = ' ' end
    return symbol .. str
end
--- Splits a string with camel cast to a string with separate words
--- e.g. StringSplitCamel('SupportCommanderUnit') -> 'Support Commander Unit'
function StringSplitCamel(str)
   return (str:gsub("[A-Z]", StringPrepend):gsub("^.", string.upper))
end

--- Reverses order of letters for specified string
--- e.g. StringCapitalize('abc123') --> 321cba
function StringReverse(str)
    local tbl =  {}
    str:gsub(".",function(c) table.insert(tbl,c) end)
    tbl = table.reverse(tbl)
    return table.concat(tbl)
end
--- Capitalizes each word in specified string
--- e.g. StringCapitalize('hello supreme commander') --> Hello Supreme Commander
function StringCapitalize(str)
    local lower = string.lower(str)
    return string.gsub(" "..lower, "%W%l", string.upper):sub(2)
end


--- Check if a given string starts with specified string
function StringStarts(str, startString)
   return string.sub(str, 1, string.len(startString)) == startString
end

--- Check if a given string ends with specified string
function StringEnds(str, endString)
   return endString == '' or string.sub(str, -string.len(endString)) == endString
end

--- Returns a new string without leading and trailing spaces
function StringTrim(str)
    local ret, count = string.gsub(str, "^%s*(.-)%s*$", "%1")
    return ret
end

--- Returns a new string with spaces inserted on left side of passed string
function StringPadLeft(str, finalLength)
    finalLength = finalLength or 0
    finalLength = finalLength - string.len(str)
     
    if finalLength > 0 then
        str = string.rep(' ', finalLength) .. str
    end
    return str
end
--- Returns a new string with spaces inserted on right side of passed string
function StringPadRight(str, finalLength)
    finalLength = finalLength or 0
    finalLength = finalLength - string.len(str)

    if finalLength > 0 then
        str = str .. string.rep(' ', finalLength)
    end
    return str
end

function StringQuote(str)
    return '"' .. (str or 'nil') .. '"'
end

function StringContains(str, words)
    for k, v in words or {} do
        if string.find(str, v) then
            return true
        end
    end
    return false
end

--- Sorts two variables based on their numeric value or alpha order (strings)
function Sort(itemA, itemB)
    if not itemA or not itemB then return 0 end

    if type(itemA) == "string" or
       type(itemB) == "string" then
        if string.lower(itemA) == string.lower(itemB) then
            return 0
        else
            -- sort string using alpha order
            return string.lower(itemA) < string.lower(itemB)
        end
    else
       if math.abs(itemA - itemB) < 0.0001 then
            return 0
       else
            -- sort numbers in decreasing order
            return itemA > itemB
       end
    end
end

--- Rounds a number to specified double precision
function math.round(num, idp)
    if not idp then
        return math.floor(num+.5)
    else
        return tonumber(string.format("%." .. (idp or 0) .. "f", num))
    end
end

--- Clamps numeric value to specified Min and Max range
function math.clamp(v, min, max)
    return math.max(min, math.min(max, v))
end

--- Initializes a value to 0 or returns its original value
--- this is helpful to check for uninitialized numeric values in table
function math.init(value)
    if value == nil then return 0 else return value end
end

--- Abbreviates specified number to a short string, e.g. 240100 => 240.1k
--- Note this function supports positive, negative, and small values, e.g. 0.25
--- @param num is a number to abbreviate
--- @param showSign is optional boolean to hide or show sign or the number
--- math.abbr(240100, true)   => +240.1k
--- math.abbr(240100, false)  => 240.1k
--- math.abbr(-240100, false) => 240.1k
function math.abbr(num, showSign)
    if num == nil then return 0 end

    -- store sign of the number for later
    local isNegative = false
    if num < 0 then
       num = num * -1
       isNegative = true
       -- default to always show sign for negative numbers
       if showSign == nil then showSign = true end
    end

    local str = ""
    if num == 0 then
        return 0
    elseif num < .1 then
        str = string.format("%1.2f", num)
    elseif num < 50 then
        if math.mod(num, 1) > 0 then 
            str = string.format("%01.1f", num)
        else 
            str = string.format("%01.0f", num)
        end
    elseif num < 1000 then        -- 1k
        str = string.format("%01.0f", num)
    elseif num < 10000 then       -- 10k
        str = string.format("%01.1fk", num / 1000)
    elseif num < 100000 then      -- 100K
        if math.mod(num, 1000) > 0 then 
            str = string.format("%01.1fk", num / 1000)
        else
            str = string.format("%01.0fk", num / 1000)
        end
    elseif num < 1000000 then      -- 1m
        str = string.format("%01.0fk", num / 1000)
    elseif num < 10000000 then      -- 10m
        str = string.format("%01.1fm", num / 1000000)
    elseif num < 100000000 then    -- 100m
        if math.mod(num, 1000000) > 0 then 
            str = string.format("%01.1fm", num / 1000000)
        else
            str = string.format("%01.1fm", num / 1000000)
        end
    elseif num < 1000000000 then  -- 1b
        str = string.format("%01.0fm", num / 1000000)
    elseif num < 10000000000 then  -- 10b
        str = string.format("%01.1fb", num / 1000000000)
    elseif num < 100000000000 then  -- 100b
        if math.mod(num, 1000000000) > 0 then 
            str = string.format("%01.1fb", num / 1000000000)
        else
            str = string.format("%01.1fb", num / 1000000000)
        end
    else
        str = string.format("%01.0fb", num / 1000000000)
    end
    -- restore sign of the number
    if showSign then
        if isNegative then
            str = "-" .. str
        else 
            str = "+" .. str
        end
    end
    return str
end

--- Creates timer for profiling task(s) and calculating time delta between consecutive function calls, e.g.
--- local timer = CreateTimer()
--- timer:Start() -- then execute some LUA code
--- timer:Stop()
--- or
--- timer:Start('task1') -- then execute task #1
--- timer:Stop('task1')
--- timer:Start('task2') -- then execute task #2
--- timer:Stop('task2')
function CreateTimer()
    return {
        tasks = {},
        Reset = function(self)
            self.tasks = {}
        end,
        -- starts profiling timer for optional task name
        Start = function(self, name, useLogging)
            name = self:Verify(name)
            -- capture start time
            self.tasks[name].stop  = nil
            self.tasks[name].start = CurrentTime()
            self.tasks[name].calls = self.tasks[name].calls + 1

            if useLogging then
                LOG('Timing task: ' ..  name .. ' started')
            end
        end,
        -- stops profiling timer and calculates stats for optional task name
        Stop = function(self, name, useLogging)
            name = self:Verify(name)
            -- capture stop time
            self.tasks[name].stop  = CurrentTime()
            self.tasks[name].time  = self.tasks[name].stop - self.tasks[name].start
            self.tasks[name].total = self.tasks[name].total + self.tasks[name].time
            -- track improvements between consecutive profiling of the same task
            if self.tasks[name].last then
               self.tasks[name].delta = self.tasks[name].last - self.tasks[name].time
            end
            -- save current time for comparing with the next task profiling
            self.tasks[name].last = self.tasks[name].time

            if useLogging then
                LOG('Timing task: ' ..  name ..' completed in ' ..  self:ToString(name))
            end
            return self:ToString(name)
        end,
        -- verifies if profiling timer has stats for optional task name
        Verify = function(self, name)
            if not name then name = 'default-task' end
            if not self.tasks[name] then
                self.tasks[name] = {}
                self.tasks[name].name  = name
                self.tasks[name].start = nil
                self.tasks[name].stop  = nil
                self.tasks[name].delta = nil
                self.tasks[name].last  = nil
                self.tasks[name].calls = 0
                self.tasks[name].total = 0
                self.tasks[name].time  = 0
            end
            return name
        end,
        -- gets stats for optional task name
        GetStats = function(self, name)
            name = self:Verify(name)
            return self.tasks[name]
        end,
        -- gets time for optional task name
        GetTime = function(self, name)
            name = self:Verify(name)
            local ret = ''
            if not self.tasks[name].start then
                WARN('Timer cannot get time duration for not started task: ' ..  tostring(name))
            elseif not self.tasks[name].stop then
                WARN('Timer cannot get time duration for not stopped task: ' ..  tostring(name))
            else
                ret = string.format("%0.3f seconds", self.tasks[name].time)
            end
            return ret
        end,
        -- gets time delta between latest and previous profiling of named tasks
        GetDelta = function(self, name)
            name = self:Verify(name)
            local ret = ''
            if not self.tasks[name].delta then
                WARN('Timer cannot get time delta after just one profiling of task: ' ..  tostring(name))
            else
                ret = string.format("%0.3f seconds", self.tasks[name].delta)
                if self.tasks[name].delta > 0 then
                    ret = '+' .. ret
                end
            end
            return ret
        end,
        -- gets time total of all profiling calls of named tasks
        GetTotal = function(self, name)
            name = self:Verify(name)
            local ret = ''
            if not self.tasks[name].start then
                WARN('Timer cannot get time total for not started task: ' ..  tostring(name))
            else
                ret = string.format("%0.3f seconds", self.tasks[name].total)
            end
            return ret
        end,
        -- converts profiling stats for optional named task to string
        ToString = function(self, name)
            name = self:Verify(name)
            local ret = self:GetTime(name)
            if self.tasks[name].delta then
                ret = ret .. ', delta: ' .. self:GetDelta(name)
            end
            if self.tasks[name].calls > 1 then
                ret = ret .. ', calls: ' .. tostring(self.tasks[name].calls)
                ret = ret .. ', total: ' .. self:GetTotal(name)
            end
            return ret
         end,
        -- prints profiling stats of all tasks in increasing order of tasks
        -- @param key is optional sorting argument of tasks, e.g. 'stop', 'time', 'start'
         Print = function(self, key)
            key = key or 'stop'
            local sorted = table.indexize(self.tasks)
            sorted = table.sorted(sorted, sort_by(key))
            for _, task in sorted do
                if task.stop then
                    LOG('Timing task: ' ..  task.name ..' completed in ' ..  self:ToString(task.name))
                end
            end
         end
    }
end

-- global table with functions for operating on binary values
bit = {}
--- returns a number shifted left by specified number of bits, e.g. 20 << 1 == 40
function bit.bshiftleft(number, bits)
    return math.pow(number * 2, bits)
end

--- returns a number shifted right by specified number of bits, e.g. 20 >> 1 == 10
function bit.bshiftright(number, bits)
    return math.floor(number / math.pow(2, bits))
end

--- converts specified number or string to binary number, e.g. 2 => 10, '2' => 10
function bit.tobinary(value)
    local num = 0
    local valueType = type(value)
    if valueType == 'string' then
        num = tonumber(value)
    else
        num = value
    end
     
    if type(num) ~= 'number' then
       WARN('cannot convert "' .. tostring(value).. '" of type "' .. valueType ..'" to binary number' )
    elseif num == 0 or num == 1 then
       return num -- skip binary conversion
    else
        local t = {}
        while num > 0 do
            rest = math.mod(num, 2)
            table.insert(t, 1, tostring(rest))
            num = (num - rest ) / 2
        end
        local binary = tonumber( table.concat(t))
        if binary == nil then
            WARN('failed converting "' .. num .. '" to binary number' )
        else
            return binary
        end
    end
    return -1 -- return invalid binary
end

--- performs bitwise 'And' operation on A and B binary numbers
function bit.band(a, b)
    local result = 0
    local binary = 1
    while a > 0 and b > 0 do
      -- check for the rightmost bits
      if math.mod(a , 2) == 1 and math.mod(b, 2) == 1 then 
          result = result + binary -- set the current bit
      end
      binary = binary * 2 -- shift left
      a = math.floor(a / 2) -- shift right
      b = math.floor(b / 2)
    end
    return result
end

--- check if A binary contains B binary using bitwise 'And' operation
function bit.contains(a, b)
    return bit.band(a, b) ~= 0
end

-- creating global table with functions for operating on global variables
global = {}

--- safely check if global variable/function exists without throwing errors
function global.exist(name)
    for key, val in _G do
        if key == name then
            return true
        end
    end
    return false
end

--- prints types and names of all global variables/functions
function global.vars()
    local ret = {}
    local utils = {'math', 'debug', 'debug'}
    for name, items in _G or {} do 
        local itemType = type(items)
        if itemType == 'cfunction' then itemType = 'function' end 

        if type(items) ~= 'table' then
            table.insert(ret, itemType .. ' _G.' .. name ..'')
        else
            local first = table.firstValue(items)
            local firstType = type(first)
            if firstType == 'cfunction' then firstType = 'function' end 
            if firstType == 'function' then 
                for k, v in items do
                    table.insert(ret, firstType .. ' _G.' .. name ..'.' .. k)
                end
            else 
                local stats = table.size(items) .. ' ' .. firstType .. 's'
                table.insert(ret, itemType .. ' _G.' .. name ..' with ' .. stats)
            end
        end 
    end
    table.sort(ret, function(a,b) return a < b end)
    LOG('Global "_G" variable has ' .. table.size(ret) .. ' items:')
    for _, info in ret do
        LOG(info)
    end
end

--- prints types and names of global modules that were already loaded using the import function
function global.modules()
    local ret = {}
    for name, val in __modules or {} do 
        if type(val) ~= 'table' then
            table.insert(ret, '__modules.' .. name ..'')
        else
            local first = table.firstValue(val)

            local stats = table.size(val) .. ' ' .. type(first) .. 's'
            table.insert(ret, '__modules["' .. name ..'"] with ' .. stats)
        end 
    end
    table.sort(ret, function(a,b) return a < b end)
    LOG('Global "__modules" variable has ' .. table.size(ret) .. ' items:')
    for _, info in ret do
        LOG(info)
    end
end

--- prints types and names of functions in moho global variable
function global.moho()
    local ret = {}
    for name, items in moho or {} do 
        if type(items) ~= 'table' then
            table.insert(ret, 'moho.' .. name ..'')
        else
            local count = 0
            for k, v in items do
                if not string.find(k, '__') then 
                    count = count + 1
                    if type(v) == 'function' or type(v) == 'cfunction' then
                        table.insert(ret, type(v) .. ' moho.' .. name ..':' .. k)
                    else
                        table.insert(ret, type(v) .. ' moho.' .. name ..'.' .. k)
                    end
                end
            end
        end 
    end
    table.sort(ret, function(a,b) return a < b end)
    LOG('Global "moho" variable has ' .. table.size(ret) .. ' items:')
    for _, info in ret do
        LOG(info)
    end
end