class_name DeathLinkManager extends MarginContainer

@export var tabs: TabContainer
@export var connected_label: Label
@export var new_config_button: Button

var config_tab_scene: PackedScene = preload("res://deathlink_client/dl_config_tab.tscn")

const DATASTORAGE_KEY := "DEATHLINK_CROSSGROUP_MANAGER"

static var config_tabs: Array[DLConfigTab]

func _ready() -> void:
	Archipelago.connected.connect(on_connect)
	Archipelago.disconnected.connect(on_disconnect)
	get_window().title += " (%s)" % ProjectSettings.get_setting("application/config/version")

func on_connect(conn: ConnectionInfo, _json: Dictionary) -> void:
	Archipelago.config.update_credentials(Archipelago.creds)
	clear_local_settings()
	conn.retrieve(DATASTORAGE_KEY, reload_settings)
	conn.set_notify(DATASTORAGE_KEY, reload_settings)
	conn.bounce.connect(receive_deathlink)
	new_config_button.set_disabled(false)
	connected_label.set_visible(false)

func on_disconnect() -> void:
	clear_local_settings()
	new_config_button.set_disabled(true)
	connected_label.set_visible(true)

func clear_local_settings() -> void:
	for child in config_tabs:
		child.queue_free()

func reload_settings(data: Variant) -> void:
	if data is not Dictionary: return
	var sel_tab := tabs.current_tab
	var num_keys: int = 1 + (data.keys()
		.map(func(s): return s.to_int() if s is String and s.is_valid_int() else -1)
		.reduce(func(i, acc): return maxi(i, acc), -1))
	for q: int in range(0, num_keys):
		var config := DLConfig.from_dict(data[str(q)]) if str(q) in data else DLConfig.new()
		if q < config_tabs.size():
			config_tabs[q].update(config)
		else:
			var new_tab := create_new_config()
			new_tab.config = config
	while config_tabs.size() > num_keys:
		config_tabs.pop_back().queue_free()
	update_tags()
	(func():
		tabs.current_tab = sel_tab if sel_tab < tabs.get_child_count() else 0
	).call_deferred()

func update_tags() -> void:
	var tags: Array[String] = Archipelago.AP_GAME_TAGS.filter(func(s: String): return not s.begins_with("DeathLink"))
	for tab in config_tabs:
		for tag: String in tab.config.sources.map(DLConfig.group_to_tag):
			if tag not in tags:
				tags.append(tag)
	Archipelago.set_tags(tags)

func receive_deathlink(json: Dictionary) -> void:
	var target_tags: Array[String]
	target_tags.assign(json.get("tags", []))
	if target_tags.is_empty(): return
	var keys: Array[int] = []
	for tag in target_tags:
		if not DLConfig.is_dl_tag(tag):
			continue
		var group := DLConfig.tag_to_group(tag)
		for tab in config_tabs:
			if tab.config.handle_deathlink(group, json):
				keys.append(tab.index)
	send_updates(keys)


func send_updates(keys: Array[int]) -> void:
	var update_data: Dictionary[String, Dictionary] = {}
	for tab in config_tabs:
		if tab.config.is_invalid(): continue
		if tab.index not in keys: continue
		update_data[str(tab.index)] = tab.config.to_dict()
	Archipelago.send_command("Set", {
		"key": DATASTORAGE_KEY,
		"default": {},
		"want_reply": true,
		"operations": [
			{
				"operation": "update",
				"value": update_data
			}
		]
	})

func create_new_config() -> DLConfigTab:
	var new_tab: DLConfigTab = config_tab_scene.instantiate() as DLConfigTab
	new_tab.index = config_tabs.size()
	new_tab.config = DLConfig.new()
	new_tab.name = str(new_tab.index)
	new_tab.tree_exited.connect(func(): config_tabs.erase(new_tab))
	config_tabs.append(new_tab)

	var keys: Array[int] = [new_tab.index]
	new_tab.update_server.connect(send_updates.bind(keys))
	new_tab.request_delete.connect(delete_tab.bind(new_tab.index))

	tabs.add_child.call_deferred(new_tab, true)
	tabs.set_current_tab.call_deferred(tabs.get_child_count())
	return new_tab

func delete_tab(index: int) -> void:
	Archipelago.send_command("Set", {
		"key": DATASTORAGE_KEY,
		"default": {},
		"want_reply": false,
		"operations": [
			{
				"operation": "pop",
				"value": str(index)
			}
		]
	})
	config_tabs.pop_at(index).queue_free()
