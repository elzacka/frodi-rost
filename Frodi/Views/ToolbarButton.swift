import SwiftUI

/// An `IconButton` in the navigation bar. iOS draws bar buttons on glass with a rim; the header's settings button has none
/// and bar buttons should match it. So the item drops the shared background and uses the header's button.
struct ToolbarButton: ToolbarContent {
    let icon: Icon
    let label: String
    let placement: ToolbarItemPlacement
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: placement) {
            IconButton(icon: icon, size: IconSize.toolbar, label: label, action: action)
        }
        .sharedBackgroundVisibility(.hidden)
    }
}

/// The back button, drawn by the app so it matches the others in the bar.
/// The system's sits on glass: neither the bar's tint nor `UIBarButtonItem.appearance()` reaches it, and the latter aborts.
/// So the screen hides it and draws its own; `PopGestureKeeper` keeps the left-edge swipe working.
private struct BackButton: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarButton(icon: .back, label: "Tilbake", placement: .topBarLeading) { dismiss() }
            }
            .background(PopGestureKeeper().frame(width: 0, height: 0).allowsHitTesting(false))
    }
}

extension View {
    func frodiBackButton() -> some View {
        modifier(BackButton())
    }
}

/// Keeps the swipe from the left edge alive on a screen that hides its back button.
/// UIKit turns the pop gesture off there: its delegate, the navigation controller, answers no. This installs a delegate that
/// says yes when there is a screen to go back to and no transition is running. Without it the swipe does nothing (simulator).
private struct PopGestureKeeper: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> Controller {
        Controller(coordinator: context.coordinator)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigation: UINavigationController?
        /// The delegate the recognizer had, given back when the screen goes.
        weak var previous: UIGestureRecognizerDelegate?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let navigation else { return false }
            return navigation.viewControllers.count > 1 && navigation.transitionCoordinator == nil
        }
    }

    final class Controller: UIViewController {
        private let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        // The navigation controller is reachable once the screen is being shown,
        // not when this controller is created.
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let navigation = navigationController,
                  let gesture = navigation.interactivePopGestureRecognizer,
                  gesture.delegate !== coordinator else { return }
            coordinator.navigation = navigation
            coordinator.previous = gesture.delegate
            gesture.delegate = coordinator
        }

        // The delegate is weak, so a screen that goes without giving it back
        // leaves the recognizer with none, and the next screen with no
        // back button of its own would be without the system's rule.
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard let gesture = coordinator.navigation?.interactivePopGestureRecognizer,
                  gesture.delegate === coordinator else { return }
            gesture.delegate = coordinator.previous
        }
    }
}
