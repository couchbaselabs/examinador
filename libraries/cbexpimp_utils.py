
"""This file contains functions that define keywords needed for the cbimport/cbexport/cbdocloader testing."""

import json
import subprocess
import random
import string
from enum import Enum, auto
from os.path import join
from typing import Dict, List

import sdk_utils
import utils

from robot.api.deco import keyword
from robot.api.deco import library
from robot.utils.asserts import assert_equal
from robot.utils.asserts import fail


ROBOT_AUTO_KEYWORDS = False

class file_format(Enum):
    """Enumeration for data formats."""
    JSON_LINES = auto()
    JSON_LIST = auto()
    CSV = auto()
    TSV = auto()
    BINARY = auto()
    MIXED = auto()

@library
class cbexpimp_utils:
    """Keywords needed for cbimport/cbexport/cbdocloader testing."""
    ROBOT_LIBRARY_SCOPE = 'SUITE'

    def __init__(self, bin_path: str, temp_data_dir: str):
        self.BIN_PATH = bin_path
        self.temp_data_dir = temp_data_dir


    @keyword(types=[str, str, str, str, str, str, int])
    def run_export_json(self, export_file: str, host: str = "http://localhost:9000", bucket: str = "default",
            user: str = "Administrator", password: str = "asdasd", format_out: str = "list", timeout_value: int = 120,
            **kwargs):
        """This function runs export in json format."""
        other_args = sdk_utils.format_flags(kwargs)
        command = [join(self.BIN_PATH, 'cbexport'), 'json', '-c', host, '-u', user, '-p', password,
            '-b', bucket, '-f', format_out, '-o', join(self.temp_data_dir, export_file)] + other_args
        _run_subprocess(command, capture_output=True, shell=False, timeout=timeout_value)


    @keyword(types=[str, str, str, str, str, str, int])
    def run_import_json(self, import_path: str, host: str = "http://localhost:9000", #pylint: disable=too-many-arguments
            bucket: str = "default", user: str = "Administrator", password: str = "asdasd", format_in: str = "list",
            timeout_value: int = 120, check_subcommand_exitcode: bool = True, **kwargs):
        """This function runs import in json format."""
        other_args = sdk_utils.format_flags(kwargs)
        command = [join(self.BIN_PATH, 'cbimport'), 'json', '-c', host, '-u', user, '-p', password,
            '-b', bucket, '-f', format_in, '-d', "file://" + import_path] + other_args
        _run_subprocess(command, capture_output=True, shell=False, timeout=timeout_value,
                        fail_on_nonzero_exitcode=check_subcommand_exitcode)


    @keyword(types=[str, str, str, str, str, str, int])
    def run_import_csv(self, import_path: str, host: str = "http://localhost:9000", #pylint: disable=too-many-arguments
            bucket: str = "default", user: str = "Administrator", password: str = "asdasd", key_gen: str = "%num%",
            timeout_value: int = 120, check_subcommand_exitcode: bool = True, **kwargs):
        """This function runs import in csv format."""
        other_args = sdk_utils.format_flags(kwargs)
        command = [join(self.BIN_PATH, 'cbimport'), 'csv', '-c', host, '-u', user, '-p', password,
            '-b', bucket, '-g', key_gen, '-d', "file://" + import_path] + other_args
        _run_subprocess(command, capture_output=True, shell=False, timeout=timeout_value,
                        fail_on_nonzero_exitcode=check_subcommand_exitcode)


    @keyword(types=[str, str, str, str, str, str, int])
    def run_docloader(self, import_path: str, host: str = "http://localhost:9000", bucket: str = "default",
            user: str = "Administrator", password: str = "asdasd", mem_quota: str = "100", timeout_value: int = 120,
            **kwargs):
        """This function runs sample import using cbdocloader."""
        other_args = sdk_utils.format_flags(kwargs)
        command = [join(self.BIN_PATH, 'cbdocloader'), '-c', host, '-u', user, '-p', password,
            '-b', bucket, '-m', mem_quota, '-d', import_path] + other_args
        _run_subprocess(command, capture_output=True, shell=False, timeout=timeout_value)


    @keyword(types=[str, int, str])
    def check_exported_json_data_contents(self, file_name: str, expected_length: int, group: str):
        """This function checks that export was successful and no contents were changed as a result."""
        with open(join(self.temp_data_dir, file_name), "r", encoding="utf-8") as read_file:
            data = json.load(read_file)
        utils.check_simple_data_contents(data, expected_length, group)
        utils.check_all_nums_distinct(data, expected_length)


    @keyword(types=[List[Dict], int, str])
    def check_imported_data_contents(self, data: List[Dict], expected_length: int, group: str):
        """This function checks that import was successful and no contents were changed as a result."""
        utils.check_simple_data_contents(data, expected_length, group)
        utils.check_all_nums_distinct(data, expected_length)


    @keyword(types=[str, str, str, str, int, int])
    def check_views(self, host: str = "http://localhost:12000", bucket: str = "default", user: str = "Administrator",
            password: str = "asdasd", expected_num_design_docs: int = 1, expected_num_views: int = 2):
        """This function checks that all views were imported correctly."""
        cluster, cb = sdk_utils.connect_to_cluster(host, user, password, bucket)
        view_mgr = cb.view_indexes()

        design_docs = view_mgr.get_all_design_documents(sdk_utils.DesignDocumentNamespace.PRODUCTION) \
                      + view_mgr.get_all_design_documents(sdk_utils.DesignDocumentNamespace.DEVELOPMENT)
        cluster.close()

        num_design_docs = len(design_docs)
        assert_equal(num_design_docs, expected_num_design_docs, "Views contents changed: unexpected number of design \
                    docs")

        num_views = sum(len(doc.views) for doc in design_docs)

        assert_equal(num_views, expected_num_views, "Views contents changed: unexpected number of views")


    @keyword(types=[str, file_format, int, str])
    def generate_simple_data(self, output_path: str, #pylint: disable=inconsistent-return-statements
            format_out: file_format, num_items: int = 2048, group: str = "example", num_binary_in_mixed: int = 148):
        """This function generates and writes simple data for import testing."""
        if format_out == file_format.JSON_LINES:
            return generate_and_write_simple_data_json_lines(output_path, num_items, group)
        if format_out == file_format.JSON_LIST:
            return generate_and_write_simple_data_json_list(output_path, num_items, group)
        if format_out == file_format.CSV:
            return generate_and_write_simple_data_csv(output_path, num_items, group)
        if format_out == file_format.TSV:
            return generate_and_write_simple_data_tsv(output_path, num_items, group)
        if format_out == file_format.BINARY:
            return write_simple_data_binary(output_path)
        if format_out == file_format.MIXED:
            return generate_and_write_mixed_data(output_path, num_items, group, num_binary_in_mixed)
        fail("Unexpected output format")


