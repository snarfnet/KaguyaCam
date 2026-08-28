# -*- coding: utf-8 -*-
"""
かぐや姫カメラ 月計算エンジン（検算用プロトタイプ）。

観測地点(緯度経度)＋日時(UT)から次を計算する：
  - 月の地平座標（方位角 azimuth・高度 altitude）… カメラをどこに向けると月か
  - 輝面比 k（0=新月, 1=満月）と 満ち欠けの向き（waxing/waning）… 月の形
  - 明縁の位置角（bright limb PA）… 三日月をどちらに傾けて描くか

Swift(MoonEphemeris.swift)へ移植する前に、既知値と突き合わせて式を確認する。
Meeus『Astronomical Algorithms』ベース（月=ch47, 太陽=ch25 低精度, 変換=ch13/ch25）。
"""
import math
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

DEG = math.pi / 180.0
RAD = 180.0 / math.pi


def julian_day(year, month, day, ut_hour):
    if month <= 2:
        year -= 1
        month += 12
    a = math.floor(year / 100)
    b = 2 - a + math.floor(a / 4)
    jd = (math.floor(365.25 * (year + 4716))
          + math.floor(30.6001 * (month + 1))
          + day + b - 1524.5)
    return jd + ut_hour / 24.0


def _norm360(x):
    return x % 360.0


# ---------- 月：黄経・黄緯・距離（Meeus ch47 主要項） ----------
_LON_LAT_TERMS = [
    # D, M, Mp, F, Σl係数(1e-6°), Σr係数(1e-3km)
    (0, 0, 1, 0, 6288774, -20905355), (2, 0, -1, 0, 1274027, -3699111),
    (2, 0, 0, 0, 658314, -2955968), (0, 0, 2, 0, 213618, -569925),
    (0, 1, 0, 0, -185116, 48888), (0, 0, 0, 2, -114332, -3149),
    (2, 0, -2, 0, 58793, 246158), (2, -1, -1, 0, 57066, -152138),
    (2, 0, 1, 0, 53322, -170733), (2, -1, 0, 0, 45758, -204586),
    (0, 1, -1, 0, -40923, -129620), (1, 0, 0, 0, -34720, 108743),
    (0, 1, 1, 0, -30383, 104755), (2, 0, -3, 0, 15327, 10321),
    (0, 0, 1, -2, -12528, 0), (0, 0, 1, 2, 10980, 79661),
    (4, 0, -1, 0, 10675, -34782), (0, 0, 3, 0, 10034, -23210),
    (4, 0, -2, 0, 8548, -21636), (2, 1, -1, 0, -7888, 24208),
    (2, 1, 0, 0, -6766, 30824), (1, 0, -1, 0, -5163, -8379),
    (1, 1, 0, 0, 4987, -16675), (2, -1, 1, 0, 4036, -12831),
    (2, 0, 2, 0, 3994, -10445), (4, 0, 0, 0, 3861, -11650),
    (2, 0, -1, -2, 3665, 14403),
]
# 黄緯 Σb（D, M, Mp, F, 係数1e-6°）主要項
_LAT_TERMS = [
    (0, 0, 0, 1, 5128122), (0, 0, 1, 1, 280602), (0, 0, 1, -1, 277693),
    (2, 0, 0, -1, 173237), (2, 0, -1, 1, 55413), (2, 0, -1, -1, 46271),
    (2, 0, 0, 1, 32573), (0, 0, 2, 1, 17198), (2, 0, 1, -1, 9266),
    (0, 0, 2, -1, 8822), (2, -1, 0, -1, 8216), (2, 0, -2, -1, 4324),
    (2, 0, 1, 1, 4200), (2, 1, 0, -1, -3359), (2, -1, -1, 1, 2463),
    (2, -1, 0, 1, 2211), (2, -1, -1, -1, 2065), (0, 1, -1, -1, -1870),
    (4, 0, -1, -1, 1828), (0, 1, 0, 1, -1794), (0, 0, 0, 3, -1749),
]


