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
- **Pakete/Stücklisten – Bestand** (geprüft 2026-11-19, `SHC`, Artikel 947207, Lager 72):
  Paketartikel (`T051ART.KZSL = 'P'`) haben **keinen eigenen Satz in `T075LAG`**. SHCWare
  (Artikelinfo UP012) zeigt als „verfügbar“ die Anzahl kompletter Pakete aus den Komponenten:
  `MIN(TRUNC(T075LAG.VERF der Komponente / T060STL.MENUA))` über alle Zeilen von
  `T060STL` mit `HARNR = Paketartikel`, `SATZART = 'STUELI'` (Join `T060STL.MANR, UARNR` →
  `T075LAG.MANR, ARNR` + Lager). Abfragen, die nur `T075LAG` zum Artikel lesen, liefern für
  Pakete Bestand 0. `KZSL` `S` (Stückliste) / `K` (Konfiguration) noch nicht geprüft.
- **EANs `T080EAN`** (2026-11-19, `SHC`): Ein Artikel darf laut Fachbereich **mehrere EANs**
  haben (PK ist `EAN, MANR`, nicht `ARNR`). In `SHC`/`MANR = 46` betrifft das 13 Artikel
  (je 2 EANs); `ART` und `VEREVK` sind dort leer, `T051ART` hat kein EAN-Feld → es gibt kein
  Kennzeichen für eine „Haupt-EAN“. Ein Join `T051ART` → `T080EAN` vervielfacht also Zeilen;
  für „eine GTIN pro Artikel“ eine Regel festlegen (z.B. `ROW_NUMBER() … ORDER BY RECNUM`).
  Änderungsprotokoll für Stammdaten: `T310CP1` (Kopf: `DATUM`, `SAC`, `TABELLE`, `KEYINHALT`)
  → `T310CP3` (Felder alt/neu) über `CID, TABELLE`.
- **Zusatzinfos `T336INFA`** (2026-11-19, `SHC`): je `MANR, ARNR, INFOKZ` eine Zeile für `A44` und `A38`
  (keine Dubletten trotz fehlendem `SART`-Filter). Bedeutung von A44/A38 noch unbekannt (Feldkatalog `T335INFO`).
- **Lieferanten-Zusatzinfos:** `KBS_Helper.get_T337InfP_AsNumber('LIE', '<INFOKZ>', KRNR)` liest `T337INFP`
  (z.B. `A20`, `A21` = Vorlaufzeiten in Tagen in der Bestandsdatei). Geprüfte Abfrage:
  `queries/kbs_bestandsdatei_lager72.sql`.

## Auf eigener DB bestätigt
- **Zusatzinfos `T337INFP`** (bestätigt 2026-11-19, SHC/MANR 46): PK `SART, INFOKZ, MANR, SART56, ADRN`,
  einzige Datenspalte `INHALT1` (VARCHAR2(1000)), keine weiteren Pflichtfelder.
  Kunden-Zusatzinfo: `SART = 'KND'`, `SART56 = 'K'` (= `T056AD.SART`), `INFOKZ` = Infoschlüssel,
  z.B. `'LNR'`. Join: `u.manr = t.manr AND u.adrn = t.adrn AND u.sart56 = t.sart AND u.sart = 'KND'
  AND u.infokz = '…'`. Nicht jeder Kunde hat eine Zeile → `LEFT JOIN`. Per SQL neu angelegte Zeilen
  (nur PK + `INHALT1`) werden im SHCWare korrekt angezeigt.
- **`T056AD` EDI-/Lieferantenfelder:** `ILN_RECHNUNG`, `ILN_LIEFERANT` (VARCHAR2(23), ILN 13-stellig),
  `KULI` (eigene Kundennr. beim Lieferanten), `VERB` (Verbandsnummer). Leere Werte sind bei MANR 46
  überwiegend NULL (~8.000–8.500 je Spalte), nur ~670 je Spalte `' '` → beim Löschen NULL setzen.
- **Stammdaten aus Excel aktualisieren:** bewährter Ablauf in `queries/t056ad_excel_abgleich_kunden.sql`
  (Hilfstabelle `TMP_…` → Vorschau → Sicherung `<TABELLE>_BAK_YYYYMMDD` → UPDATE/MERGE ohne
  AutoCommit → Prüfung → COMMIT). Excel-Spalten mit ILN/Nummern vorher als Text formatieren.

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

