import json
import tempfile
import unittest
from pathlib import Path
from pipeline import load

class SchemaTests(unittest.TestCase):
    def rows(self):
        return [dict(text=s, label='NORMAL', language='en', source='test fixture', license='CC0-1.0', group=s, split=s) for s in ['train','validation','test']]
    def check(self, rows):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'data.jsonl'; p.write_text('\n'.join(map(json.dumps,rows)))
            return load(p)
    def test_valid(self): self.assertEqual(len(self.check(self.rows())),3)
    def test_group_leak(self):
        r=self.rows();r[1]['group']='train'
        with self.assertRaises(AssertionError):self.check(r)
    def test_duplicate_text_leak(self):
        r=self.rows();r[1]['text']='TRAIN'
        with self.assertRaises(AssertionError):self.check(r)
    def test_three_labels_only(self):
        r=self.rows();r[1]['label']='CRITICAL'
        with self.assertRaises(AssertionError):self.check(r)

if __name__ == '__main__':unittest.main()
