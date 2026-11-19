# SHCOracle – SQL-Abfragen für das ERP SHCWare (Oracle)

Ziel dieses Repos: dem Benutzer helfen, SQL-Abfragen gegen die Oracle-Datenbank des
ERP-Systems **SHCWare** zu schreiben. Claude hat **keinen** Datenbankzugriff – der Benutzer
führt die Abfragen selbst aus und schickt Ergebnisse zurück.

## Arbeitsweise mit dem Benutzer
- Deutsch, **du**-Form. Der Benutzer möchte **Schritt für Schritt** vorgehen: eine Abfrage
  bzw. ein Schritt pro Nachricht, dann auf das Ergebnis warten.
- Tool des Benutzers: **PL/SQL Developer** (SQL-Fenster, F8; Export: Ergebnis → „Letzte Seite
  abrufen“ → Rechtsklick → Ergebnisse exportieren → CSV/Excel). SQL*Plus-Befehle (`SET`, `SPOOL`)
  dort nicht verwenden.
- Bei unsicheren Joins zuerst eine kleine **Prüfabfrage** geben (z.B. Kardinalität/Duplikate
  prüfen, `COUNT(*)` vor und nach dem Join), bevor eine große Auswertung gebaut wird.
- Vor jeder Abfrage klären: **welcher Mandant** (Schema) – oder alle zusammen (`UNION ALL`).
- Nur lesende Abfragen (`SELECT`) vorschlagen, nie DML/DDL auf Produktivdaten.

## Datenbank
- Ein **Schema pro Mandant**, alle mit (nahezu) gleicher Struktur:
  | Schema | Mandant |
  |---|---|
  | `HS` | Herzau und Schmitt |
  | `SHC` | KBS |
  | `SLDV` | SLDV |
  | `BS` | B. Schmitt |
  | `COCO` | unbekannt (vermutlich alter/Test-Mandant, 2.497 Tabellen) |
- Ignorieren: `APEX_*`, `ORDS_METADATA` (Oracle APEX), `ANMELDUNG` (1 Login-Tabelle).
- Tabellen immer mit Schema qualifizieren, z.B. `shc.t081auk`.

## Schema-Dokumentation (exportiert aus Schema `SHC`)
| Datei | Inhalt | Spalten |
|---|---|---|
| `schema/tables.csv` | 3.404 Tabellen | TABLE_NAME; NUM_ROWS; COMMENTS |
| `schema/columns.csv` | 62.648 Spalten (inkl. Views) | TABLE_NAME; COLUMN_ID; COLUMN_NAME; DATA_TYPE; NULLABLE; PK; COMMENTS |
| `schema/foreign_keys.csv` | 779 Oracle-FKs | TABLE_NAME; COLUMNS; REF_TABLE; REF_COLUMNS |
| `schema/NOTES.md` | Erkenntnisse: Namensregeln, Schlüsselspalten, Kerntabellen, Beziehungen | |

Alle CSVs: UTF-8, Trennzeichen `;`. Die Kommentare sind die gepflegten Oracle-Kommentare
(ca. 2/3 der Tabellen, ca. 1/2 der Spalten haben eine Beschreibung) – **die wichtigste Quelle**.

Suchen statt komplett lesen (Dateien sind groß), z.B.:
```bash
grep -i 'rechnung' schema/tables.csv                 # Tabellen zu einem Thema
grep '^T081AUK;' schema/columns.csv                  # alle Spalten einer Tabelle
grep -i 'skonto' schema/columns.csv                 # Spalten nach Name/Beschreibung
grep -E '(^|;)T056AD;' schema/foreign_keys.csv       # FKs von/zu einer Tabelle
```

## Wichtigste Fakten (Details in `schema/NOTES.md`)
- Kerntabellen heißen `T<Nummer><Kürzel>`. Sicherungskopien ignorieren
  (`_YYYYMMDD`, `_SIC…`, `_BAK…`, `_HD<Ticket>`, `_AID…`, Präfix `TMP`) – ca. 300 Stück.
- `NUM_ROWS` ist ein Statistik-Schätzwert; nur ~777 Tabellen haben laut Statistik Daten.
- **`MANR`** (Mandant/Betrieb) ist fast überall Teil des PK → bei Joins immer mitjoinen.
  In FiBu-Tabellen (T7xx/T8xx) heißt dieselbe Spalte oft `BETRIEB`.
- Kunden **und** Lieferanten liegen in `T056AD` (PK `MANR, SART, ADRN`):
  Kunde `SART='K'` (`ADRN` = `KDNR`), Lieferant `SART='L'` (`ADRN` = `KRNR`).
- Aufträge: `T081AUK` Kopf (PK `MANR, AINR`) → `T086AUP` Positionen (PK `MANR, AINR, PONR`).
- Die Kern-Belegtabellen (Aufträge, Lieferungen, Rechnungen, Artikel, Adressen) haben
  **keine Oracle-FKs** → Joins aus gleichnamigen Schlüsselspalten + Kommentaren herleiten
  und mit Prüfabfrage absichern.
- Status-/Kennzeichenfelder sind in den Spaltenkommentaren erklärt (z.B. `T081AUK.STAT`).
- Der Oracle-Discoverer-Katalog (`EUL4_*`) enthält nur die aus den FKs generierten Joins –
  keine Zusatzinfo.
- `T045DEF` ist ein Feldkatalog des alten dateibasierten Systems – normalerweise nicht nötig.

## Erkenntnisse festhalten
Neue, bestätigte Erkenntnisse (z.B. ein geprüfter Join, Bedeutung eines Kennzeichens,
Unterschiede zwischen Mandanten) in `schema/NOTES.md` ergänzen. Bewährte Abfragen als
`.sql`-Datei unter `queries/` ablegen (Dateikopf: Zweck, Mandant, Datum der Prüfung).

## Weitere Dateien
- `sql/` – SQL*Plus-Skripte für den Schema-Export (für PL/SQL Developer nicht nötig).
