extends Node2D

@onready var player = $Player
@onready var score_label = $ScoreLabel
@onready var restart_message = $RestartMessage

const GRAVITY = 1000
const JUMP_FORCE = -400
const PIPE_SPEED = 200
const SPAWN_TIME = 1.5

var velocity = Vector2.ZERO
var score = 0
var game_over = false
var pipes = []

# Preload the pipe scene
var pipe_scene = preload("res://pipe.tscn")

func reset_game():
	# Reset game state
	game_over = false
	score = 0
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
	timer.wait_time = SPAWN_TIME
	timer.timeout.connect(spawn_pipe)
	add_child(timer)
	timer.start()
	
func _process(delta):
	if game_over:
		# Check for restart input
		if Input.is_action_just_pressed("jump") or Input.is_key_pressed(KEY_R):
			reset_game()
		return
		
	# Apply gravity
	velocity.y += GRAVITY * delta
	
	# Handle jump input
	if Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_FORCE
	
	# Update player position
	player.position += velocity * delta
	
	# Move pipes
	var pipes_to_remove = []
	for pipe in pipes:
		pipe.position.x -= PIPE_SPEED * delta
		
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
		if !game_over and pipe.position.x + 25 < player.position.x and !pipe.get_meta("passed", false):
			score += 1
			pipe.set_meta("passed", true)
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
