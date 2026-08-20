import json
from pathlib import Path

namespace = {'__file__': str(Path(__file__).with_name('preview_server.py'))}
source = Path(namespace['__file__']).read_text(encoding='utf-8')
exec(source.rsplit("ThreadingHTTPServer(('127.0.0.1',4173)", 1)[0], namespace)

products = namespace['PRODUCTS']
items = []
for product in products:
    for colorway in product['colorways']:
        card = dict(product)
        card.update({
            'catalogItemId': f"{product['id']}:{colorway['id']}",
            'colorwayId': colorway['id'],
            'colorwaySlug': colorway['slug'],
            'colorwayName': colorway['name'],
            'swatch': colorway['swatch'],
            'color': colorway['cardColor'],
            'image': colorway['image'],
            'variants': [v for v in product['variants'] if v.get('colorwayId') == colorway['id']],
        })
        items.append(card)

items.sort(key=lambda p: (
    not p['featured'],
    next((i for i, x in enumerate(products) if x['id'] == p['id']), 999),
    p.get('colorwayName', ''),
))

payload = json.dumps({'items': items[:12]}, ensure_ascii=False).encode()
assert len(items) > len(products), 'Expected multiple colorway cards'
assert b'colorwayName' in payload
print(f'preview self-test passed: {len(items)} colorway cards, {len(payload)} bytes')
