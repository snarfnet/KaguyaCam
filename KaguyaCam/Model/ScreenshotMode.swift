import Foundation

/// CI のスクショ撮影が渡す `-screenshot <n>` 引数を読む。
/// ARはシミュレータで描画されないため、スクショ時は描いた夜空に
/// 実アプリの月ディスク・HUDを重ねた画面を表示する。
enum ScreenshotMode {
    static let value: String? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screenshot"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }()

    static var isActive: Bool { value != nil }
}
