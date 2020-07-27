"""This contain miscelaneous utility funtions used by the tests"""
import random
import string
import json
from typing import Dict, Union, List

from robot.api.deco import keyword
from robot.api import logger


ROBOT_AUTO_KEYWORDS = False


@keyword(types=[int, str, str])
def generate_random_string(length: int = 10, chars: str = string.ascii_letters+string.digits,
                           start_char: str = string.ascii_letters) -> str:
    """Generate a random string of length 'length' where the first character is taken from the start_char string and
    the remainder characters are taken from chars
    """
    if length < 1:
        return ''

    generated = random.choice(start_char)
    length -= 1
    if length > 0:
        generated += ''.join(random.choices(chars, k=length))

    return generated


@keyword
def dictionary_like_equals(first: Union[Dict, str], second: Union[Dict, str], remove_empty: List[str] = []) -> bool:
    """Compare either strings to dictionaries and see if they match"""
    logger.info(f'Comparing {sorted_json_string(first)} == {sorted_json_string(second)} filter: {remove_empty}')
    if sorted_json_string(first, remove_empty) != sorted_json_string(second, remove_empty):
        raise AssertionError(f'{sorted_json_string(first, remove_empty)} != {sorted_json_string(second, remove_empty)}')


def sorted_json_string(dict_like: Union[Dict, str], remove_empty: List[str] = []) -> str:
    """Convert a dictionary or a string into a key sorted JSON string"""
    val = dict_like
    if isinstance(val, str):
        val = json.loads(val)
    for remove in remove_empty:
        if remove in val and (val[remove] == '' or val[remove] is None):
            del val[remove]
    return json.dumps(val, sort_keys=True)
