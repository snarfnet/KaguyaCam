#!/usr/bin/env python3
"""Set all App Store metadata for Kaguya Moon Camera (first submission).
Version localizations, category, content rights, age rating, copyright,
privacy policy URL and the review contact detail. Discovers app by bundle id.
Idempotent."""
import jwt, time, requests, os

KEY_ID = 'WDXGY9WX55'
ISSUER = '2be0734f-943a-4d61-9dc9-5d9045c46fec'
BUNDLE = 'com.tokyonasu.KaguyaCam'
URL = "https://snarfnet.github.io/"
p8 = open(os.path.expanduser('~/.appstoreconnect/private_keys/AuthKey_WDXGY9WX55.p8')).read()

DESC_EN = (
    "Point your phone at the night sky and see exactly where the Moon is and "
    "how it looks tonight.\n\n"
    "Kaguya Moon Camera draws the Moon in its real direction over the live "
    "camera, with its true phase for the moment. On each side it shows "
    "yesterday's and tomorrow's Moon, so you can see the phase change at a glance.\n\n"
    "\u2022 The Moon appears in its real compass direction and altitude\n"
    "\u2022 Its shape matches the real phase, right now\n"
    "\u2022 Yesterday and tomorrow sit beside tonight's Moon\n"
    "\u2022 Works even when it's cloudy or daytime \u2014 the position is computed\n"
    "\u2022 An arrow guides you to the Moon's direction\n"
    "\u2022 No account, no ads, works offline\n\n"
    "One-time purchase. A quiet, beautiful way to find and follow the Moon.\n\n"
    "The Moon's direction and phase are astronomical estimates. Compass accuracy "
    "depends on your device."
)

DESC_JA = (
    "夜空にかざすと、今の月がどの方角にあって、どんな形かがわかります。\n\n"
    "かぐや姫カメラは、カメラ映像の上に、いまの月をその方角へ、"
    "そのときの満ち欠けのまま重ねて描きます。月の両隣には昨夜と明晩の月を並べるので、"
    "満ち欠けの移り変わりがひと目でわかります。\n\n"
    "・月が、実際の方角と高度に浮かびます\n"
    "・形は、いまの満ち欠けそのまま\n"
    "・今夜の月の両隣に、昨夜と明晩の月\n"
    "・曇りや昼でも、計算で月の位置を表示\n"
    "・矢印が、月のいる方角へ案内します\n"
    "・アカウント不要、広告なし、オフラインで動作\n\n"
    "買い切り。月を見つけて、静かに眺めるためのアプリです。\n\n"
    "月の方角・満ち欠けは天文計算による目安です。方位の精度は端末のコンパスに依存します。"
)

KW_EN = "moon,phase,ar,night sky,lunar,astronomy,stargazing,full moon,moonrise,compass,direction,tonight"
KW_JA = "月,満ち欠け,月齢,方角,夜空,天体,月見,満月,新月,三日月,コンパス,ムーン,ar,星,カレンダー"

PROMO_EN = "Point at the sky and find the Moon \u2014 its direction and phase, right now."
PROMO_JA = "夜空にかざすと、今の月。方角と満ち欠けがすぐわかります。"

LOCS = {
    'en-US': dict(description=DESC_EN, keywords=KW_EN, promotionalText=PROMO_EN,
                  marketingUrl=URL, supportUrl=URL),
    'ja': dict(description=DESC_JA, keywords=KW_JA, promotionalText=PROMO_JA,
               marketingUrl=URL, supportUrl=URL),
}


def tok():
    return jwt.encode({'iss': ISSUER, 'iat': int(time.time()), 'exp': int(time.time()) + 1200,
                       'aud': 'appstoreconnect-v1'}, p8, algorithm='ES256', headers={'kid': KEY_ID})


def api(m, p, payload=None):
    h = {'Authorization': f'Bearer {tok()}', 'Content-Type': 'application/json'}
    return requests.request(m, f'https://api.appstoreconnect.apple.com/v1{p}',
                            headers=h, **({'json': payload} if payload else {}))


apps = api('GET', f'/apps?filter[bundleId]={BUNDLE}&limit=1').json().get('data', [])
if not apps:
    print('App record not found for', BUNDLE, '- create it in App Store Connect first.')
    raise SystemExit(0)
APP_ID = apps[0]['id']
VERSION_ID = api('GET', f'/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=1').json()['data'][0]['id']
print('app', APP_ID, 'version', VERSION_ID)

# Version localizations
existing = {l['attributes']['locale']: l['id']
            for l in api('GET', f'/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations?limit=20').json()['data']}
for locale, attrs in LOCS.items():
    if locale in existing:
        lid = existing[locale]
        r = api('PATCH', f'/appStoreVersionLocalizations/{lid}',
                {'data': {'type': 'appStoreVersionLocalizations', 'id': lid, 'attributes': attrs}})
    else:
        r = api('POST', '/appStoreVersionLocalizations',
                {'data': {'type': 'appStoreVersionLocalizations',
                          'attributes': {'locale': locale, **attrs},
                          'relationships': {'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': VERSION_ID}}}}})
    print(locale, r.status_code, '' if r.status_code < 300 else r.text[:300])

