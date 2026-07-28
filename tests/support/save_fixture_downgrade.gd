class_name SaveFixtureDowngrade
extends RefCounted


static func strip_r9_fields(envelope: Dictionary) -> void:
	var habitat: Variant = envelope["frozen_config_bundle"].get("habitat")
	if typeof(habitat) == TYPE_DICTIONARY:
		habitat.erase("colony_work_config")
		for zone: Dictionary in habitat.get("zones", []):
			zone.erase("initially_discovered")
	var state: Dictionary = envelope["state_payload"]
	state.erase("colony_work")
	var queen: Variant = state.get("queen")
	if typeof(queen) == TYPE_DICTIONARY:
		queen.erase("zone_id")
		queen.erase("zone_entered_tick")
	for zone: Dictionary in state.get("zones", []):
		zone.erase("discovered")
		zone.erase("discovered_tick")
	for ant: Dictionary in state.get("ants", []):
		ant.erase("waste_cleanup_task")
		ant.erase("scout_task")
		ant.erase("migration_task")
