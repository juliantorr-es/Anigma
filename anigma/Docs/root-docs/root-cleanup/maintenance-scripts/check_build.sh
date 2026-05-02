#!/bin/bash
cd /Users/user/Developer/GitHub/Anigma_clean/anigma
swift build --target HarmoniaV2CLIKernel 2>&1 | head -50
