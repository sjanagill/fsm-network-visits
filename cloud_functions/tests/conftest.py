import os
from typing import Any
from unittest.mock import patch

import pytest

TEST_PROJECT = "test_project"
TEST_DATASET = "test_dataset_id"
TEST_TABLE = "test_table_name"


@pytest.fixture(scope="session", autouse=True)
def mock_env_vars_for_config() -> Any:
    mock_env_vars = {"GCP_PROJECT": TEST_PROJECT, "DATASET": TEST_DATASET, "TABLE_NAME": TEST_TABLE}
    with patch.dict(os.environ, mock_env_vars):
        yield
