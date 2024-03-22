# Code repository for Cloud Function 'adjlist_to_bq'

This function is called from the Eventarc trigger set on bucket which will receive adjacency list of nodes in space
separated CSV format.

- Called on a Eventarc trigger
- Load file from storage and transform to add hops
- Check if node bq table exists, otherwise create using provided schema.
- If it exists then delete existing data and load the new file.

![FMS_Network_Visits](../../FMS_Network_Visits.jpg "FMS_Network_Visits")

## Repository

This repository contains the code for the Code repository for Cloud Function 'adjlist_to_bq'