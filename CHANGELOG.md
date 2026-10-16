# Changelog

Formato basato su [Keep a Changelog](https://keepachangelog.com/it/1.1.0/), versioni secondo [SemVer](https://semver.org/lang/it/).

## [Non rilasciato]

### Aggiunto
- Sezione Allenamenti con **Routine** personalizzate (esercizi + serie) e **Storico**.
- Tipi di serie: Normale, Riscaldamento, Cedimento, Drop set (il riscaldamento non conta nel volume).
- Libreria di ~870 esercizi importata da free-exercise-db, risincronizzata ogni 7 giorni o a mano; filtro per muscolo ed esercizi personalizzati.
- Avvio di un allenamento da una routine, con pesi precompilati dall'ultima volta.
- Il coach IA vede le routine e i tipi di serie.

### Modificato
- La vecchia lista allenamenti diventa la scheda "Storico".

## [0.1.0] - 2026-10-16

### Aggiunto
- Allenamenti: esercizi e serie, precompilazione dall'ultima volta, volume totale.
- Diario calorie e macro con ricerca alimenti (Open Food Facts) e inserimento manuale.
- Coach IA (API Anthropic) con i dati dell'utente come contesto.
- Obiettivi giornalieri e chiave API nel Portachiavi.
