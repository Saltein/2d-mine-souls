class_name Render
extends Node

@export var Player: Node2D
@export var camera: Node2D
@export var tile: PackedScene
@export var water_tile: PackedScene
@export var solid: PackedScene
@export var tree: PackedScene
@export var tile_size_x: int = 64
@export var tile_size_y: int = 48

var renderGrid = []
var renderGridSizeX: float = 36
var renderGridSizeY: float = 31

var playerPosRoundedX: float = 0
var playerPosRoundedY: float = 0

# Кеш созданных тайлов: ключ Vector2i(tile_x, tile_y) -> { "ground": узел, "water": узел или null }
var existing_tiles := {}

# Текстуры (preload для быстродействия)
var tex_water_bottom = preload("res://assets/tiles/water_bottom.png")
var tex_water = preload("res://assets/tiles/water.png")
var tex_grass = preload("res://assets/tiles/grass.png")
var tex_grass_wall = preload("res://assets/tiles/grass_wall.png")
var tex_humus = preload("res://assets/tiles/humus.png")
var tex_humus_wall = preload("res://assets/tiles/humus_wall.png")
var tex_sand = preload("res://assets/tiles/sand.png")
var tex_sand_wall = preload("res://assets/tiles/sand_wall.png")
var tex_snow = preload("res://assets/tiles/snow.png")
var tex_snow_wall = preload("res://assets/tiles/snow_wall.png")
var tex_steppe = preload("res://assets/tiles/steppe.png")
var tex_steppe_wall = preload("res://assets/tiles/steppe_wall.png")
var tex_meadow = preload("res://assets/tiles/meadow.png")
var tex_meadow_wall = preload("res://assets/tiles/meadow_wall.png")
var tex_rock= preload("res://assets/tiles/rock.png")
var tex_rock_wall = preload("res://assets/tiles/rock_wall.png")
var tex_tree = preload("res://assets/trees/tree.png")

var center_of_map_x = 0
var center_of_map_y = 0

func _ready() -> void:
	center_of_map_x = Worldgen.array_size/2*tile_size_x
	center_of_map_y = Worldgen.array_size/2*tile_size_y
	
	Player.global_position.x = center_of_map_x
	Player.global_position.y = center_of_map_y
	camera.global_position.x = center_of_map_x
	camera.global_position.y = center_of_map_y
	
	
	playerPosRoundedX = round(Player.global_position.x / tile_size_x) * tile_size_x
	playerPosRoundedY = round(Player.global_position.y / tile_size_y) * tile_size_y

	for x in range(renderGridSizeX):
		renderGrid.append([])
		for y in range(renderGridSizeY):
			renderGrid[x].append([x * tile_size_x, y * tile_size_y])

	if tile == null:
		print("Ошибка: tile не назначен в инспекторе!")
		return
	print("Тайл назначен")

	# Первичная отрисовка
	gridRefresh()

func _process(delta: float) -> void:
	var currentTileX = Player.global_position.x / tile_size_x - renderGridSizeX / 2
	var currentTileY = Player.global_position.y / tile_size_y - renderGridSizeY / 2

	var newRoundedX = round(currentTileX) * tile_size_x
	var newRoundedY = round(currentTileY) * tile_size_y

	if newRoundedX != playerPosRoundedX or newRoundedY != playerPosRoundedY:
		playerPosRoundedX = newRoundedX
		playerPosRoundedY = newRoundedY
		gridRefresh()

func is_valid_tile(tile_x: int, tile_y: int) -> bool:
	# Проверяем, что координаты тайла находятся в пределах массивов Worldgen
	if tile_x < 0 or tile_y < 0:
		return false
	if tile_x >= Worldgen.height_map.size():
		return false
	if tile_y >= Worldgen.height_map[0].size():
		return false
	return true

