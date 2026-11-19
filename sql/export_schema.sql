-- =============================================================================
-- Schema-Export fuer SHCWare (Oracle)
-- -----------------------------------------------------------------------------
-- Exportiert NUR Metadaten (keine Geschaeftsdaten) als CSV-Dateien nach ./schema/
--
-- Aufruf (SQL*Plus >= 12.2 oder SQLcl), im Repo-Hauptverzeichnis:
--   sqlplus user/passwort@db @sql/export_schema.sql SHCWARE_OWNER
--   sql     user/passwort@db @sql/export_schema.sql SHCWARE_OWNER
--
-- Parameter 1 = Schema-Owner der SHCWare-Tabellen (z.B. SHC, SHCWARE, ...).
-- Wenn du den Owner nicht kennst: zuerst sql/find_owner.sql ausfuehren.
-- =============================================================================

SET TERMOUT OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
SET PAGESIZE 0 EMBEDDED ON
SET LINESIZE 32767
SET LONG 100000
SET LONGCHUNKSIZE 100000
SET TRIMSPOOL ON
SET MARKUP CSV ON DELIMITER ; QUOTE ON

DEFINE owner = "&1"

-- -----------------------------------------------------------------------------
-- 1) Tabellen + Views mit Kommentar und (statistischer) Zeilenzahl
-- -----------------------------------------------------------------------------
SPOOL schema/tables.csv
SELECT o.object_type                         AS typ,
       o.object_name                         AS tabelle,
       t.num_rows                            AS zeilen_ca,
       TO_CHAR(t.last_analyzed,'YYYY-MM-DD') AS stats_vom,
       c.comments                            AS kommentar
  FROM all_objects o
  LEFT JOIN all_tables t
         ON t.owner = o.owner AND t.table_name = o.object_name
  LEFT JOIN all_tab_comments c
         ON c.owner = o.owner AND c.table_name = o.object_name
 WHERE o.owner = UPPER('&owner')
   AND o.object_type IN ('TABLE','VIEW')
   AND o.object_name NOT LIKE 'BIN$%'
 ORDER BY o.object_type, o.object_name;
SPOOL OFF

-- -----------------------------------------------------------------------------
-- 2) Spalten mit Datentyp, Nullable, Kommentar und Kardinalitaet
-- -----------------------------------------------------------------------------
SPOOL schema/columns.csv
SELECT c.table_name                AS tabelle,
       c.column_id                 AS pos,
       c.column_name               AS spalte,
       CASE
         WHEN c.data_type IN ('VARCHAR2','NVARCHAR2','CHAR','NCHAR')
           THEN c.data_type || '(' || c.char_length
                || DECODE(c.char_used,'C',' CHAR','') || ')'
         WHEN c.data_type = 'NUMBER' AND c.data_precision IS NOT NULL
           THEN 'NUMBER(' || c.data_precision || ',' || NVL(c.data_scale,0) || ')'
         WHEN c.data_type = 'RAW'
           THEN 'RAW(' || c.data_length || ')'
         ELSE c.data_type
       END                         AS datentyp,
       c.nullable                  AS nullable,
       c.num_distinct              AS distinct_ca,
       c.num_nulls                 AS nulls_ca,
       cc.comments                 AS kommentar
  FROM all_tab_columns c
  LEFT JOIN all_col_comments cc
         ON cc.owner = c.owner
        AND cc.table_name = c.table_name
        AND cc.column_name = c.column_name
 WHERE c.owner = UPPER('&owner')
   AND c.table_name NOT LIKE 'BIN$%'
 ORDER BY c.table_name, c.column_id;
SPOOL OFF

-- -----------------------------------------------------------------------------
-- 3) Primaer-, Unique- und Fremdschluessel (inkl. Spalten und Zieltabelle)
-- -----------------------------------------------------------------------------
SPOOL schema/constraints.csv
SELECT k.table_name                                         AS tabelle,
       k.constraint_name                                    AS constraint_name,
       DECODE(k.constraint_type,'P','PK','U','UK','R','FK') AS typ,
       (SELECT LISTAGG(cc.column_name, ',') WITHIN GROUP (ORDER BY cc.position)
          FROM all_cons_columns cc
         WHERE cc.owner = k.owner
           AND cc.constraint_name = k.constraint_name)     AS spalten,
       r.table_name                                         AS ref_tabelle,
       (SELECT LISTAGG(rc.column_name, ',') WITHIN GROUP (ORDER BY rc.position)
          FROM all_cons_columns rc
         WHERE rc.owner = r.owner
           AND rc.constraint_name = r.constraint_name)     AS ref_spalten,
       k.status                                             AS status
  FROM all_constraints k
  LEFT JOIN all_constraints r
         ON r.owner = k.r_owner AND r.constraint_name = k.r_constraint_name
 WHERE k.owner = UPPER('&owner')
   AND k.constraint_type IN ('P','U','R')
   AND k.table_name NOT LIKE 'BIN$%'
 ORDER BY k.table_name, k.constraint_type, k.constraint_name;
SPOOL OFF

-- -----------------------------------------------------------------------------
-- 4) Indizes (zeigen oft die "echten" Schluessel, wenn keine FKs existieren)
-- -----------------------------------------------------------------------------
SPOOL schema/indexes.csv
SELECT i.table_name   AS tabelle,
       i.index_name   AS index_name,
       i.uniqueness   AS eindeutig,
       (SELECT LISTAGG(ic.column_name, ',') WITHIN GROUP (ORDER BY ic.column_position)
          FROM all_ind_columns ic
         WHERE ic.index_owner = i.owner
           AND ic.index_name = i.index_name) AS spalten
  FROM all_indexes i
 WHERE i.table_owner = UPPER('&owner')
   AND i.table_name NOT LIKE 'BIN$%'
 ORDER BY i.table_name, i.index_name;
SPOOL OFF

-- -----------------------------------------------------------------------------
-- 5) View-Definitionen (zeigen, wie SHCWare selbst Tabellen verknuepft)
--    TEXT_VC ist auf 4000 Zeichen begrenzt (ab Oracle 12.1 vorhanden).
-- -----------------------------------------------------------------------------
SPOOL schema/views.csv
SELECT v.view_name AS view_name,
       v.text_vc   AS definition
  FROM all_views v
 WHERE v.owner = UPPER('&owner')
 ORDER BY v.view_name;
SPOOL OFF

SET MARKUP CSV OFF
SET TERMOUT ON
PROMPT Export fertig: schema/tables.csv, columns.csv, constraints.csv, indexes.csv, views.csv
EXIT
