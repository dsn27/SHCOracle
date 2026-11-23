-- =====================================================================================
-- Zweck   : Seriennummern zu einer bereits gelieferten Auftragsposition nachträglich
--           erfassen (T093NR, eine Zeile je Seriennummer)
-- Mandant : SHC / KBS (MANR = 46, Lager 72) – für andere Mandanten Schema/MANR/Lager anpassen
-- Geprüft : 2026-11-23 – Auftrag 1620725 Pos. 1, Artikel 110784, Lieferschein 1376369 Lauf 1,
--           4 Seriennummern eingefügt (RECNUM 404356–404359 per Trigger)
--
-- ACHTUNG : Ändert Produktivdaten! Nur auf ausdrücklichen Wunsch, AutoCommit AUS,
--           alle Schritte im selben SQL-Fenster.
--
-- Befüllung wie SHCWare selbst (geprüft an den Zeilen vom Oktober/November 2026):
--   RECNUM  = Trigger T093NR_ORAFLEX setzt bei jedem INSERT T093NR_DFSEQ.NEXTVAL
--             (mitgegebener Wert wird überschrieben → Platzhalter 0)
--   BLNR    = 0 (wird auch nach Lieferscheindruck/Rechnung NICHT nachgetragen)
--   LAUF    = Lauf der Lieferung (T087POLI.LAUF)
--   BEDA    = Erfassungsdatum der Seriennummer (bei Nacherfassung = Tag der Erfassung)
--   KONT    = Kundennummer, AIBENR = AINR, PONR = Auftragsposition (T087POLI.AUFPOS)
--   MENGE   = 1, PREIS/RENR/REDA = NULL, FRN1_LG = Lagernummer (T081AUK/T086AUP.LANR)
--   T036SN (Gerätestamm) wird bei KBS-Handelsartikeln nicht geführt → nichts mitpflegen.
-- Platzhalter unten: :manr, :ainr, :ponr, Seriennummern, Lager 72
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
-- Schritt 5: Prüfen, dann  commit;  bzw.  rollback;
-- -------------------------------------------------------------------------------------
select recnum, manr, nummer, arnr, kont, blnr, lauf, beda,
       aibenr, ponr, menge, preis, renr, reda, frn1_lg
  from shc.t093nr
 where manr = 46 and aibenr = 1620725
 order by recnum;

-- Rückgängig (nur wenn die Position vorher KEINE Seriennummern hatte):
-- delete from shc.t093nr where manr = 46 and aibenr = 1620725 and ponr = 1;
