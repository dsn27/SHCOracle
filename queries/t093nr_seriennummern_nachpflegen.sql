-- =====================================================================================
-- Zweck   : Seriennummern zu einer bereits gelieferten Auftragsposition nachträglich
--           erfassen (T093NR, eine Zeile je Seriennummer)
-- Mandant : SHC / KBS (MANR = 46, Lager 72) – für andere Mandanten Schema/MANR/Lager anpassen
-- Geprüft : 2026-11-23/24 – Aufträge 1620725 und 1619402 (siehe Änderungsprotokoll unten).
--           Ergebnis: Nummern stehen in T093NR wie von SHCWare angelegt; in der SHCWare-Suche
--           über die Auftragsnummer sichtbar (diese zeigt grundsätzlich nur Lauf 1).
-- EINSCHRÄNKUNG (offen): Auf dem Rechnungs-Duplikat erscheinen so nachgetragene Nummern
--           NICHT (geprüft 506133, 505980). Ursache unbekannt – siehe schema/NOTES.md,
--           „Rechnungsdruck und Seriennummern – OFFEN“. Wer die Nummern auf der Rechnung
--           braucht: vorher klären (SHCWare-Support bzw. Quelltext der Druck-Packages).
-- Hinweise: Kunden schreiben „Auftrag/01“, „/02“ = Lieferschein-Lauf (LAUF), siehe Schritt 4b.
--           Seriennummern teils mit Leerzeichen („FR 020195922“) → ohne Leerzeichen erfassen
--           (so stehen sie in T093NR). Vor dem Einfügen immer Schritt 3: dieselbe Nummer wurde
--           einmal für zwei Aufträge genannt (Tippfehler des Kunden).
--
-- Änderungsprotokoll (Produktiv, SHC/MANR 46, alle committet):
--   2026-11-23  T093NR  +4  1620725 Lauf 1 Pos 1  FR020195678–681       RECNUM 404356–404359
--   2026-11-24  T093NR  +3  1619402 Lauf 1 Pos 1  FR020195682           RECNUM 404409
--                           1619402 Lauf 2 Pos 1  FR020195918, …922     RECNUM 404411, 404410
--   2026-11-24  T487KOM4 +3 1619402 (IDKOM3 265815 / 266348), dieselben 3 Nummern, ID aus
--                           T487KOM4_SEQ (≥ 188282). Versuch für den Rechnungsdruck – ohne
--                           Wirkung; entspricht dem, was die Kommissionierung schreibt, bleibt
--                           stehen. Rückgängig: delete from shc.t487kom4 where ainr = 1619402
--                           and idkom3 in (265815, 266348);
--
-- ACHTUNG : Ändert Produktivdaten! Nur auf ausdrücklichen Wunsch, AutoCommit AUS,
--           alle Schritte im selben SQL-Fenster.
--
-- Befüllung wie SHCWare selbst (geprüft an den Zeilen vom Oktober/November 2026):
--   RECNUM  = Trigger T093NR_ORAFLEX setzt bei jedem INSERT T093NR_DFSEQ.NEXTVAL
--             (mitgegebener Wert wird überschrieben → Platzhalter 0)
--   BLNR    = 0 (wird auch nach Lieferscheindruck/Rechnung NICHT nachgetragen)
--   LAUF    = Lauf der Lieferung (T087POLI.LAUF)
--   BEDA    = Datum der Erfassung (bei SHCWare teils nach dem Lieferdatum); hier TRUNC(SYSDATE)
--   KONT    = Kundennummer, AIBENR = AINR, PONR = Auftragsposition (T087POLI.AUFPOS)
--   MENGE   = 1, PREIS/RENR/REDA = NULL, FRN1_LG = Lagernummer (T081AUK/T086AUP.LANR)
--   T036SN (Gerätestamm): für Artikel 110784 / Serie …020195… keine Zeilen → nicht gepflegt.
-- Anpassen: MANR, AINR, LAUF, Position und Seriennummern stehen unten als feste Werte.
-- =====================================================================================


-- -------------------------------------------------------------------------------------
-- Schritt 1: Position prüfen – gelieferte Menge, schon vorhandene Seriennummern
-- -------------------------------------------------------------------------------------
select p.manr, p.ainr, p.ponr, p.arnr, p.lanr,
       p.beme as bestellt, p.meng as geliefert, p.rume as rueckstand,
       (select count(*) from shc.t093nr n
         where n.manr = p.manr and n.aibenr = p.ainr and n.ponr = p.ponr) as anz_seriennr
  from shc.t086aup p
 where p.manr = 46
   and p.ainr = 1620725
   and p.ponr = 1;


