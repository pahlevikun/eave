#if canImport(AppKit)
import EaveCore
import SwiftUI

struct NotchTrayView: View {
    let plan: NotchTrayModel.Plan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overflow preview").font(.system(size: 13, weight: .semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if plan.overflowed.isEmpty {
                        Text("No script items exceed the available space on this display.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(plan.overflowed, id: \.id) { item in
                            Text(item.title).frame(maxWidth: .infinity, alignment: .leading)
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
    }
}
#endif
