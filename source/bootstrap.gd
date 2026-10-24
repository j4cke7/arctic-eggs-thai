extends Node
# Created synchronously as an autoload, before the native main scene is loaded.
var package_directory = ""
var payload = {}
var manifest = {}
var watched = []
var fonts = {}
var failed = false
var startup_before_main = false
var initial_locale = ""
var probe_output = ""
var probe_records = []
var literal_sources = {}
var dialogue_owners = {}
var last_locale = ""
var counters = {}

func _init():
	package_directory = get_script().resource_path.get_base_dir()
	initial_locale = TranslationServer.get_locale()
	var tree = Engine.get_main_loop()
	startup_before_main = tree is SceneTree and tree.current_scene == null
	for index in range(OS.get_cmdline_user_args().size() - 1):
		if OS.get_cmdline_user_args()[index] == "--arctic-replace-probe":
			probe_output = OS.get_cmdline_user_args()[index + 1]
	initialize_service()

func is_english():
	return TranslationServer.get_locale().to_lower().replace("-", "_").get_slice("_", 0) == "en"

func fail(message):
	failed = true
	push_error("Arctic Thai replace-en: " + message)
	write_probe(false, message)
	Engine.get_main_loop().quit(2)

func initialize_service():
	if FileAccess.get_sha256(package_directory.path_join("manifest.json")) != String(ProjectSettings.get_setting("arctic_thai/manifest_sha256", "")):
		fail("Manifest pin mismatch")
		return
	manifest = JSON.parse_string(FileAccess.get_file_as_string(package_directory.path_join("manifest.json")))
	if manifest == null or manifest.schema != "arctic-replace-en-package/v1" or manifest.build != "18492481" or manifest.project_id != "7998b3ea-3044-4e4e-b5f0-fa0690d02b8d":
		fail("Unsupported manifest")
		return
	for name in manifest.artifacts:
		if name.contains("/") or name.contains("\\") or name.contains("..") or FileAccess.get_sha256(package_directory.path_join(name)) != manifest.artifacts[name]:
			fail("Artifact hash mismatch: " + name)
			return
	if FileAccess.get_sha256(OS.get_executable_path()) != manifest.exe_sha256 or FileAccess.get_sha256(OS.get_executable_path().get_base_dir().path_join("game.pck")) != manifest.pck_sha256:
		fail("Unsupported executable/PCK")
		return
	payload = JSON.parse_string(FileAccess.get_file_as_string(package_directory.path_join("payload.json")))
	if payload == null or payload.project_id != manifest.project_id or payload.plan_sha256 != manifest.plan_sha256:
		fail("Payload identity mismatch")
		return
	if not manifest.has("native_source_hashes") or manifest.native_source_hashes.is_empty():
		fail("Native identities required")
		return
	for resource in manifest.native_source_hashes:
		if FileAccess.get_sha256(resource) != manifest.native_source_hashes[resource]:
			fail("Native resource mismatch: " + resource)
			return
	# Patch before any native main-scene consumer/preload can cache the original script.
	for resource in manifest.script_patches:
		if not patch_script(resource, manifest.script_patches[resource]):
			return
	for role in ["Bold", "Regular", "Mirror"]:
		var name = "Sarabun-" + role + ".ttf" if role != "Mirror" else "ArcticThaiMirrorPrototype-Regular.ttf"
		var font = FontFile.new()
		font.allow_system_fallback = false
		if font.load_dynamic_font(package_directory.path_join(name)) != OK:
			fail("Font load failed: " + name)
			return
		fonts[role] = font

func _ready():
	if failed:
		return
	get_tree().node_added.connect(on_node_added)
	get_tree().process_frame.connect(refresh_properties)
	if not probe_output.is_empty():
		probe.call_deferred()