- Paket 2 (ca. 12.000 Dateien → 4.609 eindeutige `.sql`, davon 4.253 reine Auswertungen,
  überwiegend aktuelle SHCWare-Version, Schema `SHC`): 306 der 381 referenzierten
  T-Tabellen existieren auch bei uns. Daraus abgeleitet: **`schema/joins.csv`**
  (329 Tabellenpaare, je Paar die umfassendste häufige Join-Variante + Alternativen + Hinweise).

### Regeln aus Paket 2 (ungeprüft, aber vielfach verwendet)
- **Artikelstamm-Betrieb:** `T051ART.MANR` ist nicht zwingend der Mandant des Belegs, sondern
  `T070BETR.BETART` („Betriebsnummer für Artikelstamm“). Darum joinen viele Abfragen
  `T051ART` nur über `ARNR`. Sicher: `T051ART.MANR = (SELECT BETART FROM T070BETR WHERE MANR = <Beleg-MANR>)`.
  → **Geprüft 2026-11-19 (`T070BETR` aller Mandanten):**
  | Schema | MANR | BETART |
  |---|---|---|
  | `SHC` | 46 | 46 |
  | `HS` | 50 | 50 |
  | `SLDV` | 60 | 60 |
  | `BS` | 30 | 30 |
  | `BS` | **70** | **30** |
  → In `SHC`, `HS`, `SLDV` Artikel normal über `MANR + ARNR` joinen.
  → In **`BS`** hat Betrieb 70 keinen eigenen Artikelstamm: für Belege mit `MANR = 70`
    Artikel über `T051ART.MANR = 30` lesen. Allgemein gültige Form:
    ```sql
    JOIN bs.t070betr b  ON b.manr = p.manr
    JOIN bs.t051art  a  ON a.manr = b.betart AND a.arnr = p.arnr
    ```
    Gilt vermutlich auch für andere artikelbezogene Stammdaten (Warengruppen, Preise) – je Tabelle prüfen.
- **Blank statt NULL:** Kennzeichen-/Freifelder enthalten oft `' '` (ein Leerzeichen) statt NULL
  (z.B. `T155PRGR.FREI = ' '`, `T064WGTX.UWGR = ' '`). Robust filtern mit `TRIM(spalte) IS NULL`.
- **Preiseinheit:** Werte = Menge × Preis / `T051ART.PREIVK` (Preisfaktor 1/10/12/100/1000), z.B.
  Lagerwert `SUM(NVL(T075LAG.EFFB,0) * NVL(T075LAG.DUPR,0) / NVL(T051ART.PREIVK,1))`
  (`EFFB` = effektiver Bestand, `DUPR` = Durchschnittspreis). Analog Inventur `T688BEW.IST * PREISINV`.
- **Warengruppentexte `T064WGTX`** (PK `MANR, WABE, HWGR, UWGR`): Text der Hauptwarengruppe =
  Satz mit `UWGR = ' '`.
- **Adressen `T056AD`:** `SART = 'K'` Kunden (am häufigsten), `'L'` Lieferanten, `'AN'`, `'AD'` selten.
  Nebentabellen mit `MANR, SART, ADRN`: `T042WKOM` (Kommunikation, `ART` z.B. TEL1/FAX/MHS/WWW),
  `T058ASP` (Ansprechpartner), `T355VERT` (Vertreter je Kunde, `SART='K'`, `LFDNR=1` = Hauptvertreter).
- **Statistik-Tabellen** (fertig verdichtet, für Umsatzauswertungen bevorzugt genutzt):
  | Tabelle | Inhalt | typische Kennzahlen / Filter |
  |---|---|---|
  | `T096STAT` | Statistik-Einzelsätze je Belegposition | `SART='V'` Verkauf / `'E'` Einkauf; `VKWERT`, `EKWERT`, `MENGE`, `KG`; Rohertrag = `VKWERT-EKWERT`; `GSART` L/S/B = Lager/Strecke/Besorgung; oft `WABE <> '99'` |
  | `T155PRGR` | Kunde × Produktgruppe × Jahr | `VKGES`, `EKGES`, `MGGES`, Monatsfelder `MG01..`; Filter `TRIM(FREI) IS NULL` |
  | `T156KUST` | Kunden-Statistik je Jahr | `VKGES`; Filter `TRIM(FREI) IS NULL` |
  | `T153VEST` | Vertreter × Produktgruppe | Monatsumsätze `VK01..VK12`, `VTRN` |
  | `T075STAT` | Bestands-Statistik je Stichtag | `EFFB`, `VKMENGE`, `WERT_DUPR` |
  | `T688ZL` / `T688BEW` | Inventur Zählliste / Bewertung | `SOLL`, `IST`, `PREISDUPR`, `PREISINV`, `DATUM` |
