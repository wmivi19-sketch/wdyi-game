class_name MenuResources
extends RefCounted
const CONFIG_PATH := "res://resources/ui/main_menu_config.json"
const ACTIONS := ["start_new_game", "load_game", "open_settings", "show_credits", "quit_game"]
## 配置全部丢失时仍可启动；资源路径留空，使用占位与静音。
static func defaults() -> Dictionary:
 return {
  "visual":{"background_image":"", "logo_image":"", "title_text":"逐神终焉", "subtitle_text":"六神之战 · 十四日轮回", "background_color_fallback":{"r":0.1,"g":0.05,"b":0.15,"a":1.0}, "logo_fallback_color":{"r":0.8,"g":0.6,"b":1.0,"a":1.0}, "button_theme_path":"", "button_textures":{"normal":"","hover":"","pressed":"","disabled":""}},
  "audio":{"bgm_path":"","bgm_volume":0.8,"hover_sound":"","click_sound":"","enable_audio":true,"sfx_volume":0.7,"pool_size":5,"bgm_bus":"BGM","sfx_bus":"SFX","generate_placeholders":false,"sample_rate":22050,"hover_hz":740,"click_hz":520,"tone_seconds":0.06,"tone_amplitude":0.12},
  "buttons":[{"id":"new_game","text":"新游戏","action":"start_new_game"},{"id":"continue","text":"继续游戏","action":"load_game"},{"id":"settings","text":"设置","action":"open_settings"},{"id":"credits","text":"制作人员","action":"show_credits"},{"id":"quit","text":"退出游戏","action":"quit_game"}],
  "version":"0.1.0", "copyright":"© 2026 Game Studio",
  "navigation":{"game_scene":"res://scenes/MapDemo.tscn","menu_scene":"res://scenes/ui/main_menu.tscn","settings_scene":"res://scenes/ui/settings_menu.tscn","credits_scene":"res://scenes/ui/credits_screen.tscn"},
  "storage":{"save_path":"user://save_game.json","preferences_path":"user://menu_settings.cfg","max_save_bytes":1048576,"max_day":10000,"new_game_continent":0},
  "layout":{"max_width":480,"logo_height":112,"button_height":48,"spacing":10,"margin":24,"poll_seconds":1.0,"transition_seconds":0.5,"hover_scale":1.035,"hover_seconds":0.12},
  "style":{"font_name":"Microsoft YaHei","font_size":20,"border_color":"#9970bb","normal_color":"#30243d","hover_color":"#493454","pressed_color":"#63466e","disabled_color":"#24202c","font_color":"#fff4ed","border_width":2,"corner_radius":8},
  "credits":{"title":"制作人员","lines":["制作团队：待填写","开发引擎：Godot 4.x"]}}
## 深合并配置；source 可只覆盖部分可选字段。
static func merged(base: Dictionary, source: Dictionary) -> Dictionary:
 var result := base.duplicate(true)
 for key in source:
  if source[key] is Dictionary and result.get(key) is Dictionary: result[key] = merged(result[key], source[key])
  else: result[key] = source[key]
 return result
## 读取并验证JSON；失败返回空对象，由调用方保留旧配置或使用默认值。
static func read_config(path: String = CONFIG_PATH) -> Dictionary:
 if not FileAccess.file_exists(path): return {}
 var parser := JSON.new()
 if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
 var result := merged(defaults(), parser.data)
 return result if valid(result) else {}
## 仅允许有限数字；value 为JSON字段。
static func numeric(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))
## 校验可替换资源路径；空字符串表示使用占位。
static func valid_path(path: Variant) -> bool:
 return path is String and (path.is_empty() or ((path.begins_with("res://") or path.begins_with("user://")) and not ".." in path))
## 检查颜色字段；value 为RGBA字典。
static func valid_color(value: Variant) -> bool:
 if not value is Dictionary: return false
 for key in ["r","g","b","a"]:
  if not numeric(value.get(key)) or value[key] < 0 or value[key] > 1: return false
 return true
