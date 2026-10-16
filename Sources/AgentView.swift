import SwiftUI
import SwiftData

struct AgentView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("calorieGoal") private var calorieGoal = 2200.0
    @AppStorage("proteinGoal") private var proteinGoal = 150.0
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var busy = false
    @State private var error: String?

    private let suggestions = ["Come sto andando con le proteine?", "Cosa miglioro nell'ultimo allenamento?", "Quante kcal mi restano oggi?"]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if messages.isEmpty {
                            GlassEffectContainer(spacing: 10) {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(suggestions, id: \.self) { s in
                                        Button(s) { input = s; send() }.buttonStyle(.glass)
                                    }
                                }
                            }
                        }
                        ForEach(messages) { m in
                            Text(m.text)
                                .padding(12)
                                .glassEffect(m.role == "user" ? .regular.tint(.accentColor.opacity(0.45)) : .regular,
                                             in: .rect(cornerRadius: 18))
                                .frame(maxWidth: .infinity, alignment: m.role == "user" ? .trailing : .leading)
                                .id(m.id)
                        }
                        if busy { ProgressView().padding() }
                        if let error { Text(error).foregroundStyle(.red).font(.caption) }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { if let l = messages.last { proxy.scrollTo(l.id) } }
            }
            .background(AppBackground())
            .safeAreaInset(edge: .bottom) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("Chiedi al coach…", text: $input)
                            .onSubmit(send)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .glassEffect(.regular.interactive(), in: .capsule)
                        Button(action: send) { Image(systemName: "arrow.up").font(.headline).padding(6) }
                            .buttonStyle(.glassProminent)
                            .buttonBorderShape(.circle)
                            .disabled(busy || input.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.horizontal).padding(.bottom, 4)
            }
            .navigationTitle("Coach")
            .toolbar { Button("Nuova chat") { messages = [] } }
        }
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !busy else { return }
        input = ""; error = nil; busy = true
        messages.append(ChatMessage(role: "user", text: text))
        // Contesto ricalcolato a ogni domanda: l'agente vede sempre i dati aggiornati.
        let ctx = ContextBuilder.build(in: context, calorieGoal: calorieGoal, proteinGoal: proteinGoal)
        let history = messages
        Task {
            do {
                let answer = try await AgentClient().reply(history: history, dataContext: ctx)
                messages.append(ChatMessage(role: "assistant", text: answer))
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}

struct SettingsView: View {
    @State private var apiKey = Keychain.load()

    var body: some View {
        Form {
            Section("Agente IA") {
                SecureField("Chiave API Anthropic", text: $apiKey)
                    .onChange(of: apiKey) { Keychain.save(apiKey) }
                Text("Salvata nel Portachiavi. I tuoi dati (non la foto) vengono inviati ad Anthropic solo quando fai una domanda al coach.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Crediti") {
                Text("Esercizi da free-exercise-db (pubblico) e wger.de, licenza CC-BY-SA 3.0. Alimenti da Open Food Facts (ODbL).")
                    .font(.caption).foregroundStyle(.secondary)
                Link("wger.de", destination: URL(string: "https://wger.de")!)
                Link("free-exercise-db", destination: URL(string: "https://github.com/yuhonas/free-exercise-db")!)
            }
        }
        .formStyle(.grouped)
        .glassList()
        .navigationTitle("Impostazioni")
    }
}