- **Lieferscheine `T082AULI`:** Join zu Positionen `T087POLI` über `MANR, AINR, LAUF`;
  `T087POLI.AUFPOS` = Auftragsposition (`T086AUP.PONR`). Häufige Filter `STAT = 3` bzw. `8`
  (Bedeutung laut Kommentar: 3 = Entnahmeschein gedruckt …). Rechnung: `T084RESU` über `MANR, KDNR, RENR`.
- **Bestellungen:** `T141BEK` Kopf → `T146BEP` Positionen über `MANR, BENR`; Lieferant = `T056AD` mit `SART='L'`, `ADRN = KRNR`.
- **Lagerbewegungen `T092EP.VORG`:** E Eingang, A Abgang, ID Inventurdifferenz, B Berichtigung, V Vortrag.
- **Schlüsseldatei `T065SCH`:** generische Nachschlagetabelle (`SART` = Schlüsselart, `SCHL` = Schlüssel,
  `BETR` = Betrieb, 0 = alle). Für Klartexte zu Codes (Versandarten, Gutschriftgründe, Touren …).
- **Installationsabhängig – nie blind übernehmen:** Auftragsarten (`AART`), Lager-, Vertreter-,
  Warenbereichsnummern, Freifelder (`FRA*`, `FRN*`, `FREI`, `IND*`) und deren Bedeutung.
- `T052PR` (alte Preisdatei, 123 Verwendungen): steht nicht in `tables.csv`, aber in `columns.csv` →
  bei uns vermutlich ein **View** (auf `T052PRDAT`). `shc.t052pr` ist abfragbar (2026-11-19);
  mit `KZPR = ' ' AND WAEC = ' '` eine Zeile je Artikel (`SHC`, `MANR = 46`). Tabelle: `T052PRDAT`.
- **Oracle: Leerstring = NULL.** `x = ''` und `NVL(x, '') = ''` sind nie wahr →
  `TRIM(x) IS NULL` verwenden (Fehler steckte in alten LogiCAL-Skripten).
- **ORA-01799:** keine Unterabfrage im `ON` eines Outer Joins (z.B. `T051ART.MANR = (SELECT BETART …)`)
  → Wert vorher in eine CTE holen und `CROSS JOIN`en.

## LogiCAL (Blechverwaltung) ↔ SHCWare – HS (`MANR = 50`), geprüft 2026-11-22

### Tabellen und Joins
- LogiCAL-Tabellen `DIP_BLECHE`, `DIP_MATERIAL`, `DIP_LAGER` (DevExpress XPO: Schlüssel `OID`,
  `GCRECORD IS NOT NULL` = gelöscht) sind aus der HS-Sitzung **unqualifiziert** erreichbar
  (Besitzer-Schema / Synonym noch nicht geklärt: `all_tables`/`all_synonyms` prüfen).
- SHCWare-Charge = `T036MENG` mit `LTYP = 'T'` (PK `MANR, LANR, LTYP, LAGO`; `LAGO` = Zugangsnummer).
- Join Charge ↔ Blech: `DIP_BLECHE.EXREF1 = T036MENG.LAGO`
  und `DIP_MATERIAL.OID = DIP_BLECHE.MATERIAL AND DIP_MATERIAL.ARTIKELNR = T036MENG.ARNR`.
- Aktives Blech: `GCRECORD IS NULL AND VERBRAUCHT = 0 AND AUSGEBUCHT = 0`.
  Eine Charge hat oft **mehrere** aktive Bleche (528 von 1.179) → vor Mengen-Joins aggregieren.
- Lagerplatz: `DIP_BLECHE.LAGER` → `DIP_LAGER.OID`; `DIP_LAGER.VALUE` = `T036MENG.LGORT`
  (`VALUE` nicht eindeutig → altes Skript nimmt `MIN(OID)` je `VALUE`).
