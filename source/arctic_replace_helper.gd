# Appended to the original hash-verified ActivityArea in memory only.
var _arctic_defaults = {}
var _arctic_plan_key = []
var _arctic_breaks = []
var arctic_layout_status = "not_requested"

func _arctic_service():
	return get_node("/root/ArcticThai")

func _arctic_scope():
	if not _arctic_service().is_english():
		return {}
	return _arctic_service().dialogue_scope(self)

func _arctic_translate(text):
	var scope = _arctic_scope()
	if scope.has(text):
		return String(scope[text])
	return TranslationServer.translate(text)

func _arctic_prepare_layout():
	_arctic_service().dialogue_owners[get_instance_id()] = weakref(self)
	if current_label == null:
		return
	var identity = current_label.get_instance_id()
	if not _arctic_scope().is_empty():
		if not _arctic_defaults.has(identity):
			_arctic_defaults[identity] = {"reference": weakref(current_label), "wrap": current_label.autowrap_mode, "language": current_label.language, "font": current_label.font, "outline": current_label.outline_modulate}
		current_label.set_meta("arctic_dialogue_managed", true)
		current_label.font = _arctic_service().fonts.Bold
		current_label.outline_modulate = Color(0, 0, 0, 0.25)
		current_label.language = "th"
	elif _arctic_defaults.has(identity):
		var original = _arctic_defaults[identity]
		_arctic_restore_label(current_label, original)
		_arctic_defaults.erase(identity)

func _arctic_restore_label(label, original):
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		label.autowrap_mode = original.wrap
	if label.language == "th":
		label.language = original.language
	if label.font == _arctic_service().fonts.Bold:
		label.font = original.font
	if label.outline_modulate == Color(0, 0, 0, 0.25):
		label.outline_modulate = original.outline
	label.remove_meta("arctic_dialogue_managed")

func _arctic_locale_changed():
	if not _arctic_service().is_english():
		for identity in _arctic_defaults.keys():
			var original = _arctic_defaults[identity]
			var label = original.reference.get_ref()
			if label != null:
				_arctic_restore_label(label, original)
		_arctic_defaults.clear()
	_arctic_prepare_layout()
	if current_label == null or current_label.text.is_empty() or line_index >= dialog.size() or dialog[line_index].begins_with("/"):
		return
	var text = String(_arctic_translate(dialog[line_index])).replace("/br", "\n")
	var count = text.length() if is_line_complete else mini(letter_index, text.length())
	current_label.text = text.substr(0, count)
	_arctic_refresh_text(text, count)

func _arctic_measure(text):
	var line = TextLine.new()
	line.add_string(text, current_label.font, current_label.font_size, "th")
	return line.get_size().x

func _arctic_prepare_plan(text):
	var key = [text, current_label.font.get_instance_id(), current_label.font_size, current_label.width]
	if key == _arctic_plan_key:
		return
	_arctic_plan_key = key
	_arctic_breaks = []
	var entries = _arctic_service().payload.word_boundaries
	if not entries.has(text):
		arctic_layout_status = "unsupported_missing_word_metadata"
		return
	var tokens = entries[text]
	var joined = ""
	for token in tokens:
		joined += token
	if joined != text:
		arctic_layout_status = "word_metadata_identity_mismatch"
		return
	var line = ""
	var offset = 0
	for token in tokens:
		if token == "\n":
			line = ""
			offset += token.length()
			continue
		if _arctic_measure(token) > current_label.width:
			arctic_layout_status = "unsupported_word_exceeds_column"
			_arctic_breaks = []
			return
		if not line.is_empty() and _arctic_measure(line + token) > current_label.width:
			_arctic_breaks.append(offset)
			line = ""
		line += token
		offset += token.length()
	arctic_layout_status = "word_safe_plan_ready"

func _arctic_refresh_text(text, visible_source_characters):
	if _arctic_scope().is_empty():
		return
	_arctic_prepare_plan(text)
	if arctic_layout_status != "word_safe_plan_ready":
		current_label.autowrap_mode = _arctic_defaults[current_label.get_instance_id()].wrap
		return
	current_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var prefix = text.substr(0, visible_source_characters)
	var displayed = ""
	var previous = 0
	for boundary in _arctic_breaks:
		if boundary < visible_source_characters:
			displayed += prefix.substr(previous, boundary - previous) + "\n"
			previous = boundary
	displayed += prefix.substr(previous)
	current_label.text = displayed
