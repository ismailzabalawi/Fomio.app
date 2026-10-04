# Composer v4 r1 supplemental disposition

These files supplement [18 — r1 reconciliation](../18-composer-v4-r1-reconciliation.md)
after Ismail approved its five policy recommendations on 2026-09-30. They do
not replace the immutable r1 acceptance or copy CSVs, authorize Stage 1, or
approve a build reference.

- `acceptance-disposition.csv` lists all 35 r1 acceptance records whose
  `decisions` field explicitly names D1–D10. Each row records current scope,
  native/settings evidence still needed, and the pending build-reference
  approval. Other r1 records can share affected copy; absence here does not
  grant approval.
- `copy-disposition.csv` selects 49 r1 copy entries affected by D1–D10,
  P-1–P-4, LT, shared recovery copy, or the approved native-default policy.
  `r1_mapping_index` is the one-based **record order** in
  `composer-v4-copy-mapping-r1.csv`, not a physical text line number. The
  original mapping remains the complete 103-row inventory.

The direction is approved, while exact native behavior, settings, labels and
conditional Fomio copy remain unverified. The r1 capture is design evidence,
not a Discourse implementation. Review a separate build reference after
those gaps are addressed; Stage 1 needs distinct authorization.
