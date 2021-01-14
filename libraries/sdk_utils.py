"""This file contains functions that define keywords needed for the cbbackupmgr testing."""

import time
import json
from typing import Dict, List, Optional

from couchbase.cluster import Cluster, ClusterOptions, QueryOptions
from couchbase.analytics import AnalyticsOptions, AnalyticsDataset, AnalyticsIndex, AnalyticsDataType
from couchbase.search import SearchQuery, SearchOptions, PrefixQuery
from couchbase.management.search import UpsertSearchIndexOptions, SearchIndex
from couchbase.management.queries import QueryIndexManager, CreatePrimaryQueryIndexOptions
from couchbase.management.analytics import AnalyticsIndexManager, CreateDatasetOptions
from couchbase.exceptions import NetworkException
from couchbase_core.cluster import PasswordAuthenticator

from robot.api.deco import keyword
from robot.api import logger


@keyword(types=[str, str, str, str])
def drop_gsi_indexes(host: str = "http://localhost:9000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd"):
    """Drops any GSI in the cluster."""
    cluster = Cluster(host, ClusterOptions(PasswordAuthenticator(user, password)))
    cb = cluster.bucket(bucket) # pylint: disable=unused-variable
    index_mgr = cluster.query_indexes()
    for idx in get_all_indexes_with_retry(index_mgr, service="gsi", bucket=bucket):
        if idx.name == "#primary":
            index_mgr.drop_primary_index(bucket)
            wait_for_index_to_be_dropped(index_mgr, "#primary", service="gsi", bucket=bucket)
    cluster.disconnect()


@keyword(types=[QueryIndexManager, str, str, str, str])
def load_index_data(mgr: Optional[QueryIndexManager] = None, host: str = "http://localhost:9000",
        bucket: str = "default", user: str = "Administrator", password: str = "asdasd"):
    """Creates a query index and waits for it to be built."""
    cluster = Cluster(host, ClusterOptions(PasswordAuthenticator(user, password)))
    cb = cluster.bucket(bucket) # pylint: disable=unused-variable
    index_mgr = cluster.query_indexes() if mgr is None else mgr
    index_mgr.create_primary_index(bucket, CreatePrimaryQueryIndexOptions(ignore_if_exists=True))
    for _ in range(120):
        time.sleep(1)
        result = cluster.query("SELECT * FROM system:indexes WHERE name='#primary';")
        for row in result:
            if row["indexes"]["state"] == "online":
                cluster.disconnect()
                return
    cluster.disconnect()
    raise AssertionError("Index failed to build in 120 seconds")


@keyword(types=[str, str, str, str, str, str, str])
def load_analytics_data(host: str = "http://localhost:9000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd", dataset: str = "analytics_data",
        name: str = "analytics_index", field: str = "name"):
    """Creates an analytics dataset and index and waits for them to be built."""
    cluster = Cluster(host, ClusterOptions(PasswordAuthenticator(user, password)))
    cb = cluster.bucket(bucket) # pylint: disable=unused-variable
    analytics_mgr = cluster.analytics_indexes()
    analytics_mgr.create_dataset(dataset, "default", CreateDatasetOptions(ignore_if_exists=True))
    analytics_mgr.create_index(name, dataset, {field:AnalyticsDataType.STRING})
    for _ in range(120):
        time.sleep(1)
        for idx in analytics_mgr.get_all_indexes():
            if idx["IndexName"] == "analytics_index":
                cluster.disconnect()
                return
    cluster.disconnect()
    raise AssertionError("Analytics index failed to build in 120 seconds")


@keyword(types=[str, str, str, str])
def load_fts_data(host: str = "http://localhost:9000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd"):
    """Creates a full-text search index and waits for it to be built."""
    cluster = Cluster(host, ClusterOptions(PasswordAuthenticator(user, password)))
    cb = cluster.bucket(bucket) # pylint: disable=unused-variable
    fts_mgr = cluster.search_indexes()
    fts_index = get_index()
    fts_mgr.upsert_index(fts_index)
    for _ in range(120):
        time.sleep(1)
        result = cluster.query("SELECT * FROM system:indexes WHERE name='fts_index';")
        for row in result:
            if row["indexes"]["state"] == "online":
                cluster.disconnect()
                return
    cluster.disconnect()
    raise AssertionError("FTS index failed to build in 120 seconds")


