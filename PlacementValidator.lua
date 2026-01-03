local PlacementValidator = {}

function PlacementValidator.WithinBounds(plot : Model , objectSize : Vector3 , worldCF : CFrame) : boolean
	local plotCF , plotSize = plot:GetBoundingBox()
	local objectCF = plotCF:ToObjectSpace(worldCF)
	

	--create corners in X/Z
	--corner coordinates are generated using:
	--(-1,  1), ( 1, -1), ( 1,  1), (-1, -1)
	local cornerpoints = {}
	for _ , x in pairs({-1, 1}) do
		for _ , z in pairs({-1 , 1}) do
			table.insert(cornerpoints , objectCF:PointToWorldSpace(Vector3.new(x * objectSize.X / 2 , 0 , z * objectSize.Z / 2))) 
			-- Convert the local corner into plot-local space
			-- then insert each corner in cornerpoints table
		end
	end
	
	for _ , point : Vector3 in cornerpoints do
		if math.abs(point.X) > plotSize.X / 2 or math.abs(point.Z) > plotSize.Z / 2 then
			return false
			--check each corner point against the plot bounds
			--If ANY corner is outside the plot, placement is invalid
		end
	end
	return true -- ALL corners inside plot so placement is valid
	
end

function PlacementValidator.IntersectingObject(plot : Model , objectSize : Vector3 , worldCF : CFrame) : boolean
	local params = OverlapParams.new()
	params:AddToFilter(plot.Objects)-- folder
	params.FilterType = Enum.RaycastFilterType.Include
	-- ONLY considers object in Objects folder to be intersecting

	local overlappingPart : {Instance} = workspace:GetPartBoundsInBox(worldCF , objectSize , params) -- creates a box surrounding object
	
	if #overlappingPart > 0 then -- if another object is inside the box then its intersecting
		return true , overlappingPart[1]
	else
		return false
	end
end

return PlacementValidator
