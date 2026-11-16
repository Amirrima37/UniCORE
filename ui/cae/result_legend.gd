extends PanelContainer
const Colors=preload("res://core/cae/engineering_visuals.gd")
func configure(title: String,unit: String,low: float,high: float,palette: String,detail: String) -> void:
	for child in get_children():remove_child(child);child.queue_free()
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var box:=VBoxContainer.new();add_child(box)
	var heading:=Label.new();heading.text=title+" ("+unit+")";heading.clip_text=true;box.add_child(heading)
	var gradient:=Gradient.new()
	gradient.set_color(0,Colors.color(0,0,1,palette));gradient.set_color(1,Colors.color(1,0,1,palette))
	for i in range(1,4):gradient.add_point(i/4.0,Colors.color(i/4.0,0,1,palette))
	var texture:=GradientTexture1D.new();texture.gradient=gradient;texture.width=1024
	var bar:=TextureRect.new();bar.texture=texture;bar.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bar.custom_minimum_size=Vector2(210,12);box.add_child(bar)
	var ticks:=Label.new();ticks.text=Colors.number(low)+" | "+Colors.number((low+high)/2)+" | "+Colors.number(high);ticks.clip_text=true;box.add_child(ticks)
	ticks.tooltip_text=JSON.stringify([low,(low+high)/2,high])
	var note:=Label.new();note.text=palette+"; "+detail;note.clip_text=true;note.tooltip_text=note.text;box.add_child(note)
