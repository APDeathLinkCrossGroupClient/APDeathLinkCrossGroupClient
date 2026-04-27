class_name DLConfig

var sources: Array[String]
var dests: Array[String]
var count: int
var received: Array[float]

## Does not check 'received', as that's current "state", not configuration
func same_config(other: DLConfig) -> bool:
	if sources.size() != other.sources.size():
		return false
	if dests.size() != other.dests.size():
		return false
	if count != other.count:
		return false
	for src in sources:
		if src not in other.sources:
			return false
	for src in other.sources:
		if src not in sources:
			return false
	for dest in dests:
		if dest not in other.dests:
			return false
	for dest in other.dests:
		if dest not in dests:
			return false
	return true

func is_invalid() -> bool:
	return sources.is_empty() or dests.is_empty() or count <= 0

func handle_deathlink(group: String, packet: Dictionary) -> bool:
	if is_invalid(): return false
	if group not in sources: return false
	var time: float = packet.get("time", 0.0)
	for t in received:
		if absf(time - t) < 0.5:
			return false # ignore duplicate death
	received.append(time)
	if received.size() >= count:
		for q in count:
			received.pop_front()
		packet["tags"] = dests.map(group_to_tag) # Reroute the packet to the destination tags
		Archipelago.send_command("Bounce", packet)
	return true

## Updates configuration data
func give_config(other: DLConfig) -> void:
	other.sources.assign(sources)
	other.dests.assign(dests)
	other.count = count

## Updates non-configuration data
func give_data(other: DLConfig) -> void:
	other.received.assign(received)

func to_config_dict() -> Dictionary:
	return {
		"sources": sources,
		"dests": dests,
		"count": count,
	}
func to_received_dict() -> Dictionary:
	return {
		"received": received,
	}
func to_dict() -> Dictionary:
	return to_config_dict().merged(to_received_dict())

static func from_dict(dict: Dictionary) -> DLConfig:
	var config := DLConfig.new()
	config.sources.assign(dict.get("sources", []))
	config.dests.assign(dict.get("dests", []))
	config.count = dict.get("count", 1)
	config.received.assign(dict.get("received", []))
	return config

const DL_PREFIX := "DeathLink"
static func group_to_tag(group: String) -> String:
	return DL_PREFIX + group

static func tag_to_group(tag: String) -> String:
	assert(is_dl_tag(tag))
	return tag.substr(DL_PREFIX.length())

static func is_dl_tag(tag: String) -> bool:
	return tag.begins_with(DL_PREFIX)
