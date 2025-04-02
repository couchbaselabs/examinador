"""This file contains functions that define keywords needed for the cbbackupmgr testing."""

import time
import json
import traceback
from typing import List, Optional
from datetime import timedelta
from utils import log_to_log_file_and_console

from couchbase.cluster import Cluster
from couchbase.exceptions import InternalServerFailureException, AmbiguousTimeoutException
from couchbase.options import ClusterOptions, PingOptions, ClusterTimeoutOptions
from couchbase.management.logic.analytics_logic import AnalyticsDataType
from couchbase.management.search import SearchIndex
from couchbase.management.queries import QueryIndexManager, CreatePrimaryQueryIndexOptions
from couchbase.management.analytics import CreateDatasetOptions
from couchbase.management.views import DesignDocumentNamespace
from couchbase.exceptions import CouchbaseException
from couchbase.diagnostics import ServiceType, PingState
from couchbase.auth import PasswordAuthenticator

from robot.api.deco import keyword
from robot.api import logger
from robot.utils.asserts import assert_equal

@keyword(types=[str, dict, str, str, str, str])
def sdk_replace(key: str, value: dict, host: str = "http://localhost:12000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd"):
    """This function uses the Couchbase SDK to replace a value with a new given value for the document of the
    given key."""
    cluster, cb = connect_to_cluster(host, user, password, bucket)
    result = cb.default_collection().replace(key, value)
    cluster.close()
    if not result.success:
        raise AssertionError(result.success, result.args, result.stdout)


@keyword(types=[str, str, str, str])
def drop_gsi_indexes(host: str = "http://localhost:12000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd"):
    """Drops any GSI in the cluster."""
    cluster, cb = connect_to_cluster(host, user, password, bucket) # pylint: disable=unused-variable
    index_mgr = cluster.query_indexes()
    for idx in get_all_indexes_with_retry(index_mgr, service="gsi", bucket=bucket):
        if idx.name == "#primary":
            index_mgr.drop_primary_index(bucket)
            wait_for_index_to_be_dropped(index_mgr, "#primary", service="gsi", bucket=bucket)
    cluster.close()


@keyword(types=[int, str, str, str, str, str, str])
def load_docs_sdk(items: int = 2048, key_pref: str = "pymc", group: str = "group", host: str = "http://localhost:12000",
        bucket: str = "default", user: str = "Administrator", password: str = "asdasd"):
    """Creates a query index and waits for it to be built."""
    cluster, cb = connect_to_cluster(host, user, password, bucket)
    for i in range(items):
        doc = {"group": group, "id": i}
        cb.default_collection().upsert(key_pref+str(i), doc)
    cluster.close()


@keyword(types=[QueryIndexManager, str, str, str, str])
def load_index_data(mgr: Optional[QueryIndexManager] = None, host: str = "http://localhost:12000",
        bucket: str = "default", user: str = "Administrator", password: str = "asdasd"):
    """Creates a query index and waits for it to be built."""
    cluster, cb = connect_to_cluster(host, user, password, bucket) # pylint: disable=unused-variable
    index_mgr = cluster.query_indexes() if mgr is None else mgr
    for _ in range(60):
        try:
            index_mgr.create_primary_index(bucket, CreatePrimaryQueryIndexOptions(ignore_if_exists=True))
            break
        except (InternalServerFailureException, AmbiguousTimeoutException):
            time.sleep(1)

    for _ in range(120):
        time.sleep(1)
        for idx in index_mgr.get_all_indexes(bucket):
            log_to_log_file_and_console(f'Index "{idx.name}" - {idx.state}')
            if idx.name == "#primary" and idx.state == "online":
                cluster.close()
                return
    cluster.close()
    raise AssertionError("Index failed to build in 120 seconds")


