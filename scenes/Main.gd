extends Node2D

@onready var background: TextureRect = $Background

func _ready() -> void:
	var texture = load("res://asserts/image/backgroud/bg_generated_16x9_b.jpg")
	background.texture = texture
