-- =============================================================================
-- Welcher Schema-Owner enthaelt die SHCWare-Tabellen?
-- Zeigt alle fuer dich sichtbaren Owner (ohne Oracle-Systemschemata)
-- mit Anzahl Tabellen und grob geschaetzter Gesamtzeilenzahl.
-- =============================================================================
SELECT t.owner,
       COUNT(*)         AS anzahl_tabellen,
       SUM(t.num_rows)  AS zeilen_ca
  FROM all_tables t
  JOIN all_users  u ON u.username = t.owner
 WHERE u.oracle_maintained = 'N'      -- ab Oracle 12c; bei 11g Zeile entfernen
 GROUP BY t.owner
 ORDER BY anzahl_tabellen DESC;