func patch_script(resource, recipe):
	if FileAccess.get_sha256(resource) != recipe.sha256:
		fail("Script hash mismatch: " + resource)
		return false
	var source = FileAccess.get_file_as_string(resource)
	for site in recipe.hook_counts:
		if source.count(site) != int(recipe.hook_counts[site]):
			fail("Manifest hook count mismatch: " + resource)
			return false
	var lines = source.split("\n")
	for literal in recipe.literals:
		var index = int(literal.line) - 1
		if index < 0 or index >= lines.size() or lines[index].count(literal.source) != 1:
			fail("Literal hook count: " + resource)
			return false
		if resource == "res://Tools/hungry_npc_canvas.gd":
			# Capture the full composition, retaining the native suffix identity.
			var count_expression = "1" if int(literal.line) == 26 else "(_total_feedable - _num_fed)"
			var expression = "\"1 \" + tr(" + literal.source + ")" if int(literal.line) == 26 else "(\"%d \" % (_total_feedable - _num_fed)) + tr(" + literal.source + ")"
			var assignment = "_display.text = " + expression
			if lines[index].count(assignment) != 1:
				fail("Counter composition hook mismatch")
				return false
			var call = "get_node(\"/root/ArcticThai\").set_counter(self, _display, " + count_expression + ", " + literal.source + ", " + literal.replacement + ")"
			lines[index] = lines[index].replace(assignment, call)
			continue
		var conditional = "get_node(\"/root/ArcticThai\").translate_literal(self, " + literal.source + ", " + literal.replacement + ")"
		lines[index] = lines[index].replace(literal.source, conditional)
	var patched = "\n".join(lines)
	var hooks = []
	if resource == "res://Tools/ActivityArea.gd":
		var site = "TranslationServer.translate(dialog[line_index])"
		if patched.count(site) != 2:
			fail("Activity translation hook count")
			return false
		patched = patched.replace(site, "_arctic_translate(dialog[line_index])")
		hooks = [
			["if !TranslationServer.get_locale() == \"en\":", "if not _arctic_scope().is_empty() or TranslationServer.get_locale() != \"en\":"],
			["func display_next_letter():\n", "func display_next_letter():\n\t_arctic_prepare_layout()\n"],
			["func go_to_end_of_line():\n", "func go_to_end_of_line():\n\t_arctic_prepare_layout()\n"],
			["\t\t\tcurrent_label.text += next_char\n\t\t\tletter_timing_and_audio(next_char)", "\t\t\tcurrent_label.text += next_char\n\t\t\t_arctic_refresh_text(processed_text, letter_index)\n\t\t\tletter_timing_and_audio(next_char)"],
			["\tcurrent_label.text += str(processed_text)\n\tis_line_complete = true\n", "\tcurrent_label.text += str(processed_text)\n\tis_line_complete = true\n\t_arctic_refresh_text(processed_text, processed_text.length())\n"]
		]
	elif resource == "res://Levels/Closet/Tutorial.gd":
		hooks = [["TranslationServer.translate(dialog_type[line])", "get_node(\"/root/ArcticThai\").translate_tutorial(self, dialog_type[line])"]]
	elif resource == "res://Stations/stab/raw/stab.gd":
		hooks = [["TranslationServer.translate(label_type)", "get_node(\"/root/ArcticThai\").translate_property(label, label_type)"], ["label.text = og_text", "label.text = get_node(\"/root/ArcticThai\").translate_property(label, og_text)"]]
	for hook in hooks:
		if patched.count(hook[0]) != 1:
			fail("Runtime hook count: " + resource)
			return false
		patched = patched.replace(hook[0], hook[1])
	if resource == "res://Tools/ActivityArea.gd":
		patched += "\n" + FileAccess.get_file_as_string(package_directory.path_join("arctic_replace_helper.gd"))
	var script = load(resource)
	script.source_code = patched
	if script.reload(true) != OK:
		fail("Runtime script compilation failed: " + resource)
		return false
	return true

func scopes_for(node):
	var matches = []
	var ancestor = node
	while ancestor != null:
		if not ancestor.scene_file_path.is_empty():
			var scene = String(ancestor.scene_file_path)
			var relative = str(ancestor.get_path_to(node))
			var scope = payload.scenes.get(scene, {}).get(relative, {})
			if not scope.is_empty():
				matches.push_front(scope)
		ancestor = ancestor.get_parent()
	return matches

func dialogue_scope(node):
	var result = {}
	for scope in scopes_for(node):
		for property in ["dialog", "completed_dialog"]:
			for english in scope.get(property, {}):
				if not result.has(english):
					result[english] = scope[property][english]
	return result

func translate_literal(node, english, thai):
	var identity = node.get_instance_id()
	if not literal_sources.has(identity):
		literal_sources[identity] = {"reference": weakref(node), "sources": {}, "translations": {}}
	literal_sources[identity].sources[thai] = english
	literal_sources[identity].translations[english] = thai
	return thai if is_english() else english