- View **`V036CH`** = Chargenübersicht mit WE-Daten: `CHARGE` (Lieferanten-Charge), `LSDA`
  (Eingang), `KRNR`, `LIEFNAME`, `WE_NUMMER`, Schmelz-/Zeugnis-Nr., `DICKE`, `BREITE`, `KG`.
  Eindeutig je `MANR, LANR, LTYP, LAGO`.

### Kennzeichen
- `T036MENG.IDENT` (LTYP 'T'): Chargen aus der LogiCAL-Schnittstelle haben eine Zahl mit
  Sternchen-Auffüllung (z.B. `**1378.00`) – alle 1.179 aktiven Chargen haben dieses Format.
- `IDENT = 'MAN'` = **von Hand eingebuchte Charge** → existiert nie in LogiCAL, wird darum nie
  über LogiCAL verbraucht. Es entstehen laufend neue (letzte 19.11.2026). `LSDA` hat dann eine Uhrzeit.
- `V036CH.CHARGE = '00000'` ist **kein** sicheres Leichen-Kennzeichen (96 davon sind in LogiCAL aktiv).
  Altes Skript `… charge = '00000' and lsda < '01.01.2025'` daher nicht verwenden.
- `T036MENG.DLAB` wird seit 11/2020 nicht mehr gepflegt; verbrauchte Chargen stehen auf `VERF = 0`
  (9.321 Stück, `FR3` bleibt leer; nur 9 Chargen mit `FR3 = 'I'`).

### Befund (Stand 2026-11-22)
| | Chargen mit Bestand |
|---|---|
| aktiv in LogiCAL | 1.179 |
| nicht aktiv in LogiCAL (= Leichen) | **215** |
| davon `MAN` (von Hand) | 179 |
| davon Sternchen, in LogiCAL fehlt/verbraucht/ausgebucht/gelöscht | 22 |
| davon `IDENT` leer (LAGO 4-stellig 8989/8990/98xx, 2023–2024) | 12 |
| davon sonstige (`4711`, `003153`, 2017) | 2 |
| davon in LogiCAL unter **anderem Artikel** (Teilmenge der obigen) | 7 |
Alle Artikel der 215 existieren in `DIP_MATERIAL`.
- **Artikelbestand ≠ Chargenbestand ist bei HS der Normalfall:** `T075LAG.EFFB` = Summe
  `T036MENG.VERF` nur bei 81 von 217 Artikel/Lager ohne Leichen. Einheit beidseitig kg, kein fester
  Faktor. Teils negativer Artikelbestand (Lager 66), teils Artikel 0 bei Chargen mit Bestand
  (Lager 69, Lochbleche – laut LogiCAL aktiv!). Abgang wird am Artikel gebucht, Chargen nicht
  (vollständig) abgebaut → Chargen sind kein verlässlicher Spiegel des Artikelbestands.

### Alte Skripte (vom Benutzer gefunden)
- `MERGE INTO dip_bleche … SET lager = …`: überträgt `T036MENG.LGORT` → `DIP_BLECHE.LAGER`
  (Richtung SHCWare → LogiCAL), dazu ein Vorschau-SELECT. Schwächen: `NVL(TRIM(lgort),'') = ''`
  nie wahr; Vorschau joint `dip_lager` inner → Bleche ohne Lager fehlen in der Vorschau.

### Trigger auf `HS.T036MENG` (Code geprüft 2026-11-25)
- `T036MENG_ORAFLEX` (BEFORE ROW, I/U): setzt nur bei INSERT `RECNUM` aus `T036MENG_DFSEQ`.
- `T036MENG_NULLTRIG` (BEFORE ROW, I/U/D): ersetzt NULL in `LAGO/IDENT` (→ `' '`),
  `KAPAZ/VERF/ANZAHL` (→ 0), `DLZU` (→ 01.01.0001); entfernt `FR3 = 'I'`, wenn `VERF` auf > 0
  geändert wird; schreibt **jede** Änderung als Historie über `SHC_BESTAND.PROTOKOLL36(Hist)`
  (→ `T036HIST`, Aktion I/U/D, `VERF_OLD/NEW` …). Ein SQL-`UPDATE` wird also protokolliert.
- `T036MENG_HOCHREGALLAGER` (AFTER ROW, I/U/D): bei `LTYP = 'T'` und `LGORT` ≠ `' '` →
  `SHC_KABELANLAGE.INSERT_T036LGORT(manr, lanr, arnr, lgort)` (Lagerort zum Artikel anlegen);
  bei `LTYP = 'R'` zusätzlich `T069LGORT`. Fehler werden nur über `SHC_PROTOKOLL('FM', …)`
  protokolliert, die Exception wird geschluckt (kein Abbruch).
