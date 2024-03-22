import logging
from os import environ

import functions_framework
from cloudevents.http import CloudEvent
from google.cloud.bigquery import (
    Client as BQClient,
    DatasetReference,
    Table,
    LoadJobConfig,
    SourceFormat,
    TimePartitioning,
)


@functions_framework.cloud_event  # type: ignore
def visits_to_bq(cloud_event: CloudEvent) -> None:
    # Loads CSV data (JSON rows) into a BigQuery table.
    data = cloud_event.data
    bucket_name: str = data["bucket"]
    blob_name: str = data["name"]

    # Initialize a BigQuery client
    bq_client = BQClient()

    # Define project ID and dataset name (replace with yours)
    table_id = environ["TABLE_NAME"]
    dataset_id = environ["DATASET"]
    partition_column = environ["PARTITION_COL"]

    # Load schema from JSON file
    # with open("schema.json", "r") as f:
    #    schema_json = json.load(f)
    # schema = [SchemaField.from_api_repr(field) for field in schema_json]

    # Create the BigQuery nodes_table if it doesn't exist
    dataset_ref = DatasetReference(bq_client.project, dataset_id).table(table_id)
    table_ref = Table(dataset_ref)

    # Set autodetect schema and source format
    table_ref.schema = []  # Empty schema for autodetection

    # Load data from Cloud Storage
    job_config = LoadJobConfig(
        source_format=SourceFormat.NEWLINE_DELIMITED_JSON,
        autodetect=True,
        time_partitioning=TimePartitioning(field=partition_column),
    )

    uri = f"gs://{bucket_name}/{blob_name}"
    load_job = bq_client.load_table_from_uri(uri, table_ref, job_config=job_config)

    load_job.result()  # Wait for the load job to complete

    logging.info("Loaded %s rows from '%s' to '%s'.", load_job.output_rows, uri, table_ref)
