import logging
from os import environ

import functions_framework
import networkx as nx
import pandas as pd
from cloudevents.http import CloudEvent
from google.cloud.bigquery import Client as BQClient, SchemaField, DatasetReference, Table, LoadJobConfig
from google.cloud.storage import Client as StorageClient


# Triggered by a change in a storage bucket
@functions_framework.cloud_event  # type: ignore
def adjlist_to_bq(cloud_event: CloudEvent) -> None:
    # Get file info from storage bucket trigger event
    data = cloud_event.data
    bucket_name: str = data["bucket"]
    blob_name: str = data["name"]
    logging.debug("Trigger for Bucket: %s and File: %s", bucket_name, blob_name)
    logging.debug("Created: %s, Updated: %s", data["timeCreated"], data["updated"])

    # Get new file data and parse nodes
    storage_client = StorageClient()
    bucket = storage_client.bucket(bucket_name=bucket_name)

    # Blob with your input file containing the adjacency list
    blob = bucket.blob(blob_name)
    data_string = blob.download_as_string()
    # convert bytes to unicode
    data_string = data_string.decode()

    # Add hops to nodes data
    lines = data_string.split("\n")
    node_graph = nx.parse_adjlist(lines)
    hop_list = []
    for node in node_graph.nodes():
        length = nx.single_source_dijkstra_path_length(node_graph, node)
        for item, hop in length.items():
            if hop > 0:
                hop_list.append([node, item, hop])

    # Initialize a BigQuery client
    bq_client = BQClient()

    # Define your dataset and table_ref information
    dataset_id = environ["DATASET"]
    table_id = environ["TABLE_NAME"]

    # Define the schema of the table_ref
    schema = [
        SchemaField("source_node", "STRING", mode="REQUIRED"),
        SchemaField("target_node", "STRING", mode="REQUIRED"),
        SchemaField("hops", "INT64", mode="REQUIRED"),
    ]

    # Create the BigQuery table_ref if it doesn't exist
    dataset_ref = DatasetReference(bq_client.project, dataset_id).table(table_id)
    table_ref = Table(dataset_ref, schema=schema)
    try:
        table_ref = bq_client.create_table(table_ref)  # API request
        logging.debug("Table %s created.", table_id)
    except Exception as e:  # pylint: disable=W0703
        logging.debug("Table %s already exists. Delete existing data %s", table_id, e)
        where_clause = " hops > 0"  # Delete rows older than 1 day
        delete_bigquery_rows(bq_client, table_ref.project, dataset_id, table_id, where_clause)

    dataset = pd.DataFrame(hop_list, columns=["source_node", "target_node", "hops"])

    job_config = LoadJobConfig(schema=schema)

    load_job = bq_client.load_table_from_dataframe(dataset, table_ref, job_config=job_config)

    load_job.result()  # Waits for the job to complete.

    logging.info("Loaded %s rows and %s columns to %s", len(hop_list), len(table_ref.schema), table_id)


def delete_bigquery_rows(
        client: BQClient, project_id: str, dataset_name: str, table_name: str, where_clause: str
) -> None:
    """Deletes rows from a BigQuery table based on a WHERE clause.

    Args:
      client: bigquery.Client()
      project_id (str): Your GCP project ID.
      dataset_name (str): Name of the dataset containing the table.
      table_name (str): Name of the table to delete rows from.
      where_clause (str): The WHERE clause to filter rows for deletion.
    """

    query = f"""DELETE FROM `{project_id}.{dataset_name}.{table_name}` WHERE {where_clause};"""

    job = client.query(query)
    job.result()  # Wait for the job to complete

    logging.info("Deleted rows matching '%s' from '%s'.", where_clause, table_name)
