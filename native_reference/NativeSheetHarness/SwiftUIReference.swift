import SwiftUI
import UIKit

/// Companion reference surface. Geometry instrumentation remains UIKit-owned;
/// this view is available for explicit SwiftUI semantics experiments, not a
/// substitute for the accepted UIKit trace evidence.
struct SwiftUIReference: View {
    @State private var presented = false
    @State private var selected: PresentationDetent = .medium
    @State private var disableDismiss = false
    @State private var scrollFirst = false
    @State private var nonmodal = false
    var body: some View {
        VStack(spacing: 20) {
            Text("Native SwiftUI Sheet Reference")
            Toggle("Disable interactive dismissal", isOn: $disableDismiss)
            Toggle("Scroll content first", isOn: $scrollFirst)
            Toggle("Undimmed through medium", isOn: $nonmodal)
            Button("Present opaque sheet") { presented = true }
        }
        .padding().background(Color.white)
        .sheet(isPresented: $presented) {
            VStack {
                Text("native.swiftui.medium_large")
                Button("Medium") { selected = .medium }
                Button("Large") { selected = .large }
                ScrollView { ForEach(0..<60) { n in Text("Known row \(n)").frame(height: 40) } }
            }
            .background(Color.white)
            .presentationBackground(Color.white)
            .presentationDetents([.height(320), .medium, .large], selection: $selected)
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(disableDismiss)
            .presentationContentInteraction(scrollFirst ? .scrolls : .resizes)
            .presentationBackgroundInteraction(nonmodal ? .enabled(upThrough: .medium) : .disabled)
        }
    }
}