@keyword(types=[str, str, str, str, str, str, str])
def load_analytics_data(host: str = "http://localhost:12000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd", dataset: str = "analytics_data",
        name: str = "analytics_index", field: str = "name"):
    """Creates an analytics dataset and index and waits for them to be built."""
    cluster, cb = connect_to_cluster(host, user, password, bucket) # pylint: disable=unused-variable
    analytics_mgr = cluster.analytics_indexes()
    analytics_mgr.create_dataset(dataset, "default", CreateDatasetOptions(ignore_if_exists=True))
    analytics_mgr.create_index(name, dataset, {field:AnalyticsDataType.STRING})
    for _ in range(120):
        time.sleep(1)
        for idx in analytics_mgr.get_all_indexes():
            if idx.name == "analytics_index":
                cluster.close()
                return
    cluster.close()
    raise AssertionError("Analytics index failed to build in 120 seconds")


@keyword(types=[str, str, str, str])
def load_fts_data(host: str = "http://localhost:12000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd"):
    """Creates a full-text search index and waits for it to be built."""
    cluster, cb = connect_to_cluster(host, user, password, bucket) # pylint: disable=unused-variable
    fts_mgr = cluster.search_indexes()
    fts_index = get_index()
    fts_mgr.upsert_index(fts_index)
    for _ in range(120):
        time.sleep(1)
        for idx in fts_mgr.get_all_indexes():
            if idx.name == "fts_index":
                cluster.close()
                return
    cluster.close()
    raise AssertionError("FTS index failed to build in 120 seconds")


@keyword(types=[str, str, str, str, str])
def check_indexes(host: str = "http://localhost:12000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd", service: str = "gsi"):
    """Uses the Couchbase SDK to get all indexes and checks that those indexes are all using the
    correct service."""
    cluster, cb = connect_to_cluster(host, user, password, bucket) # pylint: disable=unused-variable
    index_mgr = cluster.query_indexes()
    fts_mgr = cluster.search_indexes()
    analytics_mgr = cluster.analytics_indexes()

    index_not_exist = check_index_does_not_exist(index_mgr, "#primary", service="gsi", bucket=bucket)
    search_index_not_exist = check_index_does_not_exist(fts_mgr,"fts_index", service="fts")
    analytics_index_not_exist = check_index_does_not_exist(analytics_mgr,"analytics_index", service="analytics")

    cluster.close()

    if not index_not_exist and service != "gsi":
        raise AssertionError("Index from wrong service restored: gsi")
    if index_not_exist and service == "gsi":
        raise AssertionError("GSI not restored")
    if not search_index_not_exist and service != "fts":
        raise AssertionError("Index from wrong service restored: fts")
    if search_index_not_exist and service == "fts":
        raise AssertionError("FTS index not restored")
    if not analytics_index_not_exist and service != "analytics":
        raise AssertionError("Index from wrong service restored: analytics")
    if analytics_index_not_exist and service == "analytics":
        raise AssertionError("Analytics index not restored")


def get_all_indexes_collection_aware(host: str = "http://localhost:12000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd"):
    """Gets all indexes (collection aware)."""
    cluster, cb = connect_to_cluster(host, user, password, bucket) # pylint: disable=unused-variable
    indexes = cluster.query(
        f"SELECT idx.* FROM system:indexes AS idx where bucket_id = '{bucket}' or keyspace_id = '{bucket}'")

    return indexes


@keyword(types=[str, str, str, str])
def get_number_of_indexes_collection_aware(host: str = "http://localhost:12000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd"):
    """This function will use the Couchbase SDK to get all of the indexes (collection aware)."""
    num_of_indexes = len(list(get_all_indexes_collection_aware(host, bucket, user, password)))

    return num_of_indexes


@keyword(types=[str, str, str, str])
def check_all_indexes_have_been_built_collection_aware(host: str = "http://localhost:12000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd"):
    """Checks that all of the indexes have been built (collection aware)."""
    num_of_tries = 24
    sleep_time = 5
    for i in range(num_of_tries):
        indexes = get_all_indexes_collection_aware(host, bucket, user, password)
        is_built = True
        for idx_dict in indexes:
            if idx_dict["state"] != "online":
                logger.debug(f'Not all indexes have been built, index with name {idx_dict["name"]} is in state \
                    {idx_dict["state"]}')
                is_built = False
                break

        if is_built:
            return
        if i != num_of_tries - 1:
            time.sleep(sleep_time)
    raise AssertionError(f"Imported indexes failed to be built in {num_of_tries * sleep_time} seconds")