func gridRefresh() -> void:
	# Собираем множество ключей, которые должны быть видны
	var needed_keys := {}
	var base_tile_x = int(playerPosRoundedX / tile_size_x)
	var base_tile_y = int(playerPosRoundedY / tile_size_y)

	for x in range(renderGridSizeX):
		for y in range(renderGridSizeY):
			var tile_coord = Vector2i(base_tile_x + x, base_tile_y + y)
			
			# Пропускаем тайлы с отрицательными координатами или выходящие за пределы массива
			if not is_valid_tile(tile_coord.x, tile_coord.y):
				continue
				
			needed_keys[tile_coord] = true

			if not existing_tiles.has(tile_coord):
				# --- Создаём новый тайл ---
				# Мировые координаты для позиционирования
				var world_x = playerPosRoundedX + x * tile_size_x
				var world_y = playerPosRoundedY + y * tile_size_y

				var ground_node = tile.instantiate()
				var solid_node = solid.instantiate()
				var water_node = water_tile.instantiate()
				var tree_node = tree.instantiate()
				add_child(ground_node)
				add_child(solid_node)
				add_child(water_node)
				add_child(tree_node)
				
				var depth_value = Worldgen.height_map[tile_coord.x][tile_coord.y]
				var biome_value = Worldgen.biome_map[tile_coord.x][tile_coord.y]
				var chance_value = Worldgen.chance_map[tile_coord.x][tile_coord.y]
				if depth_value < 0.4:
					# Вода: дно + водная поверхность
					ground_node.get_child(0).get_child(0).texture = tex_water_bottom
					ground_node.global_position = Vector2(world_x, world_y + 64)
					ground_node.z_index = -2

					water_node.get_child(0).get_child(0).texture = tex_water
					water_node.global_position = Vector2(world_x, world_y + 24)
				elif depth_value >= 0.4 and depth_value < 0.7:
					# Суша: трава + стена
					if biome_value < 0.25:
						ground_node.get_child(0).get_child(0).texture = tex_grass
						ground_node.get_child(0).get_child(1).texture = tex_grass_wall
						
						if biome_value < 0.20:
							if chance_value < 0.1:
								tree_node.get_child(0).get_child(0).texture = tex_tree
								tree_node.global_position = Vector2(world_x, world_y)
							
						else:
							pass
						
						
					elif biome_value >= 0.25 and biome_value < 0.40:
						ground_node.get_child(0).get_child(0).texture = tex_humus
						ground_node.get_child(0).get_child(1).texture = tex_humus_wall
					elif biome_value >= 0.40 and biome_value < 0.55:
						ground_node.get_child(0).get_child(0).texture = tex_sand
						ground_node.get_child(0).get_child(1).texture = tex_sand_wall
					elif biome_value >= 0.55 and biome_value < 0.70:
						ground_node.get_child(0).get_child(0).texture = tex_snow
						ground_node.get_child(0).get_child(1).texture = tex_snow_wall
					elif biome_value >= 0.70 and biome_value < 0.85:
						ground_node.get_child(0).get_child(0).texture = tex_steppe
						ground_node.get_child(0).get_child(1).texture = tex_steppe_wall
					elif biome_value >= 0.85:
						ground_node.get_child(0).get_child(0).texture = tex_meadow
						ground_node.get_child(0).get_child(1).texture = tex_meadow_wall
					else:
						ground_node.get_child(0).get_child(0).texture = tex_grass
						ground_node.get_child(0).get_child(1).texture = tex_grass_wall
						
						
					ground_node.global_position = Vector2(world_x, world_y)
				elif depth_value >= 0.7:
					solid_node.get_child(0).get_child(0).texture = tex_rock
					solid_node.get_child(0).get_child(1).texture = tex_rock_wall
					solid_node.global_position = Vector2(world_x, world_y)

				existing_tiles[tile_coord] = {
					"ground": ground_node,
					"water": water_node,
					"solid": solid_node,
					"tree": tree_node
				}
	
	var sorted_children = []
	for child in get_children():
		sorted_children.append(child)
	# Сортируем: сначала по Y, потом по X
	sorted_children.sort_custom(func(a, b): 
		if a.global_position.y != b.global_position.y:
			return a.global_position.y < b.global_position.y
		return a.global_position.x < b.global_position.x
	)

	for i in range(sorted_children.size()):
		move_child(sorted_children[i], i)

	# Удаляем тайлы, которые больше не нужны
	var to_remove := []
	for key in existing_tiles.keys():
		if not needed_keys.has(key):
			to_remove.append(key)

	for key in to_remove:
		var tile_data = existing_tiles[key]
		if tile_data.water:
			tile_data.water.queue_free()
		if tile_data.ground:
			tile_data.ground.queue_free()
		if tile_data.solid:
			tile_data.solid.queue_free()
		if tile_data.tree:
			tile_data.tree.queue_free()
		existing_tiles.erase(key)
