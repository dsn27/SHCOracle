-- =====================================================================================
-- Zweck   : Kundenstamm aus einer Excel-Liste aktualisieren
--           T056AD.ILN_RECHNUNG, ILN_LIEFERANT, KULI, VERB  +  LNR (T337INFP, INFOKZ='LNR')
-- Mandant : SHC / KBS (MANR = 46) – für andere Mandanten Schema und MANR anpassen
-- Geprüft : 2026-11-19 (413 Kunden, 381 Zeilen T056AD geändert, 184 LNR: 4 geändert / 180 neu;
--           Anzeige im SHCWare danach korrekt)
--
-- ACHTUNG : Ändert Produktivdaten! Nur auf ausdrücklichen Wunsch, Schritt für Schritt,
--           AutoCommit in PL/SQL Developer AUS (Extras → Einstellungen → SQL-Fenster).
--           Datum 20261119 in den Tabellennamen jeweils durch das aktuelle Datum ersetzen.
--
-- Regel   : Leere Excel-Zelle = Wert löschen (→ NULL; bei MANR 46 sind leere Werte
--           überwiegend NULL, nur ~670 je Spalte ' ').
-- =====================================================================================


-- -------------------------------------------------------------------------------------
-- Schritt 1: Hilfstabelle (Spaltenreihenfolge = Excel), Daten per Strg+V ins Grid
--            (select t.*, t.rowid from ... → Schloss → einfügen → Haken → commit)
--            oder Tools → Text Importer (CSV).
--            In Excel ADRN und ILN-Spalten als TEXT formatieren (sonst 4,01235E+12)!
-- -------------------------------------------------------------------------------------
create table shc.tmp_kd_iln_20261119 (
   adrn           varchar2(8)
  ,iln_rechnung   varchar2(23)
  ,iln_lieferant  varchar2(23)
  ,kuli           varchar2(20)
  ,verb           varchar2(8)
  ,lnr            varchar2(1000)
);

-- Kontrolle: anzahl = versch_adrn (keine Duplikate), ILN-Länge 13
select count(*)                          anzahl
      ,count(distinct adrn)              versch_adrn
      ,max(length(iln_rechnung))         max_len_iln_re
      ,max(length(iln_lieferant))        max_len_iln_lief
  from shc.tmp_kd_iln_20261119;


-- -------------------------------------------------------------------------------------
-- Schritt 2: Vorschau / Prüfung (vor UND nach der Änderung ausführen)
--            nicht_gefunden muss 0 sein; nach der Änderung alle diff_* = 0
-- -------------------------------------------------------------------------------------
select count(*)                                                    anzahl_excel
      ,count(t.adrn)                                               gefunden_t056ad
      ,count(*) - count(t.adrn)                                    nicht_gefunden
      ,sum(case when nvl(trim(x.iln_rechnung) ,'#') <> nvl(trim(t.iln_rechnung) ,'#') then 1 else 0 end) diff_iln_re
      ,sum(case when nvl(trim(x.iln_lieferant),'#') <> nvl(trim(t.iln_lieferant),'#') then 1 else 0 end) diff_iln_lief
      ,sum(case when nvl(trim(x.kuli)         ,'#') <> nvl(trim(t.kuli)         ,'#') then 1 else 0 end) diff_kuli
      ,sum(case when nvl(trim(x.verb)         ,'#') <> nvl(trim(t.verb)         ,'#') then 1 else 0 end) diff_verb
      ,sum(case when nvl(trim(x.lnr)          ,'#') <> nvl(trim(u.inhalt1)      ,'#') then 1 else 0 end) diff_lnr
      ,sum(case when u.adrn is null and trim(x.lnr) is not null then 1 else 0 end)                    lnr_neu_anlegen
      ,sum(case when trim(x.iln_rechnung)  is null then 1 else 0 end) leer_iln_re
      ,sum(case when trim(x.iln_lieferant) is null then 1 else 0 end) leer_iln_lief
      ,sum(case when trim(x.kuli)          is null then 1 else 0 end) leer_kuli
      ,sum(case when trim(x.verb)          is null then 1 else 0 end) leer_verb
      ,sum(case when trim(x.lnr)           is null then 1 else 0 end) leer_lnr
  from shc.tmp_kd_iln_20261119 x
  left join shc.t056ad   t on t.manr = 46 and t.sart = 'K' and t.adrn = x.adrn
  left join shc.t337infp u on u.manr = 46 and u.adrn = x.adrn
                          and u.sart = 'KND' and u.sart56 = 'K' and u.infokz = 'LNR';


