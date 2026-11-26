-- =====================================================================================
-- Zweck   : Ursache der Rechnungssperren bei Blechartikeln aus LogiCAL-Aufträgen finden
--           („Negative Bestände nicht erlaubt“, Kunde muss MAN-Charge anlegen).
--           Ergebnis: Blech wird doppelt abgebucht (DIP-Lauf + Rechnung), HS sperrt negative
--           Bestände (T070BETR.LAGF = 1), MAN-Chargen bleiben als Leichen stehen.
--           Erkenntnisse: schema/NOTES.md, Abschnitt „Warum der Kunde vor der Rechnung nachbuchen muss“.
-- Mandant : HS (MANR = 50), Lager 66/69
-- Geprüft : 2026-11-26 (alle Abfragen vom Benutzer ausgeführt, nur lesend)
-- Hinweis : Artikel, Lieferscheine und Aufträge in Abfrage 1, 4 und 7 sind Beispiele – anpassen.
-- =====================================================================================


-- -------------------------------------------------------------------------------------
-- 1) Zeitstrahl eines Artikels: Artikelbewegungen (T092EP) und Chargenbewegungen (T036HIST)
--    T092EP.EPNR = Buchungsreihenfolge (DATWZ kann davor liegen = Lieferscheindatum);
--    MENGE bei VORG 'A' positiv gespeichert. 'B' + TEXT 'DIP' = Abgleich der LogiCAL-Schnittstelle.
-- -------------------------------------------------------------------------------------
select 'ARTIKEL'            as quelle,
       ep.datwz             as datum,
       ep.epnr              as nr,
       ep.vorg              as art,
       trim(ep.text)        as text_prog,
       ep.kont              as kunde_lief,
       ep.blnr              as beleg,
       ep.lauf              as lauf,
       ep.renr              as rechnung,
       null                 as lago,
       null                 as ident,
       ep.menge             as menge,
       null                 as osuser
  from hs.t092ep ep
 where ep.manr = 50
   and ep.arnr = '103802'
   and ep.lanr = 66
union all
select 'CHARGE',
       h.datum,
       h.vorgang,
       h.aktion,
       h.prog || ' / ' || h.vart,
       null,
       h.vorgang,
       h.lauf,
       null,
       h.lago,
       trim(h.ident),
       nvl(h.verf_new, 0) - nvl(h.verf_old, 0),
       h.osuser
  from hs.t036hist h
 where h.manr = 50
   and h.arnr = '103802'
   and h.lanr = 66
   and h.datum >= date '2025-07-01'
order by 2, 1, 3;


-- -------------------------------------------------------------------------------------
-- 2) Alle MAN-Chargen seit 07/2025: Artikelzubuchung am selben Tag und nächster Rechnungsabgang.
--    Muster bestätigt: EP_AB = EP_ZU + 1 (oder + 2) → MAN-Charge war Behelf für die Rechnung.
--    Mehrfachzeilen = mehrere Berichtigungen am selben Tag (für Zählung DISTINCT LAGO).
-- -------------------------------------------------------------------------------------
with man as (
  select h.manr, h.lanr, h.arnr, h.lago, h.datum, h.verf_new as menge, h.osuser, h.prog
    from hs.t036hist h
   where h.manr = 50
     and h.ltyp = 'T'
     and h.aktion = 'I'
     and trim(h.ident) = 'MAN'
     and h.datum >= date '2025-07-01'
), zu as (
  select m.*, b.epnr as ep_zu, b.menge as zubuchung
    from man m
    left join hs.t092ep b
           on b.manr = m.manr and b.lanr = m.lanr and b.arnr = m.arnr
          and b.vorg = 'B' and trim(b.text) is null
          and b.datwz = trunc(m.datum)
), nxt as (
  select z.*,
         (select min(x.epnr) from hs.t092ep x
           where x.manr = z.manr and x.lanr = z.lanr and x.arnr = z.arnr
             and x.vorg = 'A' and x.epnr > z.ep_zu) as ep_ab
    from zu z
)
select n.lanr, n.arnr, n.lago, n.datum, n.menge as man_menge, n.osuser, n.prog,
       n.ep_zu, n.zubuchung,
       n.ep_ab, a.datwz as datum_abgang, a.menge as abgang, a.blnr as lieferschein,
       a.renr as rechnung, trim(a.text) as kunde
  from nxt n
  left join hs.t092ep a
         on a.manr = n.manr and a.lanr = n.lanr and a.arnr = n.arnr and a.epnr = n.ep_ab
 order by n.datum;


