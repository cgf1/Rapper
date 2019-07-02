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

local pinned = false

local orig_df = df

local function emptyfunc()
end

local function call(sub, x)
    return function(_, ...) sub(x, ...) end
end

local function israpid()
    local aid = GetSlotBoundId(slotn)
    local icon = GetAbilityIcon(aid)
    local israpid = icon:find('ava_002') ~= nil
-- df("------ %s %s", tostring(israpid), tostring(icon));
    return israpid, aid
end

local function reslot(rapidify)
    local n = GetActiveWeaponPairInfo()
    local aid
    if rapidify then
	saved.pair[n] = GetSlotBoundId(slotn)
	SlotSkillAbilityInSlot(6, 1, 2, slotn)
	aid = saved.pair[n]
    elseif not pinned and saved.pair[n] then
	aid = saved.pair[n]
	local skillType, skillLineIndex, skillIndex = GetSpecificSkillAbilityKeysByAbilityId(aid)
	SlotSkillAbilityInSlot(skillType, skillLineIndex, skillIndex, slotn)
    end
    if not aid then
	df("reslot: want rapid = %s, called with no saved aid", tostring(rapidify))
    else
	df("reslot: want rapid = %s, cur %s, saved %s", tostring(rapidify), GetAbilityName(GetSlotBoundId(slotn)), GetAbilityName(aid))
    end
    return
end

local function onmount(x, mounted)
    local rapid, aid = israpid()
    rearm('onmount', false)
    if mounted and rapid then
	df("onmount(%s): returning because already mounted and rapid", x)
	return
    end
    local r
    df("onmount(%s): calling reslot(%s)", x, tostring(mounted))
    reslot(mounted)
end

local armed = false
rearm = function(x, doit)
    df("rearm: %s: %s", x, tostring(doit))
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
-- d(string.format("wp %d, mounted %s, slot %d, slotn %d, saved.pair[n] %s", n, tostring(IsMounted()), slot, slotn, tostring(saved.pair[n])))
    if slot == slotn and IsMounted() and israpid() then
	reslot(false)
	rearm('ability_used', true)
    end
end

local function onslot(x, slot)
    local n = GetActiveWeaponPairInfo()
    if not saved.pair[n] or IsMounted() or pinned then
	return
    end
    if israpid() then
	reslot(false)	-- turn it off
    elseif saved.pair[n] then
	saved.pair[n] = nil
    end
end

local function keydown()
    pinned = not israpid()
    df("keydown: pinning = %s", tostring(pinned))
    onmount('key', pinned)
end

local function onloaded(_, addon_name)
    if addon_name ~= name then
	return
    end
    df = emptyfunc
    KeyDown = keydown
    saved = ZO_SavedVars:NewAccountWide(name .. 'Saved', settings_version, nil, saved)
    slotn = saved.slot + 2
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
	    df = orig_df
	else
	    df = emptyfunc
	end
	d("rapper debugging: " .. tostring(df == orig_df))
    end
end

EVENT_MANAGER:RegisterForEvent(name, EVENT_ADD_ON_LOADED, onloaded)
