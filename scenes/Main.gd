extends Node2D

@onready var background: TextureRect = $Background
@onready var bgm: AudioStreamPlayer = $BGM

func _input(_event: InputEvent) -> void:
	if not bgm.playing:
		bgm.play()

func _ready() -> void:
	var texture = load("res://asserts/image/backgroud/bg_test_1.jpg")
	background.texture = texture

	bgm.stream = load("res://asserts/audio/bg1.wav")
	bgm.volume_db = 0.0
	bgm.play()
