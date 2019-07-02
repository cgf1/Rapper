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
local try_reset

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

local function tick(what)
    if ticking == what then
        return
    end
    if what then
        EVENT_MANAGER:RegisterForUpdate(name, 1000, function() try_reset('updating') end)
    else
	EVENT_MANAGER:UnregisterForUpdate(name)
    end
    ticking = what
end

try_reset = function(x)
    local rapid, aid = israpid()
df("try_reset: %s", tostring(x))
    if not IsMounted() then
	for n in pairs(saved.pair) do
	    reset_slot('try_reset', n)
	end
    elseif ticking and not israpid() then
	local n = GetActiveWeaponPairInfo()
	saved.pair[n] = nil
    end
    if ticking and not saved.pair[1] and not saved.pair[2] then
	tick(false)
    end
end

local function slotit(aid)
    local skillType, skillLineIndex, skillIndex = GetSpecificSkillAbilityKeysByAbilityId(aid)
    SlotSkillAbilityInSlot(skillType, skillLineIndex, skillIndex, slotn)
df("slotit %d == %d: %s", GetSlotBoundId(slotn), aid, tostring(GetSlotBoundId(slotn) == aid))
    return GetSlotBoundId(slotn) == aid
end

reset_slot = function(x, n)
    local aid = saved.pair[n]
    if not aid or n ~= GetActiveWeaponPairInfo() then
	return
    end
    local rapid, aidr = israpid()
df("%s: resetting rapid, was rapid = %s, current skill = %s, want skill = %s", x, tostring(rapid), GetAbilityName(aidr), GetAbilityName(aid))
    if not israpid() then
	saved.pair[n] = nil
    else
	slotit(aid)
        tick(true)
    end
    rearm('reset_slot', false)
end

local function onmount(_, mounted)
    local rapid, aid = israpid()
    rearm('onmount', false)
    if mounted and rapid then
	return
    end
    local n = GetActiveWeaponPairInfo()
    if not mounted and not rapid then
	saved.pair[n] = nil
	return
    end
    if not mounted then
	reset_slot('onmount', n)
    else
	saved.pair[n] = aid
	SlotSkillAbilityInSlot(6, 1, 2, slotn)
    end
end

local armed
rearm = function(x, n)
df("rearm: %s: %s", x, tostring(n))
    if armed then
	EVENT_MANAGER:UnregisterForUpdate(nameCL)
	armed = false
    end
    if n == false then
	-- nothing to do
    elseif tonumber(n) then
	EVENT_MANAGER:RegisterForUpdate(nameCL, n, call(rearm, 'update event'))
	armed = true
    elseif IsMounted() then
	onmount(_, true)
    elseif israpid() then
	onmount(_, false)
    end
end

local function ability_used(x, slot)
    local n = GetActiveWeaponPairInfo()
-- d(string.format("wp %d, mounted %s, slot %d, slotn %d, saved.pair[n] %s", n, tostring(IsMounted()), slot, slotn, tostring(saved.pair[n])))
    if IsMounted() and slot == slotn and saved.pair[n] then
	reset_slot('ability_used', n)
	rearm('ability_used', saved.duration)
    end
end

local function onslot(x, slot)
    if slot == slotn then
        local n = GetActiveWeaponPairInfo()
        local name
        if saved.pair[n] then
            name = GetAbilityName(saved.pair[n])
        else
            name = 'nil'
        end

        df("%s: slot changed %d - %s, saved: %s", x, slot, GetAbilityName(GetSlotBoundId(slot)), name)
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
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_COMBAT_STATE, call(try_reset, 'combat state'))
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, call(try_reset, 'weapon pair changed'))
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
