# IMPORTANT: How to Launch Phase 3 Prototype

## ⚠️ CRITICAL: You MUST launch the .app bundle, not the raw executable

The error "Cannot index window tabs due to missing main bundle identifier" means you're running the raw executable instead of the .app bundle.

---

## ✅ Correct Way to Launch

### Canonical launcher
```bash
cd /Users/user/Developer/GitHub/Anigma_clean
./run_prototype.sh
```

### Manual bundle build (helper only)
```bash
cd /Users/user/Developer/GitHub/Anigma_clean
./build_app_bundle.sh
open anigma/.build/debug/AnigmaPrototype.app
```

---

## ❌ WRONG: Do NOT use Xcode's Run button

When you press Cmd+R in Xcode, it runs the raw executable at:
```
.build/debug/anigma-app  
```

This does NOT have a bundle identifier.

---

## ✅ Correct Workflow with Xcode

If you want to iterate with Xcode:

1. **Make code changes in Xcode**
2. **Build in Xcode** (Cmd+B) to check for errors
3. **Then run the canonical launcher:**
   ```bash
   ./run_prototype.sh
   ```

The `run_prototype.sh` script:
- Builds the executable bundle
- Launches the `.app` bundle
- Keeps the bundle identifier path stable

The `build_app_bundle.sh` helper:
- Builds the executable with `swift build`
- Wraps it in a proper `.app` bundle structure
- Adds the `Info.plist` with bundle identifier

---

## How to Verify You're Running the Right Thing

**When the app launches, check the console output:**

✅ **Correct (bundle):**
```
✅ Bundle identifier: com.anigma.prototype
✅ Database: PostgreSQL (host: localhost, db: anigma_v3)
```

❌ **Wrong (raw executable):**
```
⚠️  WARNING: No bundle identifier found!
⚠️  This app must be run as a .app bundle, not a raw executable.
```

---

## Why This Matters

macOS requires apps to have a bundle identifier for:
- File system indexing
- Sandboxing
- Permissions/entitlements
- Many AppKit/SwiftUI APIs

Without it, certain features will fail with errors like:
- "Cannot index window tabs due to missing main bundle identifier"
- Permission denied errors
- Sandbox violations

---

## For Smoke Testing

**Always use:**
```bash
./run_prototype.sh
```

This ensures you're testing the same bundle structure that would be used in production.
