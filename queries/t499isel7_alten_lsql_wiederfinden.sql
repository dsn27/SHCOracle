-- Zweck:    Überschriebenen Text in T499ISEL7.LSQL (Abfrage für den automatischen Datenversand)
--           wiederfinden. Lässt sich auf andere Spalten/Tabellen übertragen.
-- Mandant:  SHC (T499ISEL7 hat kein MANR; Schema je Mandant anpassen)
-- Geprüft:  2026-11-22 – Schritte 1–4 ausgeführt: Flashback nach 2 Tagen nicht mehr möglich
--           (ORA-01555), alter Text aber in V$SQL gefunden. Schritt 5 (Sicherung in Hilfstabelle)
--           noch nicht ausgeführt.
-- Hinweis:  Der Versandjob (ca. 05:00) führt LSQL nicht unverändert aus, sondern eingebettet:
--           'Begin DECLARE Cursor c1 is <LSQL> …', 'select count(*) from (<LSQL>)',
--           'select * from (<LSQL>)' und eine großgeschriebene Fassung ohne Zeilenumbrüche.
--           Am besten eignet sich 'select * from (…)': Hülle entfernen = Originaltext.

-- 1) Flashback: geht nur, solange die Undo-Daten noch da sind (meist nur Stunden).
SELECT ausart, bezeichnung, lastrun, lsql
  FROM shc.t499isel7 AS OF TIMESTAMP TO_TIMESTAMP('20.11.2026 06:00', 'DD.MM.YYYY HH24:MI')
 WHERE ausart = '<AUSART>';

-- 2) Kandidaten im Shared Pool: Merkmal des alten Textes + letzter Lauf vor der Änderung;
--    Texte, die einem aktuellen LSQL gleichen, ausschließen.
SELECT s.sql_id,
       s.last_active_time,
       s.executions,
       DBMS_LOB.GETLENGTH(s.sql_fulltext)      AS laenge,
       DBMS_LOB.SUBSTR(s.sql_fulltext, 200, 1) AS anfang,
       s.sql_fulltext
  FROM v$sql s
 WHERE UPPER(s.sql_fulltext) LIKE '%<MERKMAL, z.B. BEME2>%'
   AND UPPER(s.sql_fulltext) NOT LIKE '%V$SQL%'
   AND s.last_active_time BETWEEN TO_DATE('19.11.2026 00:00', 'DD.MM.YYYY HH24:MI')
                              AND TO_DATE('20.11.2026 10:00', 'DD.MM.YYYY HH24:MI')
   AND NOT EXISTS (SELECT 1
                     FROM shc.t499isel7 i
                    WHERE DBMS_LOB.COMPARE(i.lsql, s.sql_fulltext) = 0)
 ORDER BY s.last_active_time DESC;

-- 3) Kandidaten den aktuellen Ausgabearten zuordnen (ohne Leerzeichen/Zeilenumbrüche vergleichen).
--    Ein Kandidat, der in keinem aktuellen LSQL steckt, ist der verlorene Text.
WITH kand AS (
  SELECT sql_id,
         UPPER(REGEXP_REPLACE(sql_fulltext, '\s', '')) AS txt
    FROM v$sqlarea
   WHERE sql_id IN ('<SQL_ID_1>', '<SQL_ID_2>')
),
akt AS (
  SELECT ausart, periode, lastrun,
         DBMS_LOB.GETLENGTH(lsql) AS laenge,
         DBMS_LOB.SUBSTR(RTRIM(UPPER(REGEXP_REPLACE(lsql, '\s', '')), ';'), 4000, 1) AS txt
    FROM shc.t499isel7
   WHERE UPPER(lsql) LIKE '%<MERKMAL>%'
)
SELECT a.ausart, a.periode, a.lastrun, a.laenge, k.sql_id,
       CASE WHEN DBMS_LOB.INSTR(k.txt, a.txt) > 0 THEN 'ja' END AS steckt_drin
  FROM akt a
 CROSS JOIN kand k
 ORDER BY a.ausart, k.sql_id;

-- 4) Vollen Text ansehen.
SELECT sql_id, last_active_time, sql_fulltext
  FROM v$sqlarea
 WHERE sql_id = '<SQL_ID>';

-- 5) Sofort dauerhaft sichern (Shared Pool wird geleert), Hülle 'select * from ( … )' entfernen.
CREATE TABLE shc.tmp_t499isel7_alt AS
SELECT CAST('<AUSART>' AS VARCHAR2(30)) AS ausart,
       sql_id,
       last_active_time,
       sql_fulltext AS sql_original,
       REGEXP_REPLACE(sql_fulltext, '^\s*select \* from \((.*)\)\s*$', '\1', 1, 1, 'in') AS lsql_neu
  FROM v$sqlarea
 WHERE sql_id = '<SQL_ID>';

SELECT ausart,
       DBMS_LOB.GETLENGTH(sql_original) AS laenge_original,
       DBMS_LOB.GETLENGTH(lsql_neu)     AS laenge_neu,
       DBMS_LOB.SUBSTR(lsql_neu, 60, 1) AS anfang,
       DBMS_LOB.SUBSTR(lsql_neu, 80, DBMS_LOB.GETLENGTH(lsql_neu) - 79) AS ende
  FROM shc.tmp_t499isel7_alt;

-- 6) Zurückschreiben nur nach Freigabe und abgesichert (Ablauf wie in
--    queries/t056ad_excel_abgleich_kunden.sql: Sicherung T499ISEL7_BAK_YYYYMMDD → UPDATE ohne
--    AutoCommit → Prüfung → COMMIT).
