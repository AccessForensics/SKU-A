# AccessForensics/SKU-A
## AUTHORITY PROTOCOL: v3.6.0-LOCKED

# TEST AUTHORITY - Access Forensics SKU-A v3.5

## Purpose

This document defines the authoritative test reference for Access Forensics SKU-A v3.5.

It exists to prevent post-hoc reinterpretation, selective citation, scope drift, or ambiguity regarding test validity, completeness, or finality.

Any test results, claims of compliance, representations of system behavior, or external citations MUST anchor to the authority defined in this document.

---

## Authoritative Reference

### Primary Authority Tag

- Tag: `v3.5-authority`
- Commit: `1f8b429`
- Branch alignment: `main`, `origin/main`, and `origin/HEAD` all resolve to this commit

The annotated tag `v3.5-authority` represents the complete, deterministic, and finalized test authority for Access Forensics SKU-A v3.5.

This authority includes:
- The finalized deterministic test suite
- All verification harnesses and pass/fail criteria
- The authoritative documentation defining test scope and interpretation

No commits after this tag modify executor behavior, test logic, verification criteria, or authority definitions for SKU-A v3.5.

---

## Historical Clarification (Non-Authoritative)

Earlier internal references to "v3.5/" or slash-based identifiers denoted the SKU-A 3.5 version family or test scope during development.

These references were descriptive only and did NOT constitute a Git tag, immutable reference, or binding authority.

All authority for SKU-A v3.5 is now explicitly and exclusively bound to the annotated Git tag `v3.5-authority`.

Slash-based identifiers are deprecated and have no authoritative meaning.

---

## Citation Rule

All statements regarding:
- Test completeness
- Deterministic behavior
- Selector enforcement
- Verification outcomes
- Compliance claims

must cite the tag `v3.5-authority`.

Citations to branches, filenames, commit hashes without the authority tag, or prior version descriptors are non-authoritative.

---

## Authority Freeze

The authority defined by `v3.5-authority` is frozen.

Any future changes to executor behavior, test logic, or verification methodology require:
- A new SKU version, and
- A new authority document, and
- A new annotated authority tag

Absent those steps, no reinterpretation or extension of v3.5 authority is valid.

