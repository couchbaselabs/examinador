"""This file contains functions that define keywords needed for the cbbackupmgr cloud backwards compatibility tests"""

import json
import time
import os
import subprocess
from os.path import join
from typing import Dict, List, Optional
from datetime import datetime, timedelta, timezone

import sdk_utils
import utils

from robot.api.deco import keyword
from robot.api import logger
from robot.api.deco import library
from dateutil.parser import parse

ROBOT_AUTO_KEYWORDS = False

# Test configuration for backwards compatibility tests
# Structure:
#   TEST_VERSIONS = {
#       "version": {
#           "repo_name": [
#               {
#                   "type": "FULL|INCR",
#                   "buckets": {
#                       "bucket_name": {
#                           "mutations": <int>,      # number of mutations in this backup
#                           "total_items": <int>,    # total items after restoring up to this backup
#                           "key_prefix": <str>,     # optional, prefix for document keys
#                       },
#                       ...
#                   }
#               },
#               ...
#           ],
#           ...
#       },
#       ...
#   }

TEST_VERSIONS = {
    "v6.6": {
        "test_repo": [
            {
                "type": "FULL",
                "buckets": {
                    "bucket1": {
                        "mutations": 2000,
                        "total_items": 2000,
                        "key_prefix": "b1full",
                    },
                    "bucket2": {
                        "mutations": 100,
                        "total_items": 100,
                        "key_prefix": "b2full",
                    }
                }
            },
            {
                "type": "INCR",
                "buckets": {
                    "bucket1": {
                        "mutations": 0,
                        "total_items": 2000,
                        "key_prefix": "b1inc",
                    },
                    "bucket2": {
                        "mutations": 100,
                        "total_items": 200,
                        "key_prefix": "b2inc",
                    }
                }
            },
        ]
    },
    "v7.0": {
        "test_repo": [
            {
                "type": "FULL",
                "buckets": {
                    "bucket1": {
                        "mutations": 2000,
                        "total_items": 2000,
                        "key_prefix": "b1full",
                    },
                    "bucket2": {
                        "mutations": 100,
                        "total_items": 100,
                        "key_prefix": "b2full",
                    }
                }
            },
            {
                "type": "INCR",
                "buckets": {
                    "bucket1": {
                        "mutations": 0,
                        "total_items": 2000,
                        "key_prefix": "b1inc",
                    },
                    "bucket2": {
                        "mutations": 100,
                        "total_items": 200,
                        "key_prefix": "b2inc",
                    }
                }
            },
        ]
    },
    "v7.2": {
        "test_repo": [
            {
                "type": "FULL",
                "buckets": {
                    "bucket1": {
                        "mutations": 2000,
                        "total_items": 2000,
                        "key_prefix": "b1full",
                    },
                    "bucket2": {
                        "mutations": 100,
                        "total_items": 100,
                        "key_prefix": "b2full",
                    }
                }
            },
            {
                "type": "INCR",
                "buckets": {
                    "bucket1": {
                        "mutations": 0,
                        "total_items": 2000,
                        "key_prefix": "b1inc",
                    },
                    "bucket2": {
                        "mutations": 100,
                        "total_items": 200,
                        "key_prefix": "b2inc",
                    }
                }
            },
        ]
    },
    "v7.6": {
        "test_repo": [
            {
                "type": "FULL",
                "buckets": {
                    "bucket1": {
                        "mutations": 2000,
                        "total_items": 2000,
                        "key_prefix": "b1full",
                    },
                    "bucket2": {
                        "mutations": 100,
                        "total_items": 100,
                        "key_prefix": "b2full",
                    }
                }
            },
            {
                "type": "INCR",
                "buckets": {
                    "bucket1": {
                        "mutations": 0,
                        "total_items": 2000,
                        "key_prefix": "b1inc",
                    },
                    "bucket2": {
                        "mutations": 100,
                        "total_items": 200,
                        "key_prefix": "b2inc",
                    }
                }
            },
        ]
    },
    "v8.0": {
        "test_repo": [
            {
                "type": "FULL",
                "buckets": {
                    "bucket1": {
                        "mutations": 2000,
                        "total_items": 2000,
                        "key_prefix": "b1full",
                    },
                    "bucket2": {
                        "mutations": 100,
                        "total_items": 100,
                        "key_prefix": "b2full",
                    }
                }
            },
            {
                "type": "INCR",
                "buckets": {
                    "bucket1": {
                        "mutations": 0,
                        "total_items": 2000,
                        "key_prefix": "b1inc",
                    },
                    "bucket2": {
                        "mutations": 100,
                        "total_items": 200,
                        "key_prefix": "b2inc",
                    }
                }
            },
        ]
    }
}


