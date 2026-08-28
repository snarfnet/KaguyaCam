#!/usr/bin/env python3
"""Set Kaguya Moon Camera to a one-time \u00a5200 (JPN base) price.
Only creates a schedule when none exists yet."""
import jwt, time, requests, os

KEY_ID = 'WDXGY9WX55'
ISSUER = '2be0734f-943a-4d61-9dc9-5d9045c46fec'
BUNDLE = 'com.tokyonasu.KaguyaCam'
BASE_TERRITORY = 'JPN'
TARGET_PRICE = '200'
p8 = open(os.path.expanduser('~/.appstoreconnect/private_keys/AuthKey_WDXGY9WX55.p8')).read()


def tok():
    return jwt.encode({'iss': ISSUER, 'iat': int(time.time()), 'exp': int(time.time()) + 1200,
                       'aud': 'appstoreconnect-v1'}, p8, algorithm='ES256', headers={'kid': KEY_ID})


def api(m, p, payload=None):
    h = {'Authorization': f'Bearer {tok()}', 'Content-Type': 'application/json'}
    return requests.request(m, f'https://api.appstoreconnect.apple.com/v1{p}',
                            headers=h, **({'json': payload} if payload else {}))


apps = api('GET', f'/apps?filter[bundleId]={BUNDLE}&limit=1').json().get('data', [])
if not apps:
    print('App record not found; skipping price')
    raise SystemExit(0)
APP_ID = apps[0]['id']

mp = api('GET', f'/appPriceSchedules/{APP_ID}/manualPrices?limit=1')
if mp.status_code < 300 and mp.json().get('data'):
    print('Price schedule already set; leaving as-is')
    raise SystemExit(0)

point_id = None
url = f'/apps/{APP_ID}/appPricePoints?filter[territory]={BASE_TERRITORY}&limit=200'
while url:
    r = api('GET', url).json()
    for pp in r.get('data', []):
        if pp['attributes'].get('customerPrice') == TARGET_PRICE:
            point_id = pp['id']
            break
    if point_id:
        break
    nxt = r.get('links', {}).get('next')
    url = nxt.replace('https://api.appstoreconnect.apple.com/v1', '') if nxt else None

if not point_id:
    print(f'Could not find \u00a5{TARGET_PRICE} price point; aborting price step')
    raise SystemExit(1)
print(f'\u00a5{TARGET_PRICE} price point', point_id)

payload = {
    'data': {'type': 'appPriceSchedules',
             'relationships': {
                 'app': {'data': {'type': 'apps', 'id': APP_ID}},
                 'baseTerritory': {'data': {'type': 'territories', 'id': BASE_TERRITORY}},
                 'manualPrices': {'data': [{'type': 'appPrices', 'id': '${price1}'}]}}},
    'included': [{'type': 'appPrices', 'id': '${price1}',
                  'attributes': {'startDate': None},
                  'relationships': {'appPricePoint': {'data': {'type': 'appPricePoints', 'id': point_id}}}}],
}
r = api('POST', '/appPriceSchedules', payload)
print('set price', r.status_code, '' if r.status_code < 300 else r.text[:400])
