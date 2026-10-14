import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import io
import unittest
from unittest.mock import patch

import requests
from urllib3.exceptions import ConnectTimeoutError
from urllib3.response import HTTPResponse

from fetch_worldbank import get_json


def response(status, body=b'{"ok": true}', headers=None):
    return HTTPResponse(body=io.BytesIO(body), status=status,
                        headers=headers or {}, preload_content=False)


class RetryTests(unittest.TestCase):
    def call(self, outcomes):
        # Replace only network I/O; Requests and urllib3 run their real retry logic.
        with patch('urllib3.connectionpool.HTTPSConnectionPool._make_request',
                   side_effect=outcomes) as network, \
             patch('urllib3.util.retry.time.sleep') as sleep, \
             patch.dict('os.environ', {'NO_PROXY': '*'}):
            try:
                result = get_json('https://example.test/data', {'page': 1})
                return result, network.call_count, sleep
            finally:
                self.calls = network.call_count

    def test_success_without_retry(self):
        result, calls, sleep = self.call([response(200)])
        self.assertEqual(result, {'ok': True})
        self.assertEqual(calls, 1)
        sleep.assert_not_called()

    def test_temporary_server_failure_recovers(self):
        result, calls, sleep = self.call([response(503), response(503), response(200)])
        self.assertEqual(result, {'ok': True})
        self.assertEqual(calls, 3)
        sleep.assert_called_once_with(2.0)

    def test_connection_timeout_recovers(self):
        result, calls, _ = self.call([ConnectTimeoutError('simulated timeout'), response(200)])
        self.assertEqual(result, {'ok': True})
        self.assertEqual(calls, 2)

    def test_stops_after_four_attempts(self):
        with self.assertRaises(requests.HTTPError):
            self.call([response(503) for _ in range(4)])
        self.assertEqual(self.calls, 4)

    def test_not_found_is_not_retried(self):
        with self.assertRaises(requests.HTTPError):
            self.call([response(404)])
        self.assertEqual(self.calls, 1)

    def test_respects_retry_after(self):
        _, calls, sleep = self.call([response(429, headers={'Retry-After': '5'}), response(200)])
        self.assertEqual(calls, 2)
        sleep.assert_called_once_with(5)


if __name__ == '__main__':
    unittest.main(verbosity=2)
