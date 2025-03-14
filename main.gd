extends Node2D

enum PowerUpType { SLOW_MOTION, SHIELD }
@onready var player = $Player
@onready var score_label = $UI/ScoreLabel
@onready var restart_message = $UI/RestartMessage
@onready var high_score_label = $UI/HighScoreLabel
@onready var jump_sound = $JumpSound
@onready var score_sound = $ScoreSound
@onready var level_up_sound = $LevelUpSound
@onready var game_over_sound = $GameOverSound
@onready var slow_motion_bar = $UI/SlowMotionBar

# Level 1 settings
const GRAVITY_L1 = 1000
const PIPE_SPEED_L1 = 200
const SPAWN_TIME_L1 = 1.5

# Level 2 settings
const GRAVITY_L2 = 1500
const PIPE_SPEED_L2 = 300
const SPAWN_TIME_L2 = 1.0

# Level 3 settings
const GRAVITY_L3 = 2000
const PIPE_SPEED_L3 = 400
const SPAWN_TIME_L3 = 0.8

const JUMP_FORCE = -400
const LEVEL_THRESHOLD = 10  # Level 2 at 10 points
const LEVEL3_THRESHOLD = 20  # Level 3 at 20 points

const LEVEL1_COLOR = Color(1, 1, 1, 1)  # White
const LEVEL2_COLOR = Color(0.5, 1, 0.5, 1)  # Light green
const LEVEL3_COLOR = Color(0.5, 0.5, 1, 1)  # Light blue
const POWER_UP_SPAWN_CHANCE = 0.2  # 20% chance when spawning a pipe
const SLOW_MOTION_DURATION = 5.0
const SLOW_MOTION_FACTOR = 0.5
var velocity = Vector2.ZERO
var score = 0
var high_score = 0
var game_over = false
var pipes = []
var current_level = 1
var current_gravity = GRAVITY_L1
var current_pipe_speed = PIPE_SPEED_L1
var current_spawn_time = SPAWN_TIME_L1
var level_transition_time = 0
var power_ups = []
var has_shield = false
var is_slow_motion = false
var original_speed = 0
var original_gravity = 0

# Preload the pipe scene
var pipe_scene = preload("res://pipe.tscn")
var power_up_scene = preload("res://powerup.tscn")

func reset_game():
	# Reset game state
	game_over = false
	score = 0
	current_level = 1
	current_gravity = GRAVITY_L1
	current_pipe_speed = PIPE_SPEED_L1
	current_spawn_time = SPAWN_TIME_L1
	restart_message.visible = false
	velocity = Vector2.ZERO
	
	# Reset player position
	player.position.x = 100  # Starting x position
	player.position.y = 300  # Middle of screen (window height is approximately 610px)
	
	# Clear existing pipes
	for pipe in pipes:
		pipe.queue_free()
	pipes.clear()
	
	# Clear existing power-ups
	for power_up in power_ups:
		power_up.queue_free()
	power_ups.clear()
	
	# Reset power-up states
	has_shield = false
	is_slow_motion = false
	if $Player.has_node("ShieldEffect"):
		$Player/ShieldEffect.visible = false
	slow_motion_bar.visible = false
	
	# Reset score display
	score_label.text = "Score: 0\nLevel: 1"
	update_high_score_display()
	$Player/ColorRect.color = LEVEL1_COLOR

