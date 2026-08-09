import PassKit
import UIKit

/// Presents a signed pass for adding to Wallet.
///
/// PKAddPassesViewController is an out-of-process (remote) view controller.
/// Presenting it inside a SwiftUI sheet renders a blank page on first use while
/// passd cold-starts, so we present it from the topmost UIViewController instead.
enum WalletPassPresenter {
    /// - Parameter onFinish: called after the Wallet UI is dismissed; `true` if the pass is in the library.
    static func present(_ pass: PKPass, onFinish: @escaping (Bool) -> Void) {
        guard let vc = PKAddPassesViewController(pass: pass) else {
            print("[Wallet] PKAddPassesViewController(pass:) returned nil")
            onFinish(false)
            return
        }
        guard let top = topViewController() else {
            print("[Wallet] no view controller to present from")
            onFinish(false)
            return
        }
        let delegate = Delegate(pass: pass, onFinish: onFinish)
        vc.delegate = delegate
        // Keep the delegate alive until the presented VC is gone
        objc_setAssociatedObject(vc, &delegateHandle, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        top.present(vc, animated: true)
    }

    private static var delegateHandle: UInt8 = 0

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let root = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    private final class Delegate: NSObject, PKAddPassesViewControllerDelegate {
        let pass: PKPass
        let onFinish: (Bool) -> Void

        init(pass: PKPass, onFinish: @escaping (Bool) -> Void) {
            self.pass = pass
            self.onFinish = onFinish
        }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            let added = PKPassLibrary().containsPass(pass)
            controller.dismiss(animated: true) { [onFinish] in
                onFinish(added)
            }
        }
    }
}
