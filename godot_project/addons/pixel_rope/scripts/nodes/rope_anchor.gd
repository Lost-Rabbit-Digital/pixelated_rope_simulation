@tool
@icon("res://addons/pixel_rope/icons/CircleShape2D.svg")
## An interactive anchor point for rope connections
##
## Creates a circular node that serves as an attachment point for PixelRope instances.
## Features adjustable radius and color, with built-in collision detection for
## interaction. Automatically sets up required physics components on creation.
class_name RopeAnchor
extends Node2D

@export var radius: float = 8.0
@export var color: Color = Color.WHITE

func _ready() -> void:
	# Make sure we have an Area2D for interaction
	if not has_node("Area2D"):
		var area = Area2D.new()
		area.name = "Area2D"
		
		var collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		
		var shape = CircleShape2D.new()
		shape.radius = radius
		
		collision.shape = shape
		area.add_child(collision)
		add_child(area)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
