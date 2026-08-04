extends Node2D

var noise_height = FastNoiseLite.new()
var noise_biome = FastNoiseLite.new()
var noise_distortion = FastNoiseLite.new()  # Для искажения границ
var noise_rng = RandomNumberGenerator.new()
var array_size = 500
var height_map = []
var biome_map = []
var chance_map = []

var seed: int = 1442561

# Параметры для настройки размера клеток
@export var biome_cell_size: float = 15.0  # Базовый размер клетки (15.0)
@export var biome_distortion_strength: float = 7.0  # Сила искажения границ (7.0)(
@export var biome_smooth_passes: int = 3  # Количество проходов сглаживания (3)

func _ready():
	# Настройка для карты высот
	noise_height.seed = seed
	noise_height.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_height.fractal_octaves = 4 #(4)
	noise_height.fractal_lacunarity = 2.0 #(2.0)
	noise_height.fractal_gain = 0.7 #(0.7)
	
	noise_rng.seed = seed
	
	# Настройка для биомов (cellular/Voronoi)
	noise_biome.seed = seed
	noise_biome.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise_biome.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	noise_biome.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise_biome.cellular_jitter = 0.3  # Уменьшаем для более регулярной сетки (0.3)
	
	# Настройка шума для искажения границ
	noise_distortion.seed = seed
	noise_distortion.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_distortion.fractal_octaves = 3 #(3)
	noise_distortion.fractal_lacunarity = 2.0 #(2.0)
	noise_distortion.fractal_gain = 0.5 #(0.7)
	
	generate_biomes()
	
	#print("Height range: ", get_min_max(height_map))
	#print("Biome range: ", get_min_max(biome_map))
	
	analyze_biome_sizes()

func generate_biomes():
	# Сначала генерируем сырые значения с искажением координат
	var raw_biome = []
	for x in range(array_size):
		height_map.append([])
		chance_map.append([])
		raw_biome.append([])
		biome_map.append([])
		for y in range(array_size):
			# Шум для высоты
			var height_value = noise_height.get_noise_2d(x, y)
			height_value = height_value * 0.5 + 0.5
			height_map[x].append(height_value)
			
			# Шум chance
			var chance_value = noise_rng.randf()
			chance_map[x].append(chance_value)
			
			# Масштабируем координаты для увеличения размера клеток
			var scaled_x = float(x) / biome_cell_size
			var scaled_y = float(y) / biome_cell_size
			
			# Добавляем искажение координат для неровных границ
			var distortion_x = noise_distortion.get_noise_2d(scaled_x * 0.5, scaled_y * 0.5) * biome_distortion_strength
			var distortion_y = noise_distortion.get_noise_2d(scaled_x * 0.5 + 100, scaled_y * 0.5 + 100) * biome_distortion_strength
			
			var distorted_x = scaled_x + distortion_x
			var distorted_y = scaled_y + distortion_y
			
			# Получаем индекс ячейки Вороного
			var biome_value = noise_biome.get_noise_2d(distorted_x, distorted_y)
			raw_biome[x].append(biome_value)
	
	# Нормализуем значения биомов
	normalize_biomes(raw_biome)
	
	# Применяем легкое сглаживание если нужно
	if biome_smooth_passes > 0:
		smooth_biomes(biome_smooth_passes)

func normalize_biomes(raw_biome):
	# Находим все уникальные значения индексов ячеек
	var unique_values = {}
	for x in range(array_size):
		for y in range(array_size):
			unique_values[raw_biome[x][y]] = true
	
	# Сортируем уникальные значения
	var sorted_values = unique_values.keys()
	sorted_values.sort()
	
	#print("Unique biome cells: ", sorted_values.size())
	
	# Создаём маппинг: старое значение -> нормализованное [0,1]
	var value_mapping = {}
	for i in range(sorted_values.size()):
		value_mapping[sorted_values[i]] = float(i) / max(1, sorted_values.size() - 1)
	
	# Применяем маппинг
	for x in range(array_size):
		for y in range(array_size):
			biome_map[x].append(value_mapping[raw_biome[x][y]])

func smooth_biomes(passes: int):
	for pass_num in range(passes):
		var smoothed = []
		for x in range(array_size):
			smoothed.append([])
			for y in range(array_size):
				smoothed[x].append(biome_map[x][y])
		
		# Применяем сглаживание большинством голосов
		for x in range(array_size):
			for y in range(array_size):
				var votes = {}
				
				# Собираем значения из окрестности 3x3
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						var nx = posmod(x + dx, array_size)
						var ny = posmod(y + dy, array_size)
						var val = biome_map[nx][ny]
						votes[val] = votes.get(val, 0) + 1
				
				# Находим наиболее частое значение
				var max_count = 0
				var most_common = biome_map[x][y]
				for val in votes:
					if votes[val] > max_count:
						max_count = votes[val]
						most_common = val
				
				smoothed[x][y] = most_common
		
		# Обновляем карту биомов
		for x in range(array_size):
			for y in range(array_size):
				biome_map[x][y] = smoothed[x][y]
		
		#print("Smoothing pass ", pass_num + 1, " completed")

func get_min_max(map):
	var min_val = map[0][0]
	var max_val = map[0][0]
	for x in range(array_size):
		for y in range(array_size):
			min_val = min(min_val, map[x][y])
			max_val = max(max_val, map[x][y])
	return [min_val, max_val]

func analyze_biome_sizes():
	# Группируем значения биомов в категории
	var biome_categories = {}
	for x in range(array_size):
		for y in range(array_size):
			var category = biome_map[x][y]
			if not biome_categories.has(category):
				biome_categories[category] = 0
			biome_categories[category] += 1
	
	#print("Biome distribution:")
	var total = array_size * array_size
	for biome in biome_categories:
		var percentage = (biome_categories[biome] / float(total)) * 100
		#print("Biome %.3f: %d cells (%.1f%%)" % [biome, biome_categories[biome], percentage])
	
	# Визуализация карты биомов в консоли
	#print("\nBiome map preview (first 30x30):")
	for y in range(min(30, array_size)):
		var line = ""
		for x in range(min(30, array_size)):
			var biome_idx = int(biome_map[x][y] * 10)
			line += str(biome_idx) + " "

# Функция для динамического изменения параметров
func update_biome_parameters(cell_size: float, distortion: float, smooth: int):
	biome_cell_size = cell_size
	biome_distortion_strength = distortion
	biome_smooth_passes = smooth
	
	# Очищаем старые данные
	height_map.clear()
	biome_map.clear()
	
	# Перегенерируем
	generate_biomes()