func set_counter(owner, label, count, source, thai):
	if not count is int or not source in ["still hungry", "person hungry", "people hungry"]:
		fail("Unsupported counter composition")
		return
	var identity = label.get_instance_id()
	var state = counters.get(identity, {})
	if state.is_empty():
		state = {"reference": weakref(label), "owner": weakref(owner), "font_state": {}, "presented": String(label.text)}
		counters[identity] = state
	state.count = count
	state.source = source
	state.thai = thai
	label.set_meta("arctic_counter_managed", true)
	render_counter(label, owner, state)

func render_counter(label, owner, state):
	# Translate only the suffix key, exactly as the native tr() expression does.
	var suffix = String(state.thai) if is_english() else String(owner.tr(state.source))
	state.presented = str(state.count) + " " + suffix
	label.text = state.presented
	if is_english():
		apply_font(label, state.font_state)
	else:
		restore_font(label, state.font_state)

func refresh_counters():
	for identity in counters.keys():
		var state = counters[identity]
		var label = state.reference.get_ref()
		var owner = state.owner.get_ref()
		if label == null or owner == null:
			counters.erase(identity)
			continue
		if String(label.text) != state.presented:
			# A value written outside the hooked native assignment belongs to the game.
			restore_font(label, state.font_state)
			label.remove_meta("arctic_counter_managed")
			counters.erase(identity)
			continue
		render_counter(label, owner, state)

func literal_translation(node, source):
	var ancestor = node
	while ancestor != null:
		var entry = literal_sources.get(ancestor.get_instance_id(), {})
		if not entry.is_empty() and entry.reference.get_ref() == ancestor and entry.translations.has(source):
			return entry.translations[source]
		ancestor = ancestor.get_parent()
	return source

func literal_source(node, presented):
	var ancestor = node
	while ancestor != null:
		var entry = literal_sources.get(ancestor.get_instance_id(), {})
		if not entry.is_empty() and entry.reference.get_ref() == ancestor and entry.sources.has(presented):
			return entry.sources[presented]
		ancestor = ancestor.get_parent()
	return ""

func translate_tutorial(node, english):
	if not is_english():
		return TranslationServer.translate(english)
	for scope in scopes_for(node):
		for property in ["controller_dialog", "mouse_dialog"]:
			if scope.get(property, {}).has(english):
				return scope[property][english]
	return english

func translate_property(node, english, property = "text"):
	if not is_english():
		return TranslationServer.translate(english)
	for scope in scopes_for(node):
		if scope.get(property, {}).has(english):
			return scope[property][english]
	return english

func on_node_added(node):
	node.ready.connect(after_ready.bind(node), CONNECT_ONE_SHOT)

func after_ready(node):
	if node is Label or node is Button or node is Label3D or node is LineEdit or node is RichTextLabel:
		watched.append({"reference": weakref(node), "properties": {}, "font_state": {}})
	validate_arrays.call_deferred(node)

func validate_arrays(node):
	if not is_instance_valid(node) or get_tree().current_scene == null:
		return
	var ancestors = []
	var ancestor = node
	while ancestor != null:
		if not ancestor.scene_file_path.is_empty():
			ancestors.push_front(ancestor)
		ancestor = ancestor.get_parent()
	var checked = {}
	for owner in ancestors:
		var relative = str(owner.get_path_to(node))
		for row in payload.rows:
			if owner.scene_file_path != row.resource or relative != row.node or checked.has(row.property):
				continue
			var array = node.get(row.property)
			if not array is Array or int(row.index) >= array.size() or array[int(row.index)] != row.source:
				fail("Original dialogue array/index mismatch: " + row.id)
				return
		for row in payload.rows:
			if owner.scene_file_path == row.resource and relative == row.node:
				checked[row.property] = true

func regular_font(node):
	if node.has_meta("arctic_regular_font"):
		return node.get_meta("arctic_regular_font")
	var original = node.font if node is Label3D else node.get_theme_font("normal_font" if node is RichTextLabel else "font")
	var combined = original.duplicate()
	combined.fallbacks = [fonts.Mirror if original.resource_path.to_lower().contains("breymont") else fonts.Regular]
	node.set_meta("arctic_regular_font", combined)
	return combined

func contains_thai(text):
	for character in text:
		if character.unicode_at(0) >= 0x0e00 and character.unicode_at(0) <= 0x0e7f:
			return true
	return false

