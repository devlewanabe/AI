--!strict

local Players = game:GetService("Players")

type EnemyAI = any

local Perception = {}

function Perception.horizontalDetection(ai: EnemyAI, targetPos: Vector3): boolean
	local npcPosition = ai.rootPart.Position
	local targetDir = targetPos - npcPosition
	local horizontalDir = Vector3.new(targetDir.X, 0, targetDir.Z).Unit
	
	local npcForward = Vector3.new(ai.rootPart.CFrame.LookVector.X, 0, ai.rootPart.CFrame.LookVector.Z).Unit
	-- check if a target is within the horizontal FOV
	local dot = npcForward:Dot(horizontalDir)
	-- cos(θ/2) means within FOV cone
	local threshold = math.cos(math.rad(ai.config.HORIZONTAL_FOV / 2))
	
	return dot >= threshold
end

function Perception.verticalDetection(ai: EnemyAI, targetPos: Vector3): boolean
	local npcPosition = ai.rootPart.Position
	local targetDir = targetPos - npcPosition
	local horizontalMag = Vector3.new(targetDir.X, 0, targetDir.Z).Magnitude
	
	if horizontalMag == 0 then return true end
	
	--[[
		- atan2(Dy, X) = θrad
		- |deg(θ)| < vertical/2 <=> dot >= thr
	]]
	local vertical = math.deg(math.atan2(targetDir.Y, horizontalMag))
	return math.abs(vertical) <= (ai.config.VERTICAL_FOV / 2)
end

function Perception.checkFOV(ai: EnemyAI, targetPos: Vector3): boolean
	if not ai.config.USE_FOV then return true end
	return Perception.horizontalDetection(ai, targetPos) and Perception.verticalDetection(ai, targetPos)
end

function Perception.canSeePlayer(ai: EnemyAI, targetCharacter: Model): boolean
	local headInst = targetCharacter:FindFirstChild("Head")
	if not headInst or not headInst:IsA("BasePart") then
		return false
	end
	local head = headInst :: BasePart

	local origin = ai.rootPart.Position + ai.config.EYE_OFFSET
	local direction = head.Position - origin

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {ai.npc} -- ignore self
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(origin, direction, rayParams)
	return result == nil or (result.Instance and result.Instance:IsDescendantOf(targetCharacter))
end

function Perception.trackPlayer(ai: EnemyAI): (Player?, number)
	local nearestPlayer: Player? = nil
	local nearestDistance = ai.config.searchRadius

	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if not char then continue end

		local hrp = char:FindFirstChild("HumanoidRootPart")

		if hrp and hrp:IsA("BasePart") and char:FindFirstChild("Head") then
			local targetPos = hrp.Position
			local dist = (ai.rootPart.Position - targetPos).Magnitude

			if dist < nearestDistance and Perception.checkFOV(ai, targetPos) and Perception.canSeePlayer(ai, char) then
				nearestDistance = dist
				nearestPlayer = plr
			end
		end
	end
	return nearestPlayer, nearestDistance
end

return Perception
