# Phase 3 Prototype Smoke Test

**Prerequisites:**
- Run `./verify_phase3_build.sh` (should pass all checks)
- Open `anigma/Package.swift` in Xcode
- Select `AnigmaAppMacExecutable` scheme
- Press Cmd+R to launch

**Database:** PostgreSQL (db: anigma_v3)

---

## Test 1: Project Persistence

**Goal:** Verify projects survive app restart

1. [ ] Create project "alpha"
2. [ ] Verify "alpha" appears in sidebar
3. [ ] Quit app (Cmd+Q)
4. [ ] Relaunch app
5. [ ] Verify "alpha" still in sidebar and selectable

**Expected:** Project persists across launches  
**If fails:** Database write/read broken or path wrong

---

## Test 2: Basic Indexing

**Goal:** Verify indexing runs and shows progress

1. [ ] Select project "alpha"
2. [ ] Go to Index tab
3. [ ] Pick a small folder (<200 files, e.g., a git repo)
4. [ ] Start indexing
5. [ ] Observe:
   - [ ] Progress updates (files processed count increments)
   - [ ] Log lines appear and cap (no infinite scroll)
   - [ ] Cancel button works (stops stream, phase → cancelled)

**Expected:** Progress live updates, clean termination  
**If fails:** Stream producer broken or UI binding wrong

---

## Test 3: Denial During Indexing (The Critical One)

**Goal:** Verify readOnly mode blocks writes mid-stream

1. [ ] Start indexing a medium folder (500+ files)
2. [ ] While indexing is running, go to status panel
3. [ ] Flip project to **Read Only**
4. [ ] Observe:
   - [ ] Indexing stops immediately (not after "completing current file")
   - [ ] Denial banner appears with:
     - [ ] Check ID (e.g., "operating-mode")
     - [ ] Mode source (e.g., "project alpha")
     - [ ] Violation ID (copyable, looks like UUID)
     - [ ] Principal + projectId visible
   - [ ] Indexing phase becomes **failed/denied**, NOT "complete"
   - [ ] No silent swallowing

**Expected:** Denial is loud, terminal, and shows structured violation  
**If fails:** Stream termination broken or governance bypass

---

## Test 4: Recall Works in Read-Only

**Goal:** Verify reads allowed when writes blocked

1. [ ] Project still in readOnly from Test 3
2. [ ] Go to Search tab
3. [ ] Enter recall query (any text that should match indexed content)
4. [ ] Run recall
5. [ ] Observe:
   - [ ] Results appear
   - [ ] Stats shown (rows scanned, time elapsed, limit)
   - [ ] No denial banner

**Expected:** Recall succeeds, proves read/write split works  
**If fails:** OperatingModeCheck blocking reads or projectId scoping broken

---

## Test 5: Memo Denied in Read-Only

**Goal:** Verify writes blocked for memos too

1. [ ] Project still in readOnly
2. [ ] Go to Memo tab
3. [ ] Type some text
4. [ ] Try to save
5. [ ] Observe:
   - [ ] Denial banner with structured violation (same format as Test 3)
   - [ ] Memo does NOT appear in recall results

**Expected:** Write denied, violation surfaced  
**If fails:** Memo write path bypassing governance

---

## Test 6: Memo Works in Assistive

**Goal:** Verify mode flip re-enables writes

1. [ ] Flip project back to **Assistive** (or Autopilot)
2. [ ] Go to Memo tab
3. [ ] Save memo
4. [ ] Observe:
   - [ ] No denial banner
   - [ ] Memo saved (shows saved timestamp/ID)
5. [ ] Go to Search tab
6. [ ] Recall should now return the memo

**Expected:** Write succeeds, memo retrievable  
**If fails:** Mode change not applied or memo storage broken

---

## Test 7: Kill Switch Blocks Everything

**Goal:** Verify kill switch overrides mode

1. [ ] Project in Assistive (writes normally allowed)
2. [ ] Turn **Kill Switch ON** in status panel
3. [ ] Try to save memo
4. [ ] Observe:
   - [ ] Denial banner with check ID "kill-switch"
   - [ ] Memo NOT saved
5. [ ] Turn kill switch **OFF**
6. [ ] Save memo again
7. [ ] Observe:
   - [ ] Succeeds
   - [ ] Appears in recall

**Expected:** Kill switch blocks writes, turning it off restores writes  
**If fails:** KillSwitchCheck not running or cache invalidation broken

---

## Test 8: Project Scoping

**Goal:** Verify projects don't leak into each other

1. [ ] Create second project "beta"
2. [ ] Index a *different* folder into "beta"
3. [ ] Recall in project "alpha"
4. [ ] Verify results are ONLY from alpha's folder
5. [ ] Recall in project "beta"
6. [ ] Verify results are ONLY from beta's folder
7. [ ] Flip "alpha" to readOnly
8. [ ] Verify "beta" still allows writes (if in assistive/autopilot)

**Expected:** Projects isolated, mode changes scoped  
**If fails:** Empty projectId or global mode applied everywhere

---

## Success Criteria

**Prototype is "usable" if:**
- ✅ All 8 tests pass
- ✅ Denial banners show structured violations (check ID, mode source, violation ID)
- ✅ No silent failures (every denial is loud and terminal)
- ✅ Database persists across restarts
- ✅ Project scoping works

**If any test fails:**
- Note which step failed
- Check logs for governance violation extraction
- Verify ExecutionContext has correct projectId
- Check that WriteProposal context is correctly scoped

---

## Known Limitations (Phase 3)

These are expected and acceptable for the prototype:

- No daemon (all in-process)
- No background indexing
- No IPC/XPC
- No advanced UI polish
- Deterministic embeddings only (not real ML)

These will be addressed in Phase 4 when daemon is reintegrated behind `HarmoniaAppClient` protocol.

---

## Next Steps After Smoke Test

If all tests pass:
1. Lock the minimal target (add CI job running verify script)
2. Add UI polish for denial banners (show violation details)
3. Start Phase 4 planning: daemon as client implementation, not direct dependency

If tests fail:
1. Debug exactly which step broke
2. Fix at the correct layer (surface/governance/UI)
3. Re-run harness + smoke test
4. Don't move forward until green
