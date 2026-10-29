#if canImport(UIKit)
import SwiftUI
import UIKit

struct NativeNotebookCurl: UIViewControllerRepresentable {
    let play: OriginalPlaySession
    @ObservedObject var notebook: DialogueNotebook
    let layout: DialogueNotebookLayout
    let metrics: DialogueSpreadMetrics
    let fontSize: CGFloat
    let reduceMotion: Bool
    var gesturesEnabled = true

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [.spineLocation: UIPageViewController.SpineLocation.mid.rawValue])
        controller.isDoubleSided = true
        controller.view.backgroundColor = .clear
        controller.view.semanticContentAttribute = .forceLeftToRight
        controller.delegate = context.coordinator
        controller.dataSource = context.coordinator
        context.coordinator.synchronise(controller)
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.synchronise(controller)
    }

    static func dismantleUIViewController(_ controller: UIPageViewController, coordinator: Coordinator) {
        controller.delegate = nil
        controller.dataSource = nil
        if let revision = coordinator.activeRevision {
            coordinator.parent.notebook.finishTurn(revision: revision, completed: false)
        }
    }

    @MainActor
    final class Page: UIHostingController<NotebookDialogueLeaf> {
        let index: Int

        init(index: Int, leaf: NotebookDialogueLeaf) {
            self.index = index
            super.init(rootView: leaf)
            safeAreaRegions = []
            view.backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("Use init(index:leaf:)") }
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: NativeNotebookCurl
        var activeRevision: Int?
        private var pages: [Int: Page] = [:]
        private var baseSpread = 0
        private var allowsBack = false
        private var allowsForward = false
        private var pageSize = CGSize.zero
        private var pageRanges: [NSRange] = []

        init(_ parent: NativeNotebookCurl) { self.parent = parent }

        private func page(_ index: Int) -> Page {
            if let page = pages[index] { return page }
            let page = Page(index: index, leaf: leaf(index))
            pages[index] = page
            return page
        }

        private func leaf(_ index: Int) -> NotebookDialogueLeaf {
            NotebookDialogueLeaf(play: parent.play, notebook: parent.notebook,
                layout: parent.layout, metrics: parent.metrics, pageIndex: index)
        }

        func synchronise(_ controller: UIPageViewController) {
            let book = parent.notebook
            if let revision = activeRevision, book.isTurning, revision == book.turnRevision { return }
            activeRevision = nil
            baseSpread = book.reader.spreadIndex
            let back = parent.gesturesEnabled && parent.play.canReviewConversations && book.canTurnBack
            let forward = parent.gesturesEnabled && book.canTurnForward
            let needsRefresh = back != allowsBack || forward != allowsForward ||
                pageSize != parent.metrics.pageSize || pageRanges != book.reader.pages
            allowsBack = back
            allowsForward = forward
            pageSize = parent.metrics.pageSize
            pageRanges = book.reader.pages
            let left = book.reader.leftIndex
            pages = pages.filter { (left - 2...left + 3).contains($0.key) }
            for (index, page) in pages { page.rootView = leaf(index) }
            let visible = controller.viewControllers?.compactMap { ($0 as? Page)?.index } ?? []
            let target = [page(left), page(left + 1)]
            if visible != [left, left + 1] || needsRefresh {
                let revision = book.turnRevision
                let animated = book.isTurning && !parent.reduceMotion && !visible.isEmpty
                if book.isTurning { activeRevision = revision }
                controller.setViewControllers(target, direction: book.turnsBackward ? .reverse : .forward,
                    animated: animated) { [weak self, weak controller] finished in
                    Task { @MainActor in
                        guard let self, self.activeRevision == revision else { return }
                        self.activeRevision = nil
                        book.finishTurn(revision: revision, completed: finished)
                        if let controller { self.synchronise(controller) }
                    }
                }
            }
            for gesture in controller.gestureRecognizers {
                if gesture is UITapGestureRecognizer {
                    gesture.isEnabled = false
                } else {
                    gesture.isEnabled = parent.gesturesEnabled && !parent.reduceMotion && (allowsBack || allowsForward)
                }
            }
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let index = (viewController as? Page)?.index else { return nil }
            let previous = index - 1
            let minimum = (baseSpread - (allowsBack ? 1 : 0)) * 2
            guard previous >= max(0, minimum) else { return nil }
            return page(previous)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let index = (viewController as? Page)?.index else { return nil }
            let next = index + 1
            let maximum = (baseSpread + (allowsForward ? 1 : 0)) * 2 + 1
            guard next <= maximum else { return nil }
            return page(next)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                willTransitionTo pendingViewControllers: [UIViewController]) {
            guard let next = pendingViewControllers.compactMap({ ($0 as? Page)?.index }).min() else { return }
            let destination = next / 2
            guard destination != baseSpread,
                  parent.notebook.beginInteractiveTurn(backward: destination < baseSpread) else { return }
            activeRevision = parent.notebook.turnRevision
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard let revision = activeRevision else { return }
            activeRevision = nil
            parent.notebook.finishTurn(revision: revision, completed: completed)
            synchronise(pageViewController)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                spineLocationFor orientation: UIInterfaceOrientation) -> UIPageViewController.SpineLocation {
            .mid
        }
    }
}
#endif