@keyword
def get_test_versions():
    """Return the TEST_VERSIONS dictionary."""
    return TEST_VERSIONS


@keyword
def get_version_repos(version: str):
    """Return dictionary of repos for a given version."""
    return TEST_VERSIONS.get(version, {})


@keyword
def get_repo_backups(version: str, repo: str):
    """Return list of backups for a given version and repo."""
    return TEST_VERSIONS.get(version, {}).get(repo, [])


@keyword
def get_all_buckets_for_version(version: str):
    """Return a set of all bucket names used across all repos and backups for a version."""
    buckets = set()
    version_config = TEST_VERSIONS.get(version, {})
    for repo_name, backups in version_config.items():
        for backup in backups:
            buckets.update(backup.get("buckets", {}).keys())
    return list(buckets)


@keyword
def get_final_bucket_totals(version: str, repo: str):
    """Return dictionary of bucket names to their final total_items after all backups."""
    backups = TEST_VERSIONS.get(version, {}).get(repo, [])
    if not backups:
        return {}
    # Return the total_items from the last backup for each bucket
    last_backup = backups[-1]
    return {bucket: data["total_items"] for bucket, data in last_backup.get("buckets", {}).items()}


@keyword
def get_backup_bucket_totals(version: str, repo: str, backup_idx: int):
    """Return dictionary of bucket names to their total_items after restoring up to backup_idx."""
    backups = TEST_VERSIONS.get(version, {}).get(repo, [])
    if backup_idx >= len(backups) or backup_idx < 0:
        return {}
    backup = backups[backup_idx]
    return {bucket: data["total_items"] for bucket, data in backup.get("buckets", {}).items()}


@keyword
def get_bucket_key_prefix(version: str, repo: str, bucket: str):
    """Return the key prefix for a given bucket, or the bucket name if not specified."""
    backups = TEST_VERSIONS.get(version, {}).get(repo, [])
    if not backups:
        return bucket
    # Get key_prefix from first backup that has this bucket
    for backup in backups:
        bucket_data = backup.get("buckets", {}).get(bucket, {})
        if "key_prefix" in bucket_data:
            return bucket_data["key_prefix"]
    return bucket


@keyword
def get_prefix_counts_for_bucket(version: str, repo: str, bucket: str, up_to_backup_idx: int = -1):
    """Return a dictionary of prefix -> expected count for a bucket after restoring up to a specific backup.

    Args:
        version: The version string
        repo: The repository name
        bucket: The bucket name
        up_to_backup_idx: Restore up to this backup index (inclusive). -1 means all backups.

    Returns:
        Dictionary mapping key_prefix to expected document count for that prefix.
    """
    backups = TEST_VERSIONS.get(version, {}).get(repo, [])
    if not backups:
        return {}

    if up_to_backup_idx == -1:
        up_to_backup_idx = len(backups) - 1

    prefix_counts = {}
    for backup_idx in range(up_to_backup_idx + 1):
        backup = backups[backup_idx]
        bucket_data = backup.get("buckets", {}).get(bucket, {})
        if not bucket_data:
            continue

        prefix = bucket_data.get("key_prefix", bucket)
        mutations = bucket_data.get("mutations", 0)

        # For mutations, we're adding new documents with this prefix
        # The total_items reflects the cumulative state, but we track by prefix
        if prefix in prefix_counts:
            prefix_counts[prefix] += mutations
        else:
            # First backup with this prefix - use mutations (which equals total for first occurrence)
            prefix_counts[prefix] = mutations

    return prefix_counts


@keyword
def get_examine_key_for_version(version: str, repo: str):
    """Return a sample key that can be used for examine tests.
    Uses the first bucket's key prefix with a padded number format."""
    backups = TEST_VERSIONS.get(version, {}).get(repo, [])
    if not backups or not backups[0].get("buckets"):
        return None
    # Get first bucket and its key prefix
    first_bucket = list(backups[0]["buckets"].keys())[0]
    prefix = backups[0]["buckets"][first_bucket].get("key_prefix", first_bucket)
    # Return key in format used by legacy backups (e.g., b1full1)
    return f"{prefix}1"


@keyword
def get_examine_bucket_for_version(version: str, repo: str):
    """Return the bucket name to use for examine tests (first bucket in first backup)."""
    backups = TEST_VERSIONS.get(version, {}).get(repo, [])
    if not backups or not backups[0].get("buckets"):
        return None
    return list(backups[0]["buckets"].keys())[0]