-- -------------------------------------------------------------------------------------
-- 3) Schalter für Lagerführung / negative Bestände
--    Ergebnis 2026-11-26: LAGF = 1 (keine negativen Bestände), RES09 66/69 leer.
-- -------------------------------------------------------------------------------------
select 'T070BETR.LAGF' as feld, to_char(manr) as schluessel, to_char(lagf) as wert, 1 as anzahl
  from hs.t070betr
union all
select 'T069BLAG.RES09', to_char(lanr), to_char(res09), 1
  from hs.t069blag
 where manr = 50 and lanr in (66, 69)
union all
select 'T051ART.NEGA (Artikel in Lager 66/69)', null, to_char(a.nega), count(*)
  from hs.t051art a
 where a.manr = 50
   and exists (select 1 from hs.t075lag l
                where l.manr = 50 and l.arnr = a.arnr and l.lanr in (66, 69))
 group by a.nega
union all
select 'T086AUP.NEGA (Positionen Lager ' || p.lanr || ')', to_char(p.lanr), to_char(p.nega), count(*)
  from hs.t086aup p
 where p.manr = 50 and p.lanr in (66, 69)
 group by p.lanr, p.nega
order by 1, 2, 3;


-- -------------------------------------------------------------------------------------
-- 4) Aufbau eines LogiCAL-Auftrags über die Lieferscheinnummer (T082AULI.BLNR = T092EP.BLNR)
--    Blechkomponente: KZSL = 2, NEGA NULL (= mit Lagerführung); Anarbeitung/Schrott NEGA = 2.
-- -------------------------------------------------------------------------------------
select l.blnr       as lieferschein,
       l.lauf,
       p.ainr,
       p.ponr,
       p.arnr,
       p.lanr,
       '[' || p.nega || ']' as pos_nega,
       '[' || a.nega || ']' as art_nega,
       p.kzma,
       p.kzsl,
       p.meng
  from hs.t082auli l
  join hs.t086aup p
    on p.manr = l.manr
   and p.ainr = l.ainr
  left join hs.t051art a
    on a.manr = p.manr
   and a.arnr = p.arnr
 where l.manr = 50
   and l.blnr in (430392, 431564, 422563, 423317, 428955)
 order by l.blnr, l.lauf, p.ponr;


-- -------------------------------------------------------------------------------------
-- 5) Programmcode, der T620LP (LogiCAL-Schnittstelle) verwendet – immer auf Owner HS eingrenzen.
--    Import = SHC043 (kalk2_verarbeite_auftrag), Lagerführung = SHC_AB001_L.CheckIsLagerfuehrung.
-- -------------------------------------------------------------------------------------
select name, type,
       count(*) as zeilen,
       sum(case when upper(text) like '%NEGA%'  then 1 else 0 end) as zeilen_nega,
       sum(case when upper(text) like '%KALK2%' then 1 else 0 end) as zeilen_kalk2
  from all_source
 where owner = 'HS'
   and (name, type) in (select name, type
                          from all_source
                         where owner = 'HS'
                           and upper(text) like '%T620LP%')
 group by name, type
 order by name, type;

-- Codeabschnitt mit Umgebung lesen (Beispiel: Funktion und Aufrufer)
with hits as (
  select name, line,
         case when name = 'SHC_AB001_L' then 120 else 30 end as danach
    from all_source
   where owner = 'HS'
     and type  = 'PACKAGE BODY'
     and (   (name = 'SHC_FAKT'    and upper(text) like '%PRUEF_158_SONDER%')
          or (name = 'SHC_AB001_L' and upper(text) like '%FUNCTION%CHECKISLAGERFUEHRUNG%'))
)
select distinct s.name, s.line, rtrim(s.text, chr(10) || chr(13)) as text
  from all_source s
  join hits h
    on s.owner = 'HS'
   and s.type  = 'PACKAGE BODY'
   and s.name  = h.name
   and s.line between h.line - 20 and h.line + h.danach
 order by s.name, s.line;


