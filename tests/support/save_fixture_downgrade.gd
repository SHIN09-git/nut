class_name SaveFixtureDowngrade
extends RefCounted


static func strip_r12_fields(envelope: Dictionary) -> void:
	var habitat: Variant = envelope["frozen_config_bundle"].get("habitat")
	if typeof(habitat) == TYPE_DICTIONARY:
		var progression: Variant = habitat.get("act1_progression_config")
		if typeof(progression) == TYPE_DICTIONARY:
			progression.erase("finale_stable_ticks")
			progression.erase("final_report_observation_card_id")
	var state: Dictionary = envelope["state_payload"]
	var act1: Variant = state.get("act1")
	if typeof(act1) == TYPE_DICTIONARY:
		act1.erase("finale_stable_ticks")
		act1.erase("final_report_generated_tick")
	var cards: Variant = state.get("unlocked_observation_card_ids")
	if typeof(cards) == TYPE_ARRAY:
		cards.erase("glass_observation_report")
	var campaign: Variant = state.get("campaign")
	if typeof(campaign) != TYPE_DICTIONARY:
		return
	for evidence_id: String in [
		"first_worker_history_reviewed",
		"key_interventions_reviewed",
		"final_layout_stable",
		"long_term_colony_pattern",
	]:
		(campaign["collected_evidence_ids"] as Array).erase(evidence_id)
	(campaign["confirmed_inference_ids"] as Array).erase(
		"layout_shapes_long_term_behavior"
	)
	if (
		int(campaign.get("chapter", -1))
		== CampaignState.Chapter.ACT1_STABLE_COLONY_SUMMARY
	):
		campaign["chapter"] = (
			CampaignState.Chapter.ACT1_MODULAR_MIGRATION
		)
		campaign["completed_chapter_count"] = 5
		campaign["status"] = CampaignState.Status.COMPLETED
		campaign["campaign_completed_tick"] = int(
			state.get("simulation_tick", 0)
		)


static func strip_r11_fields(envelope: Dictionary) -> void:
	strip_r12_fields(envelope)
	var habitat: Variant = envelope["frozen_config_bundle"].get("habitat")
	if typeof(habitat) == TYPE_DICTIONARY:
		var progression: Variant = habitat.get("act1_progression_config")
		if typeof(progression) == TYPE_DICTIONARY:
			progression.erase("core_migration_stable_ticks")
		var catalog: Variant = habitat.get("facility_catalog_config")
		if typeof(catalog) == TYPE_DICTIONARY:
			var facility_types: Array = []
			for type_data: Dictionary in catalog.get(
				"facility_types",
				[]
			):
				if (
					String(type_data.get("type_id", ""))
					!= "dual_chamber_nest"
				):
					facility_types.append(type_data)
			catalog["facility_types"] = facility_types
			var initial_supplies: Array = []
			for supply: Dictionary in catalog.get("initial_supplies", []):
				if (
					String(supply.get("type_id", ""))
					!= "dual_chamber_nest"
				):
					initial_supplies.append(supply)
			catalog["initial_supplies"] = initial_supplies
	var state: Dictionary = envelope["state_payload"]
	var layout: Variant = state.get("layout")
	if typeof(layout) == TYPE_DICTIONARY:
		for facility: Dictionary in layout.get("facilities", []):
			facility.erase("secondary_zone_id")
		var supplies: Array = []
		for supply: Dictionary in layout.get("supplies", []):
			if (
				String(supply.get("type_id", ""))
				!= "dual_chamber_nest"
			):
				supplies.append(supply)
		layout["supplies"] = supplies
	var campaign: Variant = state.get("campaign")
	if (
		typeof(campaign) == TYPE_DICTIONARY
		and int(campaign.get("chapter", -1))
			== CampaignState.Chapter.ACT1_MODULAR_MIGRATION
	):
		campaign["chapter"] = (
			CampaignState.Chapter.ACT1_ENVIRONMENT_MANAGEMENT
		)
		campaign["completed_chapter_count"] = 4
		campaign["status"] = CampaignState.Status.COMPLETED
		campaign["campaign_completed_tick"] = int(
			state.get("simulation_tick", 0)
		)
		var unlocks: Array = (
			campaign.get("unlocked_facility_type_ids", []) as Array
		)
		unlocks.erase("dual_chamber_nest")


static func strip_r10_fields(envelope: Dictionary) -> void:
	strip_r11_fields(envelope)
	var habitat: Variant = envelope["frozen_config_bundle"].get("habitat")
	if typeof(habitat) == TYPE_DICTIONARY:
		habitat.erase("act1_progression_config")
		var catalog: Variant = habitat.get("facility_catalog_config")
		if typeof(catalog) == TYPE_DICTIONARY:
			var facility_types: Array = []
			for type_data: Dictionary in catalog.get(
				"facility_types",
				[]
			):
				if String(type_data.get("type_id", "")) == "connector_elbow":
					continue
				if String(type_data.get("type_id", "")) != "test_tube_nest":
					facility_types.append(type_data)
					continue
				type_data["unlock_type_id"] = "test_tube_nest"
				type_data["allowed_orientations"] = [0]
				type_data["requires_connection"] = false
				type_data["player_removable"] = false
				var effect: Dictionary = type_data.get("effect_config", {})
				effect["initial_humidity"] = 0.66
				effect["initial_light_exposure"] = 0.78
				effect["initial_pollution"] = 0.02
				facility_types.append(type_data)
			catalog["facility_types"] = facility_types
			var initial_supplies: Array = []
			for supply: Dictionary in catalog.get("initial_supplies", []):
				if String(supply.get("type_id", "")) not in [
					"test_tube_nest",
					"connector_elbow",
				]:
					initial_supplies.append(supply)
			catalog["initial_supplies"] = initial_supplies
	var state: Dictionary = envelope["state_payload"]
	var act1: Variant = state.get("act1")
	if typeof(act1) == TYPE_DICTIONARY:
		act1.erase("environment_stable_ticks")
	var layout: Variant = state.get("layout")
	if typeof(layout) == TYPE_DICTIONARY:
		var supplies: Array = []
		for supply: Dictionary in layout.get("supplies", []):
			if String(supply.get("type_id", "")) not in [
				"test_tube_nest",
				"connector_elbow",
			]:
				supplies.append(supply)
		layout["supplies"] = supplies


static func strip_r9_fields(envelope: Dictionary) -> void:
	strip_r10_fields(envelope)
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
