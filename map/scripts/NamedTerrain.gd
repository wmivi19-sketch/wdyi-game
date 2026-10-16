class_name NamedTerrain
extends RefCounted
## Explicit semantic rules, not an online language model. Unknown names use plains.
const PROFILES := {
	"ice": ["#b7c0b4", "#d1d2ba", "#788d86"],
	"forest": ["#879365", "#a8ac75", "#627150"],
	"mountain": ["#a49b80", "#c3b899", "#81725b"],
	"desert": ["#b99a55", "#cfb476", "#96723f"],
	"mystic": ["#9b8c9b", "#b5a4a8", "#746b83"],
	"marsh": ["#829584", "#a1ac8b", "#5c786e"],
	"plains": ["#a4a078", "#beb58b", "#85815d"]
}
const NAME_RULES := {"北冥": "ice", "艾兰岛": "forest", "索坦瑞": "ice",
	"神赐山脉": "mountain", "瓦尔斯卡": "desert", "法恩科": "forest",
	"维洛斯": "mystic", "方丈": "mystic", "南冥": "marsh", "斩魔池": "marsh"}

static func clean_location_name(raw_name: String) -> String:
	return raw_name.strip_edges().trim_suffix("大陆")

static func terrain_type(raw_name: String, explicit_type: String = "") -> String:
	if PROFILES.has(explicit_type):
		return explicit_type
	var name := clean_location_name(raw_name)
	if NAME_RULES.has(name):
		return NAME_RULES[name]
	for pair in [["山脉", "mountain"], ["冰", "ice"], ["雪", "ice"],
		["沙", "desert"], ["林", "forest"], ["池", "marsh"]]:
		if name.contains(pair[0]):
			return pair[1]
	return "plains"

## Stable across runs; independent of the randomized global RNG.
static func region_seed(raw_name: String, world_seed: int) -> int:
	var value := world_seed & 0x7fffffff
	for byte in clean_location_name(raw_name).to_utf8_buffer():
		value = (value * 31 + int(byte)) & 0x7fffffff
	return value

## Transparent pixels outside a normalized 0..1 polygon; never edits the source image.
static func generate(raw_name: String, world_seed: int = 42, resolution: int = 192,
		polygon: PackedVector2Array = PackedVector2Array(), explicit_type: String = "") -> Image:
	var size := clampi(resolution, 32, 512)
	var kind := terrain_type(raw_name, explicit_type)
	var colors: Array = PROFILES[kind]
	var noise := FastNoiseLite.new()
	noise.seed = region_seed(raw_name, world_seed)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.025 if kind == "mountain" else 0.014
	noise.fractal_octaves = 4
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var ink := Color("#68503b")
	for y in range(size):
		for x in range(size):
			var uv := (Vector2(x, y) + Vector2.ONE * 0.5) / float(size)
			if not polygon.is_empty() and not Geometry2D.is_point_in_polygon(uv, polygon):
				continue
			# Sample canonical coordinates so resolution changes do not change the terrain.
			var point := uv * 256.0
			var elevation := noise.get_noise_2dv(point) * 0.5 + 0.5
			if kind == "mountain":
				elevation = 1.0 - absf(elevation * 2.0 - 1.0)
			var color := Color(colors[2]).lerp(Color(colors[1]), elevation)
			color = color.lerp(Color(colors[0]), 0.2)
			# Faded brown contour ink at 0.8 opacity; gentle enough to read the relief.
			if fposmod(elevation * 9.0, 1.0) < 0.065:
				color = color.lerp(ink, 0.8)
			image.set_pixel(x, y, color)
	return image
