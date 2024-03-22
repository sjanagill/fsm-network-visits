cd cloud_functions/adjlist_to_bq/ || return
if [ -f requirements.txt ]; then pip install -r requirements.txt --no-cache; fi
cd cloud_functions/visits_to_bq/ || return
if [ -f requirements.txt ]; then pip install -r requirements.txt --no-cache; fi
