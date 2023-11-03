"""This file contains the Document class definition."""

from typing import Dict, Optional
from robot.utils.asserts import assert_not_none

class Document: # pylint: disable=invalid-name
    """Class of objects that represent documents of different types that can be stored in a Couchbase cluster."""
    def __init__(self, key: Optional[str] = None, data: Dict = {}, metadata: Dict = {},
            data_type: Optional[int] = None, collection_id: Optional[int] = None):
        self.key = key
        self.data = data
        self.metadata = metadata
        self.data_type = data_type
        self.collection_id = collection_id


    def is_json(self):
        """Determine if a document is a valid JSON document.

        The document type is treated as a binary mask, where the first bit is set to 1 if a document is JSON.
        """
        return is_kth_bit_set(self.data_type, 0)


    def is_compressed(self):
        """Determine if a document is compressed.

        The document type is treated as a binary mask, where the second bit is set to 1 if a document is compressed.
        """
        return is_kth_bit_set(self.data_type, 1)


    def has_xattrs(self):
        """Determine if a document has extra attributes.

        The document type is treated as a binary mask, where the third bit is set to 1 if a document has extra
        attributes.
        """
        return is_kth_bit_set(self.data_type, 2)


    def __eq__(self, other: object):
        if not isinstance(other, Document):
            return False

        # Compare two Documents as dictionaries
        return vars(self) == vars(other)


def is_kth_bit_set(int_num: int, k: int):
    """Check if the k-th bit is set in a binary representation of an integer number."""
    return bool(int_num & (1 << k))