-- -------------------------------------------------------------------------------------
-- Schritt 2: Lieferung(en) zur Position – bei mehreren Läufen Zuordnung beim Kunden klären
-- -------------------------------------------------------------------------------------
select l.manr, l.ainr, l.lauf, l.blnr, l.aufpos, trim(l.arnr) as arnr, l.menge,
       l.kdnr, k.stat as ls_status, k.renr, k.dadl as druck_ls
  from shc.t087poli l
  join shc.t082auli k on k.manr = l.manr and k.ainr = l.ainr and k.lauf = l.lauf
 where l.manr = 46
   and l.ainr = 1620725
   and l.aufpos = 1
 order by l.lauf;


-- -------------------------------------------------------------------------------------
-- Schritt 3: Existieren die Seriennummern schon (auch in T036SN)? Muss leer sein.
-- -------------------------------------------------------------------------------------
select 'T093NR' as quelle, n.manr, n.nummer, n.arnr, n.aibenr, n.ponr, n.beda
  from shc.t093nr n
 where upper(trim(n.nummer)) in ('FR020195678', 'FR020195679', 'FR020195680', 'FR020195681')
union all
select 'T036SN', s.manr, s.serie, s.arnr, null, null, s.dat_zug
  from shc.t036sn s
 where upper(trim(s.serie)) in ('FR020195678', 'FR020195679', 'FR020195680', 'FR020195681');


-- -------------------------------------------------------------------------------------
-- Schritt 4: Einfügen (Werte aus der Lieferposition; vorhandene Nummern werden übersprungen)
-- -------------------------------------------------------------------------------------
insert into shc.t093nr
       (recnum, manr, nummer, arnr, kont, blnr, lauf, beda,
        aibenr, ponr, menge, preis, renr, reda, frn1_lg)
select 0, l.manr, s.nr, trim(l.arnr), trim(l.kdnr), 0, l.lauf, trunc(sysdate),
       l.ainr, l.aufpos, 1, null, null, null, 72
  from shc.t087poli l
 cross join (select 'FR020195678' as nr from dual union all
             select 'FR020195679'       from dual union all
             select 'FR020195680'       from dual union all
             select 'FR020195681'       from dual) s
 where l.manr   = 46
   and l.ainr   = 1620725
   and l.lauf   = 1
   and l.aufpos = 1
   and not exists (select 1 from shc.t093nr n
                    where upper(trim(n.nummer)) = s.nr);


-- -------------------------------------------------------------------------------------
-- Schritt 4b: Variante für mehrere Lieferscheine (Läufe) – Lauf je Seriennummer angeben,
--             Lager aus der Auftragsposition
-- -------------------------------------------------------------------------------------
insert into shc.t093nr
       (recnum, manr, nummer, arnr, kont, blnr, lauf, beda,
        aibenr, ponr, menge, preis, renr, reda, frn1_lg)
select 0, l.manr, s.nr, trim(l.arnr), trim(l.kdnr), 0, l.lauf, trunc(sysdate),
       l.ainr, l.aufpos, 1, null, null, null, p.lanr
  from (select 1 as lauf, 'FR020195682' as nr from dual union all
        select 2,         'FR020195922'       from dual union all
        select 2,         'FR020195918'       from dual) s
  join shc.t087poli l
    on l.manr = 46 and l.ainr = 1619402 and l.aufpos = 1 and l.lauf = s.lauf
  join shc.t086aup p
    on p.manr = l.manr and p.ainr = l.ainr and p.ponr = l.aufpos
 where not exists (select 1 from shc.t093nr n
                    where upper(replace(n.nummer, ' ', '')) = s.nr);


-- -------------------------------------------------------------------------------------
-- Schritt 5: Prüfen, dann  commit;  bzw.  rollback;
-- -------------------------------------------------------------------------------------
select recnum, manr, nummer, arnr, kont, blnr, lauf, beda,
       aibenr, ponr, menge, preis, renr, reda, frn1_lg
  from shc.t093nr
 where manr = 46 and aibenr = 1620725
 order by recnum;

-- Rückgängig (nur wenn die Position vorher KEINE Seriennummern hatte):
-- delete from shc.t093nr where manr = 46 and aibenr = 1620725 and ponr = 1;
