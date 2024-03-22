import unittest
from pathlib import Path
from typing import Dict, Any
from unittest.mock import patch, MagicMock

from cloudevents.http import CloudEvent
from google.cloud.storage import Bucket
from google.cloud.storage.blob import Blob

from cloud_functions.adjlist_to_bq.main import adjlist_to_bq
from cloud_functions.tests.conftest import TEST_DATASET, TEST_PROJECT


class TestStorageToBQ(unittest.TestCase):
    @patch("cloud_functions.adjlist_to_bq.main.StorageClient")
    @patch("cloud_functions.adjlist_to_bq.main.BQClient")
    @patch("cloud_functions.adjlist_to_bq.main.DatasetReference")
    def test_adlist_to_bq_success(self, mock_dataset_ref, mock_bq_client, mock_storage_client):
        payload: Dict[str, Any] = {
            "name": "data/network.txt",
            "bucket": "some-bucket",
            "contentType": "application/json",
            "metageneration": "1",
            "timeCreated": "2020-04-23T07:38:57.230Z",
            "updated": "2020-04-23T07:38:57.230Z",
        }
        # Mock the GCS client and bucket
        # mock_bucket = mock_storage_client.bucket.return_value
        mock_bucket = MagicMock(autospec=Bucket)
        mock_storage_client().bucket.return_value = mock_bucket

        # Mock the CSV file content
        # csv_data = b"NODE1 NODE3 NODE5 NODE8\nNODE3 NODE5 NODE6\nNODE5 NODE8\nNODE6\nNODE8"
        with open(Path(__file__).parent.joinpath("data/network.txt").as_posix(), "r", encoding="utf=8") as input_csv:
            csv_data = input_csv.read()
            # Mock the Blob object
            mock_blob = MagicMock(autospec=Blob)
            mock_bucket.blob.return_value = mock_blob

            # Mock download_as_string method
            mock_blob.download_as_string.return_value = bytes(csv_data, "utf-8")

            # Mock the BigQuery client
            mock_client = mock_bq_client.return_value
            mock_client.project = TEST_PROJECT

            payload_mock = MagicMock(autospec=CloudEvent)
            payload_mock.data = payload

            # Call the function
            adjlist_to_bq(payload_mock)

            # Assert that GCS client and bucket methods were called
            mock_storage_client.called = 2
            mock_bucket.blob.assert_called_once_with(payload["name"])
            mock_blob.download_as_string.assert_called_once()

            # Assert that BQ client and methods were called
            mock_bq_client.called = 2
            mock_dataset_ref.assert_called_once_with(TEST_PROJECT, TEST_DATASET)
            mock_client.load_table_from_dataframe.assert_called_once()
