# Changelog

Formato basato su [Keep a Changelog](https://keepachangelog.com/it/1.1.0/), versioni secondo [SemVer](https://semver.org/lang/it/).

## [Non rilasciato]

### Aggiunto
- Sezione Allenamenti con **Routine** personalizzate (esercizi + serie) e **Storico**.
- Tipi di serie: Normale, Riscaldamento, Cedimento, Drop set (il riscaldamento non conta nel volume).
- Libreria di ~870 esercizi importata da free-exercise-db, risincronizzata ogni 7 giorni o a mano; filtro per muscolo ed esercizi personalizzati.
- Avvio di un allenamento da una routine, con pesi precompilati dall'ultima volta.
- Il coach IA vede le routine e i tipi di serie.

- Libreria esercizi ampliata da ~870 a ~1.700 unendo **wger** a free-exercise-db (pec deck, fly, ecc.), senza duplicati; nomi italiani e sinonimi come alias di ricerca.
- Ricerca per parole parziali su nome, alias, muscolo (EN/IT) e attrezzo: "chest fly", "pec dec", "petto manubri".
- **Liquid Glass** (iOS 26 / macOS 26): tab bar fluttuante che si minimizza, pulsanti e badge delle serie in vetro, riepilogo calorie e chat del coach in vetro, sfondo sfumato.
- Crediti e licenze dei dati nelle Impostazioni.

### Modificato
- **Requisiti minimi: iOS 26 e macOS 26** (prima 17 / 14).
- La vecchia lista allenamenti diventa la scheda "Storico".

## [0.1.0] - 2026-10-16

### Aggiunto
- Allenamenti: esercizi e serie, precompilazione dall'ultima volta, volume totale.
- Diario calorie e macro con ricerca alimenti (Open Food Facts) e inserimento manuale.
- Coach IA (API Anthropic) con i dati dell'utente come contesto.
- Obiettivi giornalieri e chiave API nel Portachiavi.