@keyword(types=[str, str, str, str])
def drop_all_indexes(host: str = "http://localhost:12000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd"):
    """Drops all types of index that exist in the cluster."""
    cluster, cb = connect_to_cluster(host, user, password, bucket) # pylint: disable=unused-variable
    index_mgr = cluster.query_indexes()
    fts_mgr = cluster.search_indexes()
    analytics_mgr = cluster.analytics_indexes()

    for idx in get_all_indexes_with_retry(index_mgr, service="gsi", bucket=bucket):
        if idx.name == "#primary":
            index_mgr.drop_primary_index(bucket)
            wait_for_index_to_be_dropped(index_mgr, "#primary", service="gsi", bucket=bucket)

    for idx in get_all_indexes_with_retry(fts_mgr):
        if idx.name== "fts_index":
            fts_mgr.drop_index("fts_index")
            wait_for_index_to_be_dropped(fts_mgr,"fts_index", service="fts")

    for idx in get_all_indexes_with_retry(analytics_mgr):
        if idx.name == "analytics_index":
            analytics_mgr.drop_index("analytics_index","analytics_data")
            analytics_mgr.drop_dataset("analytics_data")
            wait_for_index_to_be_dropped(analytics_mgr,"analytics_index", service="analytics")

    cluster.close()


def drop_index_collection_aware(cluster: Cluster, name: str, bucket: str = "default", scope: str = "_default",
        collection: str = "_default"):
    """Drops the specified index (collection aware)."""
    result = cluster.query(f'DROP INDEX {name} ON {bucket}.{scope}.{collection};')
    logger.debug("Query status:" + str(result.metadata()))


@keyword(types=[str, str, str, str])
def drop_all_indexes_collection_aware(host: str = "http://localhost:12000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd"):
    """Drops all indexes for a specified bucket (collection aware)."""
    indexes = get_all_indexes_collection_aware(host, bucket, user, password)
    cluster, cb = connect_to_cluster(host, user, password, bucket) # pylint: disable=unused-variable
    for idx_dict in indexes:
        name = idx_dict["name"]
        keyspace = idx_dict["keyspace_id"]
        if keyspace != bucket:
            drop_index_collection_aware(cluster, name, bucket=bucket,
                                        scope=idx_dict["scope_id"], collection=keyspace)
        else:
            drop_index_collection_aware(cluster, name, bucket=bucket)

    cluster.close()

    for _ in range(120):
        remaining_idx_num = get_number_of_indexes_collection_aware(host, bucket, user, password)
        if remaining_idx_num == 0:
            break
        time.sleep(1)

    assert_equal(remaining_idx_num, 0, "Failed to drop all bucket indexes after 30 seconds")


def wait_for_index_to_be_dropped(mgr, name: str, service: str, bucket: Optional[str] = None):
    """Waits until the given index has been dropped."""
    for _ in range(60):
        if check_index_does_not_exist(mgr, name, service, bucket):
            return
        time.sleep(1)
    raise AssertionError("Timeout: Index failed to be dropped after 60s")


def check_index_does_not_exist(mgr, name: str, service: str, bucket: Optional[str] = None):
    """Checks there is no object with the given name that is of the given type."""
    if service == "gsi":
        for idx in get_all_indexes_with_retry(mgr, service, bucket):
            if idx.name == name:
                return False

    elif service == "fts":
        for idx in get_all_indexes_with_retry(mgr):
            if idx.name == name:
                return False

    elif service == "analytics":
        for idx in get_all_indexes_with_retry(mgr):
            if idx.name == name:
                return False

    return True


def get_all_indexes_with_retry(mgr, service: Optional[str] = None, #pylint: disable=inconsistent-return-statements
        bucket: Optional[str] = None):
    """Retries getting all indexes up to ten times or until a result is returned."""
    for i in range(10):
        try:
            if service == "gsi":
                return mgr.get_all_indexes(bucket)
            return mgr.get_all_indexes()
        except CouchbaseException as e:
            logger.debug(f"{e}: Failed to get indexes, will retry {10-i} more times")
            time.sleep(1)

    raise AssertionError("Failed to retrieve indexes")


