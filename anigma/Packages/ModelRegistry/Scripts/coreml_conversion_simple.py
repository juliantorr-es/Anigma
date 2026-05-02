#!/usr/bin/env python3
"""
Enhanced CoreML conversion wrapper with quantization and calibration support.
"""

import argparse
import json
import os
import sys
import traceback
import tempfile
from pathlib import Path
from typing import Optional, Dict, Any


def convert_pytorch_to_coreml(
    model_path: str,
    output_path: str,
    target_format: str = "mlprogram",
    compute_units: str = "all",
    quantization: str = None,
    min_os_version: str = "macos15",
    calibration_data_path: Optional[str] = None,
) -> dict:
    """
    Enhanced wrapper with quantization and calibration support.
    In a real implementation, this would call coremltools with proper quantization.
    """
    try:
        # Validate inputs
        if not os.path.exists(model_path):
            return {"success": False, "error": f"Model file not found: {model_path}"}

        # Validate OS version
        valid_os_versions = [
            "macos13",
            "macos14",
            "macos15",
            "macos16",
            "ios17",
            "ios18",
        ]
        if min_os_version not in valid_os_versions:
            return {
                "success": False,
                "error": f"Unsupported OS version: {min_os_version}",
            }

        # Create output directory
        output_dir = Path(output_path)
        output_dir.mkdir(parents=True, exist_ok=True)

        # Simulate conversion with enhanced features
        if target_format == "mlprogram":
            model_filename = "model.mlpackage"
            model_type = "mlprogram"
            supports_quantization = True
        else:
            model_filename = "model.mlmodel"
            model_type = "neuralnetwork"
            supports_quantization = False

        model_output_path = output_dir / model_filename

        # Handle quantization
        quantization_info = "none"
        if quantization:
            if not supports_quantization:
                return {
                    "success": False,
                    "error": f"Quantization not supported for {target_format}",
                }

            quantization_info = quantization
            if calibration_data_path:
                quantization_info = f"{quantization}_calibrated"

                # In real implementation, load calibration data and apply it
                try:
                    with open(calibration_data_path, "r") as f:
                        calibration_data = json.load(f)
                    # Process calibration data for quantization
                    calibration_samples = len(calibration_data.get("samples", []))
                    quantization_info = (
                        f"{quantization}_calibrated_{calibration_samples}samples"
                    )
                except Exception as e:
                    print(
                        f"Warning: Failed to load calibration data: {e}",
                        file=sys.stderr,
                    )

        # Create enhanced output file with metadata
        metadata = {
            "target_format": target_format,
            "compute_units": compute_units,
            "quantization": quantization,
            "min_os_version": min_os_version,
            "model_type": model_type,
            "quantization_applied": quantization_info,
            "supports_ane": compute_units in ["all", "cpuAndNeuralEngine"],
            "timestamp": os.path.getmtime(model_path)
            if os.path.exists(model_path)
            else 0,
        }

        with open(model_output_path, "w") as f:
            f.write(f"CoreML model placeholder\n")
            f.write(f"Metadata: {json.dumps(metadata, indent=2)}")

        # Return enhanced receipt metadata
        return {
            "success": True,
            "model_path": str(model_output_path),
            "target_format": target_format,
            "compute_units": compute_units,
            "quantization": quantization,
            "min_os_version": min_os_version,
            "quantization_applied": quantization_info,
            "model_type": model_type,
            "supports_ane": metadata["supports_ane"],
            "message": "Enhanced conversion simulated - includes quantization and calibration support",
            "metadata": metadata,
        }

    except Exception as e:
        return {
            "success": False,
            "error": f"Conversion failed: {str(e)}",
            "traceback": traceback.format_exc(),
        }


def analyze_coreml_placement(model_path: str) -> dict:
    """
    Enhanced CoreML model analysis for hardware placement compatibility.
    """
    try:
        # Check if model exists
        if not os.path.exists(model_path):
            return {"success": False, "error": f"Model path not found: {model_path}"}

        # Enhanced analysis based on file structure and metadata
        model_type = "unknown"
        ane_compatible = False
        likely_placement = "unknown"
        dynamic_shapes = False
        stateful_supported = False
        supported_ops = ["convolution", "pooling", "fully_connected", "activation"]
        unsupported_ops = []

        # Check for mlpackage (mlprogram format)
        if model_path.endswith(".mlpackage") or os.path.isdir(model_path):
            model_type = "mlprogram"
            ane_compatible = True
            likely_placement = "mixed"
            # mlprogram supports more ops
            supported_ops.extend(["layer_norm", "rms_norm", "attention", "embedding"])
            dynamic_shapes = True  # mlprogram supports dynamic shapes
            stateful_supported = True  # mlprogram supports stateful models
        elif model_path.endswith(".mlmodel"):
            model_type = "neuralnetwork"
            ane_compatible = False
            likely_placement = "cpu"
            # neuralnetwork has limited op support
            unsupported_ops = ["layer_norm", "rms_norm", "attention", "embedding"]

        # Try to read metadata from file
        metadata = {}
        try:
            if os.path.isfile(model_path):
                with open(model_path, "r") as f:
                    content = f.read()
                    if "Metadata:" in content:
                        # Extract metadata from file content
                        metadata_str = content.split("Metadata:")[1].strip()
                        metadata = json.loads(metadata_str)

                        # Update analysis based on metadata
                        if metadata.get("supports_ane"):
                            ane_compatible = True
                            likely_placement = "ane_optimized"
                        if metadata.get("quantization_applied", "none") != "none":
                            # Quantized models may have different placement characteristics
                            likely_placement = "mixed_quantized"
        except:
            pass  # Metadata reading is optional

        return {
            "success": True,
            "supported_ops": supported_ops,
            "unsupported_ops": unsupported_ops,
            "likely_placement": likely_placement,
            "ane_compatible": ane_compatible,
            "dynamic_shapes": dynamic_shapes,
            "stateful_supported": stateful_supported,
            "model_type": model_type,
            "metadata_found": bool(metadata),
            "quantization": metadata.get("quantization_applied", "none"),
        }

    except Exception as e:
        return {
            "success": False,
            "error": f"Analysis failed: {str(e)}",
            "traceback": traceback.format_exc(),
        }


def main():
    parser = argparse.ArgumentParser(description="Enhanced CoreML conversion wrapper")
    parser.add_argument("--model-path", help="Path to PyTorch model")
    parser.add_argument("--output-path", help="Output directory")
    parser.add_argument(
        "--target-format", default="mlprogram", choices=["mlprogram", "neuralnetwork"]
    )
    parser.add_argument(
        "--compute-units",
        default="all",
        choices=["all", "cpuOnly", "cpuAndGPU", "cpuAndNeuralEngine"],
    )
    parser.add_argument("--quantization", choices=["int8", "fp16", "fp32"])
    parser.add_argument("--min-os-version", default="macos15")
    parser.add_argument("--calibration-data", help="Path to calibration data JSON file")
    parser.add_argument(
        "--analyze-only", action="store_true", help="Only analyze existing CoreML model"
    )

    args = parser.parse_args()

    if args.analyze_only:
        result = analyze_coreml_placement(args.model_path)
    else:
        result = convert_pytorch_to_coreml(
            model_path=args.model_path,
            output_path=args.output_path,
            target_format=args.target_format,
            compute_units=args.compute_units,
            quantization=args.quantization,
            min_os_version=args.min_os_version,
            calibration_data_path=args.calibration_data,
        )

    # Print result as JSON for Swift to parse
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
