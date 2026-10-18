"""Extract the atlas's existing alpha silhouettes into Wonderdraft symbol assets."""
from pathlib import Path
import json
import math
import zipfile
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'god-gifted-mountains-tileset-v1.png'
PACK = ROOT / 'wonderdraft-assets' / 'God_Gifted_Mountains_Pixel_v1'
rgba = np.array(Image.open(SOURCE).convert('RGBA'))
labels, _ = ndimage.label(rgba[:, :, 3] > 100)
objects = ndimage.find_objects(labels)
# Retain the original soft edges near each solid silhouette, without importing
# the atlas's almost-transparent residual background or neighboring objects.
distance, indices = ndimage.distance_transform_edt(labels == 0, return_indices=True)
nearest = labels[tuple(indices)]
entries = []
metadata = {}
for number, box in enumerate(objects, 1):
    if box is None:
        continue
    count = int(np.count_nonzero(labels[box] == number))
    if count < 100:
        continue
    y, x = box
    cx, cy = (x.start + x.stop) / 2, (y.start + y.stop) / 2
    if cy < 145:
        category = 'Ground_Paths'
    elif cy < 340:
        category = 'Cliffs_Stairs'
    elif cy < 445:
        category = 'Bridges_Fences'
    elif y.start >= 700:
        category = 'Sacred_Buildings' if x.start < 520 else ('Shrines' if x.start < 1310 else 'Props')
    elif count > 10000 and y.stop > 690:
        category = 'Village_Buildings' if x.stop < 1300 else 'Sacred_Buildings'
    else:
        category = 'Nature'
    name = f'ggm_{category.lower()}_{number:03d}'
    left, top = max(0, x.start - 6), max(0, y.start - 6)
    right, bottom = min(rgba.shape[1], x.stop + 6), min(rgba.shape[0], y.stop + 6)
    crop = rgba[top:bottom, left:right].copy()
    keep = (nearest[top:bottom, left:right] == number) & (distance[top:bottom, left:right] <= 4)
    crop[:, :, 3] = np.where(keep, crop[:, :, 3], 0)
    image = Image.fromarray(crop)
    folder = PACK / 'sprites' / 'symbols' / f'GGM_{category}'
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / f'{name}.png'
    image.save(path)
    metadata.setdefault(folder, {})[name] = {
        'name': name.replace('_', ' '), 'radius': max(8, round(min(image.size) * 0.375)),
        'offset_x': 0, 'offset_y': 0, 'draw_mode': 'normal',
    }
    entries.append({'file': str(path.relative_to(PACK)), 'source_box': [left, top, right, bottom], 'size': list(image.size)})
for folder, data in metadata.items():
    (folder / '.wonderdraft_symbols').write_text(json.dumps(data, indent=2), encoding='utf-8')
(PACK / 'manifest.json').write_text(json.dumps({'source': SOURCE.name, 'asset_count': len(entries), 'assets': entries}, indent=2), encoding='utf-8')
(PACK / 'README.txt').write_text('God Gifted Mountains Pixel v1\nInstall this entire folder under Wonderdraft/assets.\nEnable God_Gifted_Mountains_Pixel_v1 in the map Assets dialog, save and reopen the map.\nCategories start with GGM_. All assets use normal draw mode to preserve colors.\nRoads and cliff pieces are symbols, not seamless terrain or road brushes.\nOriginal atlas alpha edges are preserved around extracted silhouettes.\n', encoding='utf-8')
columns, cell = 8, 180
sheet = Image.new('RGB', (columns * cell, math.ceil(len(entries) / columns) * cell), '#41434a')
draw = ImageDraw.Draw(sheet)
for i, entry in enumerate(entries):
    image = Image.open(PACK / entry['file'])
    image.thumbnail((170, 150), Image.Resampling.NEAREST)
    x, y = (i % columns) * cell, (i // columns) * cell
    sheet.paste(image, (x + (cell - image.width) // 2, y + (155 - image.height) // 2), image)
    draw.text((x + 6, y + 158), Path(entry['file']).stem[-3:] + ' ' + Path(entry['file']).parent.name[4:17], fill='white')
sheet.save(ROOT / 'wonderdraft-assets' / 'God_Gifted_Mountains_Pixel_v1-preview.jpg')
archive = PACK.with_suffix('.zip')
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
    for file in PACK.rglob('*'):
        if file.is_file():
            z.write(file, file.relative_to(PACK.parent))
print(json.dumps({'pack': str(PACK), 'count': len(entries), 'categories': {f.name: len(data) for f, data in metadata.items()}, 'zip': str(archive)}))
