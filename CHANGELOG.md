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

- Scheda **Home**: saluto con foto, riepilogo degli ultimi 7 giorni (allenamenti, serie, volume) e storico di tutti gli allenamenti passati raggruppati per mese.
- Scheda **Profilo**: foto (dal rullino, ridimensionata e salvata sul dispositivo), nome, data di nascita, sesso, altezza, peso, peso obiettivo, obiettivo e livello di attività, BMI e statistiche.
- Calcolo dell'obiettivo giornaliero di calorie e proteine dai dati del profilo (Mifflin-St Jeor).
- Il coach IA conosce il profilo (mai la foto).

- **Superset**: dal menu ⋯ di un esercizio si crea un superset con quello sopra (badge "SUPERSET A/B…" colorato); vale sia nelle routine sia durante l'allenamento e viene copiato quando avvii una routine.
- **Timer di riposo**: parte da solo quando completi una serie, con barra in Liquid Glass sopra la tab bar (−15 s, +15 s, salta), vibrazione a fine tempo e notifica se l'app è in background. Nei superset il riposo parte dopo l'ultimo esercizio del giro.
- Riposo per esercizio (predefinito, nessuno, da 30 s a 5 min) dal menu ⋯ e riposo predefinito globale nelle Impostazioni.

### Modificato
- Lo storico non è più in Allenamenti (che mostra solo le routine) ma nella Home; Impostazioni e coach IA sono dentro il Profilo.
- **Requisiti minimi: iOS 26 e macOS 26** (prima 17 / 14).
- La vecchia lista allenamenti diventa la scheda "Storico".

## [0.1.0] - 2026-10-16

### Aggiunto
- Allenamenti: esercizi e serie, precompilazione dall'ultima volta, volume totale.
- Diario calorie e macro con ricerca alimenti (Open Food Facts) e inserimento manuale.
- Coach IA (API Anthropic) con i dati dell'utente come contesto.
- Obiettivi giornalieri e chiave API nel Portachiavi.
