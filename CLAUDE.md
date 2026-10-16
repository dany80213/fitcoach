# FitCoach — contesto per agenti IA

App nativa **SwiftUI multipiattaforma (iOS 17+ / macOS 14+)**, un solo target: tracking allenamenti (stile Hevy), diario calorie/macro (stile FatSecret) e un coach IA che risponde usando i dati dell'utente come contesto. UI in **italiano**.

## Build

Il progetto Xcode è generato da `project.yml` con XcodeGen. **Non committare `FitCoach.xcodeproj` né `build/`** (sono in `.gitignore`).

```bash
brew install xcodegen          # una tantum
xcodegen generate              # da rifare dopo aver aggiunto/rimosso file o toccato project.yml
xcodebuild -project FitCoach.xcodeproj -scheme FitCoach -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project FitCoach.xcodeproj -scheme FitCoach -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Prima di dichiarare finita una modifica, compila **entrambe** le piattaforme. Non ci sono ancora test automatici.

## Struttura (`Sources/`)

| File | Contenuto |
|---|---|
| `FitCoachApp.swift` | entry point, `TabView` (Allenamenti, Calorie, Coach, Impostazioni), `modelContainer` |
| `Models.swift` | modelli SwiftData: `Workout` → `WorkoutExercise` → `SetEntry`, `FoodEntry`; `FoodItem` (per 100 g) |
| `WorkoutViews.swift` | lista/dettaglio allenamento, serie precompilate dall'ultima volta che l'esercizio è stato fatto |
| `NutritionViews.swift` | diario giornaliero, ricerca alimento, scelta porzione/pasto, inserimento manuale |
| `FoodSearch.swift` | protocollo `FoodSearchProvider` + `OpenFoodFactsProvider` |
| `Agent.swift` | `Keychain`, `ContextBuilder` (riassunto testuale dei dati), `AgentClient` (API Anthropic) |
| `AgentView.swift` | chat del coach e `SettingsView` (obiettivi kcal/proteine, chiave API) |

## Decisioni e vincoli da rispettare

- **Dati solo locali** (SwiftData). Nessun backend. I dati lasciano il dispositivo solo quando l'utente fa una domanda al coach.
- **Chiave API Anthropic**: inserita dall'utente, salvata nel Portachiavi (`Keychain` in `Agent.swift`). Mai in codice, `UserDefaults`, log o commit.
- **Contesto dell'agente**: `ContextBuilder.build` ricalcola a ogni domanda gli ultimi 14 giorni di cibo e allenamenti. Il system prompt impone di basarsi solo su quei dati e di non dare consigli medici: mantieni queste regole. Modello in `AgentClient.model` (`claude-sonnet-5-5`).
- **Ricerca alimenti**: usa `https://search.openfoodfacts.org/search` (gratuito, senza chiave; `brands` è un array). Il vecchio `world.openfoodfacts.org/cgi/search.pl` va spesso in 503 e restituisce HTML: non tornarci. Per aggiungere FatSecret (OAuth2, serve client id/secret dell'utente) implementa `FoodSearchProvider`, non toccare le viste.
- **Swift 5 language mode** (`SWIFT_VERSION: 5.0` in `project.yml`): non attivare Swift 6 strict concurrency senza migrare tutto.
- **macOS**: app sandbox con `network.client` in `Sources/FitCoach.entitlements` (applicato solo a `sdk=macosx*`). Nuove capacità di rete/file vanno aggiunte lì.
- Codice condiviso iOS/macOS: per API specifiche di piattaforma usa `#if os(iOS)` / `#if os(macOS)` (vedi `keyboardType` e `.frame(minWidth:)`).
- Mantieni lo stile esistente: viste piccole, nessuna dipendenza esterna, commenti solo dove il motivo non è ovvio.

## Idee in sospeso

Provider FatSecret, scansione codice a barre, grafici di progressione, timer di riposo, esportazione dati, tool-use dell'agente (es. "aggiungi 100 g di riso al pranzo").

## Git

Branch `main`, remoto `dany80213/fitcoach`. Commit piccoli e descrittivi. Non inserire email personali/di lavoro nei commit: usa l'indirizzo noreply di GitHub.
