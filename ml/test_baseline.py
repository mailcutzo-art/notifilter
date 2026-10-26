"""Pipeline mechanics only. Synthetic fixtures do not measure notification quality."""
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

@unittest.skipUnless(importlib.util.find_spec('sklearn') and importlib.util.find_spec('numpy'), 'Optional research dependencies not installed')
class BaselineSmoke(unittest.TestCase):
    def test_pipeline_writes_evaluation(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            rows=[]
            for split in ['train','validation','test']:
                for label,phrase in [('HIGH','urgent call'),('NORMAL','daily update'),('LOW','sale offer')]:
                    for language in ['en','hi','hinglish']:
                        rows.append(dict(text=f'{phrase} {split} {language}', label=label, language=language, source='synthetic mechanics fixture', license='CC0-1.0', group=f'{split}-{label}-{language}',split=split))
            data=root/'fixture.jsonl';data.write_text('\n'.join(map(json.dumps,rows)))
            subprocess.run([sys.executable,str(Path(__file__).with_name('pipeline.py')),str(data),'--revision','unused-for-baseline','--baseline','--output',str(root/'output')],check=True)
            report=json.loads((root/'output/evaluation.json').read_text())
            self.assertEqual(set(report), {'all','en','hi','hinglish'})
            self.assertEqual(len(report['all']['confusion_matrix']),3)

if __name__ == '__main__': unittest.main()