func wrap_words(node, text):
	if not payload.word_boundaries.has(text):
		return text
	var width = 0.0
	var font_size = 16
	if node is Label3D:
		if node.autowrap_mode == TextServer.AUTOWRAP_OFF:
			return text
		width = node.width
		font_size = node.font_size
	elif node is Label:
		if node.autowrap_mode == TextServer.AUTOWRAP_OFF:
			return text
		width = node.size.x
		font_size = node.get_theme_font_size("font_size")
	else:
		return text
	if width <= 0:
		return text
	var font = regular_font(node)
	var line = ""
	var result = ""
	for token in payload.word_boundaries[text]:
		if token == "\n":
			result += line + "\n"
			line = ""
			continue
		var measurement = TextLine.new()
		measurement.add_string(line + token, font, font_size, "th")
		if not line.is_empty() and measurement.get_size().x > width:
			result += line + "\n"
			line = ""
		line += token
	return result + line

func capture_font(node):
	if node is Label3D:
		return {"original": node.font, "installed": null}
	var key = "normal_font" if node is RichTextLabel else "font"
	return {"key": key, "had_override": node.has_theme_font_override(key), "original": node.get_theme_font(key), "installed": null}

func apply_font(node, state):
	if state.is_empty():
		state.merge(capture_font(node))
	var replacement = regular_font(node)
	if node is Label3D:
		node.font = replacement
	else:
		node.add_theme_font_override(state.key, replacement)
	state.installed = replacement

func restore_font(node, state):
	if state.is_empty() or state.installed == null:
		return
	if node is Label3D:
		if node.font == state.installed:
			node.font = state.original
	elif node.get_theme_font(state.key) == state.installed:
		if state.had_override:
			node.add_theme_font_override(state.key, state.original)
		else:
			node.remove_theme_font_override(state.key)
	state.installed = null

func refresh_properties():
	if payload.is_empty() or failed:
		return
	refresh_counters()
	var locale = TranslationServer.get_locale()
	if locale != last_locale:
		last_locale = locale
		for identity in dialogue_owners.keys():
			var owner = dialogue_owners[identity].get_ref()
			if owner == null:
				dialogue_owners.erase(identity)
			else:
				owner._arctic_locale_changed()
	for identity in literal_sources.keys():
		if literal_sources[identity].reference.get_ref() == null:
			literal_sources.erase(identity)
	var alive = []
	for entry in watched:
		var node = entry.reference.get_ref()
		if node == null:
			continue
		alive.append(entry)
		if node.has_meta("arctic_dialogue_managed") or node.has_meta("arctic_counter_managed"):
			continue
		var owns_thai = false
		for property in ["text", "placeholder_text", "tooltip_text"]:
			if not property in node:
				continue
			var live = String(node.get(property))
			var state = entry.properties.get(property, {})
			if not state.is_empty() and live != state.presented:
				# The game owns an external update; discard our previous presentation.
				entry.properties.erase(property)
				state = {}
			if state.is_empty():
				var original_literal = literal_source(node, live)
				if not original_literal.is_empty():
					state = {"source": original_literal, "presented": live, "literal": true}
					entry.properties[property] = state
			if not is_english():
				if not state.is_empty() and live == state.presented:
					node.set(property, state.source)
					entry.properties.erase(property)
				continue
			# Look up the original source, never the Thai presentation.
			var source = String(state.source) if not state.is_empty() else live
			var translated = String(literal_translation(node, source))
			var literal = translated != source
			if not literal:
				translated = String(translate_property(node, source, property))
			if translated == source or not contains_thai(translated):
				continue
			apply_font(node, entry.font_state)
			if property == "text":
				translated = wrap_words(node, translated)
			entry.properties[property] = {"source": source, "presented": translated, "literal": literal}
			node.set(property, translated)
			owns_thai = true
		if not owns_thai:
			restore_font(node, entry.font_state)
	watched = alive


# Appended to bootstrap.gd by the package builder; optional ordinary-startup probe.
func write_probe(passed, error = ""):
	if probe_output.is_empty():
		return
	var file = FileAccess.open(probe_output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"schema": "arctic-replace-en-probe/v1", "passed": passed, "error": error, "checks": probe_records, "initial_locale": initial_locale, "startup_before_main": startup_before_main, "manifest_sha256": FileAccess.get_sha256(package_directory.path_join("manifest.json"))}))

