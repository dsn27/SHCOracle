-- =====================================================================================
-- Zweck   : Von Hand eingebuchte Blech-Chargen (T036MENG.IDENT = 'MAN'), die es in LogiCAL
--           nicht gibt (kein DIP_BLECHE mit EXREF1 = LAGO), in SHCWare ausbuchen (VERF = 0).
--           Nur der Chargenbestand – Artikelbestand T075LAG bleibt unverändert.
-- Mandant : HS (MANR = 50)
-- Freigabe: Kunde 2026-11-25 (Grund „Von Hand eingebucht, in LogiCAL nicht vorhanden“ aus
--           queries/hs_blechchargen_ausbuchliste_kunde.sql, Export vom 22.11.2026)
-- Status  : IN ARBEIT – noch nicht ausgeführt
--
-- Trigger : T036MENG_NULLTRIG → SHC_BESTAND.PROTOKOLL36 schreibt je geänderter Zeile einen
--           Satz in T036HIST (VERF_OLD/NEW, OSUSER, DATUM; PROG/VART leer, da nicht aus SHCWare).
--           Schlägt das fehl, bricht das UPDATE ab (RAISE). T036MENG_HOCHREGALLAGER legt ggf.
--           den Lagerort (T036LGORT) an – harmlos. Kein Trigger ändert T075LAG.
--
-- ACHTUNG : Ändert Produktivdaten! AutoCommit in PL/SQL Developer AUS.
-- =====================================================================================


-- -------------------------------------------------------------------------------------
-- Schritt 1: Hilfstabelle – nur Chargen, die auf der Kundenliste standen (Eingang < 23.11.2026)
-- -------------------------------------------------------------------------------------
create table hs.tmp_blech_man_20261125 as
select tm.manr, tm.lanr, tm.ltyp, tm.lago, tm.ident, tm.arnr, tm.lgort,
       tm.verf, tm.anzahl, tm.kapaz, tm.fr3, tm.dlzu, v.charge, v.lsda
  from hs.t036meng tm
  left join hs.v036ch v
         on v.manr = tm.manr
        and v.lanr = tm.lanr
        and v.ltyp = tm.ltyp
        and v.lago = tm.lago
 where tm.manr = 50
   and tm.ltyp = 'T'
   and nvl(tm.fr3, ' ') <> 'I'
   and tm.verf > 0
   and trim(tm.ident) = 'MAN'
   and nvl(v.lsda, tm.dlzu) < date '2026-11-23'
   and not exists (select 1 from dip_bleche b where b.exref1 = tm.lago);

-- Kontrolle: anz = versch_chargen = Anzahl „Von Hand eingebucht …“ im Kunden-Export
select count(*)                                   as anz,
       count(distinct lanr || '#' || lago)        as versch_chargen,
       sum(verf)                                  as summe_verf,
       sum(case when anzahl <> 0 then 1 else 0 end) as anzahl_ungleich_0,
       sum(case when trim(lgort) is not null then 1 else 0 end) as mit_lgort,
       min(nvl(lsda, dlzu))                       as erster_eingang,
       max(nvl(lsda, dlzu))                       as letzter_eingang
  from hs.tmp_blech_man_20261125;
