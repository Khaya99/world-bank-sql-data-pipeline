import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import contextlib
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import pandas as pd
import fetch_worldbank as extractor


class CoverageTests(unittest.TestCase):
    def test_complete(self):
        result = extractor.summarize_coverage({('ZAF', 2020): 1, ('ZAF', 2021): 2}, ['ZAF'], 2020, 2021)
        self.assertEqual(result, {'expected': 2, 'available': 2, 'missing': [], 'unexpected': []})

    def test_absent_and_null_but_zero_is_available(self):
        result = extractor.summarize_coverage({('ZAF', 2020): 0, ('ZAF', 2021): None}, ['ZAF'], 2020, 2022)
        self.assertEqual(result['available'], 1)
        self.assertEqual(result['missing'], [('ZAF', 2021), ('ZAF', 2022)])

    def test_unexpected_does_not_hide_missing(self):
        result = extractor.summarize_coverage({('NGA', 2020): 5}, ['ZAF'], 2020, 2020)
        self.assertEqual(result['available'], 0)
        self.assertEqual(result['missing'], [('ZAF', 2020)])
        self.assertEqual(result['unexpected'], [('NGA', 2020)])

    def test_empty(self):
        result = extractor.summarize_coverage({}, ['ZAF', 'NGA'], 2020, 2021)
        self.assertEqual(result['expected'], 4)
        self.assertEqual(len(result['missing']), 4)

    def test_reversed_dates(self):
        with self.assertRaises(ValueError):
            extractor.summarize_coverage({}, ['ZAF'], 2021, 2020)

    def test_main_reports_gap_and_preserves_blank_csv(self):
        metadata = [{}, [{'id': 'ZAF', 'name': 'South Africa',
                         'region': {'value': 'Africa'}, 'incomeLevel': {'value': 'Example'}}]]
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'test.csv'
            printed = io.StringIO()
            with patch.object(extractor, 'COUNTRIES', ['ZAF']), \
                 patch.object(extractor, 'INDICATORS', {'population': ['SP.POP.TOTL']}), \
                 patch.object(extractor, 'get_json', return_value=metadata), \
                 patch.object(extractor, 'fetch', return_value={('ZAF', 2020): 100}), \
                 patch('sys.argv', ['fetch_worldbank.py', '--start', '2020', '--end', '2021', '--out', str(output)]), \
                 contextlib.redirect_stdout(printed):
                extractor.main()
            self.assertIn('expected=2, available=1, missing=1, unexpected=0', printed.getvalue())
            self.assertIn('ZAF/2021', printed.getvalue())
            rows = pd.read_csv(output)
            self.assertEqual(len(rows), 2)
            self.assertEqual(rows.loc[0, 'population'], 100)
            self.assertTrue(pd.isna(rows.loc[1, 'population']))


if __name__ == '__main__':
    unittest.main(verbosity=2)
