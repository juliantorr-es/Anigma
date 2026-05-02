import coremltools as ct
import numpy as np
import torch
import torch.nn as nn

class SimpleModel(nn.Module):
    def __init__(self):
        super(SimpleModel, self).__init__()
        self.linear = nn.Linear(4, 1)
        with torch.no_grad():
            self.linear.weight.fill_(0.5)
            self.linear.bias.fill_(0.1)

    def forward(self, x):
        return self.linear(x)

model = SimpleModel()
model.eval()

example_input = torch.rand(1, 4)
traced_model = torch.jit.trace(model, example_input)

# Force neuralnetwork format to use .mlmodelc
mlmodel = ct.convert(
    traced_model,
    inputs=[ct.TensorType(name="input", shape=example_input.shape)],
    convert_to="neuralnetwork"
)

mlmodel.save("SimpleModel.mlmodelc")
print("SimpleModel.mlmodelc generated.")
