-- This mutates all recipes with a single intermediate-product output
-- by adding a chance to create a defective version of the product instead.
-- Also adds new technologies and recipes for recycling defective products.

local simple_defect_rate = settings.startup["defective-defect-rate-simple"].value
local advanced_defect_rate = settings.startup["defective-defect-rate-advanced"].value
local complex_defect_rate = settings.startup["defective-defect-rate-complex"].value

local function get_defect_name(item)
	return "defective-" .. item.name
end

local function add_defect_to_recipe(recipe_data, defect, rate)
	recipe_data.results = {
		{
			type="item",
			name=recipe_data.result,
			amount=recipe_data.result_count or 1,
			probability=1-rate
		}, {
			type="item",
			name=defect.name,
			amount=recipe_data.result_count or 1,
			probability=rate
		}
	}
	recipe_data.main_product = recipe_data.result
	recipe_data.result = nil
	recipe_data.result_count = nil
end

local function create_defective_item(item)
	local defect = table.deepcopy(item)
	defect.name = get_defect_name(item)
	if item.order then defect.order = item.order .. "-defective" end
	-- TODO: tint icon or add overlay icon
	-- TODO: localized name
	data:extend({defect})
	return defect
end

local function is_simple(recipe)
	return true
end

local function is_advanced(recipe)
	return #(recipe.ingredients) > 1
end

local function is_complex(recipe)
	return recipe.category == "crafting-with-fluid"
end

local function result_can_be_defective(recipe_data)
	if not recipe_data.result then return false end
	local item = data.raw["item"][recipe_data.result]
	if not item then
		-- Exclude all extensions of "item"
		return false
	end
	if item.place_as_tile or
		item.place_result or
		item.placed_as_equipment_result or
		(item.wire_count and item.wire_count > 0) or
		item.fuel_value
	then
		-- Exclude final products
		-- Exclude wires
		-- Exclude fuels
		return false
	end
	-- Allow the rest
	return true
end

local function recipe_can_be_defective(recipe)
	if recipe.category == "smelting" then
		-- Exclude smelting recipes for raw plates
		return false
	end
	-- Allow the rest
	return true
end

local function process_recipe_data(recipe, recipe_data)
	if not result_can_be_defective(recipe_data) then
		return 
	end

	local rate = 0
	if is_complex(recipe) then
		rate = complex_defect_rate
	elseif is_advanced(recipe_data) then
		rate = advanced_defect_rate
	elseif is_simple(recipe_data) then
		rate = simple_defect_rate
	end

	if rate > 0 and rate < 100 then
		local item = data.raw["item"][recipe_data.result]
		local defect = data.raw["item"][get_defect_name(item)] or create_defective_item(item)
		add_defect_to_recipe(recipe_data, defect, rate)
	end
end

local function process_recipe(recipe)
	if not recipe_can_be_defective(recipe) then
		return
	end

	process_recipe_data(recipe, recipe)
	if recipe.normal then process_recipe_data(recipe, recipe.normal) end
	if recipe.expensive then process_recipe_data(recipe, recipe.expensive) end
end

local function process_recipes(recipes)
	for name,recipe in pairs(recipes) do
		process_recipe(recipe)
	end
end

process_recipes(data.raw['recipe'])
