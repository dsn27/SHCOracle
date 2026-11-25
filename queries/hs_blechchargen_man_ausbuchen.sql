-- =====================================================================================
-- Zweck   : Von Hand eingebuchte Blech-Chargen (T036MENG.IDENT = 'MAN'), die es in LogiCAL
--           nicht gibt (kein DIP_BLECHE mit EXREF1 = LAGO), in SHCWare ausbuchen (VERF = 0).
--           Danach Artikelbestand je betroffenem Artikel/Lager wie die Altchargen-Bereinigung vom
--           17.01.2026 (HS.UEBERNAHME_ALT_AUSBUCHEN, lokale Funktion Abgleich) auf die Summe der
--           Chargen setzen: T075LAG.VERF/EFFB + Berichtigungsbuchung T092EP (VORG 'B', EIPR 0).
--           Entscheidung Benutzer 2026-11-25: Variante B (wie Januar).
-- Mandant : HS (MANR = 50)
-- Freigabe: Kunde 2026-11-25 (Grund „Von Hand eingebucht, in LogiCAL nicht vorhanden“ aus
--           queries/hs_blechchargen_ausbuchliste_kunde.sql, Export vom 22.11.2026)
-- Status  : AUSGEFÜHRT 2026-11-25, commit durch Benutzer. Ergebnis: 179 Chargen auf 0
--           (28.579,86 kg), 179 × T036HIST mit PROG 'UEB_MANCHG_AUSBUCH', 135 Artikel/Lager
--           abgeglichen: T075LAG VERF 82.289,33 → 62.972,70, EFFB 85.935,34 → 66.618,71,
--           135 × T092EP VORG 'B' TEXT 'MANCHG AUSBUCH' (Summe −19.316,63). Kontrolle in SHCWare
--           an 100060 ok (−6.152,72 kg, Restbestand = Chargen 3.884,11 kg).
--           Sicherungen: HS.T036MENG_BAK_20261125, HS.T075LAG_BAK_20261125 (einige Wochen behalten);
--           Hilfstabelle HS.TMP_BLECH_MAN_20261125 nach ein paar Tagen löschen.
--           Wiederverwendung: Datum/Tabellennamen anpassen, Erwartungswerte (179/135) neu ermitteln.
--
-- Trigger : T036MENG_NULLTRIG → SHC_BESTAND.PROTOKOLL36 schreibt je geänderter Zeile einen
--           Satz in T036HIST (VERF_OLD/NEW, OSUSER, DATUM; PROG/VART leer, da nicht aus SHCWare).
--           Schlägt das fehl, bricht das UPDATE ab (RAISE). T036MENG_HOCHREGALLAGER legt ggf.
--           den Lagerort (T036LGORT) an – harmlos. Kein Trigger ändert T075LAG.
--
-- Methode : VERF = 0, FR3 und ANZAHL unverändert – so bucht auch die LogiCAL-Schnittstelle
--           (PROG UEB_DIP_CHARGENBEST) und die Altchargen-Bereinigung vom 17.01.2026
--           (PROG UEB_ALTCHG_AUSBUCH) aus (T036HIST geprüft 2026-11-25).
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
-- Ergebnis 2026-11-25: 179 Zeilen, 179 verschiedene Chargen (= Kunden-Export).


