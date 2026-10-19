import SwiftUI
import UIKit

/// Installs the sheet delegate through a native view without adding a child controller.
/// The guard participates in the existing hosting hierarchy through the responder chain.
struct ComposerDismissGuard: UIViewRepresentable {
    var blocked: Bool
    var submitting: Bool
    var transition: ComposerNavigationTransition
    var onAttempt: () -> Void
    func makeUIView(context: Context) -> GuardView { GuardView() }
    func updateUIView(_ view: GuardView, context: Context) {
        view.blocked = blocked; view.submitting = submitting; view.onAttempt = onAttempt; transition.anchor = view
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

/// Reports when the composer's navigation push or pop has settled. A keyboard requested while the pop
/// is still animating reaches the screen, but the returning composer never receives its safe area.
@MainActor final class ComposerNavigationTransition {
    weak var anchor: UIView?
    private var navigation: UINavigationController? {
        var responder: UIResponder? = anchor
        while let current = responder {
            if let controller = current as? UIViewController { return controller.navigationController }
            responder = current.next
        }
        return nil
    }
    func finished() async {
        guard let coordinator = navigation?.transitionCoordinator else { return }
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            // The completion is not called when the transition can no longer take part; resume at once then.
            if !coordinator.animate(alongsideTransition: nil, completion: { _ in done.resume() }) { done.resume() }
        }
    }
}
