#!/usr/bin/env python3
"""
CoreML conversion wrapper for Anigma Model Registry.
Provides deterministic PyTorch → CoreML conversion with receipt generation.
"""

import argparse
import json
import os
import sys
import traceback
from pathlib import Path
from typing import Dict, Any, Optional

try:
    import coremltools as ct
    import torch
    import torch.nn as nn
    from coremltools.converters.mil import Builder as mb
    from coremltools.converters.mil.frontend.torch import load
    from coremltools.models.neural_network import quantization_utils
except ImportError as e:
    print(f"ERROR: Required Python packages not available: {e}")
    print("Please install: coremltools, torch")
    sys.exit(1)


def convert_pytorch_to_coreml(
    model_path: str,
    output_path: str,
    target_format: str = "mlprogram",
    compute_units: str = "all",
    quantization: Optional[str] = None,
    min_os_version: str = "macos15",
    input_shape: Optional[Dict[str, Any]] = None,
    output_names: Optional[list] = None,
) -> Dict[str, Any]:
    """
    Convert PyTorch model to CoreML format with deterministic settings.

    Args:
        model_path: Path to PyTorch model (.pt or .pth file)
        output_path: Directory to save CoreML model
        target_format: "mlprogram" or "neuralnetwork"
        compute_units: "all", "cpuOnly", "cpuAndGPU", "cpuAndNeuralEngine"
        quantization: "int8", "fp16", "fp32", or None
        min_os_version: Minimum macOS version (e.g., "macos15")
        input_shape: Optional input shape specification
        output_names: Optional output tensor names

    Returns:
        Dictionary with conversion metadata and receipt data
    """
    try:
        # Load PyTorch model
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model file not found: {model_path}")

        print(f"Loading PyTorch model from: {model_path}")
        model = torch.load(model_path, map_location=torch.device("cpu"))

        if not isinstance(model, nn.Module):
            raise TypeError(f"Loaded object is not a PyTorch nn.Module: {type(model)}")

        # Set model to evaluation mode
        model.eval()

        # Determine input shape if not provided
        if input_shape is None:
            # Try to infer from model or use defaults for common models
            input_shape = {
                "input_ids": (1, 512),  # Common sequence length for transformers
                "attention_mask": (1, 512),
            }

        # Create example input
        example_input = {}
        for name, shape in input_shape.items():
            if name == "input_ids":
                example_input[name] = torch.randint(0, 32000, shape, dtype=torch.long)
            elif name == "attention_mask":
                example_input[name] = torch.ones(shape, dtype=torch.float32)
            else:
                example_input[name] = torch.randn(shape, dtype=torch.float32)

        # Trace the model
        print("Tracing model with example input...")
        traced_model = torch.jit.trace(model, tuple(example_input.values()))

        # Configure CoreML conversion
        compute_units_map = {
            "all": ct.ComputeUnit.ALL,
            "cpuOnly": ct.ComputeUnit.CPU_ONLY,
            "cpuAndGPU": ct.ComputeUnit.CPU_AND_GPU,
            "cpuAndNeuralEngine": ct.ComputeUnit.CPU_AND_NE,
        }

        compute_unit = compute_units_map.get(compute_units, ct.ComputeUnit.ALL)

        # Convert to CoreML
        print(f"Converting to CoreML format: {target_format}")
        mlmodel = ct.convert(
            traced_model,
            inputs=[
                ct.TensorType(name=name, shape=tensor.shape, dtype=tensor.dtype)
                for name, tensor in example_input.items()
            ],
            outputs=[ct.TensorType(name=name) for name in (output_names or ["output"])],
            convert_to=target_format,
            compute_units=compute_unit,
            minimum_deployment_target=ct.target.macOS15
            if min_os_version == "macos15"
            else ct.target.macOS14,
        )

        # Apply quantization if requested
        if quantization == "int8":
            print("Applying INT8 quantization...")
            mlmodel = quantization_utils.quantize_weights(mlmodel, nbits=8)
        elif quantization == "fp16":
            print("Applying FP16 quantization...")
            mlmodel = quantization_utils.quantize_weights(mlmodel, nbits=16)

        # Save the model
        output_dir = Path(output_path)
        output_dir.mkdir(parents=True, exist_ok=True)

        model_filename = (
            f"model.mlpackage" if target_format == "mlprogram" else f"model.mlmodel"
        )
        model_output_path = output_dir / model_filename

        print(f"Saving CoreML model to: {model_output_path}")
        mlmodel.save(str(model_output_path))

        # Generate receipt metadata
        receipt = {
            "success": True,
            "model_path": str(model_output_path),
            "input_shape": {k: list(v.shape) for k, v in example_input.items()},
            "output_names": output_names or ["output"],
            "target_format": target_format,
            "compute_units": compute_units,
            "quantization": quantization,
            "min_os_version": min_os_version,
            "coremltools_version": ct.__version__,
            "torch_version": torch.__version__,
        }

        return receipt

    except Exception as e:
        error_msg = f"Conversion failed: {str(e)}\n{traceback.format_exc()}"
        print(f"ERROR: {error_msg}")
        return {"success": False, "error": error_msg}


def analyze_coreml_placement(model_path: str) -> Dict[str, Any]:
    """
    Analyze CoreML model for hardware placement compatibility.

    Args:
        model_path: Path to CoreML model

    Returns:
        Dictionary with placement analysis
    """
    try:
        model = ct.models.MLModel(model_path)
        spec = model.get_spec()

        analysis = {
            "supported_ops": [],
            "unsupported_ops": [],
            "likely_placement": "unknown",
            "ane_compatible": False,
            "dynamic_shapes": False,
            "stateful_supported": False,
            "model_type": spec.WhichOneof("Type"),
            "spec_version": spec.specVersion,
        }

        # Basic analysis based on model type and layers
        if hasattr(spec, "neuralNetwork"):
            nn_spec = spec.neuralNetwork
            analysis["model_type"] = "neuralNetwork"

            # Check for ANE-compatible ops
            ane_compatible_ops = {"convolution", "pooling", "softmax", "activation"}
            for layer in nn_spec.layers:
                op_type = layer.WhichOneof("layer")
                if op_type in ane_compatible_ops:
                    analysis["supported_ops"].append(op_type)
                else:
                    analysis["unsupported_ops"].append(op_type)

            # Simple heuristic for placement
            if len(analysis["supported_ops"]) > len(analysis["unsupported_ops"]):
                analysis["likely_placement"] = "ane"
                analysis["ane_compatible"] = True
            else:
                analysis["likely_placement"] = "cpu"

        elif hasattr(spec, "mlProgram"):
            analysis["model_type"] = "mlProgram"
            analysis["likely_placement"] = "mixed"
            analysis["ane_compatible"] = True  # mlprogram generally supports ANE

        return analysis

    except Exception as e:
        return {"success": False, "error": f"Analysis failed: {str(e)}"}


def main():
    parser = argparse.ArgumentParser(description="CoreML conversion wrapper")
    parser.add_argument("--model-path", required=True, help="Path to PyTorch model")
    parser.add_argument("--output-path", required=True, help="Output directory")
    parser.add_argument(
        "--target-format", default="mlprogram", choices=["mlprogram", "neuralnetwork"]
    )
    parser.add_argument(
        "--compute-units",
        default="all",
        choices=["all", "cpuOnly", "cpuAndGPU", "cpuAndNeuralEngine"],
    )
    parser.add_argument("--quantization", choices=["int8", "fp16", "fp32", None])
    parser.add_argument("--min-os-version", default="macos15")
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
        )

    # Print result as JSON for Swift to parse
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