def moon_position(jd):
    """月の視黄経 lambda(°), 黄緯 beta(°), 地心距離 dist(km)。"""
    T = (jd - 2451545.0) / 36525.0
    Lp = _norm360(218.3164477 + 481267.88123421 * T - 0.0015786 * T**2
                  + T**3 / 538841 - T**4 / 65194000)
    D = _norm360(297.8501921 + 445267.1114034 * T - 0.0018819 * T**2
                 + T**3 / 545868 - T**4 / 113065000)
    M = _norm360(357.5291092 + 35999.0502909 * T - 0.0001536 * T**2
                 + T**3 / 24490000)
    Mp = _norm360(134.9633964 + 477198.8675055 * T + 0.0087414 * T**2
                  + T**3 / 69699 - T**4 / 14712000)
    F = _norm360(93.2720950 + 483202.0175233 * T - 0.0036539 * T**2
                 - T**3 / 3526000 + T**4 / 863310000)
    E = 1 - 0.002516 * T - 0.0000074 * T**2

    sigma_l = 0.0
    sigma_r = 0.0
    for d, m, mp, f, cl, cr in _LON_LAT_TERMS:
        arg = (D * d + M * m + Mp * mp + F * f) * DEG
        e = E ** abs(m)
        sigma_l += cl * e * math.sin(arg)
        sigma_r += cr * e * math.cos(arg)
    A1 = (119.75 + 131.849 * T) * DEG
    A2 = (53.09 + 479264.290 * T) * DEG
    sigma_l += 3958 * math.sin(A1) + 1962 * math.sin((Lp - F) * DEG) \
        + 318 * math.sin(A2)

    sigma_b = 0.0
    for d, m, mp, f, cb in _LAT_TERMS:
        arg = (D * d + M * m + Mp * mp + F * f) * DEG
        e = E ** abs(m)
        sigma_b += cb * e * math.sin(arg)
    A3 = (313.45 + 481266.484 * T) * DEG
    sigma_b += -2235 * math.sin(Lp * DEG) + 382 * math.sin(A3) \
        + 175 * math.sin((A1 - F) * DEG) + 175 * math.sin((A1 + F) * DEG) \
        + 127 * math.sin((Lp - Mp) * DEG) - 115 * math.sin((Lp + Mp) * DEG)

    lam = _norm360(Lp + sigma_l / 1_000_000.0)
    beta = sigma_b / 1_000_000.0
    dist = 385000.56 + sigma_r / 1000.0
    return lam, beta, dist


# ---------- 太陽：黄経（Meeus ch25 低精度） ----------
def sun_longitude(jd):
    T = (jd - 2451545.0) / 36525.0
    L0 = _norm360(280.46646 + 36000.76983 * T + 0.0003032 * T**2)
    M = _norm360(357.52911 + 35999.05029 * T - 0.0001537 * T**2)
    C = (1.914602 - 0.004817 * T - 0.000014 * T**2) * math.sin(M * DEG) \
        + (0.019993 - 0.000101 * T) * math.sin(2 * M * DEG) \
        + 0.000289 * math.sin(3 * M * DEG)
    return _norm360(L0 + C)


def obliquity(jd):
    T = (jd - 2451545.0) / 36525.0
    return 23.439291 - 0.0130042 * T - 1.64e-7 * T**2 + 5.04e-7 * T**3


def gmst(jd):
    """グリニッジ平均恒星時（度, 0..360）。"""
    T = (jd - 2451545.0) / 36525.0
    theta = 280.46061837 + 360.98564736629 * (jd - 2451545.0) \
        + 0.000387933 * T**2 - T**3 / 38710000.0
    return _norm360(theta)


def ecl_to_equatorial(lam, beta, eps):
    lam_r, beta_r, eps_r = lam * DEG, beta * DEG, eps * DEG
    ra = math.atan2(
        math.sin(lam_r) * math.cos(eps_r) - math.tan(beta_r) * math.sin(eps_r),
        math.cos(lam_r))
    dec = math.asin(
        math.sin(beta_r) * math.cos(eps_r)
        + math.cos(beta_r) * math.sin(eps_r) * math.sin(lam_r))
    return _norm360(ra * RAD), dec * RAD


def equatorial_to_horizontal(ra, dec, lat, lon, jd):
    """RA/Dec(°) → 方位角az(北0/東90°)・高度alt(°)。lonは東経+。"""
    lst = _norm360(gmst(jd) + lon)  # 地方恒星時
    H = (lst - ra) * DEG            # 時角
    dec_r, lat_r = dec * DEG, lat * DEG
    alt = math.asin(math.sin(lat_r) * math.sin(dec_r)
                    + math.cos(lat_r) * math.cos(dec_r) * math.cos(H))
    az = math.atan2(
        math.sin(H),
        math.cos(H) * math.sin(lat_r) - math.tan(dec_r) * math.cos(lat_r))
    az = _norm360(az * RAD + 180.0)  # 北=0, 東=90 に正規化
    return az, alt * RAD


