# SwiftLint Auto-Fix Tools

Automated tools for fixing SwiftLint violations in the Anigma codebase.

## Quick Start

```bash
# Show violation statistics
python3 Scripts/swiftlint_auto_fix.py --stats

# Preview fixes (dry run)
python3 Scripts/swiftlint_auto_fix.py --dry-run --fix all

# Apply specific fix
python3 Scripts/swiftlint_auto_fix.py --fix force_unwrapping

# Apply all automated fixes
python3 Scripts/swiftlint_auto_fix.py --fix all
```

## Available Fixers

### ✅ Fully Automated

| Rule | Description | Safety | Example |
|------|-------------|--------|---------|
| `trailing_whitespace` | Remove trailing spaces | 🟢 Safe | `let x = 5   ` → `let x = 5` |
| `closure_spacing` | Fix closure brace spacing | 🟢 Safe | `{code}` → `{ code }` |
| `non_optional_string_data_conversion` | Use `Data(_:)` initializer | 🟢 Safe | `str.data(using: .utf8)` → `Data(str.utf8)` |
| `force_unwrapping` | Convert `!` to guard | 🟡 Review | `let x = dict["key"]!` → `guard let x = dict["key"] else { ... }` |
| `force_cast` | Convert `as!` to `as?` | 🟡 Review | `x as! Type` → `guard let x = x as? Type else { ... }` |

### 📋 Generates Suggestions

| Rule | Description | Output |
|------|-------------|--------|
| `large_tuple` | Convert tuples to structs | `large_tuple_suggestions.json` |
| `function_parameter_count` | Extract config objects | (Coming soon) |

## Usage Examples

### 1. Preview Changes (Recommended First Step)

```bash
python3 Scripts/swiftlint_auto_fix.py --dry-run --fix all
```

Output:
```
🔧 Fixing force unwrapping violations...
  📝 Packages/AnigmaCore/World.swift:42
     - let value = dictionary["key"]!
     + guard let value = dictionary["key"] else {
     +     fatalError("Failed to unwrap value")
     + }
✅ Fixed 15 force unwrapping violations
```

### 2. Fix Specific Rule

```bash
# Fix only force unwrapping
python3 Scripts/swiftlint_auto_fix.py --fix force_unwrapping

# Fix only trailing whitespace
python3 Scripts/swiftlint_auto_fix.py --fix trailing_whitespace
```

### 3. Apply All Fixes

```bash
python3 Scripts/swiftlint_auto_fix.py --fix all
```

**⚠️ Important**: This creates `.swift.bak` backup files. Review changes before committing!

### 4. Check Statistics

```bash
python3 Scripts/swiftlint_auto_fix.py --stats
```

Output:
```
📊 Violation Statistics:
----------------------------------------------------------------------
   1093 | explicit_type_interface
    354 | file_length
    248 | function_parameter_count
    173 | cyclomatic_complexity
    162 | large_tuple
    ...
----------------------------------------------------------------------
  36158 | TOTAL
```

## Workflow

### Recommended Process

1. **Backup your work**:
   ```bash
   git checkout -b swiftlint-fixes
   git commit -am "Checkpoint before SwiftLint fixes"
   ```

2. **Run statistics**:
   ```bash
   python3 Scripts/swiftlint_auto_fix.py --stats > violations_before.txt
   ```

3. **Preview changes**:
   ```bash
   python3 Scripts/swiftlint_auto_fix.py --dry-run --fix all | tee preview.txt
   ```

4. **Apply safe fixes first**:
   ```bash
   # Start with safest fixes
   python3 Scripts/swiftlint_auto_fix.py --fix trailing_whitespace
   python3 Scripts/swiftlint_auto_fix.py --fix closure_spacing
   
   # Verify build
   swift build && swift test
   
   # Commit
   git add -A
   git commit -m "SwiftLint: Fix trailing whitespace and closure spacing"
   ```

5. **Apply riskier fixes**:
   ```bash
   # These require review
   python3 Scripts/swiftlint_auto_fix.py --fix force_unwrapping
   
   # Review changes
   git diff
   
   # Test thoroughly
   swift test
   
   # Commit if good
   git add -A
   git commit -m "SwiftLint: Fix force unwrapping violations"
   ```

