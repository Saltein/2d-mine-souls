# MoveController.gd
class_name MoveController
extends CharacterBody2D

@export var speed: float = 200.0
@export var acceleration: float = 30.0
@export var friction: float = 40.0

@export var sprint_coeff: float = 2.0
@export var sprint_delay: float = 0.2

# Параметры переката
@export var dodge_length: float = 256.0  # фиксированное расстояние переката в пикселях
@export var dodge_active_duration: float = 0.6  # время активного перемещения
@export var dodge_total_duration: float = 0.8  # общее время до выхода из состояния
@export var dodge_finish_speed: float = 150  # начальная скорость в завершающей фазе
@export var dodge_stamina_cost: float = 12

# Параметры ускорения/замедления переката
@export var dodge_acceleration_phase: float = 0.2  # доля времени на разгон (0-1)
@export var dodge_deceleration_phase: float = 0.7  # доля времени на замедление (0-1)

@export var stamina_substract_coeff: float = 1 #12
@export var stamina_recovery_coeff: float = 20
@export var stamina_recovery_delay: float = 1

@onready var player = $Player

var stamina_recovery_timer: float = 0
var dodge_timer: float = 0
var dodge_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	Player.move_controller = self

func _physics_process(delta: float) -> void:	
	Player.playerVelocity = velocity
	
	# Получаем направление от -1 до 1
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	Player.playerDirection = direction
	
	# Запоминаем последнее направление (если есть движение)
	if direction != Vector2.ZERO:
		Player.playerLastDirection = direction
		# Обновляем масштаб персонажа только для горизонтального движения
		if player and direction.x != 0:
			player.scale.x = -1 if direction.x < 0 else 1
	else:
		# Если нет движения, используем последнее направление для масштаба
		if player and Player.playerLastDirection.x != 0:
			player.scale.x = -1 if Player.playerLastDirection.x < 0 else 1
	
	var target_speed := speed
	var current_acceleration := acceleration
	var current_friction := friction

	# Логика спринта
	if Player.isSprinting and Player.player_stamina > 0:
		stamina_recovery_timer = 0
		target_speed = speed * sprint_coeff
		current_acceleration = acceleration * sprint_coeff
		current_friction = friction * sprint_coeff
		Player.player_stamina = max(0, Player.player_stamina - stamina_substract_coeff * delta)
	else:
		if not Player.isDodging:
			stamina_recovery_timer += delta
			if Player.player_stamina < Player.player_max_stamina:
				if stamina_recovery_timer > stamina_recovery_delay:
					Player.player_stamina = min(Player.player_max_stamina, Player.player_stamina + stamina_recovery_coeff * delta)
		
	# Логика переката
	if Player.isDodging:
		stamina_recovery_timer = 0
		dodge_timer += delta
		
		# Определяем, активная ли сейчас фаза
		var is_active_phase: bool = dodge_timer < dodge_active_duration
		var current_speed: float = 0.0
		
		if is_active_phase:
			# Активная фаза - рассчитываем скорость по трапециевидному профилю
			var active_progress: float = clamp(dodge_timer / dodge_active_duration, 0.0, 1.0)
			current_speed = calculate_dodge_speed(active_progress, dodge_active_duration, dodge_length)
		else:
			# Завершающая фаза - скорость снижается от dodge_finish_speed до 0
			var finish_progress: float = (dodge_timer - dodge_active_duration) / (dodge_total_duration - dodge_active_duration)
			finish_progress = clamp(finish_progress, 0.0, 1.0)
			current_speed = dodge_finish_speed * (1.0 - smoothstep(0, 1, finish_progress))
		
		# Применяем направление и скорость
		if dodge_direction != Vector2.ZERO:
			velocity = dodge_direction * current_speed
		else:
			if direction != Vector2.ZERO:
				velocity = direction.normalized() * current_speed
				dodge_direction = direction.normalized()
			else:
				var facing_direction = Vector2.RIGHT if player.scale.x > 0 else Vector2.LEFT
				velocity = facing_direction * current_speed
				dodge_direction = facing_direction
		
		# Проверяем завершение общего времени
		if dodge_timer >= dodge_total_duration:
			Player.isDodging = false
			velocity = Vector2.ZERO
			dodge_timer = 0
			dodge_direction = Vector2.ZERO
	else: 
		dodge_timer = 0
		dodge_direction = Vector2.ZERO
		
	if Player.isLightAttacking:
		stamina_recovery_timer = 0
	
	# Применяем движение (для не-переката)
	if not Player.isDodging:
		if Player.isLightAttacking:
			return
		if direction != Vector2.ZERO:
			velocity = velocity.move_toward(direction * target_speed, current_acceleration)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, current_friction)
	
	move_and_slide()

# Рассчитывает скорость в зависимости от прогресса в активной фазе
func calculate_dodge_speed(progress: float, active_duration: float, distance: float) -> float:
	# Определяем фазы
	var accel_end: float = dodge_acceleration_phase
	var decel_start: float = 1.0 - dodge_deceleration_phase
	
	# Рассчитываем максимальную скорость для достижения distance за active_duration
	var max_speed: float = calculate_max_speed_for_distance(active_duration, distance)
	
	if progress <= accel_end:
		# Фаза разгона (от 0 до max_speed)
		var t: float = progress / accel_end
		return max_speed * smoothstep(0, 1, t)
	elif progress < decel_start:
		# Фаза постоянной скорости (max_speed)
		return max_speed
	else:
		# Фаза замедления (от max_speed до 0)
		var t: float = (progress - decel_start) / dodge_deceleration_phase
		return max_speed * (1 - smoothstep(0, 1, t))

# Рассчитывает максимальную скорость для достижения заданной дистанции
func calculate_max_speed_for_distance(active_duration: float, distance: float) -> float:
	var accel_time: float = dodge_acceleration_phase * active_duration
	var decel_time: float = dodge_deceleration_phase * active_duration
	var const_time: float = (1 - dodge_acceleration_phase - dodge_deceleration_phase) * active_duration
	
	# Эффективное время = время разгона/2 + постоянная + время замедления/2
	var effective_time: float = accel_time / 2 + const_time + decel_time / 2
	
	if effective_time <= 0:
		return speed * 2  # fallback
	
	return distance / effective_time

# Функция плавного перехода (аналог smoothstep)
func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3 - 2 * t)

# Вызывается при начале переката
func start_dodge(direction: Vector2 = Vector2.ZERO) -> void:
	if Player.isDodging or Player.player_stamina < dodge_stamina_cost:
		return
	
	Player.isDodging = true
	Player.player_stamina -= dodge_stamina_cost
	dodge_timer = 0
	dodge_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO
