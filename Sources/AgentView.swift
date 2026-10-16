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
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if messages.isEmpty {
                                ForEach(suggestions, id: \.self) { s in
                                    Button(s) { input = s; send() }.buttonStyle(.bordered)
                                }
                            }
                            ForEach(messages) { m in
                                Text(m.text)
                                    .padding(10)
                                    .background(m.role == "user" ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15),
                                                in: RoundedRectangle(cornerRadius: 12))
                                    .frame(maxWidth: .infinity, alignment: m.role == "user" ? .trailing : .leading)
                                    .id(m.id)
                            }
                            if busy { ProgressView() }
                            if let error { Text(error).foregroundStyle(.red).font(.caption) }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { if let l = messages.last { proxy.scrollTo(l.id) } }
                }
                HStack {
                    TextField("Chiedi al coach…", text: $input).textFieldStyle(.roundedBorder).onSubmit(send)
                    Button("Invia", action: send).disabled(busy || input.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
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
    @AppStorage("calorieGoal") private var calorieGoal = 2200.0
    @AppStorage("proteinGoal") private var proteinGoal = 150.0
    @State private var apiKey = Keychain.load()

    var body: some View {
        NavigationStack {
            Form {
                Section("Obiettivi giornalieri") {
                    TextField("Calorie", value: $calorieGoal, format: .number)
                    TextField("Proteine (g)", value: $proteinGoal, format: .number)
                }
                Section("Agente IA") {
                    SecureField("Chiave API Anthropic", text: $apiKey)
                        .onChange(of: apiKey) { Keychain.save(apiKey) }
                    Text("Salvata nel Portachiavi. I tuoi dati vengono inviati ad Anthropic solo quando fai una domanda al coach.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Impostazioni")
        }
    }
}