func _ready():
	# Initialize player position
	player.position.x = 100
	player.position.y = 300
	
	# Load high score if available
	load_high_score()
	update_high_score_display()
	
	# Load audio streams directly using AudioStreamWAV
	var audio_dir = "res://sounds/"

	# Create AudioStreamWAV objects manually
	if FileAccess.file_exists(audio_dir + "jump.wav"):
		var stream = AudioStreamWAV.new()
		var file = FileAccess.open(audio_dir + "jump.wav", FileAccess.READ)
		if file:
			var buffer = file.get_buffer(file.get_length())
			stream.data = buffer
			jump_sound.stream = stream
			jump_sound.volume_db = -10.0
			print("Jump sound loaded successfully")

	if FileAccess.file_exists(audio_dir + "score.wav"):
		var stream = AudioStreamWAV.new()
		var file = FileAccess.open(audio_dir + "score.wav", FileAccess.READ)
		if file:
			var buffer = file.get_buffer(file.get_length())
			stream.data = buffer
			score_sound.stream = stream
			score_sound.volume_db = -10.0
			print("Score sound loaded successfully")
			
	if FileAccess.file_exists(audio_dir + "level_up.wav"):
		var stream = AudioStreamWAV.new()
		var file = FileAccess.open(audio_dir + "level_up.wav", FileAccess.READ)
		if file:
			var buffer = file.get_buffer(file.get_length())
			stream.data = buffer
			level_up_sound.stream = stream
			level_up_sound.volume_db = -10.0
			print("Level up sound loaded successfully")
			
	if FileAccess.file_exists(audio_dir + "game_over.wav"):
		var stream = AudioStreamWAV.new()
		var file = FileAccess.open(audio_dir + "game_over.wav", FileAccess.READ)
		if file:
			var buffer = file.get_buffer(file.get_length())
			stream.data = buffer
			game_over_sound.stream = stream
			game_over_sound.volume_db = -10.0
			print("Game over sound loaded successfully")
	
	# Start pipe spawning
	var timer = Timer.new()
	timer.wait_time = current_spawn_time
	timer.timeout.connect(spawn_pipe)
	add_child(timer)
	timer.name = "PipeTimer"
	timer.start()
	
func _process(delta):
	if game_over:
		# Check for restart input
		if Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_R):
			reset_game()
		return
		
	# Handle level transition visual effect
	if level_transition_time > 0:
		level_transition_time -= delta
		if level_transition_time <= 0:
			$UI/LevelUpLabel.visible = false

	# Apply gravity
	velocity.y += current_gravity * delta
	
	# Handle jump input
	if Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_FORCE
		$Player/JumpParticles.restart()
		if jump_sound.stream:
			jump_sound.play()
	
	# Update player position
	player.position += velocity * delta
	
	# Update parallax background
	$ParallaxBackground.scroll_offset.x += current_pipe_speed * delta
	
	# Move pipes
	var pipes_to_remove = []
	for pipe in pipes:
		pipe.position.x -= current_pipe_speed * delta
		
		# Check for collision
		var top_area = pipe.get_node("TopArea")
		var bottom_area = pipe.get_node("BottomArea")
		if top_area.overlaps_body(player) or bottom_area.overlaps_body(player):
			if has_shield:
				has_shield = false
				$Player/ShieldEffect.visible = false
				play_flash_effect()  # Reuse flash effect for shield break
				continue  # Skip game over
			game_over = true
			$Player/CollisionParticles.restart()
			if game_over_sound.stream:
				game_over_sound.play()
			# Update high score if needed
			if score > high_score:
				high_score = score
				save_high_score()
			
			# Update game over screen
			score_label.text = "Game Over!\nScore: " + str(score)
			update_high_score_display()
			restart_message.visible = true
			
		# Score when passing pipe center
		if not pipe.get_meta("passed", false) and pipe.position.x < player.position.x:
			score += 1
			pipe.set_meta("passed", true)
			if score_sound.stream:
				score_sound.play()
			
			# Check for level progression
			if score == LEVEL_THRESHOLD and current_level == 1:
				current_level = 2
				current_gravity = GRAVITY_L2
				current_pipe_speed = PIPE_SPEED_L2
				get_node("PipeTimer").wait_time = SPAWN_TIME_L2
				transition_player_color(LEVEL2_COLOR)
				
				# Show level up message
				$UI/LevelUpLabel.text = "Level " + str(current_level) + "!"
				$UI/LevelUpLabel.visible = true
				if level_up_sound.stream:
					level_up_sound.play()
				level_transition_time = 2.0
			elif score == LEVEL3_THRESHOLD and current_level == 2:
				current_level = 3
				current_gravity = GRAVITY_L3
				current_pipe_speed = PIPE_SPEED_L3
				get_node("PipeTimer").wait_time = SPAWN_TIME_L3
				transition_player_color(LEVEL3_COLOR)
				
				# Show level up message
				$UI/LevelUpLabel.text = "Level " + str(current_level) + "!"
				$UI/LevelUpLabel.visible = true
				if level_up_sound.stream:
					level_up_sound.play()
				level_transition_time = 2.0
			
			# Update score display
			score_label.text = "Score: " + str(score) + "\nLevel: " + str(current_level)
			
		# Remove pipes that are off screen
		if pipe.position.x < -50:
			pipes_to_remove.append(pipe)
	
	# Remove old pipes
	for pipe in pipes_to_remove:
		pipes.erase(pipe)
		pipe.queue_free()
	
	# Check boundaries
	if player.position.y <= 20:  # Top border
		player.position.y = 20
		velocity.y = 0
	elif player.position.y >= 590:  # Bottom border - player height
		player.position.y = 590
		velocity.y = 0
	
	if player.position.x <= 20:  # Left border
		player.position.x = 20
	elif player.position.x >= 430:  # Right border - player width
		player.position.x = 430
		
