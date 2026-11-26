# Änderungsvorschlag SHC043: LogiCAL-Unterkomponenten bei HERZAU ohne Lagerführung

Stand: 2026-11-26 · Mandant HS (MANR 50) · Bezug: Package `HS.SHC043`, Funktion `kalk2_verarbeite_auftrag`
(Zeilenangaben nach dem Package-Export vom 26.11.2026)

## Problem

Für Herzau führt die LogiCAL-Schnittstelle den Blechbestand: `UEB_DIP_CHARGENBEST` bucht die in LogiCAL
verbrauchte Tafel an der Charge (`T036MENG`) aus und setzt `T075LAG` auf die Summe der Chargen
(`T092EP` `VORG 'B'`, `TEXT 'DIP'`). Die über `SHC043` (KALK2) angelegten Aufträge (Auftragsart `LM`) enthalten
das Blech als Unterkomponente (`KZSL = 2`) **mit** Lagerführung (`NEGA` aus `T051ART`, dort leer). Lieferschein
und Rechnung buchen das Blech dadurch ein zweites Mal ab. Weil `T070BETR.LAGF = 1` ist, wird die Rechnung
gesperrt („Negative Bestände nicht erlaubt“); der Anwender legt eine Hand-Charge (`IDENT = 'MAN'`) an, die
nie verbraucht wird. Seit 07/2025: 85 Hand-Chargen, rund 20 t.

## Lösung

Unterkomponenten aus KALK2 werden bei `gshc043_anw = 'HERZAU'` ohne Lagerführung angelegt (`NEGA = '2'`).
Die Anarbeitungs- und Schrottartikel haben `NEGA = '2'` bereits im Artikelstamm; Handelsware kommt als
Hauptposition (Satz 2) ohne Unterkomponente und bleibt mit Lagerführung.

## Code

### 1. Deklaration in `kalk2_verarbeite_auftrag`

Bei den übrigen lokalen Variablen (z. B. nach `lPos_in_weiterem_Lauf varchar2(1);`, Z. ~6526):

```sql
    lNega_UK          t086aup.nega%type;                                    --<Kürzel> <Datum> (Vorgang: <Nr.>) HERZAU: UK ohne Lagerführung
```

### 2. In der Schleife der Unterkomponenten, vor dem Speichern der UK

Unmittelbar **vor** der Zeile `shc_ab001.row_t386pos_zusi0.kalkstatus := lKalkStatus;` (Z. ~8218, direkt vor
`-- UK speichern` / `SHC_AB001.SavePosition(FALSE)`):

```sql
              --<Kürzel> <Datum> (Vorgang: <Nr.>) HERZAU: Unterkomponente (Blech) ohne Lagerführung anlegen.
              -- Den Blechbestand führt die LogiCAL-Schnittstelle (UEB_DIP_CHARGENBEST: Charge ausbuchen,
              -- Artikel = Summe der Chargen). Mit Lagerführung würden Lieferschein und Rechnung das Blech ein
              -- zweites Mal abbuchen und wegen T070BETR.LAGF = 1 die Rechnung sperren.
              -- Nur für neu angelegte Positionen; Positionen in weiteren Läufen behalten ihr Kennzeichen.
              if gshc043_anw = 'HERZAU'
                 and nvl(lPos_in_weiterem_Lauf,'N') != 'J'
                 and nvl(trim(shc_ab001_i.Get_t086aup_nega),'0') != '2' then
                 begin
                    lNega_UK := '2';
                    SHC_AB001_I.Set_t086aup_nega(lNega_UK);
                 exception
                    when others then
                       -- Eingliederung nicht abbrechen: Position bleibt dann wie bisher mit Lagerführung
                       shc_protokoll('FM','SHC043','LOGICAL UK ohne Lagerführung nicht gesetzt. Auftrag: ' || lAinr ||
                                                   ' FileID: ' || inFileid || ' Artikel: ' || xct620lp_uk.feld3 || chr(10) ||
                                                   'Fehlermeldung: ' || substr(sqlerrm,1,500),
                                     SHC_Session.Get_Betr,SHC_Session.Get_Lanr);
                 end;
              end if;
```

Hinweise zum Code:

