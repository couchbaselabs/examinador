"""This file contains functions that define keywords needed for the cbbackupmgr testing."""

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


@library
class cbm_utils:
    """Keywords needed for cbbackupmgr testing."""
    ROBOT_LIBRARY_SCOPE = 'SUITE'


    def __init__(self, bin_path: str, archive: str, obj_region: str = "us-east-1",
                 obj_access_key_id: str = "test", obj_secret_access_key: str = "test",
                 obj_endpoint: str = "http://localhost:4566"):
        self.BIN_PATH = bin_path
        self.archive = archive
        self.obj_region = obj_region
        self.obj_access_key_id = obj_access_key_id
        self.obj_secret_access_key = obj_secret_access_key
        self.obj_endpoint = obj_endpoint


    @keyword(types=[str, str, str, str, str, int])
    def restore_docs(self, repo: Optional[str] = None, archive: Optional[str] = None,
            host: str = "http://localhost:9000", user: str = "Administrator", password: str = "asdasd",
            timeout_value: int = 240, users: bool = False, **kwargs):
        """This function runs a restore."""
        archive = self.archive if archive is None else archive
        other_args = sdk_utils.format_flags(kwargs)
        enable_users = ['--enable-users'] if users else []
        complete = subprocess.run([join(self.BIN_PATH, 'cbbackupmgr'), 'restore', '-a', archive, '-r', repo, '-c', host,
                                   '-u', user, '-p', password, '--no-progress-bar', '--purge'] + enable_users +
                                   other_args, capture_output=True, shell=False, timeout=timeout_value)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)


    @keyword(types=[str, str, int])
    def configure_backup(self, repo: Optional[str] = None, archive: Optional[str] = None, users: bool = False,
                 timeout_value: int = 30, **kwargs):
        """This function will configure a backup repository."""
        archive = self.archive if archive is None else archive
        other_args = sdk_utils.format_flags(kwargs)
        enable_users = ['--enable-users'] if users else []
        complete = subprocess.run([join(self.BIN_PATH, 'cbbackupmgr'), 'config', '-a', archive, '-r', repo]
                                  + enable_users + self.exclude_n1ql_system_bucket(other_args),
                                  capture_output=True, shell=False, timeout=timeout_value)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)


    def exclude_n1ql_system_bucket(self, other_args):
        """Ensures we ignore the 'N1QL_SYSTEM_BUCKET' bucket where possible"""
        if "--include-data" in other_args:
            return other_args

        if "--exclude-data" not in other_args:
            return other_args + ["--exclude-data", "N1QL_SYSTEM_BUCKET"]

        idx = other_args.index("--exclude-data") + 1

        other_args[idx] = f"N1QL_SYSTEM_BUCKET,{other_args[idx]}"

        return other_args


    @keyword(types=[str, str, str, str, str, int])
    def run_backup(self, repo: Optional[str] = None, archive: Optional[str] = None, host: str = "http://localhost:9000",
            user: str = "Administrator", password: str = "asdasd", timeout_value: int = 240, **kwargs):
        """This function will run a backup."""
        archive = self.archive if archive is None else archive
        other_args = sdk_utils.format_flags(kwargs)
        complete = subprocess.run([join(self.BIN_PATH, 'cbbackupmgr'), 'backup', '-a', archive, '-r', repo, '-c',
                        host, '-u', user, '-p', password, '--no-progress-bar'] + other_args, capture_output=True,
                        shell=False, timeout=timeout_value)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)


    @keyword(types=[str, str, str, str, str])
    def run_and_terminate_backup(self, repo: Optional[str] = None, archive: Optional[str] = None,
            host: str = "http://localhost:9000", user: str = "Administrator", password: str = "asdasd", **kwargs):
        """This function will run a backup."""
        archive = self.archive if archive is None else archive
        other_args = sdk_utils.format_flags(kwargs)
        with subprocess.Popen([join(self.BIN_PATH, 'cbbackupmgr'), 'backup', '-a', archive, '-r', repo, '-c',
            host, '-u', user, '-p', password, '--no-progress-bar'] + other_args) as complete:

            logger.debug(f'rc: {complete.returncode}, args: {str(complete.args)}')
            time.sleep(1)
            complete.kill()


    @keyword(types=[str, str, str, str, str, int])
    def run_and_terminate_restore(self, repo: Optional[str] = None, archive: Optional[str] = None,
            host: str = "http://localhost:9000", user: str = "Administrator", password: str = "asdasd",
            sleep_time: int = 1, **kwargs):
        """This function will run a restore and terminate it mid-process for testing resume functionality."""
        archive = self.archive if archive is None else archive
        other_args = sdk_utils.format_flags(kwargs)
        with subprocess.Popen([join(self.BIN_PATH, 'cbbackupmgr'), 'restore', '-a', archive, '-r', repo, '-c',
            host, '-u', user, '-p', password, '--no-progress-bar', '--purge'] + other_args) as complete:

            logger.debug(f'rc: {complete.returncode}, args: {str(complete.args)}')
            time.sleep(sleep_time)
            complete.kill()


    @keyword(types=[str, str, str, int, str])
    def run_examine(self, repo: Optional[str] = None, key: Optional[str] = None, archive: Optional[str] = None,
            timeout_value: int = 120, collection_string: str = "default", **kwargs):
        """This function runs examine on a backup."""
        archive = self.archive if archive is None else archive
        other_args = sdk_utils.format_flags(kwargs)
        complete = subprocess.run([join(self.BIN_PATH, 'cbbackupmgr'), 'examine', '-a', archive, '-r', repo,
                        '--collection-string', collection_string, '--key', key] + other_args,
                        capture_output=True, shell=False, timeout=timeout_value)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)
        if '--json' in other_args:
            return self.examine_to_list(complete.stdout), json.loads(complete.stdout)
        return str(complete.stdout)


    @keyword(types=[str, str, int])
    def run_remove(self, repo: Optional[str] = None, archive: Optional[str] = None, timeout_value: int = 120, **kwargs):
        """This function runs remove on a backup."""
        archive = self.archive if archive is None else archive
        other_args = sdk_utils.format_flags(kwargs)
        complete = subprocess.run([join(self.BIN_PATH, 'cbbackupmgr'), 'remove', '-a', archive, '-r', repo]
                        + other_args, capture_output=True, shell=False, timeout=timeout_value)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)


    @keyword(types=[str, int, str, str, str, str, str, str, int])
    def run_worm(self, repo: str = "cloud_repo", period: int = 100, archive: Optional[str] = None,
            obj_staging_dir: str = "/tmp/staging/archive", obj_region: Optional[str] = None,
            obj_access_key_id: Optional[str] = None, obj_secret_access_key: Optional[str] = None,
            obj_endpoint: Optional[str] = None, timeout_value: int = 120, **kwargs):
        """This function runs worm on a backup repository to enable WORM protection."""
        archive = self.archive if archive is None else archive
        obj_region = self.obj_region if obj_region is None else obj_region
        obj_access_key_id = self.obj_access_key_id if obj_access_key_id is None else obj_access_key_id
        obj_secret_access_key = self.obj_secret_access_key if obj_secret_access_key is None else obj_secret_access_key
        obj_endpoint = self.obj_endpoint if obj_endpoint is None else obj_endpoint
        other_args = sdk_utils.format_flags(kwargs)
        complete = subprocess.run([join(self.BIN_PATH, 'cbbackupmgr'), 'worm', '-a', archive, '-r', repo,
                        '--period', str(period), '--obj-staging-dir', obj_staging_dir,
                        '--obj-region', obj_region, '--obj-access-key-id', obj_access_key_id,
                        '--obj-secret-access-key', obj_secret_access_key, '--obj-endpoint', obj_endpoint,
                        '--s3-force-path-style'] + other_args, capture_output=True, shell=False, timeout=timeout_value)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)


    @keyword(types=[str, str])
    def get_info_as_json(self, repo: Optional[str] = None, archive: Optional[str] = None, timeout_value: int = 120,
            **kwargs):
        """This function runs info on a backup."""
        archive = self.archive if archive is None else archive
        other_args = sdk_utils.format_flags(kwargs)
        complete = subprocess.run([join(self.BIN_PATH, 'cbbackupmgr'), 'info', '-a', archive, '-r', repo, '--json']
                        + other_args, capture_output=True, shell=False, timeout=timeout_value)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)

        return json.loads(complete.stdout)


    @keyword(types=[List[Dict], int, int, int, int, int])
    def verify_cbworkloadgen_documents(self, data: List[Dict], size: int, expected_len_binary: int = 0,
            expected_len_json: int = 0, expected_len_binary_xattr: int = 0, expected_len_json_xattr: int = 0) :
        """This function will check the contents of the rift dump or similar output and validate them.

        Checks that the contents of the cbworkloadgen generated documents contains; the expected number
        of documents of each type, that each document is not deleted, that the index matches the key and the body is
        made up of a certain number of 0s.

        Args:
            expected_len_binary: Optional; The expected total number of binary documents without xattrs; Default = 0.
            expected_len_json: Optional; The expected total number of json documents without xattrs; Default = 0.
            expected_len_binary_xattr: Optional; The expected total number of binary documents with xattrs; Default = 0.
            expected_len_json_xattr: Optional; The expected total number of json documents with xattrs; Default = 0.
            size: The length of the body.
        """
        binary_doc_count = 0
        json_doc_count = 0
        binary_with_xattr_doc_count = 0
        json_with_xattr_doc_count = 0

        for doc in data:
            # Skip any documents not in the default collection so we don't count, for example, system scope docs. The
            # collection_id is not always specified, if it isn't then assume the default collection.
            if doc.get("collection_id", 0) != 0:
                continue

            if doc["deleted"] != "false" and doc["deleted"] is not False:
                raise AssertionError('Document contents changed: document deleted')
            if doc["metadata"]["datatype"] == 3:
                json_doc_count += 1
                if "extended_attributes" in doc:
                    raise AssertionError("Document contents changed: contains extended attributes")
                if not doc["key"].endswith(str(doc["value"]["index"])):
                    raise AssertionError("Document contents changed: index doesn't match key")
                if doc["value"]["body"] != "0"*size:
                    raise AssertionError("Document contents changed: body has been altered")
            elif doc["metadata"]["datatype"] == 7:
                json_with_xattr_doc_count += 1
                if "extended_attributes" not in doc:
                    raise AssertionError("Document contents changed: does not contain extended attributes")
                if not doc["key"].endswith(str(doc["value"]["index"])):
                    raise AssertionError("Document contents changed: index doesn't match key")
                if doc["value"]["body"] != "0"*size:
                    raise AssertionError("Document contents changed: body has been altered")
            elif doc["metadata"]["datatype"] == 2:
                binary_doc_count += 1
                if "extended_attributes" in doc:
                    raise AssertionError("Document contents changed: contains extended attributes")
                if doc["value"] != "30"*size:
                    raise AssertionError("Document contents changed: body has been altered")
            elif doc["metadata"]["datatype"] == 6:
                binary_with_xattr_doc_count += 1
                if "extended_attributes" not in doc:
                    raise AssertionError("Document contents changed: does not contain extended attributes")
                if doc["value"] != "30"*size:
                    raise AssertionError("Document contents changed: body has been altered")
            else:
                raise AssertionError('Document contents changed: incorrect datatype')

        if json_doc_count != expected_len_json:
            raise AssertionError('Document contents changed: unexpected number of json documents with no xattrs: '
                    f'{json_doc_count} != {expected_len_json}')
        if binary_doc_count != expected_len_binary:
            raise AssertionError('Document contents changed: unexpected number of binary documents with no xattrs: '
                    f'{binary_doc_count} != {expected_len_binary}')
        if json_with_xattr_doc_count != expected_len_json_xattr:
            raise AssertionError('Document contents changed: unexpected number of json documents with xattrs: '
                    f'{json_with_xattr_doc_count} != {expected_len_json_xattr}')
        if binary_with_xattr_doc_count != expected_len_binary_xattr:
            raise AssertionError('Document contents changed: unexpected number of json documents with xattrs: '
                    f'{binary_with_xattr_doc_count} != {expected_len_binary_xattr}')


    @keyword(types=[List[Dict],str])
    def check_key_not_included_in_backup(self, data: List[Dict], excluded_key: str) :
        """The function will check the documents key prefix and raise an error if any documents have the
        excluded_key prefix."""
        for doc in data:
            if doc["key"].startswith(excluded_key):
                raise AssertionError("Document with wrong key prefix included")


    @keyword(types=[List[Dict],str,int])
    def check_key_is_included_in_backup(self, data: List[Dict], included_key: str, expected_count: int) :
        """The function will check the documents key prefix to ensure these documents have been included in the
        backup."""
        count = len(list(filter(lambda doc: doc["key"].startswith(included_key), data)))
        if count != expected_count:
            raise AssertionError(f"Unexpected number of documents with included key: {count} != {expected_count}")


    @keyword(types=[List[Dict],str])
    def check_key_not_included_in_restore(self, data: List[Dict], excluded_key: str) :
        """The function will check the documents key prefix and raise an error if any documents have the
        excluded_key prefix."""
        for doc in data:
            if doc["name"].startswith(excluded_key):
                raise AssertionError("Document with wrong key prefix included")


    @keyword(types=[List[Dict], int, int])
    def check_restored_cbworkloadgen_docs_contents(self, data: List[Dict], expected_length: int, size: int) :
        """The function checks the documents contents and validates them.

        Checks that the cbtransfer output of cbworkloadgen generated documents contains; the expected number of
        documents, that the index matches the key and the body is made up of a certain number of 0s.

        Arguments:
            expected_length: The expected number of documents.
            size: The length of the body.
        """
        if len(data) != expected_length:
            raise AssertionError(f'Document contents changed: unexpected number of documents: {len(data)} \
                                    != {expected_length}')

        for doc in data:
            if not doc["name"].endswith(str(doc["index"])):
                raise AssertionError("Document contents changed: index doesn't match key")
            if doc["body"] != "0"*size:
                raise AssertionError("Document contents changed: body has been altered")


    @keyword(types=[List[Dict], int, str])
    def check_restored_cbc_docs_contents(self, data: List[Dict], expected_length: int, group: str) :
        """The function checks the documents contents and validates them.

        Checks that the cbtransfer output of cbc-create generated documents contains; the expected number of
        documents and the group field is the expected value.

        Arguments:
            expected_length: The expected number of documents.
            group: The expected value of the group field.
        """
        utils.check_simple_data_contents(data, expected_length, group)


    @keyword(types=[str])
    def rift_to_list(self, data: str) -> List[Dict]:
        """This function will convert the rift dump into a list of dictionaries, with a dictionary for each of the
        documents."""
        result_list = []
        result= data.split('\n')
        for json_doc in result:
            if json_doc is not None and json_doc != ' ' and json_doc != '':
                json_doc = json_doc.replace("false","\"false\"")
                dict_doc = json.loads(json_doc)
                result_list.append(dict_doc)
        return result_list


    @keyword(types=[str])
    def examine_to_list(self, data: str) -> List[str]:
        """This function create a list of the document returned by examine from each of the backups."""
        doc_list = [backup['document'] for backup in json.loads(data) if backup['event_type'] == 1]
        return doc_list


    @keyword(types=[str])
    def cbtransfer_to_list(self, data: str) -> List[Dict]:
        """This function will convert the output of the cbtransfer bucket information into a list of dictionaries,
        with a dictionary for each of the documents."""
        result_list = []
        result = data.split('\n')
        for i in result:
            if not i.startswith("set"):
                result_list.append(json.loads(i))
        return result_list


    @keyword(types=[List[Dict], str])
    def check_correct_scope(self, data: List[Dict], expected_value: str):
        """Checks the value of the docs in a scope are the expected value, allowing it to check the correct
        scope was backed up."""
        for doc in data:
            if doc["value"]["group"] != expected_value:
                raise AssertionError("Data from incorrect scope included in backup")


    @keyword(types=[str, str])
    def change_backup_date(self, date: str, path: str):
        """Renames the backup file to one day earlier."""
        new_date = datetime.strftime(datetime.strptime(date[:10], "%Y-%m-%d") - timedelta(days=1), "%Y-%m-%d")\
                    + date[10:]
        os.rename(f'{path}/{date}', f'{path}/{new_date}')


    @keyword(types=[Dict, str])
    def get_bucket_index(self, data: Dict, bucket: str = "default") -> int:
        """Returns the index of the desired bucket in the Get Info As Json output."""
        for i, buck in enumerate(data["backups"][-1]["buckets"]):
            if buck["name"] == bucket:
                return i
        raise AssertionError(f"Bucket {bucket} not backed up")

    @keyword(types=[str, str, str, str, str, int])
    def add_user(self, username: str = "test-user" ,archive: Optional[str] = None, host: str = "http://localhost:9000",
            user: str = "Administrator", password: str = "asdasd", timeout_value: int = 240, **kwargs):
        """This function will add a user."""
        archive = self.archive if archive is None else archive
        other_args = sdk_utils.format_flags(kwargs)
        complete = subprocess.run([join(self.BIN_PATH, 'couchbase-cli'), 'user-manage', '-c', host, '-u', user, '-p',
                        password, '--set', '--rbac-username', username, '--rbac-password', 'password',
                        '--roles', 'admin', '--auth-domain', 'local'] + other_args, capture_output=True,
                        shell=False, timeout=timeout_value)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)

    @keyword(types=[str, str, str, str, str, int])
    def delete_user(self, username: str = "test-user", archive: Optional[str] = None,
                    host: str = "http://localhost:9000", user: str = "Administrator", password: str = "asdasd",
                    timeout_value: int = 240, **kwargs):
        """This function will delete a user."""
        archive = self.archive if archive is None else archive
        other_args = sdk_utils.format_flags(kwargs)
        complete = subprocess.run([join(self.BIN_PATH, 'couchbase-cli'), 'user-manage', '-c', host, '-u', user, '-p',
                        password, '--rbac-username', username, '--auth-domain', 'local',
                        '--delete'] + other_args, capture_output=True,
                        shell=False, timeout=timeout_value)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)

    @keyword(types=[str, str, str, str, int])
    def get_user_info(self, archive: Optional[str] = None, host: str = "http://localhost:9000",
            user: str = "Administrator", password: str = "asdasd", timeout_value: int = 240, **kwargs):
        """This function will get user info."""
        archive = self.archive if archive is None else archive
        other_args = sdk_utils.format_flags(kwargs)
        complete = subprocess.run([join(self.BIN_PATH, 'couchbase-cli'), 'user-manage', '-c', host, '-u', user, '-p',
                        password, '--list'] + other_args, capture_output=True,
                        shell=False, timeout=timeout_value)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)
        user_info = json.loads(complete.stdout)
        return user_info[0]

    @keyword(types=[str, str, str, int])
    def check_user_role(self, archive: Optional[str] = None, host: str = "http://localhost:9000/default",
            username: str = "test-user" , timeout_value: int = 240, **kwargs):
        """This function will connect to the cluster using the user credentials."""
        archive = self.archive if archive is None else archive
        other_args = sdk_utils.format_flags(kwargs)
        complete = subprocess.run([join(self.BIN_PATH, 'cbc-cat'), 'key', '-U', host, '-u', username, '-P',
                        'password'] + other_args, capture_output=True,
                        shell=False, timeout=timeout_value)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)
        return complete.returncode

    @keyword(types=[str, str, str, str, str, int])
    def check_flush_is_disabled(self, archive: Optional[str] = None, host: str = "http://localhost:9000",
            user: str = "Administrator", password: str = "asdasd", bucket: str = "default", timeout_value: int = 240,
            **kwargs):
        """This function will check if flush is disabled for the given bucket."""
        archive = self.archive if archive is None else archive
        other_args = sdk_utils.format_flags(kwargs)
        complete = subprocess.run([join(self.BIN_PATH, 'couchbase-cli'), 'bucket-list', '-c', host, '-u', user, '-p',
                        password, '-o', 'json'] + other_args, capture_output=True,
                        shell=False, timeout=timeout_value)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)
        buckets = json.loads(complete.stdout)
        for curBucket in buckets:
            if curBucket["name"] == bucket:
                if "flush" not in curBucket["controllers"]:
                    return
                raise AssertionError(f"Flush not disabled in bucket \"{curBucket['name']}\"")
        raise AssertionError(f"Bucket {bucket} not found")

    @keyword(types=[str, str, str, str, str, str, str, str, str, int])
    def get_bucket_uuid_from_plan(self, backup_name: str, bucket_name: str = "default",
            cloud_bucket: str = "s3://aws-buck", archive_name: str = "archive", repo: str = "cloud_repo",
            obj_region: Optional[str] = None, obj_access_key_id: Optional[str] = None,
            obj_secret_access_key: Optional[str] = None, obj_endpoint: Optional[str] = None,
            timeout_value: int = 120) -> str:
        """Retrieves the bucket UUID from the plan.json file in a cloud backup directory.

        Args:
            backup_name: The name/date of the backup.
            bucket_name: The name of the bucket to get the UUID for.
            cloud_bucket: The S3 bucket URL.
            archive_name: The archive name.
            repo: The repository name.
            local_dir: The local staging directory.
            obj_region: The object storage region.
            obj_access_key_id: The access key ID.
            obj_secret_access_key: The secret access key.
            obj_endpoint: The object storage endpoint.
            timeout_value: Command timeout in seconds.

        Returns:
            The UUID of the specified bucket.

        Raises:
            AssertionError: If the bucket is not found in the plan.json or has no UUID.
        """
        obj_region = self.obj_region if obj_region is None else obj_region
        obj_access_key_id = self.obj_access_key_id if obj_access_key_id is None else obj_access_key_id
        obj_secret_access_key = self.obj_secret_access_key if obj_secret_access_key is None else obj_secret_access_key
        obj_endpoint = self.obj_endpoint if obj_endpoint is None else obj_endpoint
        plan_s3_path = f"{cloud_bucket}/{archive_name}/{repo}/{backup_name}/plan.json"

        env = os.environ.copy()
        env['AWS_ACCESS_KEY_ID'] = obj_access_key_id
        env['AWS_SECRET_ACCESS_KEY'] = obj_secret_access_key
        env['AWS_DEFAULT_REGION'] = obj_region

        complete = subprocess.run([
            'aws', 's3', 'cp', plan_s3_path, '-',
            '--endpoint-url', obj_endpoint
        ], capture_output=True, shell=False, timeout=timeout_value, env=env)

        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)

        plan_data = json.loads(complete.stdout)

        for bucket in plan_data.get("cluster", {}).get("buckets", []):
            if bucket.get("name") == bucket_name:
                config = bucket.get("config", {})
                if config.get("sink_uuid"):
                    return config["sink_uuid"]

                data = bucket.get("data", {})
                range_section = data.get("range", {})
                if range_section.get("uuid"):
                    return range_section["uuid"]

                restrictions = data.get("restrictions", {})
                if restrictions.get("sink_uuid"):
                    return restrictions["sink_uuid"]

                manifest = data.get("manifest", {})
                if manifest.get("sink_uuid"):
                    return manifest["sink_uuid"]

                key_value = data.get("key_value", {})
                if key_value.get("sink_uuid"):
                    return key_value["sink_uuid"]

                raise AssertionError(f"Bucket '{bucket_name}' found but has no sink_uuid in plan.json")

        raise AssertionError(f"Bucket '{bucket_name}' not found in plan.json")

    @keyword(types=[str, str, str, str, str, int])
    def enable_bucket_object_lock(self, bucket: str = "aws-buck", obj_region: Optional[str] = None,
            obj_access_key_id: Optional[str] = None, obj_secret_access_key: Optional[str] = None,
            obj_endpoint: Optional[str] = None, timeout_value: int = 120):
        """Enables object versioning and object lock on an S3 bucket.

        This function first enables versioning on the bucket, then enables object lock configuration.
        Both are required for WORM (Write Once Read Many) backups.

        Args:
            bucket: The S3 bucket name.
            obj_region: The AWS region.
            obj_access_key_id: The AWS access key ID.
            obj_secret_access_key: The AWS secret access key.
            obj_endpoint: The S3 endpoint URL (for minio or other S3-compatible storage).
            timeout_value: Command timeout in seconds.

        Raises:
            subprocess.CalledProcessError: If either command fails.
        """
        obj_region = self.obj_region if obj_region is None else obj_region
        obj_access_key_id = self.obj_access_key_id if obj_access_key_id is None else obj_access_key_id
        obj_secret_access_key = self.obj_secret_access_key if obj_secret_access_key is None else obj_secret_access_key
        obj_endpoint = self.obj_endpoint if obj_endpoint is None else obj_endpoint
        env = os.environ.copy()
        env['AWS_ACCESS_KEY_ID'] = obj_access_key_id
        env['AWS_SECRET_ACCESS_KEY'] = obj_secret_access_key
        env['AWS_DEFAULT_REGION'] = obj_region

        # Enable bucket versioning
        versioning_cmd = [
            'aws', 's3api', 'put-bucket-versioning',
            '--bucket', bucket,
            '--versioning-configuration', 'Status=Enabled',
            '--endpoint-url', obj_endpoint
        ]

        complete = subprocess.run(versioning_cmd, capture_output=True, shell=False, timeout=timeout_value, env=env)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)
        logger.info(f"Enabled versioning on bucket '{bucket}'")

        # Enable object lock configuration
        object_lock_cmd = [
            'aws', 's3api', 'put-object-lock-configuration',
            '--bucket', bucket,
            '--object-lock-configuration', '{"ObjectLockEnabled": "Enabled"}',
            '--endpoint-url', obj_endpoint
        ]

        complete = subprocess.run(object_lock_cmd, capture_output=True, shell=False, timeout=timeout_value, env=env)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)
        logger.info(f"Enabled object lock on bucket '{bucket}'")

    @keyword(types=[str, str, str, str, str, str, str, int])
    def verify_object_lock_retention(self, prefix: str, min_retention_date: str, bucket: str = "aws-buck",
            obj_region: Optional[str] = None, obj_access_key_id: Optional[str] = None,
            obj_secret_access_key: Optional[str] = None, obj_endpoint: Optional[str] = None,
            timeout_value: int = 120):
        """Verifies that all objects in an S3 directory have object lock retention that expires after a specified date.

        This function lists all objects in the specified S3 bucket/prefix, retrieves all versions of each object,
        and verifies that the first (oldest) version of each object has an object lock retention date that is
        after the specified minimum retention date.

        Args:
            prefix: The S3 prefix (directory path) to list objects from.
            min_retention_date: The minimum expected retention date in ISO format (e.g., "2024-01-01T00:00:00Z").
                                Object lock must expire after this date.
            bucket: The S3 bucket name.
            obj_region: The AWS region.
            obj_access_key_id: The AWS access key ID.
            obj_secret_access_key: The AWS secret access key.
            obj_endpoint: The S3 endpoint URL (for minio or other S3-compatible storage).
            timeout_value: Command timeout in seconds.

        Raises:
            AssertionError: If any object's first version does not have object lock retention that expires
                            after the specified date.
        """
        obj_region = self.obj_region if obj_region is None else obj_region
        obj_access_key_id = self.obj_access_key_id if obj_access_key_id is None else obj_access_key_id
        obj_secret_access_key = self.obj_secret_access_key if obj_secret_access_key is None else obj_secret_access_key
        obj_endpoint = self.obj_endpoint if obj_endpoint is None else obj_endpoint
        env = os.environ.copy()
        env['AWS_ACCESS_KEY_ID'] = obj_access_key_id
        env['AWS_SECRET_ACCESS_KEY'] = obj_secret_access_key
        env['AWS_DEFAULT_REGION'] = obj_region

        # Parse the minimum retention date
        min_date = parse(min_retention_date)
        if min_date.tzinfo is None:
            min_date = min_date.replace(tzinfo=timezone.utc)

        # List all object versions in the prefix
        list_versions_cmd = [
            'aws', 's3api', 'list-object-versions',
            '--bucket', bucket,
            '--prefix', prefix,
            '--endpoint-url', obj_endpoint
        ]

        complete = subprocess.run(list_versions_cmd, capture_output=True, shell=False, timeout=timeout_value, env=env)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)

        versions_data = json.loads(complete.stdout)
        versions = versions_data.get('Versions', [])

        if not versions:
            raise AssertionError(f"No objects found in s3://{bucket}/{prefix}")

        # Group versions by object key
        objects_versions: Dict[str, List[Dict]] = {}
        for version in versions:
            key = version['Key']
            if key not in objects_versions:
                objects_versions[key] = []
            objects_versions[key].append(version)

        # Sort versions by LastModified date to find the first (oldest) version
        for key in objects_versions:
            objects_versions[key].sort(key=lambda v: parse(v['LastModified']))

        # Verify object lock retention for the first version of each object
        verified_count = 0
        for key, key_versions in objects_versions.items():
            first_version = key_versions[0]
            version_id = first_version.get('VersionId')

            # Get object retention
            get_retention_cmd = [
                'aws', 's3api', 'get-object-retention',
                '--bucket', bucket,
                '--key', key,
                '--endpoint-url', obj_endpoint
            ]

            if version_id and version_id != 'null':
                get_retention_cmd.extend(['--version-id', version_id])

            retention_result = subprocess.run(
                get_retention_cmd, capture_output=True, shell=False, timeout=timeout_value, env=env
            )

            if retention_result.returncode != 0:
                logger.debug(f"No object lock retention for key '{key}', version '{version_id}': "
                             f"{retention_result.stderr.decode('utf-8')}")
                raise AssertionError(f"Object '{key}' (version: {version_id}) does not have object lock retention")

            retention_data = json.loads(retention_result.stdout)
            retention = retention_data.get('Retention', {})
            retain_until_date_str = retention.get('RetainUntilDate')

            if not retain_until_date_str:
                raise AssertionError(f"Object '{key}' (version: {version_id}) has no RetainUntilDate")

            retain_until_date = parse(retain_until_date_str)
            if retain_until_date.tzinfo is None:
                retain_until_date = retain_until_date.replace(tzinfo=timezone.utc)

            if retain_until_date <= min_date:
                raise AssertionError(
                    f"Object '{key}' (version: {version_id}) retention expires at {retain_until_date}, "
                    f"which is not after {min_date}"
                )

            logger.debug(f"Verified object lock for '{key}': retention until {retain_until_date}")
            verified_count += 1

        logger.info(f"Successfully verified object lock retention for {verified_count} objects in s3://{bucket}/{prefix}")

    @keyword(types=[str, str, str, str, str, str, int])
    def delete_current_version_of_cloud_objects(self, prefix: str, bucket: str = "aws-buck",
            obj_region: Optional[str] = None, obj_access_key_id: Optional[str] = None,
            obj_secret_access_key: Optional[str] = None, obj_endpoint: Optional[str] = None,
            timeout_value: int = 120):
        """Deletes the current (latest) version of all objects in an S3 prefix.

        This function lists all objects in the specified S3 bucket/prefix and deletes
        the current version of each object in a single bulk request. For versioned buckets
        with WORM protection, this will create delete markers but the previous versions
        should remain accessible.

        Args:
            prefix: The S3 prefix (directory path) to delete objects from.
            bucket: The S3 bucket name.
            obj_region: The AWS region.
            obj_access_key_id: The AWS access key ID.
            obj_secret_access_key: The AWS secret access key.
            obj_endpoint: The S3 endpoint URL (for minio or other S3-compatible storage).
            timeout_value: Command timeout in seconds.

        Returns:
            The number of objects deleted.

        Raises:
            AssertionError: If no objects are found or deletion fails.
        """
        obj_region = self.obj_region if obj_region is None else obj_region
        obj_access_key_id = self.obj_access_key_id if obj_access_key_id is None else obj_access_key_id
        obj_secret_access_key = self.obj_secret_access_key if obj_secret_access_key is None else obj_secret_access_key
        obj_endpoint = self.obj_endpoint if obj_endpoint is None else obj_endpoint
        env = os.environ.copy()
        env['AWS_ACCESS_KEY_ID'] = obj_access_key_id
        env['AWS_SECRET_ACCESS_KEY'] = obj_secret_access_key
        env['AWS_DEFAULT_REGION'] = obj_region

        # List all objects in the prefix
        list_cmd = [
            'aws', 's3api', 'list-objects-v2',
            '--bucket', bucket,
            '--prefix', prefix,
            '--endpoint-url', obj_endpoint
        ]

        complete = subprocess.run(list_cmd, capture_output=True, shell=False, timeout=timeout_value, env=env)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)

        objects_data = json.loads(complete.stdout)
        contents = objects_data.get('Contents', [])

        if not contents:
            raise AssertionError(f"No objects found in s3://{bucket}/{prefix}")

        # Build the delete request with all object keys
        objects_to_delete = [{"Key": obj['Key']} for obj in contents]
        delete_request = json.dumps({"Objects": objects_to_delete, "Quiet": False})

        # Delete all objects in a single request
        delete_cmd = [
            'aws', 's3api', 'delete-objects',
            '--bucket', bucket,
            '--delete', delete_request,
            '--endpoint-url', obj_endpoint
        ]

        delete_result = subprocess.run(
            delete_cmd, capture_output=True, shell=False, timeout=timeout_value, env=env
        )

        utils.log_subprocess_run_results(delete_result)

        deleted_count = len(objects_to_delete)
        if delete_result.returncode == 0:
            result_data = json.loads(delete_result.stdout) if delete_result.stdout else {}
            deleted_count = len(result_data.get('Deleted', []))
            errors = result_data.get('Errors', [])
            if errors:
                logger.debug(f"Some objects could not be deleted: {errors}")

        logger.info(f"Deleted {deleted_count} of {len(contents)} objects in s3://{bucket}/{prefix}")
        return deleted_count

    @keyword(types=[str, str, str, str, str, str, int])
    def overwrite_cloud_objects_with_random_data(self, prefix: str, bucket: str = "aws-buck",
            obj_region: Optional[str] = None, obj_access_key_id: Optional[str] = None,
            obj_secret_access_key: Optional[str] = None, obj_endpoint: Optional[str] = None,
            timeout_value: int = 120):
        """Overwrites all objects in an S3 prefix with random data.

        This function lists all objects in the specified S3 bucket/prefix and overwrites
        each object with random bytes of the same size.

        Args:
            prefix: The S3 prefix (directory path) containing objects to overwrite.
            bucket: The S3 bucket name.
            obj_region: The AWS region.
            obj_access_key_id: The AWS access key ID.
            obj_secret_access_key: The AWS secret access key.
            obj_endpoint: The S3 endpoint URL (for minio or other S3-compatible storage).
            timeout_value: Command timeout in seconds.

        Raises:
            AssertionError: If no objects are found or overwrite fails.
        """
        import tempfile
        import secrets

        obj_region = self.obj_region if obj_region is None else obj_region
        obj_access_key_id = self.obj_access_key_id if obj_access_key_id is None else obj_access_key_id
        obj_secret_access_key = self.obj_secret_access_key if obj_secret_access_key is None else obj_secret_access_key
        obj_endpoint = self.obj_endpoint if obj_endpoint is None else obj_endpoint
        env = os.environ.copy()
        env['AWS_ACCESS_KEY_ID'] = obj_access_key_id
        env['AWS_SECRET_ACCESS_KEY'] = obj_secret_access_key
        env['AWS_DEFAULT_REGION'] = obj_region

        list_cmd = [
            'aws', 's3api', 'list-objects-v2',
            '--bucket', bucket,
            '--prefix', prefix,
            '--endpoint-url', obj_endpoint
        ]

        complete = subprocess.run(list_cmd, capture_output=True, shell=False, timeout=timeout_value, env=env)
        utils.log_subprocess_run_results(complete)
        utils.check_subprocess_status(complete)

        objects_data = json.loads(complete.stdout)
        contents = objects_data.get('Contents', [])

        if not contents:
            raise AssertionError(f"No objects found in s3://{bucket}/{prefix}")

        for obj in contents:
            key = obj['Key']
            size = obj.get('Size', 1024)

            random_data = secrets.token_bytes(max(size, 1))

            with tempfile.NamedTemporaryFile(delete=False) as tmp_file:
                tmp_file.write(random_data)
                tmp_file_path = tmp_file.name

            try:
                put_cmd = [
                    'aws', 's3api', 'put-object',
                    '--bucket', bucket,
                    '--key', key,
                    '--body', tmp_file_path,
                    '--endpoint-url', obj_endpoint
                ]

                put_result = subprocess.run(
                    put_cmd, capture_output=True, shell=False, timeout=timeout_value, env=env
                )

                utils.log_subprocess_run_results(put_result)
                utils.check_subprocess_status(put_result)
            finally:
                os.unlink(tmp_file_path)

        logger.info(f"All objects in s3://{bucket}/{prefix} have been overwritten")
