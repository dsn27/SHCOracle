-- Zweck:    Kundenstammdaten (Branche, E-Mail, E-Rechnung, Steuer-Nr., USt-IdNr., Leitweg-ID, ILN …)
--           für aktive Kunden mit Umsatz in GJ 24/25 oder 25/26, inkl. Umsatz je Geschäftsjahr.
-- Mandant:  SHC (KBS, MANR = 46)
-- Stand:    2026-11-22 – ENTWURF, noch nicht geprüft.
--           Geschäftsjahr SHC beginnt am 01.10. (T070BETR.ABWIJ = 22, siehe schema/NOTES.md).
-- Offen:    - Duplikate je Kunde prüfen (T042WKOM email1, T679ERK mehrere ART, T337INFP S10).
--           - T065SCH ohne BETR gejoint (BETR 0 = alle) – Duplikate möglich.
--           - Umsatz = Netto (Gutschriften verrechnet), Filter: > 0 in mind. einem GJ.
with ums as (
  select s.kdnr,
         sum(case when s.reda <  date '2025-10-01' then s.vkwert end) ums_2425,
         sum(case when s.reda >= date '2025-10-01' then s.vkwert end) ums_2526
  from shc.t096stat s
  where s.manr = 46
    and s.sart = 'V'
    and s.reda >= date '2024-10-01'
    and s.reda <  date '2026-10-01'
  group by s.kdnr
)
select a.adrn
,a.name
,a.fr3 Aktiv
,a.kdstat Branche
,d.text4 BranchenName
,b.nr email
,e.mail EmailRechnung
,a.refnr "Steuer-Nr."
,a.idnr "UST-IDNR"
,c.inhalt1 "RechnungKZ"
,a.leitwegid "LEITWEGID"
,a.land
,a.iln_rechnung
,a.iln_lieferant
,a.kuli LieferantNr
,a.verb Verband_KdNr
,e.art Versandart
,e.ausgabedateien AusgabeDat
,u.ums_2425 "Umsatz 24/25"
,u.ums_2526 "Umsatz 25/26"
from shc.t056ad a
join ums u on u.kdnr = a.adrn
left join shc.t042wkom b on b.manr = a.manr and b.sart = a.sart and b.adrn = a.adrn
                        and b.art = 'email1' and b.persnr = 0
left join shc.t337infp c on c.manr = a.manr and c.sart56 = a.sart and c.adrn = a.adrn
                        and c.infokz = 'S10'
left join shc.t065sch d  on d.sart = 'BRANCHE' and d.schl = a.kdstat
left join shc.t679erk e  on e.manr = a.manr and e.kdnr = a.adrn
where a.manr = 46
  and a.sart = 'K'
  and nvl(a.fr3, 0) <> 1
  and (u.ums_2425 > 0 or u.ums_2526 > 0)
order by a.adrn
