import SwiftUI

/// Campo numerico che resta vuoto quando il valore è 0 (niente "0" da cancellare) e accetta virgola o punto.
struct NumberField: View {
    let placeholder: String
    @Binding var value: Double
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .onAppear { text = Self.format(value) }
            .onChange(of: text) { _, t in value = Self.parse(t) }
            .onChange(of: value) { _, v in if Self.parse(text) != v { text = Self.format(v) } }
    }

    private static func format(_ v: Double) -> String {
        v == 0 ? "" : v.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
    }

    private static func parse(_ t: String) -> Double {
        Double(t.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}