@keyword(types=[str, str, str, str, str])
def check_indexes(host: str = "http://localhost:9000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd", service: str = "gsi"):
    """Uses the Couchbase SDK to get all indexes and checks that those indexes are all using the
    correct service."""
    cluster = Cluster(host, ClusterOptions(PasswordAuthenticator(user, password)))
    cb = cluster.bucket(bucket) # pylint: disable=unused-variable
    index_mgr = cluster.query_indexes()
    fts_mgr = cluster.search_indexes()
    analytics_mgr = cluster.analytics_indexes()

    index_not_exist = check_index_does_not_exist(index_mgr, "#primary", service="gsi", bucket=bucket)
    search_index_not_exist = check_index_does_not_exist(fts_mgr,"fts_index", service="fts")
    analytics_index_not_exist = check_index_does_not_exist(analytics_mgr,"analytics_index", service="analytics")

    cluster.disconnect()

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


@keyword(types=[str, str, str, str])
def drop_all_indexes(host: str = "http://localhost:9000", bucket: str = "default",
        user: str = "Administrator", password: str = "asdasd"):
    """Drops all types of index that exist in the cluster."""
    cluster = Cluster(host, ClusterOptions(PasswordAuthenticator(user, password)))
    cb = cluster.bucket(bucket) # pylint: disable=unused-variable
    index_mgr = cluster.query_indexes()
    fts_mgr = cluster.search_indexes()
    analytics_mgr = cluster.analytics_indexes()

    for idx in get_all_indexes_with_retry(index_mgr, service="gsi", bucket=bucket):
        if idx.name == "#primary":
            index_mgr.drop_primary_index(bucket)
            wait_for_index_to_be_dropped(index_mgr, "#primary", service="gsi", bucket=bucket)

    for idx in get_all_indexes_with_retry(fts_mgr):
        if idx["name"] == "fts_index":
            fts_mgr.drop_index("fts_index")
            wait_for_index_to_be_dropped(fts_mgr,"fts_index", service="fts")

    for idx in get_all_indexes_with_retry(analytics_mgr):
        if idx["IndexName"] == "analytics_index":
            analytics_mgr.drop_index("analytics_index","analytics_data")
            analytics_mgr.drop_dataset("analytics_data")
            wait_for_index_to_be_dropped(analytics_mgr,"analytics_index", service="analytics")

    cluster.disconnect()


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
            if idx["name"] == name:
                return False

    elif service == "analytics":
        for idx in get_all_indexes_with_retry(mgr):
            if idx["IndexName"] == name:
                return False

    return True


def get_all_indexes_with_retry(mgr, service: Optional[str] = None, bucket: Optional[str] = None):
    """Retries getting all indexes up to ten times or until a result is returned."""
    for i in range(10):
        try:
            if service == "gsi":
                return mgr.get_all_indexes(bucket)
            return mgr.get_all_indexes()
        except NetworkException as e:
            logger.debug(f"{e}: Failed to get indexes, will retry {10-i} more times")
            time.sleep(1)

    raise AssertionError("Failed to retrieve indexes")


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
    return SearchIndex(name,"fulltext-index","default","",params,"",{},"couchbase",plan_params)


@keyword(types=[str, str, str])
def create_eventing_file(source_bucket: str = "default", meta_bucket: str = "meta", func_name: str = "eventing_func"):
    """Creates a simple eventing function file. A function can be used to process and respond to data
    changes; this function logs a document's ID to the meta bucket whenever the document is updated."""
    false = False
    data =  [{"appcode":"function OnUpdate(doc, meta) \
            {\n    log('docId', meta.id);\n}\nfunction OnDelete(meta, options){\n}",
            "depcfg":{"buckets":[],"curl":[],"metadata_bucket":meta_bucket,"source_bucket":source_bucket},
            "appname":func_name,
            "settings":{
            "dcp_stream_boundary":"everything",
            "deadline_timeout":62,
            "deployment__status":false,
            "description":"",
            "execution_timeout":60,
            "language_compatibility":"6.5.0",
            "log_level":"INFO",
            "n1ql_consistency":"none",
            "processing_status":false,
            "user_prefix":"eventing",
            "using_timer":false,
            "worker_count":3
            },
            "using_timer":false,
            "src_mutation":false
            }]
    with open("eventing_function.txt", "w") as outfile:
        json.dump(data, outfile)
