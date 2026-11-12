class_name RewardCardController
extends Control

@export var reward_name:Label
@export var image:TextureRect
@export var frame_icon:TextureRect
@export var reward_value:Label


func setup(key:String,value:String,icon:Texture, frame_icon_texture:Texture = null):
	reward_name.text=key
	reward_value.text=value
	image.texture=icon
	frame_icon.texture=frame_icon_texture
