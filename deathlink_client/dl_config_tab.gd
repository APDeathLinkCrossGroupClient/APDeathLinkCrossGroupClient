class_name DLConfigTab extends MarginContainer

@export var source_container: GridContainer
@export var dest_container: GridContainer
@export var count_box: SpinBox
@export var save_btn: Button
@export var reset_btn: Button
@export var err_label: Label

signal update_server()
signal request_delete()

var index: int
var config: DLConfig
var changes_dirty := false

func reset() -> void:
	mark_changed(true)
	for child in source_container.get_children():
		child.queue_free()
	for child in dest_container.get_children():
		child.queue_free()

	for src in config.sources:
		add_source().text = src

	for dest in config.dests:
		add_dest().text = dest

	count_box.value = config.count
	mark_changed(false)

func _ready() -> void:
	reset()

func add_source() -> LineEdit:
	var edit := LineEdit.new()
	edit.custom_minimum_size.x = 150
	var delete := Button.new()
	delete.text = " - "
	delete.pressed.connect(edit.queue_free)
	delete.pressed.connect(delete.queue_free)
	source_container.add_child(edit)
	source_container.add_child(delete)
	mark_changed()
	return edit

func add_dest() -> LineEdit:
	var edit := LineEdit.new()
	edit.custom_minimum_size.x = 150
	var delete := Button.new()
	delete.text = " - "
	delete.pressed.connect(edit.queue_free)
	delete.pressed.connect(delete.queue_free)
	dest_container.add_child(edit)
	dest_container.add_child(delete)
	mark_changed()
	return edit

func change_count() -> void:
	mark_changed()

func update(new_config: DLConfig) -> void:
	if config.same_config(new_config):
		new_config.give_data(config)
		return
	config = new_config
	reset()

func mark_changed(val: bool = true) -> void:
	if val == changes_dirty: return
	changes_dirty = val
	save_btn.set_disabled(not val)
	reset_btn.set_disabled(not val)

func save_changes() -> void:
	if not changes_dirty: return

	var new_config := DLConfig.new()

	for child in source_container.get_children():
		if child is LineEdit:
			if child.text in new_config.sources:
				continue
			new_config.sources.append(child.text)
	for child in dest_container.get_children():
		if child is LineEdit:
			if child.text in new_config.dests:
				continue
			new_config.dests.append(child.text)
	new_config.count = roundi(count_box.value)

	if new_config.is_invalid():
		err_label.text = "Error: Invalid Config"
		return

	err_label.text = ""
	mark_changed(false)
	if new_config.same_config(config): return
	new_config.give_config(config)
	update_server.emit()

func delete_config() -> void:
	request_delete.emit()
