# Model delivery workflow

The Hugging Face model API was read during implementation: base revision `6f75de8b60a9f8a2fdf7b69cbd86d9e64bcb3837`, model-card license metadata `mit`. Training-data rights and a full redistribution review remain outstanding.

No trained model, Android inference runtime or deployed tokenizer is bundled. `Engine.LocalModel` is the replaceable real inference boundary; production uses explicit MODEL_UNAVAILABLE → Normal fallback. Rule results have null confidence. The three output labels are ordered HIGH, NORMAL, LOW throughout.

`prajjwal1/bert-tiny` is an English BERT architecture (2 layers, hidden dimension 128). Review the exact model-card/license and vocabulary for an immutable revision before acquisition; do not assume repository-level licensing proves weight/data rights. It is not a ready-made notification classifier. Hindi and Hinglish quality are unverified.

## Reproducible research path

Prepare a legally usable, consented JSONL dataset. Every row requires `text`, `label`, `language` (en/hi/hinglish), `source`, `license`, `group`, and `split` (train/validation/test). Split conversations/sources before creating examples; loader rejects group/text overlap. Do not use private notification history or synthetic-only tests as production evidence.

```sh
python3 -m venv ml/.venv
ml/.venv/bin/pip install -r ml/requirements.txt
cd ml
.venv/bin/python pipeline.py DATA.jsonl --revision AUDITED_HF_COMMIT --baseline
.venv/bin/python pipeline.py DATA.jsonl --revision AUDITED_HF_COMMIT --output output/bert
```

Pipeline trains BERT-Tiny with a three-class head on CPU, exports fixed-shape 1×128 ONNX (opset 17), dynamically quantizes INT8 weights, checks ONNX float logits against PyTorch, and compares INT8 labels against float. Evaluation reports per-language precision/recall/F1, confusion matrices and High false negatives. Validation split is reserved; threshold calibration/model selection is still to implement. Quantization disagreement is reported, not automatically accepted. Training/export has not run: no dataset was provided. Dataset validation and a synthetic baseline smoke test have run; the latter checks report generation only, not classifier quality. Neural training/export remain unrun.

Before Android deployment: manually review quality, test multilingual alternatives, calibrate conservative thresholds on validation data, implement and test Kotlin WordPiece parity (NFC/casing/accent handling and special tokens), integrate CPU ONNX Runtime Mobile, enforce asset hashes and schema, close tensors with `use`, enforce a bounded inference deadline, implement idle-release strategy, compare Kotlin/Python golden logits, then profile PSS/RSS and latency. Do not merely copy model files into assets and claim this app can run them. Android packaging/inference remains incomplete.
