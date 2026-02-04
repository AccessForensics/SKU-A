# Release Notes

## SKU-A v3.5 (Hardened, Locked)

Passive capture enforces zero interaction.
Interactive mode validated via capability controls.
All restrictions are intentional and mechanically enforced.
# TEST AUTHORITY — Access Forensics SKU-A v3.5

## Purpose

This document defines the **authoritative test reference** for Access Forensics SKU-A v3.5.  
It exists to prevent post-hoc reinterpretation, selective citation, or ambiguity regarding test validity, scope, or finality.

Any test results, claims of compliance, or representations of system behavior **must anchor to the authority defined here**.

---

## Authoritative Reference

**Primary Authority Tag**

- **Tag:** `v3.5-tests-complete`
- **Commit:** `3c94ca2`
- **Branch Alignment:** `main`, `origin/main`, and `origin/HEAD` all point to this commit

This tag represents the **complete, deterministic, and finalized test suite** for Access Forensics SKU-A v3.5.

No commits after this tag modify executor behavior, test logic, verification criteria, or sealing rules for v3.5.

---

## Relationship to Other Tags

The following tags exist for historical or developmental context only and are **not authoritative**:

- `v3.5.0` — Product freeze (executor behavior lock)
- `v3.5-test02-pass` — Intermediate validation milestone
- `v3.5-tests01-03`
- `v3.5-tests01-03-renormalized`

These tags **do not supersede** `v3.5-tests-complete` and must not be used as proof of final system behavior.

---

## Scope of the Authoritative Test Suite

The authoritative suite enforces, at minimum:

- Deterministic step indexing
- Strict selector ambiguity hard-fail (>1 match)
- Policy gate enforcement (passive vs interactive capture)
- Explicit misuse classification in `STATUS.txt`
- Sealed failure behavior (failed runs still produce complete packets)
- Mandatory manifest inclusion of:
  - `STATUS.txt`
  - `Execution_Report.txt`
  - `interaction_log.json`
  - `flow_plan.sealed.json`
  - `run_metadata.json`
  - `packet_hash.txt`
- URL provenance logging (start and final URL sealed)
- Verification via deterministic PowerShell harnesses

All tests are designed to be **repeatable, non-heuristic, and non-interpretive**.

---

## Finality Statement

As of tag `v3.5-tests-complete`, the Access Forensics SKU-A v3.5 test suite is considered:

- Final
- Complete
- Deterministic
- Non-evolving

Any future changes to executor behavior or test logic **must occur under a new semantic version and a new authority tag**.

---

## Usage Guidance

When referencing system behavior, validation results, or compliance claims:

- Cite **`v3.5-tests-complete`**
- Reference this document
- Avoid referencing branch tips, local runs, or intermediate tags

Failure to do so constitutes reliance on **non-authoritative material**.

---

## Custody Note

This repository preserves full commit history, tags, and test artifacts.  
Authority is established by cryptographic commit hashes and annotated tags, not by narrative description.
All claims about Access Forensics SKU-A v3.5 test coverage, deterministic behavior, or verification outcomes are governed exclusively by the repository state at the annotated Git tag v3.5-authority