- Keiner der Trigger ändert direkt `T075LAG`.
- `SHC_BESTAND.PROTOKOLL36` schreibt nur `T036HIST` (bei Änderung von VERF/ANZAHL/SOLL/IST/FR3/4/5
  oder INSERT); `PROG`, `VART`, `VORGANG` … kommen aus Package-Globals (`pProg` …), sonst leer.
  Fehler beim Insert → `RAISE` (DML bricht ab). Keine weiteren Seiteneffekte.
  Setzen: `SHC_BESTAND.SET_INFOS(prog, vart, manr, vorgang, lauf, ponr)` (2 Overloads, Spec Z. 8/17),
  z.B. `SHC_Bestand.Set_Infos('UEB_ALTCHG_AUSBUCH','DP',50,null,null,null)` in Prozedur
  `HS.UEBERNAHME_ALT_AUSBUCHEN` (Altchargen-Bereinigung 17.01.2026). **Achtung:** `PROTOKOLL36`
  ruft nach jedem Satz `Init_Globals` → Globals gelten nur für **eine** Zeile → `SET_INFOS` vor
  jedem Einzel-UPDATE aufrufen (Schleife), sonst bleibt `PROG` ab der 2. Zeile leer.

### Wie SHCWare Chargen ausbucht (`T036HIST`, HS, LTYP 'T', 12/2025–11/2026)
| PROG | VART | Anzahl | Muster |
|---|---|---|---|
| `UEB_DIP_CHARGENBEST` | DP | 2.963 | LogiCAL-Schnittstelle (laufend) |
| `UEB_ALTCHG_AUSBUCH` | DP | 262 | einmalige Altchargen-Bereinigung am 17.01.2026 (16:53–17:14) |
| (leer) | | 24 + 8 | SQL von Hand (8× zusätzlich `ANZAHL 1 → 0`) |
| `SHC036LCV` | K | 5 | Programm SHC036 |
In allen Fällen: `VERF → 0`, **`FR3` unverändert**, `ANZAHL` unverändert (meist 1).

### Prozedur `HS.UEBERNAHME_ALT_AUSBUCHEN` (Altchargen-Bereinigung 17.01.2026)
- Auswahl: `V036CH` mit `CHARGE = '00000' AND LSDA < c_cutoff_date` (ohne LogiCAL-Prüfung! –
  `00000` ist kein sicheres Kriterium, siehe oben).
- Je Charge: `UPDATE t036meng SET verf = 0, anzahl = 1, frn2 = -3` (über `RECNUM`);
  `FRN2 = -3` = Markierung dieser Bereinigung (wird zu Beginn auf 0 zurückgesetzt).
- `SET_INFOS('UEB_ALTCHG_AUSBUCH','DP',50,…)` wird **nach** dem UPDATE aufgerufen → wirkt erst auf
  die nächste Zeile (Fehler; richtig: vorher aufrufen).
- Stichtag `c_cutoff_date = DATE '2022-01-01'` (nur `00000`-Chargen mit Eingang vor 2022).
- Danach je Artikel/Lager mit `FRN2 = -3`: lokale Funktion `Abgleich(50, lanr, arnr, 'DIP', 'DIP')`:
  - `Summe_t036`: Summe der Chargen (`LTYP IN ('T','K')`, `VERF > 0`, `FR3 <> 'I'`), umgerechnet
    nach `T051ART.BERKZ` (bei `FORMATV = 'J'` wie `'4'`): `'3'/'4'` → `VERF`; `'1'` → × `THHGW`;
    `'2'` → `VERF` bzw. `ANZAHL × KAPAZ`; `'5'` → über `T636MENG` (`DICKE`, `BREITE`; Join
    `T636MENG.ZUNR = T036MENG.LAGO`); gerundet mit `SHC_STAHL.STAHL_RUNDEN`.
  - `T075LAG.VERF := Summe Chargen`, `EFFB := Summe + (EFFB_alt − VERF_alt)`, `EPZAE := max EPNR + 1`.
  - Bewegung in `T092EP`: `VORG = 'B'` (Berichtigung), `MENGE` = neu − alt, `EIPR = 0`,
    `TEXT = 'DIP'`; vorher `SET_INFOS(prog, 'K', manr, 0, 0, 0)`.
  - **D.h. der Artikelbestand wird komplett auf die Chargensumme gesetzt** (nimmt auch alle
    anderen Differenzen mit), nicht nur um die ausgebuchte Menge reduziert.

