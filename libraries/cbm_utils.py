"""This file contains functions that define keywords needed for the cbbackupmgr testing."""

import json
import time
import os
import subprocess
from os.path import join
from typing import Dict, List, Optional
from datetime import datetime, timedelta

import sdk_utils
import utils

from robot.api.deco import keyword
from robot.api import logger
from robot.api.deco import library

ROBOT_AUTO_KEYWORDS = False


@library
class cbm_utils:
    """Keywords needed for cbbackupmgr testing."""
    ROBOT_LIBRARY_SCOPE = 'SUITE'


    def __init__(self, bin_path: str, archive: str):
        self.BIN_PATH = bin_path
        self.archive = archive


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


    @keyword(types=[str, str, str])
    def run_remove(self, repo: Optional[str] = None, archive: Optional[str] = None, timeout_value: int = 120, **kwargs):
        """This function runs remove on a backup."""
        archive = self.archive if archive is None else archive
        other_args = sdk_utils.format_flags(kwargs)
        complete = subprocess.run([join(self.BIN_PATH, 'cbbackupmgr'), 'remove', '-a', archive, '-r', repo]
                        + other_args, capture_output=True, shell=False, timeout=timeout_value)
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
            if json_doc is not None and json_doc != ' ':
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
