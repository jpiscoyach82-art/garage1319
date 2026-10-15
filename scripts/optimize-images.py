"""Build web-sized copies; retain complete product framing and original sources."""
from pathlib import Path
from PIL import Image, ImageOps
import json
import subprocess

root = Path(__file__).resolve().parent.parent
map_file = root / 'assets/js/image-map.js'
text = map_file.read_text()
mapping = json.loads(text.split('Object.freeze(', 1)[1].rsplit(');', 1)[0])
for url, relative in list(mapping.items()):
    source = root / relative
    output = source.with_suffix('.webp')
    # Do not repeatedly recompress already optimized images.
    if output == source:
        try:
            with Image.open(source) as check:
                check.verify()
            content = source.read_bytes()
            expected = int.from_bytes(content[4:8], 'little') + 8
            if content[:4] == b'RIFF' and 12 < expected < len(content):
                temporary = source.with_suffix('.tmp')
                temporary.write_bytes(content[:expected])
                temporary.replace(source)
            continue
        except Exception:
            source = next((p for ext in ('.jpg', '.png', '.gif', '.avif') if (p := output.with_suffix(ext)).exists()), None)
            if source is None:
                source = output.with_suffix('.original')
                subprocess.run(['curl', '--fail', '--silent', '--show-error', '--location', '--max-time', '30', '--output', str(source), url], check=True)
    with Image.open(source) as original:
        image = ImageOps.exif_transpose(original).convert('RGB')
        image.thumbnail((1400, 1800))
        temporary = output.with_suffix('.tmp')
        image.save(temporary, 'WEBP', quality=86, method=2)
        with Image.open(temporary) as check:
            check.verify()
        temporary.replace(output)
    mapping[url] = output.relative_to(root).as_posix()
map_file.write_text('// Verified local mirrors; original URLs remain unchanged in the inventory.\nwindow.GARAGE_IMAGE_MAP=Object.freeze(' + json.dumps(mapping, indent=2) + ');\n')
print(f'{len(mapping)} fotos preparadas para la web')
