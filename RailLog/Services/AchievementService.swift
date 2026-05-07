import GameKit
import SwiftUI

@Observable
final class AchievementService {
    static let shared = AchievementService()

    private(set) var authenticated = false

    private init() {
        authenticate()
    }

    // MARK: - Auth

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, error in
            if let vc {
                self?.presentAuth(vc)
            } else if let _ = error {
                self?.authenticated = false
            } else {
                self?.authenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    private func presentAuth(_ vc: UIViewController) {
        topViewController()?.present(vc, animated: true)
    }

    // MARK: - Achievements

    private let achievements: [String: AchievementDef] = [
        "first_trip": AchievementDef(
            id: "first_trip",
            title: "初出茅庐",
            description: "完成第一次运转记录"
        ),
        "5033": AchievementDef(
            id: "5033",
            title: "5033",
            description: "乘坐 CR400BF-5033"
        ),
        "450": AchievementDef(
            id: "450",
            title: "450",
            description: "乘坐 CR450 系列动车组"
        )
    ]

    func reportAchievement(id: String, percentComplete: Double) {
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { error in
            if let error { print("Achievement report error: \(error.localizedDescription)") }
        }
    }

    func checkLog(_ log: TripLog, totalCount: Int) {
        if totalCount >= 1 {
            reportAchievement(id: "first_trip", percentComplete: 100)
        }
        if log.emuNumber == "CR400BF-5033" {
            reportAchievement(id: "5033", percentComplete: 100)
        }
        if log.emuNumber.hasPrefix("CR450") {
            reportAchievement(id: "450", percentComplete: 100)
        }
    }

    func syncAll(logs: [TripLog]) {
        let nonDrafts = logs.filter { !$0.isDraft }
        for log in nonDrafts {
            checkLog(log, totalCount: nonDrafts.count)
        }
    }

}

// MARK: - GKGameCenterViewController Wrapper

struct GKGameCenterView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let vc = GKGameCenterViewController(state: .achievements)
        vc.gameCenterDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
            dismiss()
        }
    }
}

struct AchievementDef {
    let id: String
    let title: String
    let description: String
}
