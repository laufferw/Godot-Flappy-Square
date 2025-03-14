extends Area2D

enum PowerUpType { SLOW_MOTION, SHIELD }

var type: PowerUpType
var float_offset = 0.0
var float_speed = 2.0
var float_amplitude = 10.0

func _ready():
	# Randomly assign type
	type = PowerUpType.values()[randi() % PowerUpType.size()]
	
	# Set color based on type
	match type:
		PowerUpType.SLOW_MOTION:
			$ColorRect.color = Color(0.2, 0.8, 1.0, 1.0)  # Light blue
		PowerUpType.SHIELD:
			$ColorRect.color = Color(1.0, 0.8, 0.2, 1.0)  # Gold

func _process(delta):
	# Simple floating animation
	float_offset += delta * float_speed
	position.y = position.y + cos(float_offset) * float_amplitude * delta

func _on_power_up_body_entered(body):
	if body.name == "Player":
		get_parent().apply_power_up(type)
		queue_free()

func _exit_tree():
	# Remove from parent's power_ups array when destroyed
	if get_parent() and get_parent().has_method("remove_power_up"):
		get_parent().remove_power_up(self)
