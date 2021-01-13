"""This file contains functions that define keywords needed for the cbbackupmgr testing."""

import json
import time
import os
import subprocess
from subprocess import Popen
from os.path import join
from typing import Dict, List, Optional
from datetime import datetime, timedelta

import sdk_utils

from couchbase.cluster import Cluster
from couchbase.cluster import ClusterOptions
from couchbase.cluster import QueryOptions
from couchbase.management.queries import QueryIndexManager, CreatePrimaryQueryIndexOptions
from couchbase_core.cluster import PasswordAuthenticator

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


    @keyword(types=[str, dict, str, str, str, str])
    def sdk_replace(self, key: str, value: dict, host: str = "http://localhost:9000", bucket: str = "default",
            user: str = "Administrator", password: str = "asdasd"):
        """This function uses the Couchbase SDK to replace a value with a new given value for the document of the
        given key."""
        cluster = Cluster(host, ClusterOptions(PasswordAuthenticator(user, password)))
        cb = cluster.bucket(bucket)
        result = cb.replace(key, value)
        cluster.disconnect()
        if result.rc != 0:
            raise subprocess.CalledProcessError(result.rc, result.args, result.stdout)


    @keyword(types=[str, str, str, str, str, int])
    def restore_docs(self, repo: Optional[str] = None, archive: Optional[str] = None,
            host: str = "http://localhost:9000", user: str = "Administrator", password: str = "asdasd",
            timeout_value: int = 120, **kwargs):
        """This function runs a restore."""
        archive = self.archive if archive is None else archive
        other_args = self.format_flags(kwargs)
        complete = subprocess.run([join(self.BIN_PATH, 'cbbackupmgr'), 'restore', '-a', archive, '-r', repo, '-c',
                        host, '-u', user, '-p', password] + other_args, capture_output=True, shell=False,
                        timeout=timeout_value)

        logger.debug(complete.returncode)
        logger.debug(complete.args)
        logger.debug(complete.stdout)
        if complete.returncode != 0:
            raise subprocess.CalledProcessError(complete.returncode, complete.args, complete.stdout)


    @keyword(types=[str, str, int])
    def configure_backup(self, repo: Optional[str] = None, archive: Optional[str] = None, timeout_value: int = 30,
                **kwargs):
        """This function will configure a backup repository."""
        archive = self.archive if archive is None else archive
        other_args = self.format_flags(kwargs)
        complete = subprocess.run([join(self.BIN_PATH, 'cbbackupmgr'), 'config', '-a', archive, '-r', repo]
                        + other_args, capture_output=True, shell=False, timeout=timeout_value)

        logger.debug(complete.returncode)
        logger.debug(complete.args)
        logger.debug(complete.stdout)
        if complete.returncode != 0:
            raise subprocess.CalledProcessError(complete.returncode, complete.args, complete.stdout)


    @keyword(types=[str, str, str, str, str, int])
    def run_backup(self, repo: Optional[str] = None, archive: Optional[str] = None, host: str = "http://localhost:9000",
            user: str = "Administrator", password: str = "asdasd", timeout_value: int = 60, **kwargs):
        """This function will run a backup."""
        archive = self.archive if archive is None else archive
        other_args = self.format_flags(kwargs)
        complete = subprocess.run([join(self.BIN_PATH, 'cbbackupmgr'), 'backup', '-a', archive, '-r', repo, '-c',
                        host, '-u', user, '-p', password] + other_args, capture_output=True, shell=False,
                        timeout=timeout_value)

        logger.debug(complete.returncode)
        logger.debug(complete.args)
        logger.debug(complete.stdout)
        if complete.returncode != 0:
            raise subprocess.CalledProcessError(complete.returncode, complete.args, complete.stdout)


    @keyword(types=[str, str, str, str, str])
    def run_and_terminate_backup(self, repo: Optional[str] = None, archive: Optional[str] = None,
            host: str = "http://localhost:9000", user: str = "Administrator", password: str = "asdasd", **kwargs):
        """This function will run a backup."""
        archive = self.archive if archive is None else archive
        other_args = self.format_flags(kwargs)
        complete = subprocess.Popen([join(self.BIN_PATH, 'cbbackupmgr'), 'backup', '-a', archive, '-r', repo, '-c',
                               host, '-u', user, '-p', password] + other_args)

        logger.debug(complete.returncode, complete.args)
        time.sleep(1)
        complete.kill()


    @staticmethod
    def format_flags(kwargs):
        """Format extra flags into a list."""
        other_args = []
        for flag in kwargs:
            other_args.append(f'--{flag}')
            if kwargs.get(flag) != 'None':
                other_args.append(kwargs.get(flag))
        return other_args


    @keyword(types=[List[Dict], int, int, int, int, int])
    def check_cbworkloadgen_rift_contents(self, data: List[Dict], size: int, expected_len_binary: int = 0,
            expected_len_json: int = 0, expected_len_binary_xattr: int = 0, expected_len_json_xattr: int = 0) :
        """This function will check the contents of the rift dump and validate them.

        Checks that the contents of the rift dump of cbworkloadgen generated documents contains; the expected number
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
            if doc["deleted"] != "false":
                raise AssertionError('Document contents changed: document deleted')
            if doc["metadata"]["datatype"] == 3:
                json_doc_count += 1
                if "extended_attributes" in doc:
                    raise AssertionError("Document contents changed: contains extended attributes")
                if not doc["key"].endswith(str(doc["value"]["index"])):
                    raise AssertionError("Document contents changed: index doesn't match key")
                if doc["value"]["body"] != "0"*size:
                    raise AssertionError("Document contents changed: body has been alterd")
            elif doc["metadata"]["datatype"] == 7:
                json_with_xattr_doc_count += 1
                if "extended_attributes" not in doc:
                    raise AssertionError("Document contents changed: does not contain extended attributes")
                if not doc["key"].endswith(str(doc["value"]["index"])):
                    raise AssertionError("Document contents changed: index doesn't match key")
                if doc["value"]["body"] != "0"*size:
                    raise AssertionError("Document contents changed: body has been alterd")
            elif doc["metadata"]["datatype"] == 2:
                binary_doc_count += 1
                if "extended_attributes" in doc:
                    raise AssertionError("Document contents changed: contains extended attributes")
                if doc["value"] != "30"*size:
                    raise AssertionError("Document contents changed: body has been alterd")
            elif doc["metadata"]["datatype"] == 6:
                binary_with_xattr_doc_count += 1
                if "extended_attributes" not in doc:
                    raise AssertionError("Document contents changed: does not contain extended attributes")
                if doc["value"] != "30"*size:
                    raise AssertionError("Document contents changed: body has been alterd")
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
        """The function checks the documents cotents and validates them.

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
                raise AssertionError("Document contents changed: body has been alterd")


    @keyword(types=[List[Dict], int, str])
    def check_restored_cbc_docs_contents(self, data: List[Dict], expected_length: int, group: str) :
        """The function checks the documents cotents and validates them.

        Checks that the cbtransfer output of cbc-create generated documents contains; the expected number of
        documents and the group field is the expected value.

        Arguments:
            expected_length: The expected number of documents.
            group: The expected value of the group field.
        """
        if len(data) != expected_length:
            raise AssertionError(f'Document contents changed: unexpected number of documents: {len(data)} \
                                    != {expected_length}')

        for doc in data:
            if not doc["group"] == group:
                raise AssertionError(f'Document contents changed: {doc["group"]} != {group}')


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
    def cbtransfer_to_list(self, data: str) -> List[Dict]:
        """This function will convert the output of the cbtransfer bucket information into a list of dictionaries,
        with a dictionary for each of the documents."""
        result_list = []
        result= data.split('\n')
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


    @keyword(types=[str, str, str, str])
    def get_doc_info(self, host: str = "http://localhost:9000", bucket: str = "default",
            user: str = "Administrator", password: str = "asdasd"):
        """This function will use the Couchbase SDK to get the contents of the bucket."""
        cluster = Cluster(host, ClusterOptions(PasswordAuthenticator(user, password)))
        cb = cluster.bucket(bucket) # pylint: disable=unused-variable
        mgr = cluster.query_indexes()
        sdk_utils.load_index_data(mgr, bucket=bucket)

        result = cluster.query(f"SELECT * FROM {bucket};")
        doc_list = []
        for row in result:
            doc_list.append(row[bucket])

        mgr.drop_primary_index(bucket)
        sdk_utils.wait_for_index_to_be_dropped(mgr, '#primary', service="gsi", bucket=bucket)
        cluster.disconnect()
        return doc_list
