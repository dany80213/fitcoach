import SwiftUI

/// Intestazione di un esercizio (in allenamento o in routine): nome, badge superset, riposo e menu azioni.
struct ExerciseHeader: View {
    let name: String
    let supersetLetter: String?
    @Binding var restSeconds: Int
    let canJoin: Bool
    let onJoin: () -> Void
    let onLeave: () -> Void
    let onRemove: () -> Void

    private static let palette: [Color] = [.orange, .teal, .pink, .indigo]

    private var color: Color {
        guard let l = supersetLetter, let a = l.unicodeScalars.first else { return .secondary }
        return Self.palette[Int(a.value - 65) % Self.palette.count]
    }

    private var restDescription: String {
        switch restSeconds {
        case 0: "Riposo \(RestTimer.format(RestTimer.defaultSeconds))"
        case ..<0: "Nessun riposo"
        default: "Riposo \(RestTimer.format(restSeconds))"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if let letter = supersetLetter {
                Text("SUPERSET \(letter)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .foregroundStyle(color)
                    .glassEffect(.regular.tint(color.opacity(0.35)), in: .capsule)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.subheadline.bold())
                Label(restDescription, systemImage: "timer").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                if canJoin {
                    Button { onJoin() } label: { Label("Superset con l'esercizio sopra", systemImage: "link") }
                }
                if supersetLetter != nil {
                    Button { onLeave() } label: { Label("Rimuovi dal superset", systemImage: "link.badge.minus") }
                }
                Picker("Riposo", selection: $restSeconds) {
                    Text("Predefinito (\(RestTimer.format(RestTimer.defaultSeconds)))").tag(0)
                    Text("Nessuno").tag(-1)
                    ForEach([30, 45, 60, 90, 120, 150, 180, 240, 300], id: \.self) { Text(RestTimer.format($0)).tag($0) }
                }
                .pickerStyle(.menu)
                Button("Rimuovi esercizio", role: .destructive, action: onRemove)
            } label: { Image(systemName: "ellipsis.circle") }
        }
        .textCase(nil)
        .foregroundStyle(.primary)
    }
}
