# FitCoach

App nativa SwiftUI per iOS e macOS: tracking allenamenti (stile Hevy), conteggio calorie e macro (stile FatSecret) e un coach IA che risponde usando i tuoi dati come contesto.

## Build

```bash
brew install xcodegen
xcodegen generate
open FitCoach.xcodeproj
```

Richiede Xcode 26. Il progetto è generato da `project.yml`: non committare `FitCoach.xcodeproj`.

## Struttura

- `Sources/Models.swift` — modelli SwiftData (Workout, FoodEntry…)
- `Sources/WorkoutViews.swift` — allenamenti, serie, precompilazione dall'ultima volta
- `Sources/NutritionViews.swift`, `FoodSearch.swift` — diario alimentare e ricerca (Open Food Facts, provider sostituibile)
- `Sources/Agent.swift`, `AgentView.swift` — coach IA (API Anthropic, chiave nel Portachiavi)