# Copyright
r = api('PATCH', f'/appStoreVersions/{VERSION_ID}',
        {'data': {'type': 'appStoreVersions', 'id': VERSION_ID,
                  'attributes': {'copyright': '2026 tokyonasu'}}})
print('copyright', r.status_code, '' if r.status_code < 300 else r.text[:200])

# Content rights
r = api('PATCH', f'/apps/{APP_ID}',
        {'data': {'type': 'apps', 'id': APP_ID,
                  'attributes': {'contentRightsDeclaration': 'DOES_NOT_USE_THIRD_PARTY_CONTENT'}}})
print('content rights', r.status_code, '' if r.status_code < 300 else r.text[:200])

# Category + privacy policy URL on editable appInfo
infos = api('GET', f'/apps/{APP_ID}/appInfos').json()['data']
info_id = None
for i in infos:
    if i['attributes'].get('appStoreState') in ('PREPARE_FOR_SUBMISSION', 'REPLACED_WITH_NEW_INFO', None):
        info_id = i['id']
info_id = info_id or infos[0]['id']
r = api('PATCH', f'/appInfos/{info_id}',
        {'data': {'type': 'appInfos', 'id': info_id,
                  'relationships': {
                      'primaryCategory': {'data': {'type': 'appCategories', 'id': 'REFERENCE'}},
                      'secondaryCategory': {'data': {'type': 'appCategories', 'id': 'EDUCATION'}}}}})
print('category', r.status_code, '' if r.status_code < 300 else r.text[:300])

for il in api('GET', f'/appInfos/{info_id}/appInfoLocalizations?limit=10').json().get('data', []):
    r = api('PATCH', f'/appInfoLocalizations/{il["id"]}',
            {'data': {'type': 'appInfoLocalizations', 'id': il['id'],
                      'attributes': {'privacyPolicyUrl': URL}}})
    print('privacy', il['attributes'].get('locale'), r.status_code)

# Age rating: everything none/false (no ads, paid app)
inf = api('GET', f'/apps/{APP_ID}/appInfos?include=ageRatingDeclaration').json()
decl_id = None
for i in inf.get('included', []):
    if i['type'] == 'ageRatingDeclarations':
        decl_id = i['id']
if decl_id:
    freq = ['alcoholTobaccoOrDrugUseOrReferences', 'contests', 'gamblingSimulated',
            'medicalOrTreatmentInformation', 'profanityOrCrudeHumor',
            'sexualContentGraphicAndNudity', 'sexualContentOrNudity', 'horrorOrFearThemes',
            'matureOrSuggestiveThemes', 'violenceCartoonOrFantasy',
            'violenceRealisticProlongedGraphicOrSadistic', 'violenceRealistic',
            'gunsOrOtherWeapons']
    age_attrs = {k: 'NONE' for k in freq}
    age_attrs.update({
        'gambling': False, 'unrestrictedWebAccess': False, 'kidsAgeBand': None,
        'parentalControls': False, 'messagingAndChat': False, 'advertising': False,
        'ageAssurance': False, 'userGeneratedContent': False, 'lootBox': False,
        'healthOrWellnessTopics': False,
    })
    r = api('PATCH', f'/ageRatingDeclarations/{decl_id}',
            {'data': {'type': 'ageRatingDeclarations', 'id': decl_id, 'attributes': age_attrs}})
    print('age rating', r.status_code, '' if r.status_code < 300 else r.text[:400])

# Review contact detail (required for first submission)
existing_detail = api('GET', f'/appStoreVersions/{VERSION_ID}/appStoreReviewDetail')
detail_attrs = {
    'contactFirstName': 'Tokyo', 'contactLastName': 'Nasu',
    'contactEmail': 'snarfnet@gmail.com', 'contactPhone': '+14155550100',
    'demoAccountRequired': False, 'demoAccountName': '', 'demoAccountPassword': '',
    'notes': 'No account needed. The app overlays the Moon\'s computed direction and '
             'phase on the camera. Camera and location permissions are used only for '
             'the AR sky view and local astronomical calculation; nothing is stored or sent.'
}
if existing_detail.status_code < 300 and existing_detail.json().get('data'):
    did = existing_detail.json()['data']['id']
    r = api('PATCH', f'/appStoreReviewDetails/{did}',
            {'data': {'type': 'appStoreReviewDetails', 'id': did, 'attributes': detail_attrs}})
else:
    r = api('POST', '/appStoreReviewDetails',
            {'data': {'type': 'appStoreReviewDetails', 'attributes': detail_attrs,
                      'relationships': {'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': VERSION_ID}}}}})
print('review detail', r.status_code, '' if r.status_code < 300 else r.text[:300])
print('metadata done')
