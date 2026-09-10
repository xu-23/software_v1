class_name UnitIconFormatter
extends RefCounted


static func initials(display_name: String) -> String:
	var words := display_name.strip_edges().split(" ", false)
	var result := ""
	for index in range(words.size()):
		var word := str(words[index]).strip_edges()
		if word.is_empty():
			continue
		if index > 0 and word.to_lower() in ["man", "woman"]:
			continue
		result += word.left(1).to_upper()
	return result if not result.is_empty() else "?"


static func class_badge(class_id: String) -> String:
	return {"soldier": "sword", "raider": "horse", "archer": "bow"}.get(class_id, "")
