--!strict

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local EnemyAI = require(ServerScriptService.AI.EnemyAI)
type EnemyAI = EnemyAI.EnemyAI

local Tag = "Enemy"
local active: { [Instance]: EnemyAI } = {}

--[[

	- Optional: Define custom configs for specific types by their model name
	
	local customConfigs = 
	{
    	["Scout"] = { searchRadius = 150, patrolRadius = 50 },
	}
	
]]

local function setupAI(npc: Instance)
	if not npc:IsA("Model") then return end
	if active[npc] then return end

	-- local config = customConfigs[npc.Name] 
	local distance = EnemyAI.new(npc, nil) -- Pass 'config' if using custom configs
	active[npc] = distance
	distance:start()

	print(`AI Initialized for: {npc:GetFullName()}`)
end

local function cleanupAI(npc: Instance)
	local distance = active[npc]
	if distance then
		distance:stop()
		active[npc] = nil
		print(`AI Cleaned up for: {npc:GetFullName()}`)
	end
end

for _, npc in ipairs(CollectionService:GetTagged(Tag)) do
	task.spawn(setupAI, npc)
end

CollectionService:GetInstanceAddedSignal(Tag):Connect(setupAI)
CollectionService:GetInstanceRemovedSignal(Tag):Connect(cleanupAI)
