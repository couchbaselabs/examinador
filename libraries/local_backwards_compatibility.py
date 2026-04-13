"""This file contains functions that define keywords needed for the cbbackupmgr local backwards compatibility tests"""

from robot.api.deco import keyword
import backwards_compatibility as bc

ROBOT_AUTO_KEYWORDS = False

# Test configuration for local backwards compatibility tests
TEST_VERSIONS = {
    "v6.5.2": {
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
                    },
                    "bucket3": {
                        "mutations": 100,
                        "total_items": 100,
                        "key_prefix": "b3full",
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
                    },
                    "bucket3": {
                        "mutations": 2000,
                        "total_items": 2100,
                        "key_prefix": "b3inc",
                    }
                }
            },
        ],
        "test_repo_2": [
            {
                "type": "FULL",
                "complete": False,
                "buckets": {
                    "bucket1": {
                        "mutations": 500,
                        "total_items": 500,
                        "key_prefix": "r2b1full",
                    }
                }
            }
        ]
    }
}


@keyword
def get_test_versions():
    """Return the TEST_VERSIONS dictionary."""
    return bc.get_test_versions(TEST_VERSIONS)


@keyword
def get_version_repos(version: str):
    """Return list of repo names for a given version."""
    return bc.get_version_repos(TEST_VERSIONS, version)


@keyword
def get_version_repos_by_complete_status(version: str, complete: bool):
    """Return list of repo names filtered by complete status."""
    return bc.get_version_repos_by_complete_status(TEST_VERSIONS, version, complete)


@keyword
def get_repo_backups(version: str, repo: str):
    """Return list of backups for a given version and repo."""
    return bc.get_repo_backups(TEST_VERSIONS, version, repo)


@keyword
def get_all_buckets_for_version(version: str):
    """Return a set of all bucket names used across all repos and backups for a version."""
    return bc.get_all_buckets_for_version(TEST_VERSIONS, version)


@keyword
def get_final_bucket_totals(version: str, repo: str):
    """Return dictionary of bucket names to their final total_items after all backups."""
    return bc.get_final_bucket_totals(TEST_VERSIONS, version, repo)


@keyword
def get_backup_bucket_totals(version: str, repo: str, backup_idx: int):
    """Return dictionary of bucket names to their total_items after restoring up to backup_idx."""
    return bc.get_backup_bucket_totals(TEST_VERSIONS, version, repo, backup_idx)


@keyword
def get_bucket_key_prefix(version: str, repo: str, bucket: str):
    """Return the key prefix for a given bucket, or the bucket name if not specified."""
    return bc.get_bucket_key_prefix(TEST_VERSIONS, version, repo, bucket)


@keyword
def get_prefix_counts_for_bucket(version: str, repo: str, bucket: str, up_to_backup_idx: int = -1):
    """Return a dictionary of prefix -> expected count for a bucket after restoring up to a specific backup."""
    return bc.get_prefix_counts_for_bucket(TEST_VERSIONS, version, repo, bucket, up_to_backup_idx)


@keyword
def get_examine_key_for_version(version: str, repo: str):
    """Return a sample key that can be used for examine tests."""
    return bc.get_examine_key_for_version(TEST_VERSIONS, version, repo)


@keyword
def get_examine_bucket_for_version(version: str, repo: str):
    """Return the bucket name to use for examine tests (first bucket in first backup)."""
    return bc.get_examine_bucket_for_version(TEST_VERSIONS, version, repo)
