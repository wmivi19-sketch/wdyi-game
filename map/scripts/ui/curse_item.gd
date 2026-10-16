extends Label
## id 是诅咒 ID；data 是配置文本，不引入诅咒效果。
func setup(id: String, data: Dictionary = {}) -> void:
 text = str(data.get("name", id))
 tooltip_text = str(data.get("description", ""))
 autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