-- -------------------------------------------------------------------------------------
-- Schritt 3: Sicherung der betroffenen Zeilen
-- -------------------------------------------------------------------------------------
create table shc.t056ad_bak_20261119 as
select t.*
  from shc.t056ad t
 where t.manr = 46
   and t.sart = 'K'
   and t.adrn in (select adrn from shc.tmp_kd_iln_20261119);

create table shc.t337infp_bak_20261119 as
select u.*
  from shc.t337infp u
 where u.manr = 46
   and u.sart = 'KND'
   and u.sart56 = 'K'
   and u.infokz = 'LNR'
   and u.adrn in (select adrn from shc.tmp_kd_iln_20261119);


-- -------------------------------------------------------------------------------------
-- Schritt 4a: T056AD – nur Kunden mit mindestens einer Abweichung; leere Zelle → NULL
-- -------------------------------------------------------------------------------------
update shc.t056ad t
   set (t.iln_rechnung, t.iln_lieferant, t.kuli, t.verb) =
       (select trim(x.iln_rechnung), trim(x.iln_lieferant), trim(x.kuli), trim(x.verb)
          from shc.tmp_kd_iln_20261119 x
         where x.adrn = t.adrn)
 where t.manr = 46
   and t.sart = 'K'
   and exists (select 1
                 from shc.tmp_kd_iln_20261119 x
                where x.adrn = t.adrn
                  and (   nvl(trim(x.iln_rechnung) ,'#') <> nvl(trim(t.iln_rechnung) ,'#')
                       or nvl(trim(x.iln_lieferant),'#') <> nvl(trim(t.iln_lieferant),'#')
                       or nvl(trim(x.kuli)         ,'#') <> nvl(trim(t.kuli)         ,'#')
                       or nvl(trim(x.verb)         ,'#') <> nvl(trim(t.verb)         ,'#')));


-- -------------------------------------------------------------------------------------
-- Schritt 4b: LNR in T337INFP – ändern bzw. fehlende Zeile anlegen
--             (T337INFP hat nur PK-Spalten + INHALT1, keine weiteren Pflichtfelder)
--             Hinweis: leere LNR in Excel würden hier als NULL-Zeile angelegt bzw. auf
--             NULL gesetzt – bei Bedarf vorher filtern oder per DELETE behandeln.
-- -------------------------------------------------------------------------------------
merge into shc.t337infp u
using (select adrn, trim(lnr) lnr
         from shc.tmp_kd_iln_20261119) x
   on (    u.sart   = 'KND'
       and u.infokz = 'LNR'
       and u.manr   = 46
       and u.sart56 = 'K'
       and u.adrn   = x.adrn)
 when matched then
      update set u.inhalt1 = x.lnr
       where nvl(trim(u.inhalt1),'#') <> nvl(x.lnr,'#')
 when not matched then
      insert (sart, infokz, manr, sart56, adrn, inhalt1)
      values ('KND', 'LNR', 46, 'K', x.adrn, x.lnr);


-- -------------------------------------------------------------------------------------
-- Schritt 5: Schritt 2 erneut ausführen (selbes Fenster!) → alle diff_* = 0
--            dann:  commit;      sonst:  rollback;
--            Danach 1–2 Kunden im SHCWare kontrollieren.
--            Hilfstabelle danach löschen, Sicherungen einige Wochen behalten.
-- -------------------------------------------------------------------------------------
