# FaceSwap Flutter App - ONNX Models

This directory should contain the following ONNX model files:

## Required Models

### 1. BlazeFace (Face Detection)
- **File:** `blazeface.onnx`
- **Input:** 128x128 RGB image (1, 3, 128, 128)
- **Output:** Face bounding boxes and 5-point landmarks
- **Source:** [MediaPipe BlazeFace](https://github.com/google/mediapipe/blob/master/mediapipe/models/face_detection_front.tflite)
- **Conversion:** Convert TFLite to ONNX using `tf2onnx` or use pre-converted versions from:
  - https://github.com/google/mediapipe/tree/master/mediapipe/models
  - https://github.com/onnx/models/tree/main/vision/body_analysis/blazeface

### 2. ArcFace (Face Embedding/Recognition)
- **File:** `arcface.onnx`
- **Input:** 112x112 aligned face (1, 3, 112, 112)
- **Output:** 512-dimensional embedding vector
- **Source:** [InsightFace ArcFace](https://github.com/deepinsight/insightface/tree/master/recognition/arcface_torch)
- **Pre-trained models:** https://github.com/deepinsight/insightface-model-zoo
- **Conversion:** PyTorch → ONNX using `torch.onnx.export`

### 3. Inswapper (Face Swapping)
- **File:** `inswapper_mobile.onnx`
- **Input:** 
  - Target: 128x128 aligned face (1, 3, 128, 128)
  - Source: 512-dim embedding (1, 512)
- **Output:** 128x128 swapped face (1, 3, 128, 128)
- **Source:** [InsightFace Inswapper](https://github.com/deepinsight/insightface/tree/master/python-package/insightface/model_zoo/inswapper)
- **Model:** `inswapper_128.onnx` (mobile optimized version)
- **Conversion:** Use the mobile-optimized version directly

## Download Links

### Option 1: Pre-converted ONNX Models (Recommended)
- BlazeFace ONNX: https://github.com/onnx/models/tree/main/vision/body_analysis/blazeface
- ArcFace ONNX: https://github.com/onnx/models/tree/main/vision/body_analysis/arcface
- Inswapper: https://github.com/deepinsight/insightface/releases (look for `inswapper_128.onnx`)

### Option 2: Convert from Original Formats
```bash
# Install conversion tools
pip install onnx onnxruntime tf2onnx torch torchvision

# Convert BlazeFace (from TFLite)
python -m tf2onnx.convert --tflite blazeface.tflite --output blazeface.onnx

# Convert ArcFace (from PyTorch)
python -c "
import torch
from insightface.model_zoo import get_model
model = get_model('arcface_r100_v1')
model.eval()
dummy = torch.randn(1, 3, 112, 112)
torch.onnx.export(model, dummy, 'arcface.onnx', opset_version=11)
"

# Inswapper is already ONNX format
# Download inswapper_128.onnx and rename to inswapper_mobile.onnx
```

## Model Placement

Place all three `.onnx` files in this `assets/` directory:
```
face_swap_app/
├── assets/
│   ├── blazeface.onnx      (~2 MB)
│   ├── arcface.onnx        (~85 MB for R100, ~6 MB for MobileFaceNet)
│   └── inswapper_mobile.onnx  (~50 MB)
```

## Notes

1. **Model Sizes**: The full models are large. For mobile, use:
   - MobileFaceNet instead of ResNet-100 for ArcFace (~6 MB vs ~85 MB)
   - Inswapper 128x128 mobile version (~50 MB)
   - BlazeFace is already lightweight (~2 MB)

2. **Optimization**: Consider quantizing models to INT8 for faster mobile inference:
   ```bash
   # Using ONNX Runtime quantization
   python -m onnxruntime.quantization.quantize \
     --input_model arcface.onnx \
     --output_model arcface_int8.onnx \
     --quant_format QOperator \
     --activation_type QUInt8 \
     --weight_type QInt8
   ```

3. **Licensing**: Check model licenses before commercial use:
   - BlazeFace: Apache 2.0 (MediaPipe)
   - ArcFace: InsightFace license (research/non-commercial)
   - Inswapper: InsightFace license

## Verification

After placing models, verify they load correctly:
```dart
// In your Dart code
final session = OrtSession.fromFile('assets/blazeface.onnx', options);
print('Input: ${session.inputNames}');
print('Output: ${session.outputNames}');
print('Input shape: ${session.getInputInfo("input").shape}');
```