## 验证菜单数据及动作白名单，拒绝任意方法调用。
static func valid(data: Dictionary) -> bool:
 for key in ["visual","audio","navigation","storage","layout","style","credits"]:
  if not data.get(key) is Dictionary: return false
 if not data.get("buttons") is Array or data.buttons.is_empty(): return false
 for key in ["title_text","subtitle_text"]:
  if not data.visual.get(key) is String: return false
 for key in ["background_image","logo_image","button_theme_path"]:
  if not valid_path(data.visual.get(key)): return false
 if not data.visual.get("button_textures") is Dictionary: return false
 for path in data.visual.button_textures.values():
  if not valid_path(path): return false
 if not valid_color(data.visual.get("background_color_fallback")) or not valid_color(data.visual.get("logo_fallback_color")): return false
 for key in ["bgm_path","hover_sound","click_sound"]:
  if not valid_path(data.audio.get(key)): return false
 for key in ["enable_audio","generate_placeholders"]:
  if not data.audio.get(key) is bool: return false
 for key in ["bgm_volume","sfx_volume","tone_amplitude"]:
  if not numeric(data.audio.get(key)) or data.audio[key] < 0 or data.audio[key] > 1: return false
 for key in ["pool_size","sample_rate","hover_hz","click_hz","tone_seconds"]:
  if not numeric(data.audio.get(key)) or data.audio[key] <= 0: return false
 if data.audio.pool_size > 16 or data.audio.pool_size != floor(float(data.audio.pool_size)) or data.audio.sample_rate > 192000 or data.audio.tone_seconds > 1: return false
 for key in ["bgm_bus","sfx_bus"]:
  if not data.audio.get(key) is String or data.audio[key].is_empty(): return false
 var ids: Dictionary = {}
 for button in data.buttons:
  if not button is Dictionary or not button.get("id") is String or button.id.is_empty() or ids.has(button.id) or not button.get("text") is String or button.get("action") not in ACTIONS: return false
  ids[button.id] = true
 for key in ["game_scene","menu_scene","settings_scene","credits_scene"]:
  if not valid_path(data.navigation.get(key)) or data.navigation[key].is_empty(): return false
 for key in ["save_path","preferences_path"]:
  if not valid_path(data.storage.get(key)) or not data.storage[key].begins_with("user://"): return false
 for key in ["max_save_bytes","max_day","new_game_continent"]:
  if not numeric(data.storage.get(key)) or data.storage[key] < 0 or data.storage[key] != floor(float(data.storage[key])): return false
 if data.storage.max_save_bytes <= 0 or data.storage.max_day <= 0: return false
 for value in data.layout.values():
  if not numeric(value) or value <= 0: return false
 for key in ["normal_color","hover_color","pressed_color","disabled_color","border_color","font_color"]:
  if not data.style.get(key) is String or not Color.html_is_valid(data.style[key]): return false
 for key in ["font_size","border_width","corner_radius"]:
  if not numeric(data.style.get(key)) or data.style[key] < 0: return false
 if not data.style.get("font_name") is String or not data.credits.get("title") is String or not data.credits.get("lines") is Array: return false
 for line in data.credits.lines:
  if not line is String: return false
 return data.get("version") is String and data.get("copyright") is String
## 配置颜色转Godot颜色；value 为已验证RGBA字典。
static func color(value: Dictionary) -> Color:
 return Color(float(value.r), float(value.g), float(value.b), float(value.a))
## 原始PNG/JPG可运行时直接替换；导出包内资源再走ResourceLoader。
static func texture(path: String) -> Texture2D:
 if path.is_empty(): return null
 if FileAccess.file_exists(path) and path.get_extension().to_lower() in ["png","jpg","jpeg","webp","svg"]:
  var image := Image.new()
  var bytes := FileAccess.get_file_as_bytes(path)
  var image_error := ERR_FILE_UNRECOGNIZED
  match path.get_extension().to_lower():
   "png": image_error = image.load_png_from_buffer(bytes)
   "jpg", "jpeg": image_error = image.load_jpg_from_buffer(bytes)
   "webp": image_error = image.load_webp_from_buffer(bytes)
   "svg": image_error = image.load_svg_from_buffer(bytes)
  if image_error == OK and not image.is_empty(): return ImageTexture.create_from_image(image)
 if ResourceLoader.exists(path): return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
 return null
