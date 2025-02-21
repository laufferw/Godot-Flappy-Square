extends Node2D

@onready var player = $Player
@onready var score_label = $ScoreLabel
@onready var restart_message = $UI/RestartMessage

# Level 1 settings
const GRAVITY_L1 = 1000
const PIPE_SPEED_L1 = 200
const SPAWN_TIME_L1 = 1.5

# Level 2 settings
const GRAVITY_L2 = 1500
const PIPE_SPEED_L2 = 300
const SPAWN_TIME_L2 = 1.0

const JUMP_FORCE = -400
const LEVEL_THRESHOLD = 50

var velocity = Vector2.ZERO
var score = 0
var game_over = false
var pipes = []
var current_level = 1
var current_gravity = GRAVITY_L1
var current_pipe_speed = PIPE_SPEED_L1
var current_spawn_time = SPAWN_TIME_L1
var level_transition_time = 0

# Preload the pipe scene
var pipe_scene = preload("res://pipe.tscn")

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
	player.position.y = 300  # Middle of screen
	
	# Clear existing pipes
	for pipe in pipes:
		pipe.queue_free()
	pipes.clear()
	
	# Reset score display
	score_label.text = "0"

func _ready():
	# Initialize player position
	player.position.x = 100
	player.position.y = 300
	# Start pipe spawning
	var timer = Timer.new()
	timer.wait_time = current_spawn_time
	timer.timeout.connect(spawn_pipe)
	add_child(timer)
	timer.name = "PipeTimer"
	timer.start()
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
			$LevelUpLabel.visible = false

	# Apply gravity
	velocity.y += current_gravity * delta
	
	# Handle jump input
	if Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_FORCE
	
	# Update player position
	player.position += velocity * delta
	
	# Move pipes
	var pipes_to_remove = []
	for pipe in pipes:
		pipe.position.x -= current_pipe_speed * delta
		
		# Check for collision
		var top_area = pipe.get_node("TopArea")
		var bottom_area = pipe.get_node("BottomArea")
		if top_area.overlaps_body(player) or bottom_area.overlaps_body(player):
			game_over = true
			score_label.text = "Game Over!\nScore: " + str(score)
			restart_message.visible = true
			
		# Remove pipes that are off screen
		if pipe.position.x < -50:
			pipes_to_remove.append(pipe)
			
		# Score when passing pipe center
			score += 1
			pipe.set_meta("passed", true)
			
			# Check for level progression
			if score == LEVEL_THRESHOLD and current_level == 1:
				current_level = 2
				current_gravity = GRAVITY_L2
				current_pipe_speed = PIPE_SPEED_L2
				get_node("PipeTimer").wait_time = SPAWN_TIME_L2
				
				# Show level up message
				$LevelUpLabel.visible = true
				level_transition_time = 2.0
			
			score_label.text = "Score: " + str(score) + "\nLevel: " + str(current_level)
			score_label.text = str(score)
	
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
