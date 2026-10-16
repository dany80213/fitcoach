import SwiftUI

/// Sfondo sfumato dietro liste e chat: dà al Liquid Glass qualcosa da rifrangere.
struct AppBackground: View {
    var body: some View {
        LinearGradient(colors: [.blue.opacity(0.30), .purple.opacity(0.18), .teal.opacity(0.10)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

extension View {
    /// Lista trasparente su sfondo sfumato, righe in vetro.
    func glassList() -> some View {
        self.scrollContentBackground(.hidden)
            .background(AppBackground())
    }

    /// Lista trasparente senza sfondo proprio (lo sfondo lo mette il contenitore).
    func transparentList() -> some View { self.scrollContentBackground(.hidden) }

    /// Scheda in Liquid Glass con angoli arrotondati.
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        self.padding()
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}
