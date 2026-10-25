#if canImport(AppKit)
import AppKit
import EaveCore
import SwiftUI

public struct NotchTrayRow: View {
    public let item: ScriptItem
    public let isSelected: Bool
    public let perform: (ScriptItemAction) -> Bool

    public init(item: ScriptItem, isSelected: Bool, perform: @escaping (ScriptItemAction) -> Bool) {
        self.item = item
        self.isSelected = isSelected
        self.perform = perform
    }

    public var isActionable: Bool {
        switch item.action {
        case .openURL:
            return true
        case .runShell, .unsupported, .none:
            return false
        }
    }

    public var body: some View {
        Button {
            guard isActionable else { return }
            perform(item.action)
        } label: {
            Text(item.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(isActionable ? Color(nsColor: .labelColor) : Color(nsColor: .secondaryLabelColor))
        }
        .buttonStyle(NotchTrayRowButtonStyle(isSelected: isSelected))
        .disabled(!isActionable)
        .accessibilityLabel(item.title)
        .frame(height: 32)
    }
}

struct NotchTrayRowButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color(nsColor: .selectedContentBackgroundColor) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isSelected ? Color(nsColor: .keyboardFocusIndicatorColor) : .clear, lineWidth: 2)
            )
    }
}
#endif
