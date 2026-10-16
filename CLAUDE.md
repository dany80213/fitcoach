# FitCoach — contesto per agenti IA

App nativa **SwiftUI multipiattaforma (iOS 26+ / macOS 26+, Liquid Glass)**, un solo target: tracking allenamenti (stile Hevy), diario calorie/macro (stile FatSecret) e un coach IA che risponde usando i dati dell'utente come contesto. UI in **italiano**.

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
| `Models.swift` | modelli SwiftData: `Workout` → `WorkoutExercise` → `SetEntry` (con `SetType`), `Routine` → `RoutineExercise` → `RoutineSet`, `Exercise` (libreria), `FoodEntry`; `FoodItem` (per 100 g) |
| `ExerciseLibrary.swift` | import/sync della libreria esercizi da free-exercise-db + wger, con deduplica e alias (all'avvio se vuota, vecchia di >7 giorni o con `libraryVersion` obsoleta); nomi muscoli in italiano |
| `Glass.swift` | `AppBackground` (sfondo sfumato) e helper `glassList()`, `transparentList()`, `glassCard()` |
| `HomeView.swift` | tab Home: saluto, riepilogo 7 giorni, storico allenamenti per mese (esclude quelli senza esercizi) |
| `ProfileView.swift` | tab Profilo: foto (`PhotosPicker`), dati fisici, obiettivo, calcolo kcal/proteine, statistiche, link alle Impostazioni |
| `Avatar.swift`, `NumberField.swift` | foto profilo cross-platform (ImageIO, JPEG ≤640 px) e campo numerico vuoto-se-zero |
| `RestTimer.swift` | `RestTimer` (`@Observable`, un'istanza nell'environment), `RestTimerBar` e modifier `restTimerInset()` applicato a ogni tab |
| `ExerciseHeader.swift` | intestazione esercizio condivisa da allenamento e routine: badge superset, riposo, menu azioni |
| `RoutineViews.swift` | scheda Allenamenti (Routine/Storico), editor routine, `ExercisePickerView`, `SetTypeMenu` |
| `WorkoutViews.swift` | dettaglio allenamento, serie precompilate dall'ultima volta che l'esercizio è stato fatto |
| `NutritionViews.swift` | diario giornaliero, ricerca alimento, scelta porzione/pasto, inserimento manuale |
| `FoodSearch.swift` | protocollo `FoodSearchProvider` + `OpenFoodFactsProvider` |
| `Agent.swift` | `Keychain`, `ContextBuilder` (riassunto testuale dei dati), `AgentClient` (API Anthropic) |
| `AgentView.swift` | chat del coach e `SettingsView` (obiettivi kcal/proteine, chiave API) |

## Decisioni e vincoli da rispettare

- **Dati solo locali** (SwiftData). Nessun backend. I dati lasciano il dispositivo solo quando l'utente fa una domanda al coach.
- **Chiave API Anthropic**: inserita dall'utente, salvata nel Portachiavi (`Keychain` in `Agent.swift`). Mai in codice, `UserDefaults`, log o commit.
- **Contesto dell'agente**: `ContextBuilder.build` ricalcola a ogni domanda gli ultimi 14 giorni di cibo e allenamenti. Il system prompt impone di basarsi solo su quei dati e di non dare consigli medici: mantieni queste regole. Modello in `AgentClient.model` (`claude-sonnet-5-5`).
- **Relazioni SwiftData**: dopo `context.insert(x)` aggiungi l'oggetto all'array del padre (`parent.items.append(x)`); impostare solo il lato inverso (`x.parent = p`) non aggiorna subito la UI.
- **Profilo**: un solo record `Profile` (creato al primo accesso al tab). La foto è `externalStorage`, ridimensionata con `AvatarImage.downscaledJPEG`; non va mai inviata al coach. `calorieGoal`/`proteinGoal` restano in `@AppStorage` e si modificano dal Profilo. Per i campi numerici usa `NumberField` (un `TextField(value:format:)` lascia lo "0" iniziale).
- **Superset**: `supersetID` (0 = nessuno) su `WorkoutExercise` e `RoutineExercise`; esercizi con lo stesso id e adiacenti formano il gruppo. Usa sempre gli helper `Superset.join/leave/cleanup` (sciolgono i gruppi da un solo membro). `makeWorkout` copia `supersetID` e `restSeconds`.
- **Riposo**: `restSeconds` per esercizio (0 = predefinito da `defaultRestSeconds` in `@AppStorage`, -1 = nessuno). `WorkoutExercise.restToStart(in:)` decide se avviare il timer: nei superset solo dopo l'ultimo esercizio. Il timer è unico per tutta l'app; `tabViewBottomAccessory` non esiste su macOS e nell'SDK 26.0 non ha `isEnabled`, per questo la barra è un `safeAreaInset`. Notifica locale (`UNUserNotificationCenter`) programmata alla partenza e annullata a fine/skip.
- **Tab bar nascosta nell'allenamento**: `WorkoutDetailView` usa `.toolbarVisibility(.hidden, for: .tabBar)` dentro `#if os(iOS)` (su macOS `.tabBar` non esiste). La barra del timer resta visibile perché è un `safeAreaInset` della NavigationStack.
- **Test UI nel simulatore**: i tocchi rapidi non attivano gli interruttori: usa `tap` con `duration` ~0.15.
- **Storico**: vive nella Home; il tab Allenamenti mostra solo le routine. Il volume esclude il riscaldamento.
- **Tipi di serie**: `SetType` (normal/warmup/failure/dropset). Le normali sono numerate, le altre mostrano W/F/D; il riscaldamento è escluso dal volume. Nuove proprietà dei modelli devono avere un valore di default (migrazione leggera sui dati esistenti).
- **Libreria esercizi**: due fonti, `yuhonas/free-exercise-db` e `wger.de` (`/api/v2/exerciseinfo/?limit=1000`, ~1,2 MB gzip, CC-BY-SA 3.0: tieni i crediti in Impostazioni e README). Nomi in inglese; i nomi italiani di wger finiscono in `aliases` (solo per la ricerca). La deduplica usa `ExerciseLibrary.normalize` (ordine parole, plurali, flye→fly). Se cambi fonti o mappatura, incrementa `libraryVersion` per forzare il resync. Gli esercizi con `isCustom` non vanno mai sovrascritti dal sync.
- **Liquid Glass**: target minimo iOS/macOS 26, quindi usa le API native (`.glassEffect`, `.buttonStyle(.glass/.glassProminent)`, `GlassEffectContainer`) senza fallback `#available`. Tab bar, toolbar e sheet diventano vetro da soli: non rimettere sfondi opachi sopra. Usa `AppBackground` dietro liste/chat, e `transparentList()` quando lo sfondo lo mette già il contenitore (evita giunzioni). Non sovrapporre più `glassEffect` annidati: raggruppali in un `GlassEffectContainer`.
- **Test su iOS 26**: simulatore "iPhone 17 Pro" (iOS 26.0). Il runtime iOS 18 non esegue più l'app.
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
