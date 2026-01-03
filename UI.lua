return function()
	for _ , module : ModuleScript in script:GetDescendants() do
		if not module:IsA("ModuleScript") then
			continue
			
		end
		
		local feature = require(module)
		if type(feature) == "table" and feature.Init then
		feature.Init()
		end
	end
end