def _run_subprocess(command_as_list: list, capture_output: bool = True, shell: bool = False, timeout: int = 120,
        log_results: bool = True, fail_on_nonzero_exitcode: bool = True):
    complete = subprocess.run(command_as_list, capture_output=capture_output, shell=shell, timeout=timeout)
    if log_results:
        utils.log_subprocess_run_results(complete)
    if fail_on_nonzero_exitcode:
        utils.check_subprocess_status(complete)


def generate_and_write_simple_data_json_lines(output_path: str, num_items: int = 2048, group: str = "example"):
    """Generates and writes simple JSON data."""
    file_name = "simple_import_data_lines.json"
    with open(join(output_path, file_name), "w", encoding="utf-8") as file:
        items_nums = list(range(0, num_items))
        random.shuffle(items_nums)

        for item in items_nums:
            file.write(f'{{"group":"{group}","num":{item}}}\n')

    return file_name


def generate_and_write_simple_data_json_list(output_path: str, num_items: int = 2048, group: str = "example"):
    """Generates and writes simple JSON data."""
    file_name = "simple_import_data_list.json"
    with open(join(output_path, file_name), "w", encoding="utf-8") as file:
        items_nums = list(range(0, num_items))
        random.shuffle(items_nums)

        file.write("[\n")
        for idx, item in enumerate(items_nums):
            if idx != len(items_nums) - 1:
                file.write(f'{{"group":"{group}","num":{item}}},\n')
            else:
                file.write(f'{{"group":"{group}","num":{item}}}')
        file.write("\n]")

    return file_name


