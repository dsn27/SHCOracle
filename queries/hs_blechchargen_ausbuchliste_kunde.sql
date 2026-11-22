-- Zweck:    Kundenliste der Blech-Chargen, die in SHCWare ausgebucht werden sollen
--           (Bestand in T036MENG, aber kein aktives Blech in LogiCAL) – mit Klartext-Grund.
--           Gleiche Auswahl wie queries/hs_blechchargen_abgleich_logical.sql.
-- Mandant:  HS (MANR = 50). DIP_*-Tabellen (LogiCAL) unqualifiziert.
-- Geprüft:  2026-11-22 – erwartet 215 Zeilen. V036CH ist je LANR/LAGO eindeutig (geprüft).
with ba as (
    select betart from hs.t070betr where manr = 50
),
shc as (
    select tm.lanr, tm.lago, tm.ident, tm.arnr, tm.lgort, tm.verf
      from hs.t036meng tm
     where tm.manr = 50
       and tm.ltyp = 'T'
       and nvl(tm.fr3, ' ') <> 'I'
       and tm.verf > 0
),
lc as (
    select s.lanr, s.lago, s.ident, s.arnr, s.lgort, s.verf,
           count(b.oid) as anz_bleche,
           sum(case when m.artikelnr = s.arnr then 1 else 0 end) as anz_gleicher_artikel,
           sum(case when m.artikelnr = s.arnr and b.gcrecord is null
                     and nvl(b.verbraucht, 0) = 0 and nvl(b.ausgebucht, 0) = 0
                    then 1 else 0 end) as anz_aktiv,
           sum(case when m.artikelnr = s.arnr and b.gcrecord is null
                     and nvl(b.verbraucht, 0) <> 0 then 1 else 0 end) as anz_verbraucht,
           sum(case when m.artikelnr = s.arnr and b.gcrecord is null
                     and nvl(b.ausgebucht, 0) <> 0 then 1 else 0 end) as anz_ausgebucht,
           max(m.artikelnr) as logical_artikel
      from shc s
      left join dip_bleche   b on b.exref1 = s.lago
      left join dip_material m on m.oid    = b.material
     group by s.lanr, s.lago, s.ident, s.arnr, s.lgort, s.verf
)
select lc.lanr                as lager,
       lc.arnr                as artikel,
       a.arbe                 as bezeichnung,
       lc.lago                as zugangsnr,
       v.charge               as charge,
       trunc(v.lsda)          as eingangsdatum,
       v.liefname             as lieferant,
       lc.lgort               as lagerort,
       lc.verf                as menge,
       a.txmevk               as einheit,
       case
         when trim(lc.ident) = 'MAN' and lc.anz_bleche = 0
              then 'Von Hand eingebucht, in LogiCAL nicht vorhanden'
         when lc.anz_bleche = 0
              then 'In LogiCAL nicht (mehr) vorhanden'
         when lc.anz_gleicher_artikel = 0
              then 'In LogiCAL unter anderem Artikel ' || lc.logical_artikel
         when lc.anz_verbraucht > 0
              then 'In LogiCAL verbraucht'
         when lc.anz_ausgebucht > 0
              then 'In LogiCAL ausgebucht'
         else      'In LogiCAL gelöscht'
       end                    as grund
  from lc
 cross join ba
  left join hs.t051art a
         on a.manr = ba.betart
        and a.arnr = lc.arnr
  left join hs.v036ch v
         on v.manr = 50
        and v.ltyp = 'T'
        and v.lanr = lc.lanr
        and v.lago = lc.lago
 where lc.anz_aktiv = 0
 order by lc.lanr, lc.arnr, lc.lago;
