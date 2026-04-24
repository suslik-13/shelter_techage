
-- Lava Slimes by TomasJLuis & TenPlus1

local S = minetest.get_translator("mobs_slimes")

-- sounds

local lava_sounds = {
	damage = "slimes_damage",
	death = "slimes_death",
	jump = "slimes_jump",
	attack = "slimes_attack"
}

-- lava slime textures

local lava_textures = {
	"lava_slime_sides.png", "lava_slime_sides.png", "lava_slime_sides.png",
	"lava_slime_sides.png", "lava_slime_front.png", "lava_slime_sides.png"
}

-- choose spawn medium depending on [game]

local nod_lava_source = "default:lava_source"
local nod_lava_flow = "default:lava_flowing"

if minetest.get_modpath("mcl_core") then
	nod_lava_source = "mcl_core:lava_source"
	nod_lava_flow = "mcl_core:lava_flowing"
end

-- small lava slime

mobs:register_mob("mobs_slimes:lavasmall", {
	type = "monster",
	hp_min = 1, hp_max = 2,
	collisionbox = {-0.25, -0.25, -0.25, 0.25, 0.25, 0.25},
	visual = "cube",
	visual_size = {x = 0.5, y = 0.5},
	textures = { lava_textures },
	blood_texture = "lava_slime_blood.png",
	makes_footstep_sound = false,
	sounds = lava_sounds,
	attack_type = "dogfight",
	attacks_monsters = true,
	damage = 1,
	passive = false,
	walk_velocity = 2,
	run_velocity = 2,
	walk_chance = 0,
	jump_chance = 30,
	jump_height = 6,
	armor = 90,
	view_range = 15,
	drops = {
		{name = "tnt:gunpowder", chance = 4, min = 1, max = 2},
	},
	drawtype = "front",
	water_damage = 10,
	lava_damage = 0,
	light_damage = 0,
	replace_rate = 20,
	replace_what = {"air"},
	replace_with = "fire:basic_flame",
	fly_in = {nod_lava_source, nod_lava_flow},
	glow = 10
})

-- medium lava slime

mobs:register_mob("mobs_slimes:lavamedium", {
	type = "monster",
	hp_min = 3, hp_max = 4,
	collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
	visual = "cube",
	visual_size = {x = 1, y = 1},
	textures = { lava_textures },
	blood_texture = "lava_slime_blood.png",
	makes_footstep_sound = false,
	sounds = lava_sounds,
	attack_type = "dogfight",
	attacks_monsters = true,
	damage = 2,
	passive = false,
	walk_velocity = 2,
	run_velocity = 2,
	walk_chance = 0,
	jump_chance = 30,
	jump_height = 6,
	armor = 90,
	view_range = 15,
	drawtype = "front",
	water_damage = 10,
	lava_damage = 0,
	light_damage = 0,
	replace_rate = 20,
	replace_what = {"air"},
	replace_with = "fire:basic_flame",
	fly_in = {nod_lava_source, nod_lava_flow},
	glow = 10,

	on_die = function(self, pos)

		local num = math.random(2, 4)

		for i = 1, num do

			minetest.add_entity({
				x = pos.x + math.random(-2, 2),
				y = pos.y + 1,
				z = pos.z + (math.random(-2, 2))
			}, "mobs_slimes:lavasmall")
		end
	end
})

-- big lava slime

mobs:register_mob("mobs_slimes:lavabig", {
	type = "monster",
	hp_min = 5, hp_max = 6,
	collisionbox = {-1, -1, -1, 1, 1, 1},
	visual = "cube",
	visual_size = {x = 2, y = 2},
	textures = { lava_textures },
	blood_texture = "lava_slime_blood.png",
	makes_footstep_sound = false,
	sounds = lava_sounds,
	attack_type = "dogfight",
	attacks_monsters = true,
	damage = 3,
	passive = false,
	walk_velocity = 2,
	run_velocity = 2,
	walk_chance = 0,
	jump_chance = 30,
	jump_height = 6,
	armor = 90,
	view_range = 15,
	drawtype = "front",
	water_damage = 10,
	lava_damage = 0,
	light_damage = 0,
	replace_rate = 20,
	replace_what = {"air"},
	replace_with = "fire:basic_flame",
	replace_offset = -1,
	fly_in = {nod_lava_source, nod_lava_flow},
	glow = 10,

	on_die = function(self, pos)

		local num = math.random(1, 2)

		for i = 1, num do

			minetest.add_entity({
				x = pos.x + math.random(-2, 2),
				y = pos.y + 1,
				z = pos.z + (math.random(-2, 2))
			}, "slimes:lavamedium")
		end
	end,
})

-- spawn eggs

mobs:register_egg("mobs_slimes:lavasmall", S("Small Lava Slime"), "lava_slime_egg.png", 1)
mobs:register_egg("mobs_slimes:lavamedium", S("Medium Lava Slime"), "lava_slime_egg.png", 1)
mobs:register_egg("mobs_slimes:lavabig", S("Big Lava Slime"), "lava_slime_egg.png", 1)

-- spawn in world

mobs:spawn({
	name = "mobs_slimes:lavasmall",
	nodes = {nod_lava_source},
	neighbors = {nod_lava_flow},
	min_light = 4,
	chance = 5000,
	max_height = -64,
	active_object_count = 8
})

mobs:spawn({
	name = "mobs_slimes:lavamedium",
	nodes = {nod_lava_source},
	neighbors = {nod_lava_flow},
	min_light = 4,
	chance = 10000,
	max_height = -64,
	active_object_count = 8
})

mobs:spawn({
	name = "mobs_slimes:lavabig",
	nodes = {nod_lava_source},
	neighbors = {nod_lava_flow},
	min_light = 4,
	chance = 15000,
	max_height = -64,
	active_object_count = 8
})

-- compatibility

mobs:alias_mob("slimes:lavasmall", "mobs_slimes:lavasmall")
mobs:alias_mob("slimes:lavamedium", "mobs_slimes:lavamedium")
mobs:alias_mob("slimes:lavabig", "mobs_slimes:lavabig")