6. **Verify improvements**:
   ```bash
   python3 Scripts/swiftlint_auto_fix.py --stats > violations_after.txt
   diff violations_before.txt violations_after.txt
   ```

## Safety Features

### Automatic Backups

Every modified file gets a `.swift.bak` backup:

```bash
# Restore a file if needed
cp Packages/AnigmaCore/World.swift.bak Packages/AnigmaCore/World.swift

# Remove all backups after verification
find . -name "*.swift.bak" -delete
```

### Dry Run Mode

Always preview changes first:

```bash
python3 Scripts/swiftlint_auto_fix.py --dry-run --fix all
```

### Incremental Commits

The script modifies files in place. Commit after each rule fix:

```bash
# Fix one rule
python3 Scripts/swiftlint_auto_fix.py --fix force_unwrapping

# Review
git diff

# Test
swift test

# Commit
git add -A
git commit -m "SwiftLint: Fix force unwrapping (42 files)"
```

## Limitations

### Not Automated (Manual Review Required)

These violations require human judgment:

- **`explicit_type_interface`** (1,093 violations): Adding type annotations
- **`file_length`** (354 violations): Splitting large files
- **`function_parameter_count`** (248 violations): Extracting config objects
- **`cyclomatic_complexity`** (173 violations): Refactoring complex functions
- **`large_tuple`** (162 violations): Converting to structs (generates suggestions)

### Known Issues

1. **Context-sensitive fixes**: The script uses regex, which may not handle all edge cases
2. **Multi-line patterns**: Some violations span multiple lines and are harder to fix
3. **Semantic understanding**: The script doesn't understand Swift semantics, only patterns

**Recommendation**: Always review changes and run tests!

## Advanced Usage

### Custom Repository Root

```bash
python3 Scripts/swiftlint_auto_fix.py --repo-root /path/to/repo --stats
```

### Integration with CI/CD

```yaml
# .github/workflows/swiftlint-auto-fix.yml
name: Auto-fix SwiftLint

on:
  workflow_dispatch:

jobs:
  fix:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install SwiftLint
        run: brew install swiftlint
      
      - name: Apply safe fixes
        run: |
          python3 Scripts/swiftlint_auto_fix.py --fix trailing_whitespace
          python3 Scripts/swiftlint_auto_fix.py --fix closure_spacing
      
      - name: Create PR
        uses: peter-evans/create-pull-request@v5
        with:
          title: "SwiftLint: Automated fixes"
          branch: swiftlint-auto-fixes
```

## Troubleshooting

### "SwiftLint not found"

```bash
brew install swiftlint
```

### "No violations found" but SwiftLint shows violations

The script uses JSON output. Verify SwiftLint works:

```bash
swiftlint lint --reporter json | head
```

### Changes not applied

Check you're not in dry-run mode:

```bash
# ❌ Dry run (no changes)
python3 Scripts/swiftlint_auto_fix.py --dry-run --fix all

# ✅ Apply changes
python3 Scripts/swiftlint_auto_fix.py --fix all
```

### Build breaks after fixes

Restore from backups:

```bash
# Restore all
find . -name "*.swift.bak" -exec sh -c 'cp "$1" "${1%.bak}"' _ {} \;

# Or restore specific file
cp Packages/AnigmaCore/World.swift.bak Packages/AnigmaCore/World.swift
```

## Contributing

To add a new fixer:

1. Add rule to `fix_rule()` method
2. Implement `fix_<rule_name>()` method
3. Add to `fix_all()` in appropriate order
4. Update this README

Example:

```python
def fix_my_new_rule(self, violations: List[Violation]) -> int:
    """Fix my new rule violations."""
    print("\n🔧 Fixing my new rule...")
    
    my_violations = [v for v in violations if v.rule_id == 'my_new_rule']
    # ... implementation
    
    return fixed_count
```

## See Also

- [SwiftLint Remediation Plan](../../Docs/development/swiftlint-remediation-plan.md)
- [SwiftLint Rules](https://realm.github.io/SwiftLint/rule-directory.html)
- [Anigma Code Style Guide](../../Docs/development/code-style-guide.md)

---

**Last Updated**: 2026-01-11  
**Maintainer**: Anigma Development Team
