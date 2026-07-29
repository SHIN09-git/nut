class_name ProductionAssetsTestSuite
extends RefCounted

const TITLE_TEXTURE_PATH: String = (
	"res://assets/production/backgrounds/title_observation_desk.png"
)
const TITLE_TEXTURE_SHA256: String = (
	"642769e2be9a86f1d84037536e7dcc530d195537b854156872de77a2692cdf10"
)
const ASSET_LEDGER_PATH: String = (
	"res://docs/production/asset_ledger.csv"
)

var _assertion_count: int = 0
var _failure_count: int = 0


func run(scene_root: Node) -> void:
	_test_title_asset_and_shell(scene_root)
	_test_asset_ledger()
	_test_facility_catalog_has_production_styles()
	_test_chapter_markers()
	_test_report_seal()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_title_asset_and_shell(scene_root: Node) -> void:
	_expect_true(
		FileAccess.file_exists(TITLE_TEXTURE_PATH),
		"title production texture exists"
	)
	var texture: Texture2D = load(TITLE_TEXTURE_PATH) as Texture2D
	_expect_true(texture != null, "title production texture imports")
	if texture != null:
		_expect_true(
			float(texture.get_width()) / float(texture.get_height()) > 1.7,
			"title production texture preserves a wide safe crop"
		)
	_expect_string(
		FileAccess.get_sha256(TITLE_TEXTURE_PATH),
		TITLE_TEXTURE_SHA256,
		"title production texture hash matches the ledger evidence"
	)
	var scene: PackedScene = load(
		"res://scenes/app/game_shell.tscn"
	) as PackedScene
	var shell: Control = scene.instantiate() as Control
	scene_root.add_child(shell)
	var backdrop: TextureRect = shell.get_node(
		"ShellOverlay/TitleBackdrop"
	) as TextureRect
	_expect_true(
		backdrop != null and backdrop.texture != null,
		"title shell consumes the approved production texture"
	)
	_expect_true(
		shell.theme != null
		and shell.theme.has_stylebox(&"normal", &"Button")
		and shell.theme.has_stylebox(&"focus", &"Button"),
		"title shell exposes production button and focus materials"
	)
	shell.queue_free()


func _test_asset_ledger() -> void:
	_expect_true(
		FileAccess.file_exists(ASSET_LEDGER_PATH),
		"production asset ledger exists"
	)
	var content: String = FileAccess.get_file_as_string(
		ASSET_LEDGER_PATH
	)
	var lines: PackedStringArray = content.split("\n", false)
	var asset_count: int = 0
	for index: int in range(1, lines.size()):
		var line: String = lines[index].strip_edges()
		if line.is_empty():
			continue
		var columns: PackedStringArray = line.split(",", true)
		_expect_int(
			columns.size(),
			17,
			"production asset row keeps the frozen ledger schema"
		)
		if columns.size() != 17:
			continue
		asset_count += 1
		var repository_path: String = String(columns[2])
		_expect_true(
			not repository_path.is_empty()
			and FileAccess.file_exists("res://" + repository_path),
			"approved production asset path exists"
		)
		_expect_true(
			not repository_path.to_lower().begins_with("sucai/"),
			"production ledger excludes reference-only material"
		)
		_expect_string(
			String(columns[13]),
			"approved_production",
			"tracked production asset is approved for production"
		)
		_expect_string(
			String(columns[7]),
			"yes",
			"tracked production asset allows commercial game use"
		)
		_expect_string(
			String(columns[10]),
			"yes",
			"tracked production asset allows build redistribution"
		)
	_expect_true(
		asset_count >= 18,
		"ledger covers the complete R14 visual and R15 audio packages"
	)
	_expect_true(
		not content.contains("example_placeholder"),
		"production ledger removed its example placeholder row"
	)


func _test_facility_catalog_has_production_styles() -> void:
	var catalog: FacilityCatalogData = load(
		"res://data/facilities/act1_layout_catalog.tres"
	) as FacilityCatalogData
	_expect_true(catalog != null and catalog.is_valid(), "facility catalog loads")
	var view: FacilityLayoutView = FacilityLayoutView.new()
	for facility: FacilityData in catalog.facility_types:
		_expect_true(
			view.has_production_style(facility.type_id),
			"catalog facility has a production visual style"
		)
	view.free()


func _test_chapter_markers() -> void:
	var view: ChapterArtView = ChapterArtView.new()
	for offset: int in 6:
		view.set_chapter(
			CampaignState.Chapter.ACT1_FOUNDING + offset
		)
		_expect_int(
			view.get_active_index(),
			offset,
			"chapter art exposes the current six-chapter marker"
		)
	view.free()


func _test_report_seal() -> void:
	var view: ObservationReportSealView = ObservationReportSealView.new()
	_expect_true(
		view != null,
		"final observation report exposes its production seal"
	)
	view.free()


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_record_failure(message, "true", "false")


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _expect_string(
	actual: String,
	expected: String,
	message: String
) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, expected, actual)


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
