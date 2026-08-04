extends Control

@export var Player: Node2D
@export var Render: Node

@onready var label: Label = $map_coords_text

var currentPlayerPosX: int
var currentPlayerPosY: int
var height_value = 0
var biome_value = 0
var chance_value = 0

func _process(delta: float) -> void:
	if Render == null:
		return
		
	# Получаем позицию из Render
	var base_tile_x = int(Player.global_position.x / Render.tile_size_x)
	var base_tile_y = int(Player.global_position.y / Render.tile_size_y)
	
	currentPlayerPosX = base_tile_x
	currentPlayerPosY = base_tile_y
	
	# Получаем значения из Worldgen
	if base_tile_x >= 0 and base_tile_x < Worldgen.height_map.size():
		if base_tile_y >= 0 and base_tile_y < Worldgen.height_map[base_tile_x].size():
			height_value = Worldgen.height_map[base_tile_x][base_tile_y]
			biome_value = Worldgen.biome_map[base_tile_x][base_tile_y]
			chance_value = Worldgen.chance_map[base_tile_x][base_tile_y]
	
	# Вариант 1: Получить Label как узел и привести к типу
	label.text = "X: " + str(currentPlayerPosX)+ " Y: " + str(currentPlayerPosY) + "\n" \
	+ "Height: " + str(height_value) + "\n" \
	+ "Biome: " + str(biome_value) + "\n" \
	+ "Chance: " + str(chance_value)
