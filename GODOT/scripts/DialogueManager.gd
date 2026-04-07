extends CanvasLayer

@onready var label: Label = $Panel/DialogLabel
@onready var panel: Panel = $Panel

func show_dialog(text: String):
	label.text = text
	panel.visible = true

func hide_dialog():
	panel.visible = false
