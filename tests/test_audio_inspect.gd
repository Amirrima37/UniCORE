extends SceneTree

# Comprehensive AudioServer Volume Scaling & Audio Settings Test Suite
# UniCORE Audio Engine Validation

var passed_count := 0
var failed_count := 0

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - %s" % [test_name, error_msg])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_approx_equal(actual: float, expected: float, tolerance: float, test_name: String) -> void:
	var diff := absf(actual - expected)
	if diff <= tolerance:
		print("  [PASS] %s (actual: %.4f, expected: %.4f, diff: %.6f)" % [test_name, actual, expected, diff])
		passed_count += 1
	else:
		print("  [FAIL] %s - actual %.4f != expected %.4f (diff: %.6f > tol: %.6f)" % [test_name, actual, expected, diff, tolerance])
		failed_count += 1

func _init() -> void:
	print("==================================================")
	print("Starting UniCORE AudioServer & Audio Settings Test Suite")
	print("==================================================")

	var settings_script = load("res://core/settings_manager.gd")
	assert_true(settings_script != null, "SettingsManager script loads")
	var settings_mgr: SettingsManager = settings_script.new()
	root.add_child(settings_mgr)

	# -------------------------------------------------------------------------
	# 1. Bus Architecture & Layout Audit
	# -------------------------------------------------------------------------
	print("\n--- 1. Audio Bus Layout Audit ---")
	print("Total AudioServer bus count: %d" % AudioServer.bus_count)
	for i in range(AudioServer.bus_count):
		print("  Bus %d: '%s' (send: '%s', solo: %s, mute: %s, db: %.2f)" % [
			i,
			AudioServer.get_bus_name(i),
			AudioServer.get_bus_send(i),
			AudioServer.is_bus_solo(i),
			AudioServer.is_bus_mute(i),
			AudioServer.get_bus_volume_db(i)
		])

	assert_true(AudioServer.bus_count >= 4, "AudioServer has at least 4 buses configured")
	
	var master_idx := AudioServer.get_bus_index("Master")
	var music_idx := AudioServer.get_bus_index("Music")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	var ui_idx := AudioServer.get_bus_index("UI")

	assert_true(master_idx == 0, "'Master' bus exists at index 0")
	assert_true(music_idx >= 0, "'Music' bus exists in AudioServer")
	assert_true(sfx_idx >= 0, "'SFX' bus exists in AudioServer")
	assert_true(ui_idx >= 0, "'UI' bus exists in AudioServer")

	if music_idx >= 0:
		assert_true(AudioServer.get_bus_send(music_idx) == "Master", "'Music' bus routes to 'Master'")
	if sfx_idx >= 0:
		assert_true(AudioServer.get_bus_send(sfx_idx) == "Master", "'SFX' bus routes to 'Master'")
	if ui_idx >= 0:
		assert_true(AudioServer.get_bus_send(ui_idx) == "Master", "'UI' bus routes to 'Master'")

	# Verify idempotency of ensure_audio_buses
	var count_before := AudioServer.bus_count
	settings_mgr.ensure_audio_buses()
	assert_true(AudioServer.bus_count == count_before, "ensure_audio_buses is idempotent (no duplicate buses)")

	# -------------------------------------------------------------------------
	# 2. Volume Scaling (linear slider to dB conversion using linear_to_db)
	# -------------------------------------------------------------------------
	print("\n--- 2. Volume Scaling (linear_to_db conversion) ---")
	
	# Test 1.0 (100% slider = 0.0 dB)
	settings_mgr.set_master_volume(1.0, false)
	assert_false(AudioServer.is_bus_mute(master_idx), "Volume 1.0 is NOT muted")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_idx), 0.0, 0.001, "Volume 1.0 converts to 0.0 dB")

	# Test 0.75 (75% slider ≈ -2.4988 dB)
	var expected_db_75 := linear_to_db(0.75)
	settings_mgr.set_master_volume(0.75, false)
	assert_false(AudioServer.is_bus_mute(master_idx), "Volume 0.75 is NOT muted")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_idx), expected_db_75, 0.001, "Volume 0.75 converts accurately to linear_to_db(0.75)")

	# Test 0.5 (50% slider ≈ -6.0206 dB)
	var expected_db_50 := linear_to_db(0.5)
	settings_mgr.set_master_volume(0.5, false)
	assert_false(AudioServer.is_bus_mute(master_idx), "Volume 0.5 is NOT muted")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_idx), expected_db_50, 0.001, "Volume 0.5 converts accurately to -6.02 dB")

	# Test 0.25 (25% slider ≈ -12.0412 dB)
	var expected_db_25 := linear_to_db(0.25)
	settings_mgr.set_master_volume(0.25, false)
	assert_false(AudioServer.is_bus_mute(master_idx), "Volume 0.25 is NOT muted")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_idx), expected_db_25, 0.001, "Volume 0.25 converts accurately to -12.04 dB")

	# Test 0.1 (10% slider = -20.0 dB)
	var expected_db_10 := linear_to_db(0.1)
	settings_mgr.set_master_volume(0.1, false)
	assert_false(AudioServer.is_bus_mute(master_idx), "Volume 0.1 is NOT muted")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_idx), expected_db_10, 0.001, "Volume 0.1 converts accurately to -20.0 dB")

	# Test 0.01 (1% slider = -40.0 dB)
	var expected_db_01 := linear_to_db(0.01)
	settings_mgr.set_master_volume(0.01, false)
	assert_false(AudioServer.is_bus_mute(master_idx), "Volume 0.01 is NOT muted")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_idx), expected_db_01, 0.001, "Volume 0.01 converts accurately to -40.0 dB")

	# Test monotonic dB scaling
	var steps := [0.05, 0.15, 0.3, 0.6, 0.9, 1.0]
	var last_db := -999.0
	var monotonic := true
	for s in steps:
		settings_mgr.set_master_volume(s, false)
		var current_db := AudioServer.get_bus_volume_db(master_idx)
		if current_db <= last_db:
			monotonic = false
		last_db = current_db
	assert_true(monotonic, "dB volume scaling is strictly monotonic with slider value")

	# -------------------------------------------------------------------------
	# 3. Mute & Edge Cases (Zero, Negative, Exceeding Maximum, NaN/Inf)
	# -------------------------------------------------------------------------
	print("\n--- 3. Mute & Edge Cases ---")

	# Edge Case 1: Slider exactly 0.0
	settings_mgr.set_master_volume(0.0, false)
	assert_true(AudioServer.is_bus_mute(master_idx), "Slider 0.0 sets AudioServer.set_bus_mute to true")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_idx), -80.0, 0.001, "Slider 0.0 sets volume to -80.0 dB")
	assert_true(settings_mgr.get_bus_volume("Master") == 0.0, "Stored setting for slider 0.0 is 0.0")

	# Edge Case 2: Near-zero below mute threshold (0.00005 <= 0.0001)
	settings_mgr.set_master_volume(0.00005, false)
	assert_true(AudioServer.is_bus_mute(master_idx), "Near-zero value (0.00005) triggers mute")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_idx), -80.0, 0.001, "Near-zero value sets -80.0 dB")

	# Edge Case 3: Just above mute threshold (0.0005)
	settings_mgr.set_master_volume(0.0005, false)
	assert_false(AudioServer.is_bus_mute(master_idx), "Value above threshold (0.0005) is unmuted")
	assert_true(AudioServer.get_bus_volume_db(master_idx) > -80.0, "Value above threshold has dB > -80.0 dB")

	# Edge Case 4: Negative volume (-0.5)
	settings_mgr.set_master_volume(-0.5, true)
	assert_true(AudioServer.is_bus_mute(master_idx), "Negative volume (-0.5) sets bus mute to true")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_idx), -80.0, 0.001, "Negative volume sets volume to -80.0 dB")
	assert_true(settings_mgr.get_setting("audio", "master_volume") == 0.0, "Negative volume clamps stored setting to 0.0 (not negative)")

	# Edge Case 5: Large negative volume (-100.0)
	settings_mgr.set_master_volume(-100.0, true)
	assert_true(AudioServer.is_bus_mute(master_idx), "Large negative (-100.0) sets bus mute to true")
	assert_true(settings_mgr.get_setting("audio", "master_volume") == 0.0, "Large negative clamps stored setting to 0.0")

	# Edge Case 6: Exceeding maximum (1.5)
	settings_mgr.set_master_volume(1.5, true)
	assert_false(AudioServer.is_bus_mute(master_idx), "Exceeding value (1.5) is unmuted")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_idx), 0.0, 0.001, "Exceeding value (1.5) clamps to 0.0 dB max")
	assert_true(settings_mgr.get_setting("audio", "master_volume") == 1.0, "Exceeding value (1.5) clamps stored setting to 1.0")

	# Edge Case 7: Large exceeding value (100.0)
	settings_mgr.set_master_volume(100.0, true)
	assert_false(AudioServer.is_bus_mute(master_idx), "Large exceeding value (100.0) is unmuted")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_idx), 0.0, 0.001, "Large exceeding value clamps to 0.0 dB")
	assert_true(settings_mgr.get_setting("audio", "master_volume") == 1.0, "Large exceeding value clamps stored setting to 1.0")

	# Edge Case 8: NaN and INF handling
	settings_mgr.set_master_volume(NAN, false)
	assert_true(AudioServer.is_bus_mute(master_idx), "NAN input safely mutes bus without engine error")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_idx), -80.0, 0.001, "NAN input safely sets -80.0 dB")

	settings_mgr.set_master_volume(INF, false)
	assert_true(AudioServer.is_bus_mute(master_idx), "INF input safely mutes bus without engine error")

	# Edge Case 9: Rapid slider toggle 0.0 -> 1.0 -> 0.0 -> 0.8
	settings_mgr.set_master_volume(0.0, false)
	assert_true(AudioServer.is_bus_mute(master_idx), "Rapid toggle: 0.0 is muted")
	settings_mgr.set_master_volume(1.0, false)
	assert_false(AudioServer.is_bus_mute(master_idx), "Rapid toggle: 1.0 is unmuted")
	settings_mgr.set_master_volume(0.0, false)
	assert_true(AudioServer.is_bus_mute(master_idx), "Rapid toggle: 0.0 is muted again")
	settings_mgr.set_master_volume(0.8, false)
	assert_false(AudioServer.is_bus_mute(master_idx), "Rapid toggle: 0.8 is unmuted")

	# -------------------------------------------------------------------------
	# 4. Multi-Bus Independent Volume & UI Sound Toggle
	# -------------------------------------------------------------------------
	print("\n--- 4. Multi-Bus Control & UI Sound Toggle ---")
	
	# Set individual bus volumes
	settings_mgr.set_master_volume(0.8, true)
	settings_mgr.set_music_volume(0.6, true)
	settings_mgr.set_sfx_volume(0.4, true)
	settings_mgr.set_ui_volume(0.7, true)

	assert_approx_equal(AudioServer.get_bus_volume_db(music_idx), linear_to_db(0.6), 0.001, "Music bus set to 0.6 dB")
	assert_approx_equal(AudioServer.get_bus_volume_db(sfx_idx), linear_to_db(0.4), 0.001, "SFX bus set to 0.4 dB")
	assert_approx_equal(AudioServer.get_bus_volume_db(ui_idx), linear_to_db(0.7), 0.001, "UI bus set to 0.7 dB")

	# Mute music bus individually
	settings_mgr.set_music_volume(0.0, true)
	assert_true(AudioServer.is_bus_mute(music_idx), "Music bus muted at 0.0")
	assert_false(AudioServer.is_bus_mute(sfx_idx), "SFX bus remains unmuted when Music is muted")
	assert_false(AudioServer.is_bus_mute(ui_idx), "UI bus remains unmuted when Music is muted")
	assert_false(AudioServer.is_bus_mute(master_idx), "Master bus remains unmuted when Music is muted")

	# Test UI Sound Enabled toggle
	assert_true(settings_mgr.is_ui_sound_enabled(), "UI sound is initially enabled")
	settings_mgr.set_ui_sound_enabled(false, true)
	assert_false(settings_mgr.is_ui_sound_enabled(), "UI sound is now disabled")
	assert_true(AudioServer.is_bus_mute(ui_idx), "Disabling ui_sound_enabled mutes UI audio bus")

	# Changing UI volume while disabled keeps bus muted
	settings_mgr.set_ui_volume(0.9, true)
	assert_true(AudioServer.is_bus_mute(ui_idx), "UI bus stays muted while ui_sound_enabled is false")

	# Re-enabling UI sound restores unmute
	settings_mgr.set_ui_sound_enabled(true, true)
	assert_true(settings_mgr.is_ui_sound_enabled(), "UI sound re-enabled")
	assert_false(AudioServer.is_bus_mute(ui_idx), "UI bus unmuted when ui_sound_enabled restored to true")
	assert_approx_equal(AudioServer.get_bus_volume_db(ui_idx), linear_to_db(0.9), 0.001, "UI bus restored to 0.9 dB")

	# -------------------------------------------------------------------------
	# 5. Missing Bus Resilience (No crash if bus is missing)
	# -------------------------------------------------------------------------
	print("\n--- 5. Missing Bus Resilience ---")
	
	# Verify that calls with non-existent bus name do not crash or raise fatal errors
	var non_existent := "NonExistentBus_XYZ"
	assert_true(AudioServer.get_bus_index(non_existent) == -1, "Verified bus does not exist in AudioServer")

	var safe_db = settings_mgr.get_bus_volume_db(non_existent)
	assert_true(safe_db == -80.0, "get_bus_volume_db for missing bus returns -80.0 safely without crash")

	var safe_mute = settings_mgr.is_bus_muted(non_existent)
	assert_true(safe_mute == true, "is_bus_muted for missing bus returns true safely without crash")

	settings_mgr.set_bus_volume(non_existent, 0.5, false)
	assert_true(true, "set_bus_volume for missing bus handled safely without crash")

	settings_mgr.set_bus_mute(non_existent, true)
	assert_true(true, "set_bus_mute for missing bus handled safely without crash")

	var safe_stored = settings_mgr.get_bus_volume(non_existent, 0.5)
	assert_true(safe_stored == 0.5, "get_bus_volume for unknown bus returns specified default safely")

	# -------------------------------------------------------------------------
	# 6. Settings Persistence & Disk Serialization Roundtrip
	# -------------------------------------------------------------------------
	print("\n--- 6. Audio Settings Disk Persistence Roundtrip ---")
	
	settings_mgr.set_master_volume(0.85, true)
	settings_mgr.set_music_volume(0.45, true)
	settings_mgr.set_sfx_volume(0.65, true)
	settings_mgr.set_ui_volume(0.55, true)
	settings_mgr.set_ui_sound_enabled(true, true)
	
	var saved := settings_mgr.save_settings()
	assert_true(saved, "Settings saved to disk successfully")

	# Create clean fresh SettingsManager instance to test disk load
	var fresh_mgr: SettingsManager = settings_script.new()
	root.add_child(fresh_mgr)
	fresh_mgr.setup(null)

	assert_approx_equal(fresh_mgr.get_bus_volume("Master"), 0.85, 0.001, "Persisted master_volume loaded correctly")
	assert_approx_equal(fresh_mgr.get_bus_volume("Music"), 0.45, 0.001, "Persisted music_volume loaded correctly")
	assert_approx_equal(fresh_mgr.get_bus_volume("SFX"), 0.65, 0.001, "Persisted sfx_volume loaded correctly")
	assert_approx_equal(fresh_mgr.get_bus_volume("UI"), 0.55, 0.001, "Persisted ui_volume loaded correctly")
	assert_true(fresh_mgr.is_ui_sound_enabled() == true, "Persisted ui_sound_enabled loaded correctly")

	# Verify AudioServer after apply_all_settings matches loaded values
	assert_approx_equal(AudioServer.get_bus_volume_db(master_idx), linear_to_db(0.85), 0.001, "AudioServer Master bus matches loaded 0.85 dB")
	assert_approx_equal(AudioServer.get_bus_volume_db(music_idx), linear_to_db(0.45), 0.001, "AudioServer Music bus matches loaded 0.45 dB")
	assert_approx_equal(AudioServer.get_bus_volume_db(sfx_idx), linear_to_db(0.65), 0.001, "AudioServer SFX bus matches loaded 0.65 dB")
	assert_approx_equal(AudioServer.get_bus_volume_db(ui_idx), linear_to_db(0.55), 0.001, "AudioServer UI bus matches loaded 0.55 dB")

	# Clean up to default volume 0.8
	fresh_mgr.set_master_volume(0.8, true)
	fresh_mgr.set_music_volume(0.8, true)
	fresh_mgr.set_sfx_volume(0.8, true)
	fresh_mgr.set_ui_volume(0.8, true)
	fresh_mgr.set_ui_sound_enabled(true, true)
	fresh_mgr.save_settings()

	# -------------------------------------------------------------------------
	# Summary
	# -------------------------------------------------------------------------
	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		quit(0)
	else:
		quit(1)
