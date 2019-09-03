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

local rearm

local function emptyfunc()
end

local dbg = empty_func

local function call(sub, x)
    return function(_, ...) sub(x, ...) end
end

local function israpid()
    local aid = GetSlotBoundId(slotn)
    local icon = GetAbilityIcon(aid)
    local israpid = icon:find('ava_002') ~= nil
-- dbg("------ %s %s", tostring(israpid), tostring(icon));
    return israpid, aid
end

local function reslot(rapidify)
    local n = GetActiveWeaponPairInfo()
    local aid
    if rapidify then
	saved.pair[n] = GetSlotBoundId(slotn)
	SlotSkillAbilityInSlot(6, 1, 2, slotn)
	aid = saved.pair[n]
    elseif not saved.pinned then
	aid = saved.pair[n]
	local skillType, skillLineIndex, skillIndex = GetSpecificSkillAbilityKeysByAbilityId(aid)
	SlotSkillAbilityInSlot(skillType, skillLineIndex, skillIndex, slotn)
    end
    if not aid then
	dbg("reslot: want rapid = %s, called with no saved aid", tostring(rapidify))
    else
	dbg("reslot: want rapid = %s, cur %s, saved %s", tostring(rapidify), GetAbilityName(GetSlotBoundId(slotn)), GetAbilityName(aid))
    end
    return
end

local function onmount(x, mounted)
    local rapid, aid = israpid()
    rearm('onmount', false)
    if mounted and rapid then
	dbg("onmount(%s): returning because already mounted and rapid", x)
	return
    end
    local r
    dbg("onmount(%s): calling reslot(%s)", x, tostring(mounted))
    reslot(mounted)
end

local armed = false
rearm = function(x, doit)
    dbg("rearm: %s: %s", x, tostring(doit))
    if armed then
	EVENT_MANAGER:UnregisterForUpdate(nameCL)
	armed = false
    end
    if doit then
	EVENT_MANAGER:RegisterForUpdate(nameCL, saved.duration, function() onmount('rearm', true) end)
	armed = true
    end
end

local function ability_used(x, slot)
    local n = GetActiveWeaponPairInfo()
    dbg("ability_used: wp %d, mounted %s, slot %d, slotn %d, saved.pair[n] %s", n, tostring(IsMounted()), slot, slotn, tostring(saved.pair[n]))
    if slot == slotn and IsMounted() and israpid() then
	reslot(false)
	rearm('ability_used', true)
    end
end

local function onslot(x, slot)
    local rapid = israpid()
    if IsMounted() then
        if slot == slotn and not rapid then
            local n = GetActiveWeaponPairInfo()
            saved.pair[n] = GetSlotBoundId(slotn)
        end
    elseif not saved.pinned and rapid then
        reslot(false)	-- turn it off
        dbg("tried to turn off rapid")
    end
end

local function keydown()
    saved.pinned = not saved.pinned
    dbg("keydown: pinning = %s", tostring(saved.pinned))
    onmount('key', saved.pinned)
end

local function onloaded(_, addon_name)
    if addon_name ~= name then
	return
    end
    dbg = emptyfunc
    KeyDown = keydown
    saved = ZO_SavedVars:NewAccountWide(name .. 'Saved', settings_version, nil, saved)
    slotn = saved.slot + 2
    if saved.pinned == nil then
        saved.pinned = false
    end
    if saved.debug == nil then
        saved.debug = false
    end
    if saved.debug then
        dbg = df
    else
        dbg = emptyfunc
    end
    EVENT_MANAGER:UnregisterForEvent(name, EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_MOUNTED_STATE_CHANGED, call(onmount, 'event'))
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, call(onslot, 'weapon switched'))
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTION_SLOT_ABILITY_USED, call(ability_used, 'slot ability used'))
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTION_SLOT_UPDATED, call(onslot, 'slot updated'))
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTION_SLOT_STATE_UPDATED, call(onslot, 'slot state updated'))
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
	if not n or n == '' then
	    -- nothing to do
	elseif tonumber(n) then
	    saved.duration = tonumber(n) * 1000
	else
	    d("usage: /perdur <number>")
	    return
	end

	d(string.format("%s: wait %d ms before next rapids", name, saved.duration))
    end
    SLASH_COMMANDS['/perdebug'] = function(n)
	if not n or n == '' then
	    -- nothing to do
	elseif n == 'true' or n == 'on' then
	    dbg = df
            saved.debug = true
	else
	    dbg = emptyfunc
            saved.debug = false
	end
	d("rapper debugging: " .. tostring(dbg == df))
    end
end

EVENT_MANAGER:RegisterForEvent(name, EVENT_ADD_ON_LOADED, onloaded)
