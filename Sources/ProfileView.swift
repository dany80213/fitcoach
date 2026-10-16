import SwiftUI
import SwiftData
import PhotosUI

/// Profilo personale: foto, dati fisici, obiettivo e obiettivi giornalieri di calorie e proteine.
struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [Profile]

    var body: some View {
        NavigationStack {
            Group {
                if let profile = profiles.first {
                    ProfileForm(profile: profile)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Profilo")
            .background(AppBackground())
        }
        .task {
            // Un solo profilo: lo creiamo al primo accesso.
            if ((try? context.fetchCount(FetchDescriptor<Profile>())) ?? 0) == 0 { context.insert(Profile()) }
        }
    }
}

private struct ProfileForm: View {
    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context
    @Query private var workouts: [Workout]
    @AppStorage("calorieGoal") private var calorieGoal = 2200.0
    @AppStorage("proteinGoal") private var proteinGoal = 150.0
    @State private var pickerItem: PhotosPickerItem?

    private var completed: [Workout] { workouts.filter { !$0.exercises.isEmpty } }

    var body: some View {
        Form {
            Section { header }
                .listRowBackground(Color.clear)

            Section("Dati personali") {
                DatePicker("Data di nascita", selection: $profile.birthDate, in: ...Date.now, displayedComponents: .date)
                LabeledContent("Età", value: "\(profile.age) anni")
                Picker("Sesso", selection: $profile.sex) {
                    ForEach(Sex.allCases) { Text($0.title).tag($0.rawValue) }
                }
                numberRow("Altezza", value: $profile.heightCm, unit: "cm")
                numberRow("Peso attuale", value: $profile.weightKg, unit: "kg")
                numberRow("Peso obiettivo", value: $profile.targetWeightKg, unit: "kg")
                if let bmi = profile.bmi { LabeledContent("BMI", value: String(format: "%.1f", bmi)) }
            }

            Section("Obiettivo") {
                Picker("Obiettivo", selection: $profile.goal) {
                    ForEach(FitnessGoal.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Attività", selection: $profile.activity) {
                    ForEach(ActivityLevel.allCases) { Text($0.title).tag($0.rawValue) }
                }
            }

            Section {
                numberRow("Calorie", value: $calorieGoal, unit: "kcal")
                numberRow("Proteine", value: $proteinGoal, unit: "g")
                if let kcal = profile.suggestedCalories, let protein = profile.suggestedProtein, let tdee = profile.tdee {
                    Button {
                        calorieGoal = kcal
                        proteinGoal = protein
                    } label: {
                        Label("Calcola dai miei dati: \(Int(kcal)) kcal, \(Int(protein)) g", systemImage: "wand.and.stars")
                    }
                    Text("Fabbisogno stimato \(Int(tdee)) kcal/giorno (formula Mifflin-St Jeor). Obiettivo: \(profile.fitnessGoal.title.lowercased()). È una stima, non un consiglio medico.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Inserisci altezza e peso per ottenere un obiettivo calorico suggerito.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } header: { Text("Obiettivi giornalieri") }

            Section("Statistiche") {
                LabeledContent("Allenamenti completati", value: "\(completed.count)")
                LabeledContent("Volume totale", value: "\(Int(completed.reduce(0) { $0 + $1.totalVolume })) kg")
            }

            Section {
                NavigationLink { SettingsView() } label: { Label("Impostazioni e coach IA", systemImage: "gearshape") }
            }
        }
        .scrollContentBackground(.hidden)
        .formStyle(.grouped)
    }

    private var header: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ProfileAvatar(data: profile.photoData, name: profile.name, size: 120)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.subheadline).padding(8)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
            }
            .buttonStyle(.plain)
            .onChange(of: pickerItem) { _, item in
                Task {
                    if let raw = try? await item?.loadTransferable(type: Data.self),
                       let small = AvatarImage.downscaledJPEG(from: raw) {
                        profile.photoData = small
                    }
                }
            }
            if profile.photoData != nil {
                Button("Rimuovi foto", role: .destructive) { profile.photoData = nil; pickerItem = nil }
                    .font(.caption)
            }
            TextField("Il tuo nome", text: $profile.name)
                .multilineTextAlignment(.center)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
    }

    private func numberRow(_ title: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            NumberField(placeholder: "0", value: value)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            Text(unit).foregroundStyle(.secondary).frame(width: 36, alignment: .leading)
        }
    }
}