### Warum der Kunde vor der Rechnung nachbuchen muss (Analyse 2026-11-26)
Zeitstrahl `T092EP` + `T036HIST` für 103802 (1.4539) Lager 66 seit Reorganisation 08.07.2025:
- **`IDENT` der LogiCAL-Charge = Tafelgewicht aus LogiCAL** (`**3416.00`, `**2342.40`). Die
  Schnittstelle setzt die Charge auf dieses Gewicht: WE 3.562 (29.10.2026) → DIP −146 → 3.416.
- **Der DIP-Abgleich setzt den Artikel bei jedem Lauf, in dem sich eine Charge des Artikels ändert,
  auf die Chargensumme** (`T092EP VORG 'B' TEXT 'DIP'`). Abgänge aus Rechnungen (`VORG 'A'`) seit dem
  letzten Lauf werden dabei **zurückgegeben**: 30.10.2026 −138,32 = Charge −146 + Abgang 7,68;
  12.12.2025 +3.904 = Abgänge 390,4 + 3.562,4 − Charge 48,8; 25.11.2026 +4.151,2 = Abgang 4.831,2 − MAN 680.
  → Der Artikelbestand folgt LogiCAL (Tafelverbrauch); Rechnungsabgänge wirken nur bis zum nächsten Lauf.
- **Ablauf, der zur Sperre führt:** Tafel in LogiCAL verbraucht (09.11.2026: Charge 011381 −3.416,
  Artikel −3.416) → danach Lieferung/Rechnung desselben Materials (LS 430392, 4.831,2 kg) zieht den
  Artikel ein zweites Mal ab → verfügbarer Bestand −2.687,2 → Rechnung gesperrt (HS hat vermutlich
  `T070BETR.LAGF = 1`, keine negativen Bestände; ungeprüft) → Nachbuchung von Hand.
- **Die Nachbuchung erzeugt die Leichen:** 23.11.2026 `SHC036LCV` (forconi) legt MAN-Charge 011438
  (2.700) an **und** bucht den Artikel +2.700 (EP 27, ohne Text); erst danach die Rechnung (EP 28,
  `DATWZ` = Lieferscheindatum 12.11.). Der nächste Abgleich nimmt den Artikelzugang wieder zurück,
  die MAN-Charge bleibt dauerhaft → Chargensumme und Artikel zu hoch. Gleiches Muster am 30.07.2025
  (Artikel +8.927,2, MAN 010289 680). Erklärt die laufend neuen MAN-Chargen.
- `T092EP.EPNR` ist die Buchungsreihenfolge; `DATWZ` kann davor liegen (Lieferscheindatum).
  `T092EP.MENGE` ist bei `A` positiv gespeichert (EK192 zeigt negativ).
- LogiCAL übergibt mit dem Auftrag (`T620LP`, `KALK2`) Materialartikel und Gewicht der Position
  und je verwendeter Tafel einen Satz 4 (Chargenteil, `feld3` = Charge, `feld8` = Gewicht).

- **Bestätigt über alle MAN-Chargen (Abfrage 2026-11-26, `T036HIST` I/MAN seit 07/2025):** 85 MAN-Chargen
  (rund 20 t) in 16 Monaten, fast alle `SHC036LCV` (v.a. forconi, ebleuel, henkel). Bei praktisch allen folgt
  direkt danach (`EPNR` +1 bis +2) der Rechnungsabgang `VORG 'A'` desselben Artikels/Lagers, mit
  Lieferscheindatum vor der Nachbuchung → MAN-Charge = Behelf, um die Rechnung freizubekommen.
  Ausnahmen: Umbuchung 69 → 66 (101001, ±4), eine Gutschrift (`GL-`, Menge negativ), zwei MAN-Chargen
  vom 26.11.2026 ohne Rechnung (noch offen).
- Die Artikelbuchung beim Anlegen einer MAN-Charge (`VORG 'B'`, ohne Text) ist meist **größer als die
  Charge** (z.B. MAN 26 → Artikel +2.756): `SHC036LCV` setzt den Artikel offenbar ebenfalls auf die
  Chargensumme und gibt dabei die Rechnungsabgänge seit dem letzten DIP-Lauf zurück.
