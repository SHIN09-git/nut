class_name ForagingConfig
extends RefCounted

var discovery_delay_ticks: int
var outbound_travel_duration_ticks: int
var collection_duration_ticks: int
var return_travel_duration_ticks: int
var sharing_duration_ticks: int


static func from_data(foraging_data: ForagingData) -> ForagingConfig:
	if foraging_data == null or not foraging_data.is_valid():
		return null

	var config: ForagingConfig = ForagingConfig.new()
	config.discovery_delay_ticks = foraging_data.discovery_delay_ticks
	config.outbound_travel_duration_ticks = (
		foraging_data.outbound_travel_duration_ticks
	)
	config.collection_duration_ticks = foraging_data.collection_duration_ticks
	config.return_travel_duration_ticks = (
		foraging_data.return_travel_duration_ticks
	)
	config.sharing_duration_ticks = foraging_data.sharing_duration_ticks
	return config
