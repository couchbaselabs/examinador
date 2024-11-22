"""This file contains functions that provide common testing functionality for Examinador."""

import json
import subprocess
import re

from typing import Dict, List, Optional, cast
from os.path import join
from binascii import unhexlify

from robot.api.deco import keyword
from robot.api import logger
from robot.api.deco import library

from robot.utils.asserts import assert_equal
from robot.utils.asserts import assert_not_none

from document import Document

from utils import log_subprocess_run_results
from utils import check_subprocess_status

ROBOT_AUTO_KEYWORDS = False

NONDATA_DOC_CONTENT_META = '0x83'
DEFAULT_NUM_OF_VBUCKETS = 128


@library
class common_utils:
    """Common Examinador functions and keywords."""
    ROBOT_LIBRARY_SCOPE = 'SUITE'


    def __init__(self, source_path: str):
        self.SOURCE = source_path
        self.BIN_PATH = join(self.SOURCE, 'install', 'bin')


    @keyword(types=[str, int])
    def retrieve_docs_from_backup(self, dir_path: str, timeout_value: int = 60):
        """Retrieve all data documents from a backup in a local backup directory.

        This function retrieves all of the data documents in a backup using the cbriftdump CLI command, deserializes
        them and returns a list of generic document objects.
        """
        process_results = subprocess.run([join(self.BIN_PATH, 'cbriftdump'), '-d', dir_path, '--json'],
            capture_output=True, shell=False, timeout=timeout_value)
        log_subprocess_run_results(process_results)
        check_subprocess_status(process_results)

        documents = []
        # Get all documents as bytes
        dump_split = process_results.stdout.split(b'\n')
        docs_with_meta = dump_split[:len(dump_split) - 1]

        # Deserialize all documents into Python dictionaries
        docs_dicts = [json.loads(doc) for doc in docs_with_meta]

        # Turn data documents with metadata into document objects and append them to the documents list
        for doc_dict in docs_dicts:
            document = Document()
            document.key = doc_dict.get('key')
            assert_not_none(document.key, "document key is missing for one of the documents")

            # No 'collection_id' key normally indicates that a document belongs in the default collection
            document.collection_id = doc_dict["collection_id"] if "collection_id" in doc_dict else 0

            document.metadata = doc_dict.get('metadata')
            assert_not_none(document.metadata,
                f"Metadata dictionary key is missing for a document with the key '{document.key}'")

            document.data_type = cast(int, document.metadata.get('datatype'))
            assert_not_none(document.data_type,
                f"Data type dictionary key is missing in metadata for a document with the key '{document.key}'")

            # The 'value' key contains the actual document data
            # Pop the key so that data does not get added as a metadata key in the following for loop
            document.data = doc_dict.pop('value', None)
            assert_not_none(document.data,
                f"document data dictionary key is missing for a document with the key '{document.key}'")

            # Add all other keys to the document's metadata
            document.metadata = {}
            for key, key_value in doc_dict.items():
                document.metadata[key] = key_value

            documents.append(document)

        return documents


    @keyword(types=[str, str, int])
    def retrieve_docs_from_cluster_node(self, bucket: str = "default", node: str = "n_0", timeout_value: int = 60):
        """Retrieve all data documents from a local Couchbase cluster data node.

        This function retrieves all of the data documents in a backup using the couch_dbdump CLI command, deserializes
        them and returns a list of generic document objects.
        """
        documents: List[Document] = []
        for vbucket_no in range(DEFAULT_NUM_OF_VBUCKETS):
            vbucket_docs = self._retrieve_docs_from_vbucket(vbucket_no, bucket, node, timeout_value)
            documents += vbucket_docs

        logger.debug(
            f"Retrieved {len(documents)} documents from the '{bucket}' bucket that are stored on the '{node}' node")
        return documents


    def _retrieve_docs_from_vbucket(self, vbucket_no: int, bucket: str = "default", # pylint: disable=too-many-locals
             node: str = "n_0", timeout_value: int = 60):
        """Retrieve all data documents from the specified vBucket on a local Couchbase cluster data node."""
        process_results = subprocess.run([join(self.BIN_PATH, 'couch_dbdump'), '--json', join(self.SOURCE,
            'ns_server', 'data', node, 'data', bucket, f'{vbucket_no}.couch.1')], capture_output=True, shell=False,
            timeout=timeout_value)
        log_subprocess_run_results(process_results)
        check_subprocess_status(process_results)

        documents: List[Document] = []
        # Get all documents as bytes
        # Remove "Dumping "{PATH_TO_SOURCE}/source/ns_server/data/n_0/data/{bucket-name}/{vbucket}":\n" that
        # precedes the documents on standard output and b'' at the end of the list, which gets added as a result of
        # split().
        dump_split = process_results.stdout.split(b'\n')
        docs_with_meta = dump_split[1:len(dump_split) - 1]

        # Deserialize the documents with metadata and separate vBucket information documents from the actual data
        # documents
        data_docs_dicts = []
        for doc in docs_with_meta:
            doc_dict = json.loads(doc)
            # The 'id' key includes the full id of a document which is its collection id concatenated to its key
            doc_full_id = doc_dict.get('id')
            assert_not_none(doc_full_id, "Full id dictionary key is missing for one of the documents")

            doc_content_meta = doc_dict.get('content_meta')
            assert_not_none(doc_content_meta,
                f"Content meta dictionary key is missing for a document with the full id '{doc_full_id}'")
            if doc_content_meta != NONDATA_DOC_CONTENT_META:
                data_docs_dicts.append(doc_dict)

        # Turn data documents with metadata into document objects and append them to the documents list
        for doc_dict in data_docs_dicts:
            document = Document()
            document.key = common_utils._get_key_from_full_id(doc_dict['id'])
            document.collection_id = common_utils._get_collection_id_from_full_id(doc_dict['id'])
            document.data_type = doc_dict.get('datatype')
            assert_not_none(document.data_type,
                f"Data type dictionary key is missing in metadata for a document with the key '{document.key}'")

            # The 'body' key contains the actual document data
            # Pop the key so that data does not get added as a metadata key in the following for loop
            document.data = doc_dict.pop('body', None)
            assert_not_none(document.data,
                f"document data dictionary key is missing for a document with the key '{document.key}'")

            # Add all other keys to the document's metadata
            document.metadata = {}
            for key, key_value in doc_dict.items():
                document.metadata[key] = key_value

            documents.append(document)

        return documents


    @staticmethod
    @keyword(types=[List[Document], List[Document], List[str], bool])
    def validate_docs(docs: List[Document], validation_docs: List[Document],
                      metadata_keys_to_ignore: Optional[List[str]] = None,
            only_validate_data: bool = False):
        """Validate all provided documents by comparing them to the specified validation documents.
        """
        assert_equal(len(docs), len(validation_docs), "The number of documents and validation documents is not equal")

        # In order to uniquely match each validation document to one of the documents that need to be validated
        # we use dictionary keys of the form '[collection_id] @ [key]'
        full_id_to_doc_dict = {f'{doc.collection_id} @ {doc.key}': doc for doc in docs}

        for valid_doc in validation_docs:
            if only_validate_data:
                attrs_to_validate = ['data']
            else:
                attrs_to_validate_dict = vars(valid_doc)
                if metadata_keys_to_ignore is not None:
                    for key_to_ignore in metadata_keys_to_ignore:
                        # Pop the metadata keys we want to ignore, don't throw an error if a key does not exist
                        attrs_to_validate_dict.pop(key_to_ignore, None)
                attrs_to_validate = list(attrs_to_validate_dict.keys())

            valid_doc_full_id = f'{valid_doc.collection_id} @ {valid_doc.key}'
            doc_with_same_full_id = full_id_to_doc_dict.get(valid_doc_full_id)
            assert_not_none(doc_with_same_full_id,
                "Could not find a corresponding document for the validation document with the full id " \
                    f"{valid_doc_full_id}")

            common_utils._assert_docs_equal(valid_doc, full_id_to_doc_dict[valid_doc_full_id], attrs_to_validate)


    @staticmethod
    @keyword(types=[List[Document]])
    def sort_list_of_documents(docs: List[Document]):
        """Sort a list of documents based on their collection ids and keys."""
        docs.sort(key=lambda x: (x.collection_id, x.key))


    @keyword(types=[str, str, str])
    def get_vbucket_uuids(self, bucket: str, username: str, password: str):
        """Uses cbstats to create a list of vBucket UUIDs."""
        process_results = subprocess.run([join(self.BIN_PATH, 'cbstats'), '-u', username, '-p', password, '-b', bucket, '-j',
            'localhost:11999', 'vbucket-details'], capture_output=True, shell=False)
        check_subprocess_status(process_results)
        vbstats = json.loads(process_results.stdout)

        uuids = []
        for i in range(DEFAULT_NUM_OF_VBUCKETS):
            uuids.append(vbstats[f'vb_{i}:uuid'])
        return uuids

    @keyword(types=[List[int], List[int]])
    def all_vbucket_uuids_different(self, a: List[int], b: List[int]):
        """
        a and b are assumed to be list of vBucket UUIDs. Returns true if every item in the list is different to its pair
        """
        if len(a) != len(b):
            return False

        for x, y in zip(a, b):
            if x == y:
                return False
        return True

    @staticmethod
    def _assert_docs_equal(valid_doc: Document, doc: Document, attrs_to_validate):
        """Check if two documents have the same contents and metadata but only for the specified attributes."""
        attributes_dict_1 = vars(valid_doc)
        attributes_dict_2 = vars(doc)
        for attr in attrs_to_validate:
            assert_equal(attributes_dict_1[attr], attributes_dict_2[attr],
                f"Validation document with the full id '{valid_doc.collection_id} @ {valid_doc.key}' and the " \
                    f"corresponding document are not equal for the attribute '{attr}'")


    @staticmethod
    def _get_key_from_full_id(full_id: str):
        """Get a document key from the full id returned by couch_dbdump."""
        id_split = full_id.split(")")
        if len(id_split) != 2:
            logger.debug("Could not extract the key: unexpected full id format for a document with the full id " \
                f"'{full_id}', returning the full id instead")
            return full_id
        return id_split[1]


    @staticmethod
    def _get_collection_id_from_full_id(full_id: str):
        """Get a document collection from the full id returned by couch_dbdump."""
        search_result = re.search('collection:(.*?)(:|\))', full_id) # pylint: disable=anomalous-backslash-in-string
        assert_not_none(search_result,
            f"Failed to get the corresponding collection id from the full document id '{full_id}'")
        assert search_result is not None # Required to pass the mypy static typing check
        collection_id = int(search_result.group(1), 16)
        return collection_id


    @staticmethod
    def _replace_match(match_object):
        """Replace the raw hex values with strings and remove unnecessary whitespaces where hex values are replaced."""
        matched_bytes = match_object.group(0)
        # Remove all whitespaces between the colon and the value, and add a double quotation mark before the value
        matched_bytes = re.sub(b'":\s*', b'":"', matched_bytes, 1) # pylint: disable=anomalous-backslash-in-string
        return matched_bytes + b'"'
