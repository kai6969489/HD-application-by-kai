local Data = {}

Data.Objects = {
	
	Brick = {
		ImageID = 119927858691427,
		Price = 100
	},
	
	Wood = {
		ImageID = 102419410921260,
		Price = 50
	},
	
	Ice = {
		ImageID = 128689214655358,
		Price = 20
	}	
}

function Data.GetObjectData(objectName : string)
	return Data.Objects[objectName]
end

return Data
