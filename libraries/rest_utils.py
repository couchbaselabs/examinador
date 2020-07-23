"""This file contains functions that do usefull things needed for the REST API testing."""
import base64
from robot.api.deco import keyword


ROBOT_AUTO_KEYWORDS = False


@keyword(types=[str, str])
def get_basic_auth(username: str, password: str) -> str:
    """The function will return the correct string to add to the Authorization header using basic auth."""
    return 'Basic '+base64.b64encode(f'{username}:{password}'.encode('utf-8')).decode('utf-8')
