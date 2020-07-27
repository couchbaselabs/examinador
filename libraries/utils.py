"""This contain miscelaneous utility funtions used by the tests"""
import random
import string
from robot.api.deco import keyword


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
