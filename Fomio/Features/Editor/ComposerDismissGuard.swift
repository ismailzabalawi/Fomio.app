import SwiftUI
import UIKit

/// Installs the sheet delegate through a native view without adding a child controller.
/// The guard participates in the existing hosting hierarchy through the responder chain.
struct ComposerDismissGuard: UIViewRepresentable {
    var blocked: Bool
    var submitting: Bool
    var onAttempt: () -> Void
    func makeUIView(context: Context) -> GuardView { GuardView() }
    func updateUIView(_ view: GuardView, context: Context) {
        view.blocked = blocked; view.submitting = submitting; view.onAttempt = onAttempt
        DispatchQueue.main.async { [weak view] in view?.install() }
    }
    final class GuardView: UIView, UIAdaptivePresentationControllerDelegate {
        var blocked = false
        var submitting = false
        var onAttempt: (() -> Void)?
        override func didMoveToWindow() { super.didMoveToWindow(); install() }
        func install() {
            guard window != nil else { return }
            var responder: UIResponder? = self
            while let current = responder {
                if let controller = current as? UIViewController {
                    var candidate: UIViewController? = controller
                    while let host = candidate {
                        if let presentation = host.presentationController {
                            presentation.delegate = self
                        }
                        candidate = host.parent
                    }
                    return
                }
                responder = current.next
            }
        }
        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool { !blocked && !submitting }
        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) { if !submitting { onAttempt?() } }
    }
}
