
local Types = {}

export type stack = {
	Name : string,
	Amount : number ,
	Image : string,
}

export type inventory = {
	Inventory : {stack},
}

return Types
