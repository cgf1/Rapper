local x = {
    __index = _G
}

Rapper = setmetatable(x, x)
Rapper.Rapper = Rapper
setfenv(1, Rapper)

local EVENT_MANAGER = EVENT_MANAGER
local GetAbilityIcon = GetAbilityIcon
local GetActiveWeaponPairInfo = GetActiveWeaponPairInfo
local GetSlotBoundId = GetSlotBoundId
local GetSpecificSkillAbilityKeysByAbilityId = GetSpecificSkillAbilityKeysByAbilityId
local IsMounted = IsMounted
local SlotSkillAbilityInSlot = SlotSkillAbilityInSlot

local name = 'Rapper'
local nameCL = name .. '_CL'
local settings_version = 1
local saved = {
    slot = 5
}

local slotn
local mounted
local ticking

local rearm
local reset_slot

local function israpid()
    local aid = GetSlotBoundId(slotn)
    local icon = GetAbilityIcon(aid)
    local israpid = icon:find('ava_002')
    return israpid, aid
end

local function try_reset(ev)
    local rapid, aid = israpid()
    if not IsMounted() then
        for n in pairs(saved.pair) do
            reset_slot(n, true, 'try_reset')
        end
    elseif ticking and not israpid() then
        local n = GetActiveWeaponPairInfo()
        saved.pair[n] = nil
    end
    if ticking and not saved.pair[1] and not saved.pair[2] then
        EVENT_MANAGER:UnregisterForUpdate(name)
        ticking = false
    end
end

reset_slot = function(n, force, x)
    local aid = saved.pair[n]
    if not aid or n ~= GetActiveWeaponPairInfo() then
        return
    end
    if not israpid() then
        saved.pair[n] = nil
    else
        local skillType, skillLineIndex, skillIndex = GetSpecificSkillAbilityKeysByAbilityId(aid)
        local worked = SlotSkillAbilityInSlot(skillType, skillLineIndex, skillIndex, slotn)
        if GetSlotBoundId(slotn) == aid then
            saved.pair[n] = nil
        elseif not ticking then
            ticking = true
            EVENT_MANAGER:RegisterForUpdate(name, 1000, function() try_reset(5177) end)
        end
    end
    rearm(false)
end

local function onmount(_, mounted)
    local rapid, aid = israpid()
    rearm(false)
    if mounted and rapid then
        mounted = true
        return
    end
    local n = GetActiveWeaponPairInfo()
    if not mounted and not rapid then
        mounted = false
        saved.pair[n] = nil
        return
    end
    if not mounted then
        reset_slot(n, true, 'onmount')
    else
        SlotSkillAbilityInSlot(6, 1, 2, slotn)
        saved.pair[n] = aid
    end
end

local armed
rearm = function(n)
    if armed then
        EVENT_MANAGER:UnregisterForUpdate(nameCL)
        armed = false
    end
    if n == false then
        -- nothing to do
    elseif tonumber(n) then
        EVENT_MANAGER:RegisterForUpdate(nameCL, n, function() rearm() end)
        armed = true
    elseif IsMounted() then
        onmount(_, true)
    elseif israpid() then
        onmount(_, false)
    end
end

local function ability_used(_, slot)
    local n = GetActiveWeaponPairInfo()
    if IsMounted() and slot == slotn and saved.pair[n] then
        reset_slot(n, true, 'ability_used')
        rearm(saved.duration)
    end
end

local function keydown()
    onmount(_, not israpid())
end

local function onloaded(_, addon_name)
    if addon_name ~= name then
        return
    end
    KeyDown = keydown
    saved = ZO_SavedVars:NewAccountWide(name .. 'Saved', settings_version, nil, saved)
    slotn = saved.slot + 2
    EVENT_MANAGER:UnregisterForEvent(name, EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_MOUNTED_STATE_CHANGED, onmount)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_COMBAT_STATE, try_reset)
    -- EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTION_SLOT_STATE_UPDATED, try_reset)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ABILITY_LIST_CHANGED, try_reset)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, try_reset)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTION_SLOT_ABILITY_USED, ability_used)
    saved.pair = saved.pair or {}
    saved.duration = saved.duration or 20000

    ZO_CreateStringId('SI_BINDING_NAME_RAPPER_HOTKEY', 'Toggle rapid on/off')

    SLASH_COMMANDS['/perslot'] = function(n)
        if n == '' then
            -- nothing to do
        elseif tonumber(n) then
            saved.slot = tonumber(n)
            slotn = saved.slot + 2
        else
            d("usage: /perslot <number>")
            return
        end
        d(string.format("%s: using slot %d", name, saved.slot))
    end
    SLASH_COMMANDS['/perdur'] = function(n)
        if n == '' then
            -- nothing to do
        elseif tonumber(n) then
            saved.duration = tonumber(n) * 1000
        else
            d("usage: /perdur <number>")
            return
        end

        d(string.format("%s: wait %d ms before next rapids", name, saved.duration))
    end
end

EVENT_MANAGER:RegisterForEvent(name, EVENT_ADD_ON_LOADED, onloaded)