-- -------------------------------------------------------------------------------------
-- Schritt 2: Vorschau / Prüfung (vor UND nach dem UPDATE ausführen)
--   vorher : gefunden = noch_mit_bestand = 179, alle übrigen Zähler 0
--   nachher: schon_0 = verf_geaendert_seit_tmp = 179, noch_mit_bestand = 0
-- -------------------------------------------------------------------------------------
select count(*)                                                as anz_tmp,
       count(t.lago)                                           as gefunden,
       count(*) - count(t.lago)                                as nicht_gefunden,
       sum(case when t.verf > 0 then 1 else 0 end)             as noch_mit_bestand,
       sum(case when t.verf = 0 then 1 else 0 end)             as schon_0,
       sum(case when t.verf <> x.verf then 1 else 0 end)       as verf_geaendert_seit_tmp,
       sum(case when trim(t.ident) <> 'MAN' then 1 else 0 end) as ident_nicht_man,
       sum(case when nvl(t.fr3, ' ') <> nvl(x.fr3, ' ') then 1 else 0 end) as fr3_geaendert,
       count(d.exref1)                                         as jetzt_in_logical,
       sum(x.verf)                                             as summe_verf_tmp,
       sum(t.verf)                                             as summe_verf_aktuell
  from hs.tmp_blech_man_20261125 x
  left join hs.t036meng t
         on t.manr = x.manr
        and t.lanr = x.lanr
        and t.ltyp = x.ltyp
        and t.lago = x.lago
  left join (select distinct exref1 from dip_bleche) d
         on d.exref1 = x.lago;
-- Ergebnis 2026-11-25 vorher: 179 gefunden, 179 mit Bestand, alle übrigen 0, Summe 28.579,86 kg.


-- -------------------------------------------------------------------------------------
-- Schritt 3: Sicherung der betroffenen Zeilen (erwartet 179)
-- -------------------------------------------------------------------------------------
create table hs.t036meng_bak_20261125 as
select t.*
  from hs.t036meng t
 where (t.manr, t.lanr, t.ltyp, t.lago) in
       (select x.manr, x.lanr, x.ltyp, x.lago from hs.tmp_blech_man_20261125 x);

select count(*) as anz, sum(verf) as summe_verf from hs.t036meng_bak_20261125;

-- Zusätzlich Artikelbestand sichern (erwartet 135 Artikel/Lager):
create table hs.t075lag_bak_20261125 as
select l.*
  from hs.t075lag l
 where l.manr = 50
   and (l.lanr, l.arnr) in
       (select distinct x.lanr, x.arnr from hs.tmp_blech_man_20261125 x);

select count(*) as anz, sum(verf) as summe_verf, sum(effb) as summe_effb
  from hs.t075lag_bak_20261125;
-- Ergebnis 2026-11-25: T036MENG_BAK 179 / 28.579,86; T075LAG_BAK 135 / VERF 82.289,33 / EFFB 85.935,34


