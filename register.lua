local interface = {};
local registered = {};

-- assumes only passed positive-or-zero integral values for level - checked by register_node()
local get_block_name = function(modname, nodename, level)
	local sep="__"
	return minetest.get_current_modname()..":compressed_lvl"..level..sep..modname..sep..nodename
end

local get_overlay_texture_name = function(depth)
	return "compressed_blocks_lvl"..depth..".png"
end

local fullname = function(modname, nodename) return modname..":"..nodename end

local get_description = function(basedesc, depth)
	return "Compressed "..basedesc.." (level "..depth..")"
end

local get_texture_modifier = function(texturename, depth)
	if depth > 8 then error("cannot generate texture for >8 levels") end
	return "("..texturename..")^"..get_overlay_texture_name(depth)
end

local helperlib_create_table_repeat = function(value, count)
	local ret = {}
	-- argh, 1-indexed arrays...
	for index = 1, count do
		ret[index] = value
	end
	return ret
end

-- this object might be moved in future, say to external mods.
local recipe_register_impl = function(input, output)
	local count = 8
	minetest.register_craft({
		output = output,
		type = "shapeless",
		recipe = helperlib_create_table_repeat(input, count)
	})
	minetest.register_craft({
		output = input.." "..tostring(count),
		type = "shapeless",
		recipe = { output }
	})
end

local register_node_at_depth = function(modname, nodename, description, basetiles, level, blockgroups)
	local targetname = get_block_name(modname, nodename, level)
	-- we could probably do something more sophisticated here in future.
	-- for now, just make everything stonelike.
	local groups_default = { cracky=1, stone=1 }
	local groups = nil
	if (blockgroups) then groups = nil else groups = groups_default end

	local sounds = default.node_sound_stone_defaults()

	-- FIXME: do something more sophisticated, like get the actual name?
	local description_text=get_description(description, level)

	local tiles = {}
	for key, value in pairs(basetiles) do
		tiles[key] = get_texture_modifier(value, level)
	end

	minetest.register_node(targetname, {
		description=description_text,
		tiles = tiles,
		groups = groups,
		sounds = sounds
	})

	-- calculate recipes.
	-- lvl1 is crafted from the uncompressed, normal node.
	-- note that this requires this function to be called in increasing depth order.
	local recipe_output = targetname
	local recipe_input = nil
	if level == 1 then
		recipe_input = fullname(modname, nodename)
	else
		recipe_input = get_block_name(modname, nodename, level-1)
	end
	recipe_register_impl(recipe_input, recipe_output)
end

local register_node_checked = function(modname, nodename, depth, blockgroups)
	-- try to retrieve details about the node only once
	local targetnode = fullname(modname, nodename)
	local nodeinfo = minetest.registered_nodes[targetnode]
	if nodeinfo == nil then error("Requested node "..targetnode.." doesn't exist") end

	local description = nodeinfo.description
	if description == nil then description = targetnode end

	local basetiles = nodeinfo.tiles

	for level = 1, depth do
		--minetest.log("registering compressed block for "..targetnode.." at depth "..level)
		register_node_at_depth(modname, nodename, description, basetiles, level, blockgroups)
	end

	registered[fullname] = depth
end;

interface.register_node = function(modname, nodename, depth, blockgroups)
	local tm = type(modname)
	local tn = type(nodename)
	local td = type(depth)
	local tb = type(blockgroups)
	local tsep = "/"

	if (tm == "string")
		and (tn == "string")
		and (td == "number")
		and ((tb == "table") or (tb == "nil"))
	then
		if (depth % 1.0) ~= 0.0 then
			error("compression depth must be an integral value")
		end
		if (depth < 1) then
			error("compression depth must be at least 1")
		end

		register_node_checked(modname, nodename, depth, blockgroups)
	else
		error("incorrect parameter types (got "..tm..tsep..tn..tsep..td..tsep..tb..")")
	end
end

interface.visit_registered = function(f)
	if type(f) ~= "function" then error("visitor must be a function") end
	for key, value in pairs(registered) do
		-- allow early stop if the visitor doesn't want any more info.
		if not f(key, value) then return end
	end
end

return interface
