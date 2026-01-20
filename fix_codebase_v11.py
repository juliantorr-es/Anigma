
import subprocess
import os
import re
import sys

# Configuration
PROJECT_DIR = "Anigma"
BUILD_CMD = ["swift", "build", "--product", "anigma", "-Xswiftc", "-strict-concurrency=complete"]
LOG_FILE = "fix_codebase_v11.log"

def log(msg):
    print(msg)
    with open(LOG_FILE, "a") as f:
        f.write(msg + "\n")

def run_build():
    log("Starting build for 'anigma' product...")
    process = subprocess.Popen(
        BUILD_CMD, 
        cwd=PROJECT_DIR, 
        stdout=subprocess.PIPE, 
        stderr=subprocess.PIPE, 
        text=True
    )
    stdout, stderr = process.communicate()
    return stdout, stderr, process.returncode

def parse_diagnostics(output):
    # Regex to capture: path, line, col, type (error/warning/note), message
    pattern = re.compile(r"^(.+?):(\d+):(\d+): (error|warning|note): (.+?)$", re.MULTILINE)
    diagnostics = []
    for match in pattern.finditer(output):
        path = match.group(1)
        if not os.path.isabs(path):
            potential_path = os.path.join(PROJECT_DIR, path)
            if os.path.exists(potential_path):
                path = potential_path
        
        diagnostics.append({
            'path': path,
            'line': int(match.group(2)),
            'col': int(match.group(3)),
            'type': match.group(4),
            'message': match.group(5)
        })
    return diagnostics

def apply_fixes(diagnostics):
    fixed_count = 0
    seen = set()
    diagnostics.sort(key=lambda x: x['line'], reverse=True)

    for diag in diagnostics:
        key = (diag['path'], diag['line'])
        if key in seen: continue
        seen.add(key)
        
        path = diag['path']
        line_num = diag['line']
        msg = diag['message']
        
        if not os.path.exists(path): continue
            
        try:
            with open(path, 'r') as f:
                lines = f.readlines()
        except: continue
            
        if line_num > len(lines): continue
        line_idx = line_num - 1
        original_line = lines[line_idx]
        new_line = original_line
        
        # --- TARGETED CLI & MODULE FIXES ---

        # 1. ExecutionMode Ambiguity (Qualify with AnigmaCLICore)
        if "ExecutionMode" in original_line and "'ExecutionMode' is ambiguous" in msg:
            if "AnigmaCLICore.ExecutionMode" not in original_line:
                new_line = original_line.replace("ExecutionMode", "AnigmaCLICore.ExecutionMode")

        # 2. Missing AnigmaCLIDatabase Import
        elif "cannot find type 'CLIDatabaseActor'" in msg or "cannot find 'CLIDatabaseConfig'" in msg:
            # Check if import is missing at top of file
            has_import = any("import AnigmaCLIDatabase" in l for l in lines)
            if not has_import:
                log(f"Adding missing import AnigmaCLIDatabase to {path}")
                lines.insert(0, "import AnigmaCLIDatabase\n")
                # Adjust line_idx because we inserted at 0
                line_idx += 1
                new_line = lines[line_idx] # Refresh original_line context

        # 3. Sendable Closure Requirement
        elif "function type must be marked '@Sendable'" in msg or "non-Sendable parameter type" in msg:
            if "async" in original_line and "@Sendable" not in original_line:
                new_line = original_line.replace("(Int, String) async", "@Sendable (Int, String) async")
                new_line = new_line.replace("() async", "@Sendable () async")

        # 4. Unchecked Sendable for Delegates/Classes
        elif "cannot conform to 'Sendable'; use '@unchecked Sendable'" in msg:
            if "class " in original_line and ": " in original_line:
                new_line = original_line.replace("{ ", ", @unchecked Sendable {") if "{" in original_line else original_line + ", @unchecked Sendable"

        # 5. Missing nonInteractive flag
        elif "cannot find 'nonInteractive' in scope" in msg:
            if "struct AnigmaInitCommand" in "".join(lines[max(0, line_idx-20):line_idx]):
                 # This needs to be inserted into the struct, not just replaced on the line.
                 # For simplicity in this script, we'll look for a place to insert.
                 for i in range(line_idx, 0, -1):
                     if "@Flag" in lines[i]:
                         lines.insert(i, "    @Flag(name: .long, help: \"Non-interactive mode.\")\n    var nonInteractive: Bool = false\n\n")
                         fixed_count += 1
                         break

        # 6. DatabaseActor -> DatabaseAuthority (In Tests/Adapters)
        elif "DatabaseActor" in original_line and ("cannot find type 'DatabaseActor' in scope" in msg or "cannot find 'DatabaseActor' in scope" in msg):
            new_line = original_line.replace("DatabaseActor", "MemoryDatabaseAuthority")

        if new_line != original_line:
            lines[line_idx] = new_line
            try:
                with open(path, 'w') as f:
                    f.writelines(lines)
                log(f"FIXED: {path}:{line_num} | {msg[:50]}...")
                fixed_count += 1
            except Exception as e:
                log(f"Failed to write {path}: {e}")
            
    return fixed_count

def main():
    log("=== Anigma CLI & Modules Auto-Fixer v11 ===")
    
    for i in range(10): # More iterations for complex dependency chains
        log(f"\n[Iteration {i+1}]")
        stdout, stderr, code = run_build()
        diagnostics = parse_diagnostics(stdout + stderr)
        
        if not diagnostics:
            if code == 0:
                log("Build successful!")
                break
            else:
                log("Build failed with no parsed diagnostics. Check logs.")
                log(stderr[-500:])
                break
                
        fixes = apply_fixes(diagnostics)
        log(f"Applied {fixes} fixes.")
        if fixes == 0:
            log("No more automated fixes possible.")
            break

if __name__ == "__main__":
    main()
