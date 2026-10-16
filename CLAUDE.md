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

## Git, commit e versioning

Branch `main`, remoto `dany80213/fitcoach`. Collaboratori con permesso di scrittura: dany80213 e alessandro-guttadauro.

### Commit: sempre
- **Dopo ogni modifica completata e compilata, fai subito il commit** (e il push su `main`): niente lavoro lasciato non committato a fine task. Se la modifica non compila su entrambe le piattaforme, non committare: sistemala prima.
- Un commit = una modifica logica, piccolo. Non mescolare refactoring e funzionalità.
- Messaggi in stile Conventional Commits, in italiano o inglese ma coerenti: `feat: ...`, `fix: ...`, `refactor: ...`, `docs: ...`, `chore: ...`. Prima riga ≤ 72 caratteri, il perché nel corpo se non è ovvio.
- Prima di committare controlla `git status` e `git diff --staged`: niente `build/`, `*.xcodeproj`, chiavi API, file `.env`.
- Non riscrivere la storia pubblicata (`push --force`, `rebase` su commit già pushati) e non lavorare direttamente su `main` per modifiche grosse: usa un branch `feat/...` o `fix/...` e una pull request. Fai `git pull --rebase` prima di pushare, perché lavora anche Alessandro.
- Non inserire email personali/di lavoro nei commit: usa l'indirizzo noreply di GitHub (`<id>+<utente>@users.noreply.github.com`).

### Versioning (SemVer `MAJOR.MINOR.PATCH`)
- **MAJOR**: cambi incompatibili (es. modifica dei modelli SwiftData che richiede migrazione manuale o perde dati). **MINOR**: nuove funzionalità compatibili. **PATCH**: solo correzioni. Finché siamo `0.x` le API possono ancora cambiare.
- La versione vive in **`project.yml`**: `MARKETING_VERSION` (SemVer) e `CURRENT_PROJECT_VERSION` (numero di build, intero che cresce a ogni release, anche per le patch). Dopo la modifica esegui `xcodegen generate`.
- Tieni **`CHANGELOG.md`** (formato Keep a Changelog): ogni commit `feat`/`fix` aggiunge una riga sotto `## [Non rilasciato]`; alla release quella sezione diventa `## [X.Y.Z] - AAAA-MM-GG`.

### Release
1. Verifica che `main` sia pulito e allineato (`git status -sb`), che compili su macOS e iOS Simulator e che l'app parta.
2. Aggiorna `MARKETING_VERSION` e `CURRENT_PROJECT_VERSION` in `project.yml` e sposta le voci del changelog nella nuova versione.
3. Commit: `chore(release): vX.Y.Z` e push.
4. Tag annotato e release su GitHub:
   ```bash
   git tag -a vX.Y.Z -m "FitCoach X.Y.Z"
   git push origin vX.Y.Z
   gh release create vX.Y.Z --title "FitCoach X.Y.Z" --notes-file <(sed -n '/^## \[X.Y.Z\]/,/^## \[/p' CHANGELOG.md | sed '$d')
   ```
5. I tag sono immutabili: se la release è sbagliata, pubblica una patch successiva, non spostare il tag.
6. Prima di creare una release chiedi conferma all'utente: è un'azione pubblica.