- Gesetzt wird über `SHC_AB001_I.Set_t086aup_nega` (IN OUT, daher Variable), wie in `SHC_AB001A` bei der
  Geschäftsartenänderung. Der Setter prüft selbst über `SHC_AB001_L.CheckAenderungen`, ob die Änderung erlaubt ist.
- `Set_t086aup_rest_nega` (Stelle 18 von `REST`) wird nicht gebraucht: `CheckIsLagerfuehrung` wertet
  `NEGA = '2'` **oder** `REST`-Stelle 18 aus; `SHC_AB001A` setzt für „ohne Lagerführung“ ebenfalls nur `NEGA`.
- `SavePosition2` setzt `NEGA` nur im Zweig für Sammelartikel neu aus dem Artikel; Blechartikel sind keine
  Sammelartikel.
- Die Weiche `HERZAU` gilt nur dort, wo `SHC043_ANW = 'HERZAU'` gesetzt ist (HS: ja, ohne MANR/Kennung).
  Andere KALK2-Kunden (DROESSER, HINZE, STRAUB) bleiben unverändert.

## Fragen an SHC

1. Löst `Set_t086aup_nega('2')` für eine neue, noch nicht gespeicherte Position eine Bestandskorrektur aus
   (Zweig ab Z. 6743 in `SHC_AB001_I`, `GetStatusPosition() in (0,2)`)? Erwartet: nein.
2. Einstandspreis: LogiCAL übergibt `feld9 = 0`, `SHC043` setzt deshalb keinen `EIPR`. Kommt der
   Durchschnittspreis bei `NEGA = '2'` weiterhin in die Position (Rohertrag)?
3. Statistik (`T096STAT`): Werden Menge und kg der Blechposition ohne Lagerführung weiter fortgeschrieben?
4. Wird die Änderung in den Release-Stand von `SHC043` übernommen?

## Test

1. In LogiCAL einen Auftrag mit einer Blechposition (Material aus Lager 66), einer Anarbeitung und einer
   Handelswarenposition an SHCWare übergeben.
2. Prüfen: Blech-UK `NEGA = '2'`, Anarbeitung `NEGA = '2'`, Handelsware unverändert (Abfrage unten).
3. Den Artikelbestand des Blechs vorher notieren (`T075LAG.EFFB/VERF`).
4. Lieferschein und Rechnung erstellen – auch wenn der verfügbare Bestand des Blechartikels kleiner als die
   Liefermenge ist. Erwartet: keine Sperre, kein `T092EP` `VORG 'A'` für den Blechartikel, `T075LAG` unverändert;
   die Handelsware bucht wie bisher ab.
5. Die Tafel in LogiCAL verbrauchen → DIP-Lauf bucht Charge und Artikel ab (`VORG 'B'`, `TEXT 'DIP'`).
6. Ein Auftrag mit Kundenmaterial (Blech 0,01 kg) lässt sich fakturieren, auch wenn der Artikel bei 0 steht.

Prüfabfrage nach der Einführung (neue LM-Aufträge, Unterkomponenten in Lager 66/69 nach `NEGA`):

```sql
select nvl(trim(p.nega), '(leer)') as nega,
       count(distinct p.ainr)      as auftraege,
       count(*)                    as positionen
  from hs.t081auk a
  join hs.t086aup p
    on p.manr = a.manr
   and p.ainr = a.ainr
 where a.manr = 50
   and a.aart = 'LM'
   and a.adat >= date '2026-12-01'      -- Datum der Einführung
   and p.lanr in (66, 69)
   and nvl(trim(p.kzsl), '0') = '2'
 group by nvl(trim(p.nega), '(leer)');
```

Erwartet: nur `NEGA = 2`.

## Hinweise zur Einführung

- Wirkt nur für Aufträge, die nach dem Einspielen übernommen werden. Offene `LM`-Aufträge laufen nach altem
  Muster aus; `NEGA` dort nicht nachträglich ändern (Reservierungen der Lieferscheine).
- Danach die Hand-Chargen, die bis dahin entstanden sind, einmalig ausbuchen (wie am 25.11.2026).
- Rückweg: die Zeilen entfernen bzw. auskommentieren.
