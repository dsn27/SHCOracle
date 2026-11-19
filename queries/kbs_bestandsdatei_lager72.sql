-- Zweck:    Bestandsdatei für Kunden (KBS): Artikel mit GTIN, Bestand (max. 10),
--           offener Bestellmenge (max. 10) und voraussichtlichem Lieferdatum, Lager 72.
-- Mandant:  SHC (KBS, MANR = 46)
-- Geprüft:  2026-11-19 – Paketartikel (T051ART.KZSL = 'P') bekommen den Bestand jetzt aus den
--           Stücklisten-Komponenten (T060STL), wie in SHCWare-Artikelinfo; geprüft an
--           947207/947216/947407/947416 (6/6/1/1). Zeilenzahl alt 2767 → neu 2768.
-- Offen:    - Pakete: BEME/RUME = 0 → Lieferdatum bei Bestand 0 = heute + Vorlauf
--             (Bestellungen der Komponenten werden nicht berücksichtigt).
--           - EAN: mehrere EANs je Artikel sind in SHCWare vorgesehen → 12 Artikel stehen doppelt
--             in der Datei (je GTIN eine Zeile, gleicher Bestand). Entscheidung 2026-11-19: vorerst
--             so lassen. Alternative: CTE ean1 mit ROW_NUMBER() OVER (PARTITION BY manr, arnr
--             ORDER BY recnum DESC) rn … WHERE rn = 1 statt shc.t080ean (DESC = neueste EAN).
--           - Preis (T052PR) und Zusatzinfos A44/A38 (T336INFA): je Artikel eindeutig (geprüft).
--           - LIKE '26_%': '_' ist Platzhalter (= „beginnt mit 26, mind. 3 Zeichen“).
--           - BEWC = ' ' (laut Kommentar wie 'B') wird nicht ausgegeben.
with bestand as (
  -- normale Artikel: eigener Lagersatz
  select l.manr, l.arnr, l.verf, l.beme, l.rume
    from shc.t075lag l
    join shc.t051art a on a.manr = l.manr and a.arnr = l.arnr
   where l.lanr = 72
     and nvl(a.kzsl, ' ') <> 'P'
  union all
  -- Pakete: Anzahl kompletter Pakete aus den Komponenten
  select s.manr, s.harnr,
         min(trunc(greatest(nvl(l.verf, 0), 0) / s.menua)), 0, 0
    from shc.t060stl s
    join shc.t051art a on a.manr = s.manr and a.arnr = s.harnr
    left join shc.t075lag l on l.manr = s.manr and l.arnr = s.uarnr and l.lanr = 72
   where s.satzart = 'STUELI'
     and s.menua > 0
     and a.kzsl = 'P'
   group by s.manr, s.harnr
)
select Artikelnummer, GTIN, WG, arbe "Artikel Bez.1", arb1 "Artikel Bez. 2",
       case when Lieferdatum < sysdate then sysdate + 1 else Lieferdatum end Lieferdatum,
       Bestand, Beme
from
(
select a.arnr Artikelnummer, e.ean GTIN, a.wabe WG, a.arbe, a.arb1,
case
 when nvl(l.verf,0) > 0   -- Verfügbar
   then SHC_Util.GetArbeitstag(5)
 else
case
when nvl(l.beme,0) = 0 -- Nicht bestellt
then
  -- Bei diesen Lieferanten wird ohne Bestellung kein Datum ausgegeben
  case when a.krnr in ('71407','72492','72802','73009','73070','73281','73610','73978','73534','71461','74010','74747')
    then null
  else
   trunc(sysdate)
   + greatest(nvl(KBS_Helper.get_T337InfP_AsNumber('LIE','A21',a.krnr),0),30)
   + greatest(nvl(KBS_Helper.get_T337InfP_AsNumber('LIE','A20',a.krnr),0),15)
  end
else
case when nvl(l.rume,0) = 0 -- Bestellt und kein Rückstand
then
 case
   when KBS_Helper.get_Artikel_Lter2(a.arnr,a.krnr) is null
   then KBS_Helper.get_Artikel_BDat2(a.arnr)            -- ohne Produktionsdatum
      + greatest(nvl(KBS_Helper.get_T337InfP_AsNumber('LIE','A21',a.krnr),0),30)
      + greatest(nvl(KBS_Helper.get_T337InfP_AsNumber('LIE','A20',a.krnr),0),15)
   else KBS_Helper.get_Artikel_Lter2(a.arnr,a.krnr)     -- mit Produktionsdatum
 end
else
case when nvl(l.rume,0) < nvl(l.beme,0) -- Rückstand < Bestellmenge
then
 case
   when KBS_Helper.get_Artikel_Lter2(a.arnr,a.krnr) is null
   then KBS_Helper.get_Artikel_BDat2(a.arnr)
      + greatest(nvl(KBS_Helper.get_T337InfP_AsNumber('LIE','A21',a.krnr),0),30)
      + greatest(nvl(KBS_Helper.get_T337InfP_AsNumber('LIE','A20',a.krnr),0),15)
   else KBS_Helper.get_Artikel_Lter2(a.arnr,a.krnr)
 end
else -- Rückstand >= Bestellmenge
 trunc(sysdate)
 + greatest(nvl(KBS_Helper.get_T337InfP_AsNumber('LIE','A21',a.krnr),0),30)
 + greatest(nvl(KBS_Helper.get_T337InfP_AsNumber('LIE','A20',a.krnr),0),15)
end
end
end
end Lieferdatum,
case when nvl(l.verf,0) > 10 then 10 else nvl(l.verf,0) end Bestand,
case when nvl(l.verf,0) = 0 and a.bewc in ('A','S') then 1 else 0 end f1,
p.vpr1 Katalogpreis,
i2.inhalt1,
case
  when nvl(l.beme,0)-nvl(l.rume,0) > 10 then 10
  when nvl(l.beme,0)-nvl(l.rume,0) < 0 then 0
  else nvl(l.beme,0)-nvl(l.rume,0)
end Beme,
a.krnr
from shc.t051art a
left join bestand l on a.manr = l.manr and a.arnr = l.arnr
inner join shc.t052pr p on a.manr = p.manr and a.arnr = p.arnr
inner join shc.t336infa i on a.manr = i.manr and a.arnr = i.arnr
inner join shc.t336infa i2 on a.manr = i2.manr and a.arnr = i2.arnr
inner join shc.t080ean e on a.manr = e.manr and a.arnr = e.arnr
where a.manr = 46
and a.bewc in ('A','B','K','S')
and a.wabe between '01' and '68'
and p.kzpr = ' '
and p.waec = ' '
and i.infokz = 'A44'
and i.inhalt1 like '26_%'
and i2.infokz = 'A38'
and i2.inhalt1 in ('A','B','C','D')
)
where f1 = 0
and not (Lieferdatum is null
         and krnr in ('71407','72492','72802','73009','73070','73281','73610','73978','73534','71461','74010','74747'))
