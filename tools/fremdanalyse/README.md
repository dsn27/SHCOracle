# Analyse fremder SQL-Sammlungen

Reine Python-Skripte (nur Standardbibliothek), regex-basiert. Fremde Dateien nur im
Scratchpad entpacken, **nie ins Repo**; ins Repo kommen nur abgeleitete Erkenntnisse.

```bash
python3 -I 1_uebersicht.py   <entpackter_ordner> <repo> <scratch>/files.pkl   # dedupliziert, Tabellenabgleich
python3 -I 2_joins.py        <scratch>/files.pkl <repo> <scratch>/joins.json  # Join-Muster
python3 -I 3_filter_summen.py <scratch>/files.pkl <repo> <scratch>/filters.json # Filterwerte, SUM-Formeln
```
Danach `schema/joins.csv` aus `joins.json` neu erzeugen bzw. ergänzen (siehe Git-Historie).
