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
- **Automatischer Datenversand `T499ISEL7`** (geprüft 2026-11-22, SHC): PK `AUSART` (Name der
  Ausgabeart, **kein** `MANR`), Abfrage in `LSQL` (CLOB). Keine Historie, keine Sicherungskopie in
  irgendeinem Schema. Der Versandjob läuft um ca. **05:00** und erzeugt je Ausgabeart mehrere
  Abfragen um den `LSQL`-Text herum: `Begin DECLARE Cursor c1 is <LSQL> …`,
  `select count(*) from (<LSQL>)`, `select * from (<LSQL>)` und eine großgeschriebene Fassung
  ohne Zeilenumbrüche. `PERIODE` kennt neben den kommentierten Werten (T/M/W/X/Q/J) auch **`'A'`**
  (Bedeutung unbekannt, z.B. `BESTAND KBS WEB`).
- **Alten Wert einer Spalte wiederfinden** (z.B. überschriebenes `LSQL`): Flashback
  (`AS OF TIMESTAMP`) reicht nur Stunden zurück; nach 2 Tagen kam `ORA-01555`. Den Text einer
  dynamisch ausgeführten Abfrage findet man in **`V$SQL` / `V$SQLAREA`** (Benutzer hat Leserechte;
  Text war nach 2 Tagen noch da): Filter auf `LAST_ACTIVE_TIME` vor der Änderung, Kandidaten mit
  aktuellen Texten vergleichen (Leerzeichen per `REGEXP_REPLACE(…, '\s', '')` entfernen,
  `DBMS_LOB.INSTR`). Ablauf: `queries/t499isel7_alten_lsql_wiederfinden.sql`.

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