def moon_illumination(jd):
    """輝面比 k(0..1), 満ち欠け位相角(0..360, 0=新月→90=上弦→180=満月),
       明縁位置角 chi(°)。waxing判定は位相角<180。"""
    lam_m, beta_m, dist_m = moon_position(jd)
    lam_s = sun_longitude(jd)
    eps = obliquity(jd)
    ra_m, dec_m = ecl_to_equatorial(lam_m, beta_m, eps)
    # 太陽は黄緯0近似
    ra_s, dec_s = ecl_to_equatorial(lam_s, 0.0, eps)
    ra_m_r, dec_m_r = ra_m * DEG, dec_m * DEG
    ra_s_r, dec_s_r = ra_s * DEG, dec_s * DEG
    # 地心離角 psi
    cos_psi = (math.sin(dec_s_r) * math.sin(dec_m_r)
               + math.cos(dec_s_r) * math.cos(dec_m_r)
               * math.cos(ra_s_r - ra_m_r))
    psi = math.acos(max(-1.0, min(1.0, cos_psi)))
    # 位相角 i（Meeus 48.3、太陽距離≈149.6e6km）
    sun_dist = 149_598_000.0
    i = math.atan2(sun_dist * math.sin(psi),
                   dist_m - sun_dist * math.cos(psi))
    k = (1 + math.cos(i)) / 2.0
    # 明縁位置角 chi（Meeus 48.5）
    chi = math.atan2(
        math.cos(dec_s_r) * math.sin(ra_s_r - ra_m_r),
        math.sin(dec_s_r) * math.cos(dec_m_r)
        - math.cos(dec_s_r) * math.sin(dec_m_r) * math.cos(ra_s_r - ra_m_r))
    # waxing/waning：月黄経-太陽黄経
    elong = _norm360(lam_m - lam_s)
    waxing = elong < 180.0
    phase_angle = elong  # 0=新月, 90=上弦, 180=満月, 270=下弦
    return k, phase_angle, _norm360(chi * RAD), waxing


def full_report(year, mo, day, ut_hour, lat, lon):
    jd = julian_day(year, mo, day, ut_hour)
    lam, beta, dist = moon_position(jd)
    eps = obliquity(jd)
    ra, dec = ecl_to_equatorial(lam, beta, eps)
    az, alt = equatorial_to_horizontal(ra, dec, lat, lon, jd)
    k, phase, chi, waxing = moon_illumination(jd)
    names = ["新月", "三日月(上)", "上弦", "十三夜(上)", "満月",
             "十八夜(下)", "下弦", "有明(下)"]
    seg = int(((phase + 22.5) % 360) // 45)
    return {
        "jd": jd, "lambda": lam, "beta": beta, "dist_km": dist,
        "ra": ra, "dec": dec, "az": az, "alt": alt,
        "k": k, "phase_angle": phase, "chi": chi, "waxing": waxing,
        "phase_name": names[seg],
    }


if __name__ == "__main__":
    # 東京 35.68N, 139.77E で今日と前後日を出す
    lat, lon = 35.6812, 139.7671
    print("=== かぐや姫カメラ 月計算 検算（東京, UT時刻） ===\n")
    for label, (y, mo, d, h) in {
        "今夜 2026-08-28 21:00 JST": (2026, 8, 28, 21 - 9),
        "昨夜 2026-08-27 21:00 JST": (2026, 8, 27, 21 - 9),
        "明晩 2026-08-29 21:00 JST": (2026, 8, 29, 21 - 9),
        "満月確認 2025-01-13 22:00 UT": (2025, 1, 13, 22),
        "新月確認 2025-01-29 12:00 UT": (2025, 1, 29, 12),
    }.items():
        r = full_report(y, mo, d, h, lat, lon)
        print(f"[{label}]")
        print(f"  方位角 az = {r['az']:6.1f}°  高度 alt = {r['alt']:6.1f}°")
        print(f"  輝面比 k  = {r['k']*100:5.1f}%  位相角 = {r['phase_angle']:5.1f}°"
              f"  {'満ちる' if r['waxing'] else '欠ける'}  {r['phase_name']}")
        print(f"  距離 = {r['dist_km']:.0f} km  明縁PA = {r['chi']:.0f}°\n")