-- -------------------------------------------------------------------------------------
-- 6) Funktionskonstanten: aktiv (T323FKON) und Doku (T322DKON)
--    Ergebnis 2026-11-26: KALK2_AART, LAGERFORTSONDER, VERFNEGA für HS nicht gesetzt.
-- -------------------------------------------------------------------------------------
select 'AKTIV' as quelle, k.konstante, to_char(k.manr) as manr, k.kennung,
       k.inhalt, substr(k.bemerkung, 1, 1000) as text
  from hs.t323fkon k
 where k.apptyp = 'DIAS'
   and k.konstante in ('KALK2_AART', 'LAGERFORTSONDER', 'VERFNEGA')
union all
select 'DOKU', d.konstante, null, null,
       d.inhalt, substr(d.text, 1, 1000)
  from hs.t322dkon d
 where d.apptyp = 'DIAS'
   and d.konstante in ('KALK2_AART', 'LAGERFORTSONDER', 'VERFNEGA')
order by 1, 2, 3, 4;


-- -------------------------------------------------------------------------------------
-- 7) Auftragsarten seit 07/2025: aus LogiCAL ja/nein (T620LP satzart 'KALK2') und Art der Positionen
--    Ergebnis 2026-11-26: LM nur aus LogiCAL (9.380 Aufträge), LE gemischt.
-- -------------------------------------------------------------------------------------
with auf as (
  select a.manr, a.ainr, a.aart,
         case when exists (select 1 from hs.t620lp l
                            where l.manr = a.manr
                              and l.ainr = a.ainr
                              and l.satzart = 'KALK2')
              then 'J' else 'N' end as logical
    from hs.t081auk a
   where a.manr = 50
     and a.adat >= date '2025-07-01'
), pos as (
  select u.manr, u.aart, u.logical, u.ainr,
         case when p.lanr not in (66, 69)              then '9 anderes Lager'
              when nvl(trim(p.nega), '0') = '2'        then '3 ohne Lagerfuehrung'
              when nvl(trim(p.kzsl), '0') = '1'        then '4 Paket-Hauptartikel'
              when nvl(trim(p.kzsl), '0') = '2'        then '1 Komponente mit Lagerfuehrung (Blech)'
              else                                          '2 Einzelposition mit Lagerfuehrung'
         end as art
    from auf u
    join hs.t086aup p
      on p.manr = u.manr
     and p.ainr = u.ainr
)
select p.aart, t.text06, p.logical, p.art,
       count(distinct p.ainr) as auftraege,
       count(*)               as positionen
  from pos p
  left join hs.t012aart t
    on t.manr   = p.manr
   and t.aart06 = p.aart
 group by p.aart, t.text06, p.logical, p.art
 order by p.aart, p.logical, p.art;


-- -------------------------------------------------------------------------------------
-- 8) Einzelpositionen (Handelsware) in LM-Aufträgen in Lager 66/69 – betroffen von LAGERFORTSONDER.
--    DIP_MATERIAL enthält auch Handelsware → Blech = Chargen/Tafeln vorhanden.
--    Ergebnis 2026-11-26: bis auf 100902 alles echte Handelsware (~85 Positionen in 16 Monaten).
-- -------------------------------------------------------------------------------------
select p.lanr,
       p.arnr,
       min(t.arbe) as bezeichnung,
       (select count(*) from hs.t036meng m
         where m.manr = 50 and m.lanr = p.lanr and m.arnr = p.arnr
           and m.ltyp = 'T' and m.verf > 0)                       as chargen_mit_bestand,
       (select count(*) from dip_bleche b
          join dip_material dm on dm.oid = b.material
         where dm.artikelnr = p.arnr
           and b.gcrecord is null)                                as tafeln_in_logical,
       count(*)    as positionen,
       sum(p.meng) as menge
  from hs.t081auk a
  join hs.t086aup p
    on p.manr = a.manr
   and p.ainr = a.ainr
  left join hs.t051art t
    on t.manr = p.manr
   and t.arnr = p.arnr
 where a.manr = 50
   and a.aart = 'LM'
   and a.adat >= date '2025-07-01'
   and p.lanr in (66, 69)
   and nvl(trim(p.nega), '0') <> '2'
   and nvl(trim(p.kzsl), '0') not in ('1', '2')
   and p.arnr <> '295151'
 group by p.lanr, p.arnr
 order by sum(p.meng) desc;
