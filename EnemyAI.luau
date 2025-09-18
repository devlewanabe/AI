--!strict

local ConfigDefaults = require(script.Parent.AIConfig)
local Perception = require(script.Parent.Perception)
local Movement = require(script.Parent.Movement)

local PathfindingService = game:GetService("PathfindingService")

type AIConfig = ConfigDefaults.AIConfig
type State = "idle" | "patrol" | "chase"

export type EnemyAI = {
	npc: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	config: AIConfig,

	state: State,
	active: boolean,
	lastPatrolAngle: number,
	lastJumpTime: number,

	connections: {[string]: RBXScriptConnection},

	setEnemyState: (self: EnemyAI, newState: State) -> (),
	startPatrolling: (self: EnemyAI) -> (),
	stateChase: (self: EnemyAI, target: Player) -> (),
	start: (self: EnemyAI) -> (),
	stop: (self: EnemyAI) -> (),
}

type EnemyAIClass = {
	__index: EnemyAI,
	new: (npc: Model, config: {[string]: any}?) -> EnemyAI
} & EnemyAI

local EnemyAI: EnemyAIClass = {} :: any
EnemyAI.__index = EnemyAI

function EnemyAI.new(npc: Model, config: {[string]: any}?): EnemyAI
	local self: EnemyAI = {} :: any
	setmetatable(self, EnemyAI)

	self.npc = npc
	self.humanoid = npc:WaitForChild("Humanoid") :: Humanoid
	self.rootPart = npc:WaitForChild("HumanoidRootPart") :: BasePart

	-- merge
	local finalConfig = table.clone(ConfigDefaults)
	if config then
		for key, value in pairs(config) do
			(finalConfig :: any)[key] = value
		end
	end
	self.config = finalConfig

	self.state = "idle"
	self.active = true
	self.lastPatrolAngle = math.random() * 2 * math.pi
	self.lastJumpTime = 0
	self.connections = {}

	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetNetworkOwner()
		end
	end

	return self
end

function EnemyAI:setEnemyState(newState: State)
	self.state = newState
end

function EnemyAI:startPatrolling()
	self:setEnemyState("patrol")
	local currentPos = self.rootPart.Position
	local angOffset = math.rad(math.random(45, 135))
	local newAngle = self.lastPatrolAngle + angOffset
	self.lastPatrolAngle = newAngle
	local distance = math.random(self.config.minDistance, self.config.patrolRadius)
	-- position + (cos(θ)*r, 0, sin(θ)*r) => position + <x, 0, z>
	local point = currentPos + Vector3.new(math.cos(newAngle) * distance, 0, math.sin(newAngle) * distance)

	Movement.moveToPosition(self, point)

	local pause = math.random(2, 4)
	local elapsed = 0
	while elapsed < pause do
		local dt = task.wait()
		elapsed += dt
		local target, _ = Perception.trackPlayer(self)
		if target then
			self:setEnemyState("chase") -- begin chasing immediately once a target has been spotted
			return
		end
	end
end

function EnemyAI:stateChase(target: Player)
	self:setEnemyState("chase")
	local lastSeen = time()

	local initialHRP = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not initialHRP then return end
	
	-- store target's position to activate radius check if it suddenly disappears
	local lastKnownPos: Vector3 = (initialHRP :: BasePart).Position

	while self.state == "chase" and target.Character and self.humanoid.Health > 0 do
		local current = time()
		if current - lastSeen > self.config.CIRCULAR_CHECK_DURATION then break end

		local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
		if not targetHRP then break end

		local targetPos = (targetHRP :: BasePart).Position
		local distance = Movement.horizontalDistance(self.rootPart.Position, targetPos)
		local targetVelocity = (targetHRP :: BasePart).AssemblyLinearVelocity
		local predictedPos = targetPos + targetVelocity * self.config.predictionTime -- linear motion

		local isVisible = Perception.canSeePlayer(self, target.Character)
		if isVisible and distance <= self.config.maxChaseDistance then
			lastKnownPos = predictedPos
			lastSeen = current
		elseif not isVisible and distance <= self.config.CIRCULAR_CHECK_RADIUS then -- still in radius but temporarily out of sight
			lastKnownPos = predictedPos
		end

		if Movement.horizontalDistance(self.rootPart.Position, lastKnownPos) <= self.config.targetRange then
			self.humanoid:MoveTo(self.rootPart.Position)
			task.wait(self.config.chaseUpdateDelay)
			continue
		end

		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		path:ComputeAsync(self.rootPart.Position, lastKnownPos)

		if path.Status == Enum.PathStatus.Success then
			local waypoints = path:GetWaypoints()
			if #waypoints > 1 then -- path exists
				local traversalResult = Movement.traverse(self, waypoints)
			else
				task.wait(self.config.chaseUpdateDelay)
			end
		else
			task.wait(self.config.chaseUpdateDelay) -- if pathfinding fails, wait before recalculating
		end
	end

	if self.state == "chase" then
		self:setEnemyState("patrol")
	end
end

function EnemyAI:start()
	self.active = true
	task.spawn(function()
		while self.active and self.humanoid.Health > 0 do
			local target, _ = Perception.trackPlayer(self) -- only the player is needed currently
			if target then
				self:stateChase(target)
			else
				self:startPatrolling()
			end
			task.wait(0.05)
		end
	end)
end

function EnemyAI:stop()
	self.active = false
	-- cleanup
	for _, conn in pairs(self.connections) do
		conn:Disconnect()
	end
	self.connections = {}
end

return EnemyAI