## 加载OGG/WAV；WAV使用PCM解析，确保Godot4.3支持原文件热替换。
static func audio(path: String) -> AudioStream:
 if path.is_empty(): return null
 if FileAccess.file_exists(path):
  if path.get_extension().to_lower() == "ogg": return AudioStreamOggVorbis.load_from_file(path)
  if path.get_extension().to_lower() == "wav": return wav(FileAccess.get_file_as_bytes(path))
 if ResourceLoader.exists(path): return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStream
 return null
## 解析标准RIFF PCM 8/16位单/双声道，其他编码安全返回null。
static func wav(bytes: PackedByteArray) -> AudioStreamWAV:
 if bytes.size() < 12 or bytes.slice(0,4).get_string_from_ascii() != "RIFF" or bytes.slice(8,12).get_string_from_ascii() != "WAVE": return null
 var limit := int(bytes.decode_u32(4)) + 8
 if limit < 12 or limit > bytes.size(): return null
 var offset := 12
 var format_data := PackedByteArray()
 var sound_data := PackedByteArray()
 while offset + 8 <= limit:
  var name := bytes.slice(offset, offset + 4).get_string_from_ascii()
  var length := int(bytes.decode_u32(offset + 4))
  offset += 8
  if length < 0 or offset + length > limit: return null
  if name == "fmt ": format_data = bytes.slice(offset, offset + length)
  elif name == "data": sound_data = bytes.slice(offset, offset + length)
  offset += length + (length % 2)
 if format_data.size() < 16 or sound_data.is_empty() or format_data.decode_u16(0) != 1: return null
 var channels := int(format_data.decode_u16(2))
 var rate := int(format_data.decode_u32(4))
 var bits := int(format_data.decode_u16(14))
 if channels not in [1,2] or bits not in [8,16] or rate <= 0 or rate > 192000: return null
 var frame_bytes := channels * (bits >> 3)
 if format_data.decode_u16(12) != frame_bytes or sound_data.size() % frame_bytes != 0: return null
 if bits == 8:
  for index in sound_data.size(): sound_data[index] = (int(sound_data[index]) - 128) & 255
 var stream := AudioStreamWAV.new()
 stream.format = AudioStreamWAV.FORMAT_8_BITS if bits == 8 else AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate = rate
 stream.stereo = channels == 2
 stream.data = sound_data
 stream.loop_end = floori(float(sound_data.size()) / frame_bytes)
 return stream
## 可选短音占位；values 是audio配置，frequency 为频率。
static func tone(values: Dictionary, frequency: float) -> AudioStreamWAV:
 var samples := int(float(values.sample_rate) * float(values.tone_seconds))
 var bytes := PackedByteArray()
 bytes.resize(samples * 2)
 for index in samples:
  var envelope := 1.0 - float(index) / samples
  bytes.encode_s16(index * 2, int(sin(TAU * frequency * index / float(values.sample_rate)) * float(values.tone_amplitude) * envelope * 32767.0))
 var stream := AudioStreamWAV.new()
 stream.format = AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate = int(values.sample_rate)
 stream.data = bytes
 return stream
## JSON及直连资源内容哈希，检测同路径替换和同秒修改。
static func signature(config: Dictionary, config_path: String = CONFIG_PATH) -> String:
 var paths: Array[String] = [config_path]
 for key in ["background_image","logo_image","button_theme_path"]: paths.append(str(config.visual.get(key,"")))
 for value in config.visual.button_textures.values(): paths.append(str(value))
 for key in ["bgm_path","hover_sound","click_sound"]: paths.append(str(config.audio.get(key,"")))
 var result := ""
 for path in paths:
  result += path + (FileAccess.get_sha256(path) if not path.is_empty() and FileAccess.file_exists(path) else "missing")
 return result.sha256_text()
