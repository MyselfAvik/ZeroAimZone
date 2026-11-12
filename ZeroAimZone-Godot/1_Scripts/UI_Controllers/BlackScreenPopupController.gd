class_name BlackScreenPopupController
extends BasePopupController

@export var close_btn:Button
@export var no_lan_ip_label:Label
@export var multiple_lan_ip:Label


func show_label(type:int):
	if type==0:
		no_lan_ip_label.visible=true
		multiple_lan_ip.visible=false
	elif type==1:
		no_lan_ip_label.visible=false
		multiple_lan_ip.visible=true



func _on_close_pressed() -> void:
	hide()