-- -------------------------------------------------------------------------------------
-- Schritt 4: Ausbuchen + Abgleich (PL/SQL-Block, AutoCommit AUS!)
--   - Set_Infos VOR jedem UPDATE (PROTOKOLL36 setzt die Globals nach jedem Satz zurück)
--   - Summe_t036/Abgleich 1:1 aus HS.UEBERNAHME_ALT_AUSBUCHEN, aber OHNE "when others"
--     → jeder Fehler bricht den ganzen Block ab, Oracle macht alle Änderungen des Blocks rückgängig
--   - Der Block macht KEIN commit.
-- -------------------------------------------------------------------------------------
declare
  c_prog  constant varchar2(50) := 'UEB_MANCHG_AUSBUCH';
  c_text  constant varchar2(20) := 'MANCHG AUSBUCH';
  cnt_chg pls_integer := 0;
  cnt_art pls_integer := 0;

  function summe_t036(inManr in number, inLanr in number, inArnr in varchar2) return number is
    nBetlag hs.t036meng.lanr%type;
    nBetArt hs.t036meng.manr%type;
    cursor ct051art is
      select thhgw, berkz, txmevk, formatv, katr
        from hs.t051art
       where manr = nBetArt
         and arnr = inArnr;
    xT051Art ct051art%rowtype;
    cursor ct036meng is
      select a.anzahl, a.kapaz, a.verf, b.breite, b.dicke, a.kzlv, a.ltyp
        from hs.t036meng a, hs.t636meng b
       where a.manr = nBetlag
         and a.arnr = inArnr
         and a.lanr = inLanr
         and a.manr = b.manr(+)
         and a.arnr = b.arnr(+)
         and a.lanr = b.lanr(+)
         and a.lago = b.zunr(+)
         and a.verf > 0
         and nvl(a.fr3, ' ') != 'I'
         and nvl(a.ltyp, ' ') in ('T', 'K');
    l_menge number := 0;
    r_summe number;
    l_berkz varchar2(1);
  begin
    nBetArt := hs.shc_util.get_betart(inManr);
    nBetlag := hs.shc_util.get_betlag(inManr, inLanr);
    open ct051art;
    fetch ct051art into xT051Art;
    close ct051art;
    if xT051Art.formatv = 'J' then
      l_berkz := '4';
    else
      l_berkz := xT051Art.berkz;
    end if;
    for x in ct036meng loop
      r_summe := null;
      if l_berkz = '1' then
        if x.kzlv = 'V' then r_summe := x.verf * xT051Art.thhgw;
        else                 r_summe := x.anzahl * x.kapaz * xT051Art.thhgw;
        end if;
      elsif l_berkz = '2' then
        if x.kzlv = 'V' then r_summe := x.verf;
        else                 r_summe := x.anzahl * x.kapaz;
        end if;
      elsif l_berkz in ('3', '4') then
        r_summe := x.verf;
      elsif l_berkz = '5' then
        if upper(rtrim(xT051Art.txmevk)) = 'QM' then
          r_summe := x.verf * (x.breite / 1000);
        else
          r_summe := (x.dicke * x.breite * x.kapaz / 1000) * xT051Art.thhgw * x.anzahl;
        end if;
      end if;
      if x.ltyp = 'K' then
        r_summe := x.verf;
      end if;
      l_menge := nvl(l_menge, 0) + nvl(r_summe, 0);
    end loop;
    return nvl(hs.shc_stahl.stahl_runden(l_menge, nBetArt, inArnr), 0);
  end summe_t036;

  procedure abgleich(inManr in number, inLanr in number, inArnr in varchar2) is
    nBetlag hs.t036meng.lanr%type;
    cursor ct092ep is
      select max(epnr) from hs.t092ep
       where manr = nBetlag and arnr = inArnr and lanr = inLanr;
    cursor ct075lag is
      select rowid rid, effb, verf from hs.t075lag
       where manr = nBetlag and lanr = inLanr and arnr = inArnr
         for update;
    x75          ct075lag%rowtype;
    l_anz        pls_integer;
    l_summe_verf number;
    l_effb_neu   number;
    l_buch_menge number;
    l_maxepnr    number;
  begin
    nBetlag := hs.shc_util.get_betlag(inManr, inLanr);
    l_summe_verf := summe_t036(inManr, inLanr, inArnr);
    hs.shc_bestand.set_infos(c_prog, 'K', inManr, 0, 0, 0);

    select count(*) into l_anz from hs.t075lag
     where manr = nBetlag and lanr = inLanr and arnr = inArnr;
    if l_anz = 0 then
      insert into hs.t075lag (manr, lanr, arnr) values (nBetlag, inLanr, inArnr);
    end if;

    open ct075lag;
    fetch ct075lag into x75;
    close ct075lag;

    l_effb_neu   := nvl(l_summe_verf, 0) + (nvl(x75.effb, 0) - nvl(x75.verf, 0));
    l_buch_menge := nvl(l_summe_verf, 0) - nvl(x75.verf, 0);

    open ct092ep;
    fetch ct092ep into l_maxepnr;
    close ct092ep;
    l_maxepnr := nvl(l_maxepnr, 0) + 1;

    update hs.t075lag
       set verf  = l_summe_verf,
           effb  = l_effb_neu,
           epzae = l_maxepnr
     where rowid = x75.rid;

    insert into hs.t092ep
      (manr, arnr, lanr, epnr, vorg, datwz, blnr, beda, reda, menge, eipr, text)
    values
      (nBetlag, inArnr, inLanr, l_maxepnr,
       'B', trunc(sysdate), l_maxepnr, trunc(sysdate), trunc(sysdate),
       l_buch_menge, 0, c_text);
  end abgleich;