@keyword(types=[str, str, str, str])
def drop_all_design_docs(host: str = "http://localhost:12000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd"):
    """Drops all design docs that exist in a bucket."""
    cluster, cb = connect_to_cluster(host, user, password, bucket)
    view_mgr = cb.view_indexes()

    for namespace in [DesignDocumentNamespace.PRODUCTION, DesignDocumentNamespace.DEVELOPMENT]:
        docs = get_all_design_docs_with_retry(view_mgr, namespace)
        for doc in docs:
            view_mgr.drop_design_document(doc.name, namespace)
            wait_for_design_doc_to_be_dropped(view_mgr, doc.name, namespace)

    new_docs_num = 0
    for namespace in [DesignDocumentNamespace.PRODUCTION, DesignDocumentNamespace.DEVELOPMENT]:
        new_docs_num += len(get_all_design_docs_with_retry(view_mgr, namespace))
    if new_docs_num != 0:
        raise AssertionError("Not all design docs have been dropped")

    cluster.close()


def get_all_design_docs_with_retry(mgr, namespace): #pylint: disable=inconsistent-return-statements
    """Retries getting all design docs up to ten times or until a result is returned."""
    for i in range(10):
        try:
            docs = mgr.get_all_design_documents(namespace)
            return docs
        except CouchbaseException as e:
            logger.debug(f"{e}: Failed to get design docs, will retry {10-i} more times")
            time.sleep(1)

    raise AssertionError("Failed to retrieve design docs")


def wait_for_design_doc_to_be_dropped(mgr, name, namespace):
    """Waits until the given design doc has been dropped."""
    for _ in range(60):
        if not design_doc_exists(mgr, name, namespace):
            return
        time.sleep(1)
    raise AssertionError("Timeout: Design doc failed to be dropped after 60s")


def design_doc_exists(mgr, name, namespace):
    """Checks there is a design doc with a given name."""
    for doc in get_all_design_docs_with_retry(mgr, namespace):
        if doc.name == name:
            return True
    return False


def connect_to_cluster(host: str, user: str, password: str, bucket: str, #pylint: disable=inconsistent-return-statements
        services: List[ServiceType] =  [ServiceType.Query]):
    """Creates a connection to a cluster and checks its connected to the given services before returning."""
    cluster = Cluster(host, ClusterOptions(
        PasswordAuthenticator(user, password),
        timeout_options=ClusterTimeoutOptions(management_timeout=timedelta(seconds=90),
                                              connect_timeout=timedelta(seconds=15))))
    cb = cluster.bucket(bucket)
    for _ in range(100):
        result = cb.ping(PingOptions(service_types=services))
        ready = True
        for service in services:
            try:
                if result.endpoints[service][0].state != PingState.OK:
                    ready = False
            except (KeyError, IndexError) as e:
                raise AssertionError(f"Service {service.value} not available") from e
        if ready:
            return cluster, cb
        time.sleep(1)
    raise AssertionError("Failed to connect to cluster")


@keyword(types=[str, str, str, str])
def get_doc_info(host: str = "http://localhost:12000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd"):
    """This function will use the Couchbase SDK to get the contents of the bucket."""
    cluster, cb = connect_to_cluster(host, user, password, bucket) # pylint: disable=unused-variable
    mgr = cluster.query_indexes()
    load_index_data(mgr, bucket=bucket)

    result = cluster.query(f"SELECT * FROM {bucket};")

    doc_list = [row[bucket] for row in result]

    mgr.drop_primary_index(bucket)
    wait_for_index_to_be_dropped(mgr, '#primary', service="gsi", bucket=bucket)
    cluster.close()

    return doc_list


def format_flags(kwargs):
    """Format extra flags into a list."""
    other_args = []
    for flag in kwargs:
        other_args.append(f'--{flag}')
        if kwargs.get(flag) != 'None':
            other_args.append(kwargs.get(flag))
    return other_args