func save_high_score():
	var save_game = FileAccess.open("user://highscore.save", FileAccess.WRITE)
	save_game.store_var(high_score)
	
func load_high_score():
	if FileAccess.file_exists("user://highscore.save"):
		var save_game = FileAccess.open("user://highscore.save", FileAccess.READ)
		high_score = save_game.get_var()
		
func update_high_score_display():
	high_score_label.text = "High Score: " + str(high_score)

func transition_player_color(new_color: Color):
	var tween = create_tween()
	tween.tween_property($Player/ColorRect, "color", new_color, 1.0)

func play_flash_effect():
	var flash = $UI/FlashEffect
	flash.visible = true
	flash.color = Color(1, 1, 1, 0.3)
	
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.2)
	tween.tween_callback(func(): flash.visible = false)

func spawn_pipe():
	if game_over:
		return
		
	var pipe = pipe_scene.instantiate()
	pipe.position.x = 480  # Start at right edge of screen
	# Randomize the pipe height
	var offset = randf_range(-100, 100)
	pipe.position.y = offset
	add_child(pipe)
	pipes.append(pipe)
	
	# Chance to spawn power-up
	if randf() < POWER_UP_SPAWN_CHANCE:
		var power_up = power_up_scene.instantiate()
		power_up.position.x = pipe.position.x + randf_range(100, 200)
		power_up.position.y = randf_range(50, 590)  # Keep within playable area
		add_child(power_up)
		power_ups.append(power_up)

# Add power-up effect handling
func apply_power_up(type):
	match type:
		PowerUpType.SLOW_MOTION:
			if not is_slow_motion:
				is_slow_motion = true
				original_speed = current_pipe_speed
				original_gravity = current_gravity
				current_pipe_speed *= SLOW_MOTION_FACTOR
				current_gravity *= SLOW_MOTION_FACTOR
				
				# Show and setup progress bar
				slow_motion_bar.visible = true
				slow_motion_bar.value = SLOW_MOTION_DURATION
				
				# Create timer and tween for smooth bar update
				var timer = get_tree().create_timer(SLOW_MOTION_DURATION)
				var tween = create_tween()
				tween.tween_property(slow_motion_bar, "value", 0, SLOW_MOTION_DURATION)
				
				timer.timeout.connect(func():
					is_slow_motion = false
					current_pipe_speed = original_speed
					current_gravity = original_gravity
					slow_motion_bar.visible = false
				)
		
		PowerUpType.SHIELD:
			has_shield = true
			# Add shield visual effect if not exists
			if not $Player.has_node("ShieldEffect"):
				var shield = ColorRect.new()
				shield.set_name("ShieldEffect")
				shield.size = Vector2(40, 40)
				shield.position = Vector2(-5, -5)
				shield.color = Color(1, 1, 1, 0.3)
				$Player.add_child(shield)
			else:
				$Player/ShieldEffect.visible = true
	
	# Play power-up collection sound
	if score_sound.stream:  # Reuse score sound for power-ups
		score_sound.play()

func remove_power_up(power_up):
	power_ups.erase(power_up)
