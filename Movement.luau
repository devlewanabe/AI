--!strict

local PathfindingService = game:GetService("PathfindingService")
local Perception = require(script.Parent.Perception)

type EnemyAI = any

local Movement = {}

local WAYPOINT_REACH_RADIUS = 4 -- studs at which a waypoint from the path is considered to have been reached
local STUCK_TIMEOUT = 1.5 -- seconds the AI will attempt to move to the next waypoint before checking if it got stuck
local STUCK_DISTANCE_THRESHOLD = 0.5 -- studs per frame the enemy moves to be considered unstuck
local DROP_DOWN_THRESHOLD = 5 -- vertical distance to determine a jump waypoint will drop down the enemy, in which case the jump is treated differently

-- returns the horizontal distance between 2 points in an XZ plane
function Movement.horizontalDistance(pos1: Vector3, pos2: Vector3): number
	return (Vector3.new(pos1.X, 0, pos1.Z) - Vector3.new(pos2.X, 0, pos2.Z)).Magnitude
end

function Movement.followSafePath(ai: EnemyAI, initialPos: Vector3, finalPos: Vector3): Vector3
	local dir = (finalPos - initialPos).Unit
	local distance = (finalPos - initialPos).Magnitude
	-- cast ray to scan for obstacles
	local origin = initialPos + Vector3.new(0, 2, 0)
	
	local params = RaycastParams.new()
	
	params.FilterDescendantsInstances = {ai.npc}
	params.FilterType = Enum.RaycastFilterType.Exclude
	
	local result = workspace:Raycast(origin, dir * distance, params)
	local d_buffer = 2
	
	if result then
		local heightDiff = math.abs(result.Position.Y - initialPos.Y)
		-- adjust buffer based on height difference
		if heightDiff > 1 then
			d_buffer += 1
		end
		
		-- adjust enemy distance from the obstacle as a safe spot
		local safePos = result.Position - dir * d_buffer
		
		-- ensure the safe position is above the ground and adjust if not
		local lower = workspace:Raycast(safePos, Vector3.new(0, -10, 0), params)
		
		if not lower then
			local lateral = Vector3.new(-dir.Z, 0, dir.X)
			safePos = safePos + lateral * 3
		end
		
		return safePos
	else
		return finalPos
	end
end

function Movement.traverse(ai: EnemyAI, waypoints: {PathWaypoint}): string
	for i, waypoint in ipairs(waypoints) do
		
		if ai.humanoid.Health <= 0 or (ai.state ~= "patrol" and ai.state ~= "chase") then
			return "Interrupted"
		end

		local nextWaypoint = waypoints[i + 1]
		local isDropDown = false

		if waypoint.Action == Enum.PathWaypointAction.Jump and nextWaypoint then
			if waypoint.Position.Y > nextWaypoint.Position.Y + DROP_DOWN_THRESHOLD then
				isDropDown = true
			end
		end

		if isDropDown then
			-- directly move to the dropdown waypoint, helps prevent unexpected behavior
			ai.humanoid:MoveTo(nextWaypoint.Position)
		else
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				if time() - ai.lastJumpTime > ai.config.jumpDelay then
					ai.lastJumpTime = time()
					ai.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end
			local safeMovePosition = Movement.followSafePath(ai, ai.rootPart.Position, waypoint.Position)
			ai.humanoid:MoveTo(safeMovePosition)
		end

		local timeout = 0
		local lastPos = ai.rootPart.Position
		local stuckTime = 0

		local targetPoint = isDropDown and nextWaypoint.Position or waypoint.Position

		-- enemy reaches the waypoint or got stuck
		while Movement.horizontalDistance(ai.rootPart.Position, targetPoint) > WAYPOINT_REACH_RADIUS and timeout < STUCK_TIMEOUT do
			local dt = task.wait()
			timeout += dt

			if (ai.rootPart.Position - lastPos).Magnitude < STUCK_DISTANCE_THRESHOLD then
				stuckTime += dt
				if stuckTime > 0.75 then
					return "Stuck"
				end
			else
				stuckTime = 0
				lastPos = ai.rootPart.Position
			end

			local target, _ = Perception.trackPlayer(ai)
			
			if target then
				ai:setEnemyState("chase")
				return "Interrupted"
			end
			
			if ai.state ~= "patrol" and ai.state ~= "chase" then return "Interrupted" end
		end

		if isDropDown then end
	end
	return "Completed"
end

function Movement.moveToPosition(ai: EnemyAI, destination: Vector3)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})
	
	path:ComputeAsync(ai.rootPart.Position, destination)

	if path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		if #waypoints > 0 then
			Movement.traverse(ai, waypoints)
		end
	end
end

return Movement