begin
  -- 1) Chargen ausbuchen (VERF = 0; FR3/ANZAHL unverändert)
  for t in (select manr, lanr, ltyp, lago from hs.tmp_blech_man_20261125) loop
    hs.shc_bestand.set_infos(c_prog, 'DP', 50, null, null, null);
    update hs.t036meng
       set verf = 0
     where manr = t.manr
       and lanr = t.lanr
       and ltyp = t.ltyp
       and lago = t.lago
       and verf > 0;
    cnt_chg := cnt_chg + sql%rowcount;
  end loop;

  if cnt_chg <> 179 then
    raise_application_error(-20001, 'Erwartet 179 Chargen, geändert: ' || cnt_chg);
  end if;

  -- 2) Artikelbestand je Artikel/Lager auf Chargensumme setzen
  for a in (select distinct lanr, arnr from hs.tmp_blech_man_20261125) loop
    abgleich(50, a.lanr, a.arnr);
    cnt_art := cnt_art + 1;
  end loop;

  dbms_output.put_line('Chargen ausgebucht: ' || cnt_chg || ' / Artikel abgeglichen: ' || cnt_art);
end;
/


-- -------------------------------------------------------------------------------------
-- Schritt 5: Prüfung im SELBEN Fenster (vor dem commit)
--   erwartet: T036MENG auf 0 = 179 / 28.579,86; T036HIST = 179 / 28.579,86;
--             T075LAG VERF ≈ 82.289,33 − 19.316,63 = 62.972,70; EFFB ≈ 85.935,34 − 19.316,63 = 66.618,71;
--             T092EP = 135 / ≈ −19.316,63; T075LAG <> Chargensumme = 0
--   dann: commit;   sonst: rollback;
-- -------------------------------------------------------------------------------------
select '1 T036MENG auf 0' as pruefung, count(*) as anz, sum(b.verf) as menge
  from hs.t036meng_bak_20261125 b
  join hs.t036meng t
    on t.manr = b.manr and t.lanr = b.lanr and t.ltyp = b.ltyp and t.lago = b.lago
 where t.verf = 0
union all
select '2 T036HIST mit PROG', count(*), sum(h.verf_old)
  from hs.t036hist h
 where h.manr = 50
   and h.prog = 'UEB_MANCHG_AUSBUCH'
   and h.datum >= trunc(sysdate)
union all
select '3 T075LAG VERF neu', count(*), sum(l.verf)
  from hs.t075lag_bak_20261125 b
  join hs.t075lag l on l.manr = b.manr and l.lanr = b.lanr and l.arnr = b.arnr
union all
select '4 T075LAG EFFB neu', count(*), sum(l.effb)
  from hs.t075lag_bak_20261125 b
  join hs.t075lag l on l.manr = b.manr and l.lanr = b.lanr and l.arnr = b.arnr
union all
select '5 T092EP Berichtigung', count(*), sum(e.menge)
  from hs.t092ep e
 where e.manr = 50
   and e.vorg = 'B'
   and e.text = 'MANCHG AUSBUCH'
   and e.datwz = trunc(sysdate)
union all
select '6 T075LAG <> Chargensumme', count(*), null
  from hs.t075lag_bak_20261125 b
  join hs.t075lag l on l.manr = b.manr and l.lanr = b.lanr and l.arnr = b.arnr
  left join (select lanr, arnr, sum(verf) as s
               from hs.t036meng
              where manr = 50
                and ltyp in ('T', 'K')
                and verf > 0
                and nvl(fr3, ' ') <> 'I'
              group by lanr, arnr) c
         on c.lanr = l.lanr and c.arnr = l.arnr
 where abs(nvl(l.verf, 0) - nvl(c.s, 0)) > 0.01
order by 1;
