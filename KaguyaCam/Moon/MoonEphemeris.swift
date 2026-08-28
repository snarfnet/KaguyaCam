import Foundation

/// 月の位置と満ち欠けの計算エンジン。
/// Meeus『Astronomical Algorithms』ベース（月=ch47, 太陽=ch25, 変換=ch13/ch25）。
/// tools/moon.py で検算した式をそのまま移植している。
enum MoonEphemeris {

    struct State {
        var azimuth: Double     // 方位角（度, 北=0 東=90 南=180 西=270）
        var altitude: Double    // 高度（度, 地平線=0 天頂=90）
        var illumination: Double // 輝面比 k（0=新月, 1=満月）
        var phaseAngle: Double  // 位相角（度, 0=新月 90=上弦 180=満月 270=下弦）
        var waxing: Bool        // true=満ちる, false=欠ける
        var brightLimbPA: Double // 明縁位置角（度）
        var distanceKm: Double
        var phaseNameJa: String
        var phaseNameEn: String
    }

    private static let deg = Double.pi / 180.0
    private static let rad = 180.0 / Double.pi

    // MARK: - ユリウス日

    /// UTC の日時 → ユリウス日。
    static func julianDay(_ date: Date) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        var year = c.year!
        var month = c.month!
        let day = c.day!
        let utHour = Double(c.hour!) + Double(c.minute!) / 60.0 + Double(c.second!) / 3600.0
        if month <= 2 { year -= 1; month += 12 }
        let a = floor(Double(year) / 100.0)
        let b = 2 - a + floor(a / 4.0)
        let jd = floor(365.25 * (Double(year) + 4716))
            + floor(30.6001 * (Double(month) + 1))
            + Double(day) + b - 1524.5
        return jd + utHour / 24.0
    }

    private static func norm360(_ x: Double) -> Double {
        let r = x.truncatingRemainder(dividingBy: 360.0)
        return r < 0 ? r + 360.0 : r
    }

    // MARK: - 月の黄経・黄緯・距離

    // D, M, Mp, F, Σl係数(1e-6°), Σr係数(1e-3km)
    private static let lonLatTerms: [(Double, Double, Double, Double, Double, Double)] = [
        (0,0,1,0,6288774,-20905355),(2,0,-1,0,1274027,-3699111),
        (2,0,0,0,658314,-2955968),(0,0,2,0,213618,-569925),
        (0,1,0,0,-185116,48888),(0,0,0,2,-114332,-3149),
        (2,0,-2,0,58793,246158),(2,-1,-1,0,57066,-152138),
        (2,0,1,0,53322,-170733),(2,-1,0,0,45758,-204586),
        (0,1,-1,0,-40923,-129620),(1,0,0,0,-34720,108743),
        (0,1,1,0,-30383,104755),(2,0,-3,0,15327,10321),
        (0,0,1,-2,-12528,0),(0,0,1,2,10980,79661),
        (4,0,-1,0,10675,-34782),(0,0,3,0,10034,-23210),
        (4,0,-2,0,8548,-21636),(2,1,-1,0,-7888,24208),
        (2,1,0,0,-6766,30824),(1,0,-1,0,-5163,-8379),
        (1,1,0,0,4987,-16675),(2,-1,1,0,4036,-12831),
        (2,0,2,0,3994,-10445),(4,0,0,0,3861,-11650),
        (2,0,-1,-2,3665,14403),
    ]

    // D, M, Mp, F, Σb係数(1e-6°)
    private static let latTerms: [(Double, Double, Double, Double, Double)] = [
        (0,0,0,1,5128122),(0,0,1,1,280602),(0,0,1,-1,277693),
        (2,0,0,-1,173237),(2,0,-1,1,55413),(2,0,-1,-1,46271),
        (2,0,0,1,32573),(0,0,2,1,17198),(2,0,1,-1,9266),
        (0,0,2,-1,8822),(2,-1,0,-1,8216),(2,0,-2,-1,4324),
        (2,0,1,1,4200),(2,1,0,-1,-3359),(2,-1,-1,1,2463),
        (2,-1,0,1,2211),(2,-1,-1,-1,2065),(0,1,-1,-1,-1870),
        (4,0,-1,-1,1828),(0,1,0,1,-1794),(0,0,0,3,-1749),
    ]

    /// 月の視黄経 λ(°), 黄緯 β(°), 地心距離(km)。
    static func moonPosition(_ jd: Double) -> (lambda: Double, beta: Double, dist: Double) {
        let T = (jd - 2451545.0) / 36525.0
        let Lp = norm360(218.3164477 + 481267.88123421*T - 0.0015786*T*T
                         + T*T*T/538841 - T*T*T*T/65194000)
        let D = norm360(297.8501921 + 445267.1114034*T - 0.0018819*T*T
                        + T*T*T/545868 - T*T*T*T/113065000)
        let M = norm360(357.5291092 + 35999.0502909*T - 0.0001536*T*T + T*T*T/24490000)
        let Mp = norm360(134.9633964 + 477198.8675055*T + 0.0087414*T*T
                         + T*T*T/69699 - T*T*T*T/14712000)
        let F = norm360(93.2720950 + 483202.0175233*T - 0.0036539*T*T
                        - T*T*T/3526000 + T*T*T*T/863310000)
        let E = 1 - 0.002516*T - 0.0000074*T*T

        var sigmaL = 0.0, sigmaR = 0.0
        for (d, m, mp, f, cl, cr) in lonLatTerms {
            let arg = (D*d + M*m + Mp*mp + F*f) * deg
            let e = pow(E, abs(m))
            sigmaL += cl * e * sin(arg)
            sigmaR += cr * e * cos(arg)
        }
        let A1 = (119.75 + 131.849*T) * deg
        let A2 = (53.09 + 479264.290*T) * deg
        sigmaL += 3958*sin(A1) + 1962*sin((Lp - F)*deg) + 318*sin(A2)

        var sigmaB = 0.0
        for (d, m, mp, f, cb) in latTerms {
            let arg = (D*d + M*m + Mp*mp + F*f) * deg
            let e = pow(E, abs(m))
            sigmaB += cb * e * sin(arg)
        }
        let A3 = (313.45 + 481266.484*T) * deg
        sigmaB += -2235*sin(Lp*deg) + 382*sin(A3)
            + 175*sin((A1 - F)*deg) + 175*sin((A1 + F)*deg)
            + 127*sin((Lp - Mp)*deg) - 115*sin((Lp + Mp)*deg)

        let lambda = norm360(Lp + sigmaL / 1_000_000.0)
        let beta = sigmaB / 1_000_000.0
        let dist = 385000.56 + sigmaR / 1000.0
        return (lambda, beta, dist)
    }

    // MARK: - 太陽の黄経（低精度）

    static func sunLongitude(_ jd: Double) -> Double {
        let T = (jd - 2451545.0) / 36525.0
        let L0 = norm360(280.46646 + 36000.76983*T + 0.0003032*T*T)
        let M = norm360(357.52911 + 35999.05029*T - 0.0001537*T*T)
        let C = (1.914602 - 0.004817*T - 0.000014*T*T) * sin(M*deg)
            + (0.019993 - 0.000101*T) * sin(2*M*deg)
            + 0.000289 * sin(3*M*deg)
        return norm360(L0 + C)
    }

    static func obliquity(_ jd: Double) -> Double {
        let T = (jd - 2451545.0) / 36525.0
        return 23.439291 - 0.0130042*T - 1.64e-7*T*T + 5.04e-7*T*T*T
    }

    /// グリニッジ平均恒星時（度）。
    static func gmst(_ jd: Double) -> Double {
        let T = (jd - 2451545.0) / 36525.0
        let theta = 280.46061837 + 360.98564736629*(jd - 2451545.0)
            + 0.000387933*T*T - T*T*T/38710000.0
        return norm360(theta)
    }

    static func eclToEquatorial(_ lambda: Double, _ beta: Double, _ eps: Double) -> (ra: Double, dec: Double) {
        let l = lambda*deg, b = beta*deg, e = eps*deg
        let ra = atan2(sin(l)*cos(e) - tan(b)*sin(e), cos(l))
        let dec = asin(sin(b)*cos(e) + cos(b)*sin(e)*sin(l))
        return (norm360(ra*rad), dec*rad)
    }

    /// RA/Dec(°) → 方位角(北=0 東=90)・高度(°)。lon は東経を正とする。
    static func equatorialToHorizontal(ra: Double, dec: Double, lat: Double, lon: Double, jd: Double) -> (az: Double, alt: Double) {
        let lst = norm360(gmst(jd) + lon)
        let H = (lst - ra) * deg
        let d = dec*deg, la = lat*deg
        let alt = asin(sin(la)*sin(d) + cos(la)*cos(d)*cos(H))
        var az = atan2(sin(H), cos(H)*sin(la) - tan(d)*cos(la))
        az = norm360(az*rad + 180.0)
        return (az, alt*rad)
    }

    // MARK: - 満ち欠け

    private static func illumination(_ jd: Double)
        -> (k: Double, phaseAngle: Double, chi: Double, waxing: Bool) {
        let (lamM, betaM, distM) = moonPosition(jd)
        let lamS = sunLongitude(jd)
        let eps = obliquity(jd)
        let m = eclToEquatorial(lamM, betaM, eps)
        let s = eclToEquatorial(lamS, 0.0, eps)
        let raM = m.ra*deg, decM = m.dec*deg
        let raS = s.ra*deg, decS = s.dec*deg
        let cosPsi = sin(decS)*sin(decM) + cos(decS)*cos(decM)*cos(raS - raM)
        let psi = acos(max(-1.0, min(1.0, cosPsi)))
        let sunDist = 149_598_000.0
        let i = atan2(sunDist*sin(psi), distM - sunDist*cos(psi))
        let k = (1 + cos(i)) / 2.0
        let chi = atan2(cos(decS)*sin(raS - raM),
                        sin(decS)*cos(decM) - cos(decS)*sin(decM)*cos(raS - raM))
        let elong = norm360(lamM - lamS)
        return (k, elong, norm360(chi*rad), elong < 180.0)
    }

    private static func phaseNames(_ phaseAngle: Double) -> (ja: String, en: String) {
        let ja = ["新月", "三日月", "上弦の月", "十三夜", "満月", "寝待月", "下弦の月", "有明月"]
        let en = ["New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous",
                  "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"]
        let seg = Int(((phaseAngle + 22.5).truncatingRemainder(dividingBy: 360.0)) / 45.0)
        let idx = max(0, min(7, seg))
        return (ja[idx], en[idx])
    }

    // MARK: - 公開API

    /// 指定の日時・観測地点における月の状態を返す。
    static func state(date: Date, latitude: Double, longitude: Double) -> State {
        let jd = julianDay(date)
        let (lambda, beta, dist) = moonPosition(jd)
        let eps = obliquity(jd)
        let eq = eclToEquatorial(lambda, beta, eps)
        let hz = equatorialToHorizontal(ra: eq.ra, dec: eq.dec, lat: latitude, lon: longitude, jd: jd)
        let il = illumination(jd)
        let names = phaseNames(il.phaseAngle)
        return State(azimuth: hz.az, altitude: hz.alt,
                     illumination: il.k, phaseAngle: il.phaseAngle,
                     waxing: il.waxing, brightLimbPA: il.chi, distanceKm: dist,
                     phaseNameJa: names.ja, phaseNameEn: names.en)
    }
}
