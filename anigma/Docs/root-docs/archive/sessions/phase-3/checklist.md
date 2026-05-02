# Phase 3 Lockdown Checklist

**Use this checklist EXACTLY. No improvisation.**

---

## Step 1: Run Smoke Test (15 minutes)

```bash
cd /Users/user/Developer/GitHub/Anigma_clean
./run_prototype.sh
```

In Xcode:
- Open `anigma/Package.swift`
- Select `AnigmaAppMacExecutable` scheme
- Press Cmd+R

**Follow PHASE3_SMOKE_TEST.md exactly (all 8 tests).**

For each denial (Tests 3, 5, 7):
- [ ] Screenshot denial banner
- [ ] Copy violation ID from banner
- [ ] Note: project name, mode, operation

**If ANY test fails:**
1. Stop immediately
2. Document failure in PHASE3_COMPLETE_EVIDENCE.md
3. Fix that layer
4. Rerun `./verify_phase3_build.sh`
5. Rerun full smoke test from step 1
6. DO NOT proceed until 8/8 pass

---

## Step 2: Fill Evidence File (5 minutes)

Edit `PHASE3_COMPLETE_EVIDENCE.md`:
- [ ] Replace all `[PENDING]` with actual results
- [ ] Paste violation IDs from Tests 3, 5, 7
- [ ] Mark each test ✅ PASS or ❌ FAIL
- [ ] Add commit hash: `git rev-parse HEAD`
- [ ] Add any notes from testing

**Do not proceed if any test marked FAIL.**

---

## Step 3: Freeze and Tag (2 minutes)

```bash
./freeze_phase3.sh
```

This will:
- Run final verification
- Check evidence file is complete
- Create annotated tag `phase3-complete`
- Commit evidence + CI workflow

**If script fails:**
- Read error message
- Fix issue
- Try again

---

## Step 4: Push and Verify CI (5 minutes)

```bash
git push origin main --tags
```

Then:
- [ ] Go to GitHub repo
- [ ] Check Actions tab
- [ ] Verify "Phase 3 Verification" runs green
- [ ] If fails: check logs, fix, push again

---

## Step 5: Branch for Phase 4 (1 minute)

```bash
git checkout -b phase4-daemon-client
```

**From now on:**
- Phase 3 work = main branch only
- Phase 3 changes require smoke test + CI verification
- Phase 4 work = phase4-daemon-client branch
- Never mix Phase 3 edits with Phase 4 features

---

## Success Criteria

All must be true:
- [ ] Smoke test: 8/8 passing
- [ ] Evidence file: complete with violation IDs
- [ ] Tag: phase3-complete created
- [ ] CI: phase3-verification.yml active and green
- [ ] Branch: phase4-daemon-client created

**If all checked:** Phase 3 is locked. Start Phase 4.

**If any unchecked:** Stop. Fix. Don't proceed.

---

## What Happens If You Skip This

- No smoke test = unknown if UI actually works
- No evidence = can't debug regressions
- No tag = can't roll back to known-good state
- No CI = silent regressions
- No branch = Phase 4 work contaminates Phase 3

**This is the difference between "works" and "provably works."**

Run the checklist. Don't skip steps.
