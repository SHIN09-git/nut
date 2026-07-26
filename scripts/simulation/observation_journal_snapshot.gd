class_name ObservationJournalSnapshot
extends RefCounted

var events: Array[ObservationEvent] = []
var unlocked_card_ids: Array[StringName] = []


func _init(
	new_events: Array[ObservationEvent] = [],
	new_unlocked_card_ids: Array[StringName] = []
) -> void:
	for event: ObservationEvent in new_events:
		if event != null:
			events.append(event.copy_event())
	unlocked_card_ids.assign(new_unlocked_card_ids)
	unlocked_card_ids.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return String(first) < String(second)
	)


func has_card(card_id: StringName) -> bool:
	return unlocked_card_ids.has(card_id)