def generate_and_write_simple_data_csv(output_path: str, num_items: int = 2048, group: str = "example"):
    """Generates and writes simple CSV data."""
    file_name = "simple_import_data.csv"
    with open(join(output_path, file_name), "w", encoding="utf-8") as file:
        items_nums = list(range(0, num_items))
        random.shuffle(items_nums)

        file.write("group,num\n")
        for item in items_nums:
            file.write(f'{group},{item}\n')

    return file_name


def generate_and_write_simple_data_tsv(output_path: str, num_items: int = 2048, group: str = "example"):
    """Generates and writes simple TSV data."""
    file_name = "simple_import_data.tsv"
    with open(join(output_path, file_name), "w", encoding="utf-8") as file:
        items_nums = list(range(0, num_items))
        random.shuffle(items_nums)

        file.write("group\tnum\n")
        for item in items_nums:
            file.write(f'{group}\t{item}\n')

    return file_name


def write_simple_data_binary(output_path: str):
    """Writes pre-defined simple binary data."""
    file_name = "simple_import_data_binary.json"
    with open(join(output_path, file_name), "w", encoding="utf-8") as file:
        test_cases_list = []
        # TEST CASE 1: simple unformatted single-word string
        test_cases_list.append("test\n")
        # TEST CASE 2: empty line
        test_cases_list.append("\n")
        # TEST CASE 3: simple unformatted several-word string
        test_cases_list.append("this is a test binary document\n")
        # TEST CASE 4: binary document enclosed in curly brackets
        test_cases_list.append("{this is a test binary document}\n")
        # TEST CASE 5.1: ill-formatted json
        test_cases_list.append('{group:bad, num:1}\n')
        # TEST CASE 5.2: ill-formatted json
        test_cases_list.append('{group:"bad","num":"1"}\n')
        # TEST CASE 5.4: ill-formatted json
        test_cases_list.append('{"group":bad,"num":"1"}\n')
        # TEST CASE 5.5: ill-formatted json
        test_cases_list.append('{"group":"bad",num:"1"}\n')
        # TEST CASE 5.6: ill-formatted json
        test_cases_list.append('{"group":"bad","num":1}\n')
        # TEST CASE 5.7: ill-formatted json
        test_cases_list.append('{"group":"bad","num":"1"\n')

        for item in test_cases_list:
            file.write(item)

    return file_name


def generate_and_write_mixed_data(output_path: str, num_items: int = 2048, group: str = "example",
        num_binary_in_mixed: int = 148):
    """Generates and writes mixed JSON and binary data."""
    file_name = "mixed_import_data.json"
    with open(join(output_path, file_name), "w", encoding="utf-8") as file:
        if num_items < num_binary_in_mixed:
            fail("Specified number of binary docs is greater than the total number of docs")

        items_nums = list(range(0, num_items - num_binary_in_mixed))
        docs = []
        for item in items_nums:
            docs.append(f'{{"group":"{group}","num":{item}}}\n')
        for _ in range(num_binary_in_mixed):
            docs.append(''.join(random.choice(string.ascii_letters) for _ in range(random.randint(5, 20))) + '\n')

        random.shuffle(docs)

        for doc in docs:
            file.write(doc)

    return file_name
