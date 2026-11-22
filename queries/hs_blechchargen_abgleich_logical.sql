-- Zweck:    Blech-Chargen, die SHCWare (T036MENG, LTYP='T') noch mit Bestand führt, die in
--           LogiCAL (DIP_BLECHE) aber nicht als aktives Blech existieren
--           (fehlt / anderer Artikel / verbraucht / ausgebucht / gelöscht).
-- Mandant:  HS (MANR = 50). DIP_*-Tabellen (LogiCAL) unqualifiziert wie in den alten Skripten.
-- Geprüft:  2026-11-22 – 215 Zeilen (202 fehlt, 7 anderer Artikel, 2 verbraucht, 4 ausgebucht);
--           alle Artikel existieren in DIP_MATERIAL. 1.179 Chargen sind in LogiCAL aktiv
--           (davon 528 mit mehreren aktiven Blechen je Charge, vermutlich mehrere Tafeln).
--           IDENT-Gruppen der 1.394 Chargen mit Bestand: alle 1.179 aktiven haben das normale
--           Sternchen-Format (z.B. '**1378.00'); die 215 nicht aktiven: 179 'MAN' (von Hand
--           eingebucht, nie in LogiCAL), 22 Sternchen (echte Differenzen), 12 leer (LAGO 4-stellig,
--           8989/8990/98xx), 2 sonstige ('4711', '003153').
-- Join:     DIP_BLECHE.EXREF1 = T036MENG.LAGO, DIP_MATERIAL.OID = DIP_BLECHE.MATERIAL,
--           DIP_MATERIAL.ARTIKELNR = T036MENG.ARNR.
--           Aktiv in LogiCAL: GCRECORD IS NULL AND VERBRAUCHT = 0 AND AUSGEBUCHT = 0.
-- Hinweis:  T051ART über CTE ba (BETART) joinen – Unterabfrage im ON eines Outer Joins → ORA-01799.
with ba as (
    select betart from hs.t070betr where manr = 50
),
shc as (
    select tm.lanr, tm.lago, tm.ident, tm.arnr, tm.lgort,
           tm.kapaz, tm.verf, tm.dlzu, tm.dlab
      from hs.t036meng tm
     where tm.manr = 50
       and tm.ltyp = 'T'
       and nvl(tm.fr3, ' ') <> 'I'
       and tm.verf > 0
),
lc as (
    select s.lanr, s.lago, s.ident, s.arnr, s.lgort,
           s.kapaz, s.verf, s.dlzu, s.dlab,
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
     group by s.lanr, s.lago, s.ident, s.arnr, s.lgort,
              s.kapaz, s.verf, s.dlzu, s.dlab
)
select case
         when lc.anz_bleche = 0           then '1 fehlt in LogiCAL'
         when lc.anz_gleicher_artikel = 0 then '2 anderer Artikel'
         when lc.anz_verbraucht > 0       then '3 verbraucht'
         when lc.anz_ausgebucht > 0       then '4 ausgebucht'
         else                                  '5 geloescht/sonstiges'
       end as zustand_logical,
       case
         when trim(lc.ident) = 'MAN' then 'MAN'
         when lc.ident like '%*%'    then 'Sternchen'
         when trim(lc.ident) is null then 'leer'
         else                             'sonstige'
       end as ident_gruppe,
       lc.lanr, lc.lago as charge, lc.ident, lc.arnr, a.arbe,
       lc.lgort, lc.kapaz, lc.verf, lc.dlzu, lc.dlab,
       case when lc.anz_gleicher_artikel = 0 and lc.anz_bleche > 0
            then lc.logical_artikel end as logical_artikel,
       case when exists (select 1 from dip_material m2
                          where m2.artikelnr = lc.arnr)
            then 'J' else 'N' end as artikel_in_logical
  from lc
 cross join ba
  left join hs.t051art a
         on a.manr = ba.betart
        and a.arnr = lc.arnr
 where lc.anz_aktiv = 0
 order by 1, lc.arnr, lc.lago;
