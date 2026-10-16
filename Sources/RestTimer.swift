import SwiftUI
import UserNotifications

/// Timer di riposo condiviso da tutta l'app: parte quando si completa una serie,
/// mostra un conto alla rovescia e avvisa (notifica se l'app è in background, vibrazione se è aperta).
@MainActor @Observable
final class RestTimer {
    private(set) var endDate: Date?
    private(set) var label = ""
    /// Incrementa a ogni fine timer: usato per far scattare la vibrazione.
    private(set) var finishedCount = 0
    private var task: Task<Void, Never>?
    private let notificationID = "rest-timer"

    var isActive: Bool { endDate != nil }

    nonisolated static var defaultSeconds: Int {
        let v = UserDefaults.standard.integer(forKey: "defaultRestSeconds")
        return v > 0 ? v : 90
    }

    nonisolated static func format(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) s" : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func start(seconds: Int, label: String) {
        guard seconds > 0 else { return }
        self.label = label
        endDate = Date.now.addingTimeInterval(TimeInterval(seconds))
        requestAuthorizationIfNeeded()
        reschedule()
    }

    func adjust(by delta: Int) {
        guard let end = endDate else { return }
        let newEnd = end.addingTimeInterval(TimeInterval(delta))
        if newEnd <= .now { stop() } else { endDate = newEnd; reschedule() }
    }

    func stop() {
        task?.cancel()
        endDate = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    // MARK: Interno

    private func reschedule() {
        task?.cancel()
        guard let end = endDate else { return }
        scheduleNotification(at: end)
        task = Task { [weak self] in
            let wait = end.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled, let self, self.endDate == end else { return }
            self.endDate = nil
            self.finishedCount += 1
            // L'app è aperta: basta la vibrazione, la notifica sarebbe ridondante.
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [self.notificationID])
        }
    }

    private func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleNotification(at end: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Riposo finito"
        content.body = label.isEmpty ? "Pronto per la prossima serie." : "Pronto per la prossima serie — \(label)"
        content.sound = .default
        let interval = max(1, end.timeIntervalSinceNow)
        let request = UNNotificationRequest(identifier: notificationID, content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }
}

/// Barra del timer, mostrata come accessorio in Liquid Glass sopra la tab bar.
struct RestTimerBar: View {
    @Environment(RestTimer.self) private var timer

    var body: some View {
        if let end = timer.endDate {
            HStack(spacing: 10) {
                Image(systemName: "timer").font(.title3)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Riposo").font(.caption2).foregroundStyle(.secondary)
                    Text(timerInterval: Date.now...max(end, Date.now.addingTimeInterval(1)), countsDown: true)
                        .font(.title3.monospacedDigit().bold())
                }
                Spacer()
                Button { timer.adjust(by: -15) } label: { barLabel { Text("−15") } }
                Button { timer.adjust(by: 15) } label: { barLabel { Text("+15") } }
                Button { timer.stop() } label: { barLabel { Image(systemName: "forward.end.fill") } }
                    .accessibilityLabel("Salta il riposo")
            }
            .buttonStyle(.plain)
            .font(.subheadline.bold())
            .padding(.leading, 20).padding(.trailing, 8).padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 16)
        }
    }

    /// Area di tocco di almeno 44 pt per i pulsanti della barra.
    private func barLabel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
    }
}

/// Mostra la barra del timer sopra la tab bar mentre il riposo è attivo.
private struct RestTimerInset: ViewModifier {
    @Environment(RestTimer.self) private var timer

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if timer.isActive {
                    RestTimerBar().transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: timer.isActive)
    }
}

extension View {
    func restTimerInset() -> some View { modifier(RestTimerInset()) }
}