func check_probe(ok, name, detail):
	probe_records.append({"passed": ok, "name": name, "detail": detail})
	if not ok:
		fail("Probe failed: " + name)
	return ok

func find_script_node(resource):
	if get_tree().current_scene == null:
		return null
	for node in get_tree().current_scene.find_children("*", "", true, false):
		if node.get_script() != null and node.get_script().resource_path == resource:
			return node
	return null

func probe():
	if not check_probe(startup_before_main and get_node("/root/ArcticThai") == self, "autoload-before-main", {"service_path": str(get_path())}):
		return
	var deadline = Time.get_ticks_msec() + 60000
	var menu = null
	while Time.get_ticks_msec() < deadline:
		menu = find_script_node("res://UI/main_menu.gd")
		if menu != null and menu.is_node_ready():
			break
		await get_tree().process_frame
	if not check_probe(menu != null and menu.is_node_ready(), "real-menu-ready", "res://UI/main_menu.gd"):
		return
	# Invoke the original assignment, without save/load/delete operations.
	menu._load_menu.visible = true
	menu._selected_saveslot_id = -1
	var static_entry = {}
	for locale in ["en", "fr", "en"]:
		TranslationServer.set_locale(locale)
		menu._process(0.0)
		await get_tree().process_frame
		refresh_properties()
		var text = String(menu._load_menu_load_btn.text)
		# Native Button.text keeps the original key; Godot translates its presentation.
		var expected = "เริ่มเกม" if locale == "en" else "start"
		if not check_probe(text == expected and is_english() == (locale == "en"), "dynamic-start-" + locale, {"actual": text, "expected_native_source": expected, "native_translation": TranslationServer.translate("start"), "locale": TranslationServer.get_locale()}):
			return
		if static_entry.is_empty():
			for entry in watched:
				for property in entry.properties:
					var state = entry.properties[property]
					if not state.get("literal", false):
						static_entry = {"reference": entry.reference, "property": property, "source": state.source, "thai": state.presented}
						break
				if not static_entry.is_empty():
					break
		if not check_probe(not static_entry.is_empty() and static_entry.reference.get_ref() != null, "scoped-property-present-" + locale, "Bound existing native property"):
			return
		var node = static_entry.reference.get_ref()
		var actual = String(node.get(static_entry.property))
		var expected_static = static_entry.thai if locale == "en" else static_entry.source
		if not check_probe(actual == expected_static, "scoped-property-restore-" + locale, {"node": str(node.get_path()), "property": static_entry.property, "actual": actual, "expected": expected_static}):
			return
	if not await probe_counter():
		return
	write_probe(true)
	get_tree().quit(0)

func probe_counter():
	if get_tree().change_scene_to_file("res://Levels/alley.tscn") != OK:
		return check_probe(false, "counter-scene-load", "res://Levels/alley.tscn")
	var deadline = Time.get_ticks_msec() + 60000
	var counter = null
	while Time.get_ticks_msec() < deadline:
		if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://Levels/alley.tscn":
			counter = get_tree().current_scene.get_node_or_null("HungryPeople/HungryNpcCanvas")
		if counter != null and counter.is_node_ready() and counters.has(counter._display.get_instance_id()):
			break
		await get_tree().process_frame
	if not check_probe(counter != null and counter.is_node_ready() and counters.has(counter._display.get_instance_id()), "real-alley-counter-ready", "res://Tools/hungry_npc_canvas.gd"):
		return false
	var identity = counter._display.get_instance_id()
	var state = counters[identity]
	var original_count = state.count
	var original_source = state.source
	var original_fed = counter._num_fed
	var original_total = counter._total_feedable
	for locale in ["en", "fr", "en"]:
		TranslationServer.set_locale(locale)
		await get_tree().process_frame
		refresh_properties()
		var expected_suffix = String(state.thai) if locale == "en" else String(counter.tr(original_source))
		var expected = str(original_count) + " " + expected_suffix
		var unchanged = counter._num_fed == original_fed and counter._total_feedable == original_total and state.count == original_count and state.source == original_source
		if not check_probe(counter._display.text == expected and unchanged, "real-counter-locale-" + locale, {"node": str(counter.get_path()), "actual": counter._display.text, "expected": expected, "count": original_count, "native_suffix_key": original_source, "counters_unchanged": unchanged, "meal_event_invoked": false}):
			return false
	return true
