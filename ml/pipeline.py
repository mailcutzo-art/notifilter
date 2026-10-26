"""Train/evaluate/export a 3-priority BERT-Tiny classifier. Never consumes device history.
JSONL fields: text, label (HIGH|NORMAL|LOW), language (en|hi|hinglish),
source, license, group (conversation/source grouping to prevent leakage), split.
Only consented, redistributable data may be used. No dataset is bundled.
"""
import argparse
import hashlib
import json
from pathlib import Path

LABELS = ['HIGH', 'NORMAL', 'LOW']

def load(path):
    rows = [json.loads(line) for line in Path(path).read_text().splitlines() if line.strip()]
    groups = {}
    for row in rows:
        assert row['text'].strip() and row['label'] in LABELS
        assert row['language'] in ['en', 'hi', 'hinglish']
        assert row['source'] and row['license'] and row['group']
        assert row['split'] in ['train', 'validation', 'test']
        assert groups.setdefault(row['group'], row['split']) == row['split'], 'Group leakage'
    assert all(any(r['split'] == s for r in rows) for s in ['train', 'validation', 'test'])
    text_splits = {}
    for row in rows:
        key = row['text'].strip().casefold()
        assert text_splits.setdefault(key, row['split']) == row['split'], 'Text leakage'
    return rows

def main():
    p = argparse.ArgumentParser()
    p.add_argument('dataset'); p.add_argument('--output', default='output')
    p.add_argument('--revision', required=True, help='Audited immutable Hugging Face base commit')
    p.add_argument('--epochs', type=int, default=3); p.add_argument('--baseline', action='store_true')
    args = p.parse_args()
    rows = load(args.dataset)
    from sklearn.metrics import classification_report, confusion_matrix
    import numpy as np
    out = Path(args.output); out.mkdir(parents=True, exist_ok=True)
    train = [r for r in rows if r['split'] == 'train']
    test = [r for r in rows if r['split'] == 'test']
    if args.baseline:
        from sklearn.pipeline import make_pipeline
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.linear_model import LogisticRegression
        model = make_pipeline(TfidfVectorizer(analyzer='char', ngram_range=(2,5), max_features=30000), LogisticRegression(max_iter=1000, class_weight='balanced'))
        model.fit([r['text'] for r in train], [r['label'] for r in train])
        predicted = model.predict([r['text'] for r in test]).tolist()
    else:
        import torch
        from transformers import AutoTokenizer, AutoModelForSequenceClassification
        from onnxruntime.quantization import quantize_dynamic, QuantType
        import onnxruntime as ort
        torch.manual_seed(42); torch.set_num_threads(2)
        tokenizer = AutoTokenizer.from_pretrained('prajjwal1/bert-tiny', revision=args.revision)
        model = AutoModelForSequenceClassification.from_pretrained('prajjwal1/bert-tiny', revision=args.revision, num_labels=3, id2label=dict(enumerate(LABELS)), label2id={x:i for i,x in enumerate(LABELS)})
        optimizer = torch.optim.AdamW(model.parameters(), lr=2e-5)
        model.train()
        for _ in range(args.epochs):
            order = torch.randperm(len(train)).tolist()
            for start in range(0, len(order), 16):
                batch = [train[i] for i in order[start:start+16]]
                tokens = tokenizer([r['text'] for r in batch], padding='max_length', truncation=True, max_length=128, return_tensors='pt')
                loss = model(**tokens, labels=torch.tensor([LABELS.index(r['label']) for r in batch])).loss
                optimizer.zero_grad(); loss.backward(); optimizer.step()
        model.eval(); model.save_pretrained(out / 'checkpoint'); tokenizer.save_pretrained(out / 'checkpoint')
        class Export(torch.nn.Module):
            def __init__(self, m): super().__init__(); self.m = m
            def forward(self, input_ids, attention_mask, token_type_ids):
                return self.m(input_ids=input_ids, attention_mask=attention_mask, token_type_ids=token_type_ids).logits
        sample = tokenizer('sample', padding='max_length', max_length=128, return_tensors='pt')
        names = ['input_ids','attention_mask','token_type_ids']
        torch.onnx.export(Export(model), tuple(sample[n] for n in names), str(out/'model.onnx'), input_names=names, output_names=['logits'], opset_version=17)
        quantize_dynamic(str(out/'model.onnx'),str(out/'model.int8.onnx'),weight_type=QuantType.QInt8)
        float_session = ort.InferenceSession(str(out/'model.onnx'), providers=['CPUExecutionProvider'])
        quant_session = ort.InferenceSession(str(out/'model.int8.onnx'), providers=['CPUExecutionProvider'])
        predicted = []; disagreements = 0; max_error = 0.0
        for row in test:
            tokens = tokenizer(row['text'], padding='max_length', truncation=True, max_length=128, return_tensors='np')
            inputs = {n:tokens[n].astype(np.int64) for n in names}
            f = float_session.run(None, inputs)[0]; q = quant_session.run(None, inputs)[0]
            with torch.no_grad(): reference = Export(model)(*(torch.from_numpy(inputs[n]) for n in names)).numpy()
            np.testing.assert_allclose(f, reference, atol=1e-4, rtol=1e-3)
            disagreements += int(f.argmax() != q.argmax()); max_error = max(max_error, float(abs(f-q).max()))
            predicted.append(LABELS[int(q.argmax())])
        (out/'conversion.json').write_text(json.dumps({'quantized_disagreements':disagreements,'test_count':len(test),'max_logit_error':max_error},indent=2))
        manifest = {'labels':LABELS,'base_revision':args.revision,'max_length':128,'model_sha256':hashlib.sha256((out/'model.int8.onnx').read_bytes()).hexdigest(),'android_validated':False}
        (out/'manifest.json').write_text(json.dumps(manifest,indent=2))
    report = {}
    for language in ['all','en','hi','hinglish']:
        pairs = [(r,pred) for r,pred in zip(test,predicted) if language == 'all' or r['language'] == language]
        if not pairs: report[language] = {'status':'UNVERIFIED_NO_SAMPLES'}; continue
        actual = [r['label'] for r,_ in pairs]; preds = [pred for _,pred in pairs]
        report[language] = {'metrics': classification_report(actual,preds,labels=LABELS,output_dict=True,zero_division=0), 'confusion_matrix':confusion_matrix(actual,preds,labels=LABELS).tolist(), 'high_false_negatives':sum(a=='HIGH' and b!='HIGH' for a,b in zip(actual,preds))}
    (out/'evaluation.json').write_text(json.dumps(report,indent=2))

if __name__ == '__main__': main()