- 8 Fälle mit Rechnungsabgang **0,01 kg**: LogiCAL übergibt bei `OhneMaterialKosten` (Kundenmaterial)
  den Materialartikel mit Gewicht 0,01 (`SHCWareExportHelper`, `feld4 = "0,01"`); auch das sperrt die
  Rechnung, wenn der Artikel ≤ 0 steht.
- Mögliche Stellschrauben (Kommentare, ungeprüft): `T070BETR.LAGF` (1 = keine negativen Bestände,
  ganzer Betrieb), `T069BLAG.RES09` (Lagerführung je Lager), `T051ART.NEGA` / `T086AUP.NEGA`
  (0/1 = mit Lagerführung, 2 = ohne Lagerführung, je Artikel bzw. Auftragsposition).

### Bereinigung – Stand und nächste Schritte
- Entscheidung Benutzer: zuerst nur die 215 Chargen in SHCWare abbauen (LogiCAL führend für
  Chargen); Artikelbestand bleibt, Korrektur später per Inventur.
- 2026-11-22: Kundenliste (215 Zeilen) exportiert → `queries/hs_blechchargen_ausbuchliste_kunde.sql`.
  **Warten auf Freigabe des Kunden** (bes. die 7 Chargen „unter anderem Artikel“).
- 2026-11-25: **Kunde hat entschieden:** alle Chargen mit Grund „Von Hand eingebucht, in LogiCAL
  nicht vorhanden“ (`IDENT = 'MAN'`, kein Blech in LogiCAL) werden ausgebucht. Die übrigen
  (Sternchen, leer, sonstige, anderer Artikel) bleiben vorerst stehen.
  Abgrenzung auf den Stand der Kundenliste: `V036CH.LSDA < DATE '2026-11-23'`.
- Methode bestätigt (T036HIST): `VERF = 0`, `FR3`/`ANZAHL` unverändert.
- Hilfstabelle `HS.TMP_BLECH_MAN_20261125` (179 Chargen, 28.579,86 kg), Vorschau ok (2026-11-25).
- Auswirkung auf Artikelbestand (135 Artikel/Lager, alle `FORMATV = 'J'` → Chargensumme = `VERF`):
  nur 34× gilt Artikel = übrige Chargen + MAN. Variante „Artikel − MAN“ → 64 Artikel negativ
  (−2.821,69 kg). Variante `Abgleich` (Artikel = Chargensumme) → netto −19.316,63 kg, davon
  12 Erhöhungen (+4.663,74 kg; v.a. 103802 1.4539 Lager 66: +4.151,2 kg). 28 Artikel schon ≤ 0.
  → Die MAN-Mengen sind am Artikel oft schon (teilweise) abgebucht.
- **2026-11-25 ausgeführt (Variante B, wie Januar), commit ok:** 179 MAN-Chargen `VERF = 0`
  (`T036HIST.PROG = 'UEB_MANCHG_AUSBUCH'`), 135 Artikel/Lager per Abgleich auf Chargensumme
  (`T092EP` `VORG 'B'`, `TEXT 'MANCHG AUSBUCH'`, −19.316,63 kg). Alle Prüfwerte exakt wie erwartet;
  SHCWare-Kontrolle 100060 ok. Skript: `queries/hs_blechchargen_man_ausbuchen.sql`.
  Sicherungen `HS.T036MENG_BAK_20261125`, `HS.T075LAG_BAK_20261125`.
- Danach: Trigger-Code prüfen → `TMP_`-Hilfstabelle mit freigegebenen Chargen → Vorschau →
  `T036MENG_BAK_YYYYMMDD` → `UPDATE` ohne AutoCommit → Prüfabfrage → `COMMIT`.
- **Projekt abgeschlossen (2026-11-25):** Kunde wollte nur die MAN-Chargen ausbuchen; keine
  weiteren Änderungen. Die folgenden Punkte sind **nicht beauftragt**, nur zur Info:
- Nicht bereinigt: übrige 36 Leichen (22 Sternchen, 12 IDENT leer, 2 sonstige – inkl. 7 „anderer Artikel“).
- Ungeklärt: Warum werden `MAN`-Chargen angelegt (Prozess)? Es entstehen laufend neue. Was ist Lager 69? Mengenabgleich der
  aktiven Chargen gegen LogiCAL (Gewicht der Tafeln) – Spalten von `DIP_BLECHE` noch unbekannt.
