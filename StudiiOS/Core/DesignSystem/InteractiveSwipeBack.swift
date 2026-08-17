//
//  InteractiveSwipeBack.swift
//  Gives back the swipe-from-the-left-edge gesture on screens that hide the
//  navigation bar.
//
//  UIKit switches the gesture off whenever the back button is hidden, and
//  SwiftUI's `.toolbar(.hidden, for: .navigationBar)` hides it — so a custom
//  header costs the student the gesture they expect. This puts an empty UIKit
//  view controller into the hierarchy purely to reach the enclosing
//  UINavigationController and turn the recogniser back on.
//
//  The delegate is ours, not nil: with a nil delegate the gesture also fires on
//  the root screen, which leaves UIKit trying to pop the last view controller and
//  wedges navigation until the app restarts.
//

import SwiftUI
import UIKit

extension View {
    /// Re-enables the edge swipe on a screen whose navigation bar is hidden.
    func interactiveSwipeBack() -> some View {
        background(InteractiveSwipeBackEnabler().frame(width: 0, height: 0))
    }
}

private struct InteractiveSwipeBackEnabler: UIViewControllerRepresentable {
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        /// Only pop when there is something to pop back to.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        // Runs once per navigation controller. `update` fires on every SwiftUI
        // pass — including the pass that presents a sheet — and reaching into
        // UIKit on each of those is a good way to disturb a presentation that is
        // mid-flight.
        guard context.coordinator.navigationController == nil else { return }

        // Deferred: on the first update the controller has not been added to the
        // navigation stack yet, so `navigationController` is still nil.
        DispatchQueue.main.async {
            guard let nav = controller.navigationController,
                  context.coordinator.navigationController == nil else { return }
            context.coordinator.navigationController = nav
            nav.interactivePopGestureRecognizer?.isEnabled = true
            nav.interactivePopGestureRecognizer?.delegate = context.coordinator
        }
    }
}
