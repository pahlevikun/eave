#if canImport(AppKit)
import AppKit
import EaveCore
import SwiftUI

struct NotchTrayView: View {
    let plan: NotchTrayModel.Plan
    let onPerform: (NotchTrayItem, ScriptItemAction) -> Bool

    @FocusState private var focusedID: String?

    init(
        plan: NotchTrayModel.Plan,
        onPerform: @escaping (NotchTrayItem, ScriptItemAction) -> Bool = { _, _ in false }
    ) {
        self.plan = plan
        self.onPerform = onPerform
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overflow preview").font(.system(size: 13, weight: .semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if plan.overflowed.isEmpty {
                        Text("No script items exceed the available space on this display.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(plan.overflowed, id: \.id) { trayItem in
                            NotchTrayRow(
                                item: trayItem.scriptItem,
                                isSelected: focusedID == trayItem.id,
                                perform: { action in onPerform(trayItem, action) }
                            )
                            .focused($focusedID, equals: trayItem.id)
                        }
                    }
                }
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Press Esc to close")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
        .onAppear {
            if focusedID == nil {
                focusedID = plan.overflowed.first?.id
            }
        }
        .onChange(of: plan.overflowed.map(\.id)) { _, ids in
            guard let focusedID, ids.contains(focusedID) else {
                focusedID = ids.first
                return
            }
        }
        .onKeyPress(phases: .down) { press in
            switch press.key {
            case .upArrow:
                moveSelection(by: -1)
                return .handled
            case .downArrow:
                moveSelection(by: 1)
                return .handled
            case .return:
                activateFocused()
                return .handled
            default:
                return .ignored
            }
        }
    }

    private func moveSelection(by delta: Int) {
        let ids = plan.overflowed.map(\.id)
        guard !ids.isEmpty else { return }
        let current = focusedID.flatMap { ids.firstIndex(of: $0) } ?? 0
        let next = min(max(0, current + delta), ids.count - 1)
        focusedID = ids[next]
    }

    private func activateFocused() {
        guard let focusedID,
              let trayItem = plan.overflowed.first(where: { $0.id == focusedID })
        else { return }
        let action = trayItem.scriptItem.action
        switch action {
        case .openURL:
            onPerform(trayItem, action)
        case .unsupported, .none:
            break
        }
    }
}
#endif
