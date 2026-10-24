#if canImport(AppKit)
import AppKit
import EaveCore

@MainActor
public final class HiddenSectionController {
    public enum ToggleOutcome: Equatable, Sendable {
        case toggledSeparator
        case toggledFullMode(skipped: [String])
        case moveFailed(itemID: String)
    }

    public typealias ItemResolver = (String) -> ItemMover.Item?
    public typealias BarMetrics = () -> (width: Double, height: Double)
    public typealias OnExpand = () -> Void

    private let separatorEngine: SeparatorEngine
    private let itemMover: ItemMover
    private let resolveItem: ItemResolver
    private let barMetrics: BarMetrics
    private let onExpand: OnExpand
    private var savedOriginX: [String: CGFloat] = [:]

    public init(
        separatorEngine: SeparatorEngine,
        itemMover: ItemMover,
        resolveItem: @escaping ItemResolver,
        barMetrics: @escaping BarMetrics,
        onExpand: @escaping OnExpand = {}
    ) {
        self.separatorEngine = separatorEngine
        self.itemMover = itemMover
        self.resolveItem = resolveItem
        self.barMetrics = barMetrics
        self.onExpand = onExpand
    }

    public var isCollapsed: Bool { separatorEngine.collapsed }

    /// Executes the hide plan. Permission is already reflected in `decision`.
    @discardableResult
    public func toggle(decision: HidePlan.Decision) -> ToggleOutcome {
        if separatorEngine.collapsed {
            return expandSection()
        }
        return collapseSection(decision: decision)
    }

    private func expandSection() -> ToggleOutcome {
        let ids = Array(savedOriginX.keys)
        for id in ids {
            guard let originX = savedOriginX[id],
                  let item = resolveItem(id)
            else { continue }
            if !itemMover.move(item, toX: originX) {
                return .moveFailed(itemID: id)
            }
        }
        savedOriginX.removeAll()
        separatorEngine.toggleCollapsed()
        onExpand()
        return .toggledSeparator
    }

    private func collapseSection(decision: HidePlan.Decision) -> ToggleOutcome {
        switch decision {
        case .separator:
            separatorEngine.toggleCollapsed()
            return .toggledSeparator
        case .separateThenMove(let movable, let skipped):
            let metrics = barMetrics()
            let targetX = CGFloat(
                MoveGeometry.offscreenPoint(
                    forBarWidth: metrics.width,
                    barHeight: metrics.height
                ).x
            )
            for id in movable {
                guard let item = resolveItem(id) else {
                    return .moveFailed(itemID: id)
                }
                if savedOriginX[id] == nil {
                    savedOriginX[id] = item.frame.midX
                }
                if !itemMover.move(item, toX: targetX) {
                    return .moveFailed(itemID: id)
                }
            }
            separatorEngine.toggleCollapsed()
            return .toggledFullMode(skipped: skipped)
        }
    }
}
#endif
