# SHCWare – Erkenntnisse zum Schema

Quelle: Oracle-Kommentare aus Schema `SHC` (Mandant KBS). Die Schemata
`HS`, `SHC`, `SLDV`, `BS` (und vermutlich `COCO`) haben dieselbe Struktur –
je Mandant ein Schema.

## Namenskonventionen
- Kerntabellen: `T` + Nummer + Kürzel, z.B. `T051ART`, `T081AUK`.
- Sicherungskopien ignorieren: Suffixe `_YYYYMMDD`, `_SIC…`, `_BAK…`, `_HD<Ticket>`, `_AID<nr>`, Präfix `TMP`.
- `num_rows` stammt aus den Oracle-Statistiken (Schätzwert).

## Häufige Schlüsselspalten
| Spalte | Bedeutung |
|---|---|
| MANR | Mandant/Betrieb – fast überall Teil des PK, bei Joins immer mitnehmen |
| LANR | Lagernummer |
| ARNR | Artikelnummer |
| KDNR | Kundennummer (= `T056AD.ADRN` mit `SART='K'`) |
| KRNR | Lieferantennummer (= `T056AD.ADRN` mit `SART='L'`) |
| AINR | Interne Auftragsnummer |
| PONR | Positionsnummer |
| SAC | Sachbearbeiter |
| RENR / BENR | Rechnungs- / Bestellnummer |
| WABE / HWGR / UWGR | Warenbereich / Hauptwarengruppe / Unterwarengruppe |
| SART | Satzart (Bedeutung je Tabelle verschieden!) |

## Kerntabellen
| Tabelle | Inhalt | PK |
|---|---|---|
| T056AD | Adressen: Kunden (SART='K'), Lieferanten ('L'), Adressen ('AD') | MANR, SART, ADRN |
| T051ART | Artikelstamm | |
| T052PRDAT | Preise | |
| T055WG | Warengruppen | |
| T081AUK | Auftragskopf | MANR, AINR |
| T086AUP | Auftragspositionen | MANR, AINR, PONR |
| T082AULI | Lieferscheinköpfe | |
| T087POLI | Lieferpositionen | |
| T084RESU | Rechnungssummen | |
| T078ERL | Erlöse | |
| T092EP | Lager-Einzelposten | |
| T096STAT | Statistik, SART: V=Verkauf, E=Einkauf, R=Reparatur | |
| T007SAC | Sachbearbeiter | |
| T012AART | Auftragsarten | |
| T045DEF | „Dateidefinitionen“ – evtl. SHCWare-eigener Feldkatalog (prüfen) | |

## Beziehungen
- `foreign_keys.csv`: 779 echte Oracle-FKs in 612 Tabellen – aber die Kern-Belegtabellen
  (Aufträge, Lieferungen, Rechnungen, Artikel) haben **keine** FKs. Dort Joins über
  gleichnamige Schlüsselspalten (MANR + AINR/PONR/KDNR/ARNR …) herleiten.
- Meist referenziert: `T070BETR` (Betriebstamm), `T800KONT` (Kontenplan).
- `EUL4_*` = Oracle-Discoverer End User Layer (597 Join-Definitionen in `EUL4_KEY_CONS`).
  Geprüft: die Joins wurden aus den Oracle-FKs generiert (Stichproben 1:1 identisch) und
  enthalten ebenfalls keine Kern-Belegtabellen → keine zusätzliche Information.
- `T045DEF` = Feldkatalog des alten dateibasierten Systems (DATEI/FELD, 8-stellige Dateinamen),
  vermutlich nicht nötig, da Oracle-Kommentare vorhanden.

## Fremdbestand (Abfragen eines anderen SHCWare-Kunden)
Nur abgeleitetes, neutrales Wissen – Originale werden nicht im Repo gespeichert.
Alles hier gilt als **ungeprüft**, bis es auf der eigenen DB bestätigt ist.

- Paket 1 (122 Dateien, Migrationsskripte ca. 2001–2003): fast nur `INSERT … SELECT` 1:1 von
  einem Alt-Schema ins neue Schema → **kein Abfrage-/Join-Wissen**. Erkenntnisse:
  - Die alte FIBU (Tabellen `T1xx`, z.B. `T133EPOS`, `T132KONT`) existiert im aktuellen Schema
    nicht mehr; die FIBU liegt heute in `T7xx`/`T8xx` (z.B. `T741BUDA`, `T742BUPO`, `T800KONT`).
    Fremde Abfragen auf `T1xx`-FIBU-Tabellen sind daher nicht übertragbar.
  - `T083LAE` (Schnittlängen) mit `SART='E'`: `AINR` enthält die Bestellnummer
    → Join auf `T141BEK` (Bestell-Kopf) über `MANR` + `T141BEK.BENR = T083LAE.AINR`.
