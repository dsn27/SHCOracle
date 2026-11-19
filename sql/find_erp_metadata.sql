-- =============================================================================
-- Sucht nach SHCWare-eigenen Metadaten (Data Dictionary des ERP)
-- -----------------------------------------------------------------------------
-- Viele ERP-Systeme pflegen KEINE Oracle-Kommentare, sondern speichern
-- Tabellen-/Feldbeschreibungen in eigenen Tabellen. Diese Abfrage listet
-- Kandidaten anhand typischer Namen. Gefundene Tabellen bitte mit
--   SELECT * FROM <owner>.<tabelle> FETCH FIRST 20 ROWS ONLY;
-- ansehen und - wenn es Beschreibungen sind - komplett als CSV exportieren.
--
-- Aufruf: @sql/find_erp_metadata.sql SHCWARE_OWNER
-- =============================================================================
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 200
COLUMN table_name FORMAT A40
COLUMN treffer    FORMAT A60

DEFINE owner = "&1"

-- Tabellen mit "verdaechtigen" Namen
SELECT t.table_name, t.num_rows, 'Tabellenname' AS treffer
  FROM all_tables t
 WHERE t.owner = UPPER('&owner')
   AND REGEXP_LIKE(t.table_name,
       'DICT|META|FELD|FIELD|COLUMN|SPALTE|TABELLE|TABLE|BESCHR|DESCR|TEXT|LABEL|CAPTION|MASK|SCHEMA|DEFIN|SPRACH|LANG|UEBERS|TRANSL',
       'i')
UNION ALL
-- Tabellen, die Spalten wie TABNAME + FELDNAME enthalten (typisch fuer Feldkataloge)
SELECT c.table_name, MAX(t.num_rows), 'Spalten: ' || LISTAGG(c.column_name, ',') WITHIN GROUP (ORDER BY c.column_name)
  FROM all_tab_columns c
  JOIN all_tables t ON t.owner = c.owner AND t.table_name = c.table_name
 WHERE c.owner = UPPER('&owner')
   AND REGEXP_LIKE(c.column_name, 'TAB(ELLE|LE)?_?NAME|FELD_?NAME|FIELD_?NAME|COL(UMN)?_?NAME|SPALTEN_?NAME', 'i')
 GROUP BY c.table_name
ORDER BY 1;
