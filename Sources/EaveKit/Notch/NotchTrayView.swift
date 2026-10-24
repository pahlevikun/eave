#if canImport(AppKit)
import EaveCore
import SwiftUI

/// Renders overflow tray items from a precomputed plan.
struct NotchTrayView: View {
    let plan: NotchTrayModel.Plan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(plan.overflowed, id: \.id) { item in
                Text(item.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
#endif