@keyword(types=[str, str, str])
def get_index(name: str = "fts_index", field_name: str = "group", field_type: str = "text"):
    """Returns an object of type SearchIndex."""
    true = True
    false = False
    null = None
    params = {
      "doc_config": {
        "docid_prefix_delim": "",
        "docid_regexp": null,
        "mode": "type_field",
        "type_field": "type"
      },
      "mapping": {
        "default_analyzer": "standard",
        "default_datetime_parser": "dateTimeOptional",
        "default_field": "_all",
        "default_mapping": {
          "dynamic": true,
          "enabled": false
        },
        "default_type": "_default",
        "index_dynamic": true,
        "store_dynamic": false,
        "types": {
          "product": {
            "dynamic": true,
            "enabled": true,
            "properties": {
              field_name: {
                "enabled": true,
                "dynamic": false,
                "fields": [
                  {
                    "analyzer": "",
                    "include_in_all": true,
                    "include_term_vectors": true,
                    "index": true,
                    "name": field_name,
                    "store": false,
                    "type": field_type
                  }
                ]
              }
            }
          }
        }
      },
      "store": {
        "kvStoreName": "mossStore"
      }
    }
    plan_params = {
      "maxPartitionsPerPIndex": 171,
      "numReplicas": 0,
      "indexPartitions": 6
      }

    return SearchIndex(name=name,
                       idx_type="fulltext-index",
                       source_type="couchbase",
                       source_name="default",
                       params=params,
                       plan_params=plan_params)

@keyword(types=[str, str, str])
def create_eventing_file_legacy(source_bucket: str = "default", meta_bucket: str = "meta",
                                func_name: str = "eventing_func_legacy"):
    """Creates a simple eventing function file. A function can be used to process and respond to data
    changes; this function logs a document's ID to the meta bucket whenever the document is updated."""
    data =  [{"appcode":"function OnUpdate(doc, meta) \
            {\n    log('docId', meta.id);\n}\nfunction OnDelete(meta, options){\n}",
            "depcfg":{"buckets":[],"curl":[],"metadata_bucket":meta_bucket,"source_bucket":source_bucket},
            "appname":func_name,
            "settings":{
            "dcp_stream_boundary":"everything",
            "deadline_timeout":62,
            "deployment__status":False,
            "description":"",
            "execution_timeout":60,
            "language_compatibility":"6.5.0",
            "log_level":"INFO",
            "n1ql_consistency":"none",
            "processing_status":False,
            "user_prefix":"eventing",
            "using_timer":False,
            "worker_count":3
            },
            "using_timer":False,
            "src_mutation":False
            }]
    with open("eventing_function_legacy.txt", "w", encoding="utf-8") as outfile:
        json.dump(data, outfile)

@keyword(types=[str, str, str])
def create_eventing_file(source_bucket: str = "default", meta_bucket: str = "meta", func_name: str = "eventing_func"):
    """Creates a simple eventing function file. A function can be used to process and respond to data
    changes; this function logs a document's ID to the meta bucket whenever the document is updated."""
    data = [{"appcode": "function OnUpdate(doc, meta) \
            {\n    log(\"Doc created/updated\", meta.id);\n}\n\n \
            function OnDelete(meta, options) {\n    log(\"Doc deleted/expired\", meta.id);\n}",
            "depcfg": {
                "source_bucket": source_bucket,
                "source_scope": "_default",
                "source_collection": "_default",
                "metadata_bucket": meta_bucket,
                "metadata_scope": "_default",
                "metadata_collection": "_default"
            },
            "version": "evt-0.0.0-0000-ee",
            "enforce_schema": False,
            "handleruuid": 578797332,
            "function_instance_id": "F0Vej3",
            "appname": func_name,
            "settings": {
                "dcp_stream_boundary": "everything",
                "deployment_status": False,
                "description": "",
                "execution_timeout": 60,
                "language_compatibility": "6.6.2",
                "log_level": "INFO",
                "n1ql_consistency": "none",
                "num_timer_partitions": 128,
                "processing_status": False,
                "timer_context_size": 1024,
                "user_prefix": "eventing",
                "worker_count": 3
            },
            "function_scope": {
                "bucket": source_bucket,
                "scope": "_default"
            }}]

    with open("eventing_function.txt", "w", encoding="utf-8") as outfile:
        json.dump(data, outfile)
