--!strict

--[[

	- searchRadius: maximum distance  enemy checks for targets
	- maxChaseDistance: maximum distance enemy chases a target[will stop once exceeded]
	- patrolRadius: maximum radius the npc will patrol around its current position
	- minDistance: minimum patrol distance, tune as needed to prevent tiny movements
	- targetRange: how far away from the target the enemy stops chasing
	
	- COOLDOWN_TIME: general debounce period between selected actions
	- USE_FOV: whether the enemy uses eye vision or circular radius to detect targets
	- HORIZONTAL_FOV: horizontal field of view in degrees[how wide the vision of the enemy is]
	- VERTICAL_FOV: vertical field of view in degrees[how long the vision is on the Y axis, prevents players from disappearing if they climb somewhere]
	- EYE_OFFSET: mainly Y-tuned to make the field of view start from around the head
	
	- CIRCULAR_CHECK_RADIUS: triggered when the target is close to the enemy but suddenly disappears from its FOV[like jumping above it]
	- CIRCULAR_CHECK_DURATION: if the above happened, for how long to check on the circular radius to find the target before changing its state
	
	- jumpDelay: minimum time between jumps to prevent spam jumping
	- chaseUpdateDelay: delay between frequency of path recalculation
	- predictionTime: seconds into the future the AI detects movement to predict the next path, keep high to make escaping difficult

]]

export type AIConfig = {
	searchRadius: number,
	maxChaseDistance: number,
	patrolRadius: number,
	minDistance: number,
	targetRange: number,
	
	COOLDOWN_TIME: number,
	USE_FOV: boolean,
	HORIZONTAL_FOV: number,
	VERTICAL_FOV: number,
	EYE_OFFSET: Vector3,

	CIRCULAR_CHECK_RADIUS: number,
	CIRCULAR_CHECK_DURATION: number,

	jumpDelay: number,
	chaseUpdateDelay: number,
	predictionTime: number,
}

local Defaults: AIConfig = {
	searchRadius = 75,
	maxChaseDistance = 45,
	patrolRadius = 30,
	minDistance = 15,
	targetRange = 1,
	
	COOLDOWN_TIME = 0,
	USE_FOV = true,
	HORIZONTAL_FOV = 130,
	VERTICAL_FOV = 90,
	EYE_OFFSET = Vector3.new(0, 3, 0),

	CIRCULAR_CHECK_RADIUS = 15,
	CIRCULAR_CHECK_DURATION = 5.25,

	jumpDelay = 0.5,
	chaseUpdateDelay = 0.2,
	predictionTime = 0.8,
}

return Defaults
