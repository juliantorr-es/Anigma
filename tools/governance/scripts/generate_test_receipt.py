import json
import sys
import os
from datetime import datetime

def generate_receipt(test_output_file, target_name):
    # This is a simplified implementation of a test receipt generator
    # In a real environment, this would parse a JSON test report (e.g. from --junit-xml)
    
    timestamp = datetime.now().isoformat()
    report_path = f"../anigma/Docs/Evidence/{target_name}_receipt.md"
    
    with open(report_path, 'w') as f:
        f.write(f"# Evidence Receipt: {target_name}\n")
        f.write(f"**Timestamp**: {timestamp}\n\n")
        f.write("## Execution Summary\n")
        
        # Logic to append failure details if present
        if os.path.exists(test_output_file):
            with open(test_output_file, 'r') as log:
                output = log.read()
                if "failed" in output.lower():
                    f.write("### Status: 🔴 FAILED\n\n")
                    f.write("## Remediation Suggestions\n")
                    f.write("- Check `Docs/LLM/NEW_TESTING_DOCTRINE.md` for API compliance.\n")
                    f.write("- Run `anigma doctor` to verify dependency consistency.\n")
                    f.write("- Inspect binary protocol regression (check 32-bit/64-bit alignment).\n")
                else:
                    f.write("### Status: 🟢 PASSED\n\n")
        f.write("\n---\n*Governed by Anigma Control Plane*\n")

if __name__ == "__main__":
    generate_receipt(sys.argv[1], sys.argv[2])
