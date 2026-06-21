# Window classification fixtures

Each `*.json` file is a `WindowDiagnosticDump` (scrub PII before committing — see below).
`WindowClassificationRegressionTests`
loads every fixture, feeds `omniwm.input` through `WindowClassificationReproducer.recompute`,
and asserts the result matches `omniwm.expected`. A change to `WindowRuleEngine` that alters a
captured decision fails the suite, naming the offending fixture file.

## Adding a fixture

1. Focus the window in the running app.
2. Settings → Diagnostics → **Dump Focused Window AX**. This writes a verbatim (unredacted)
   `omniwm-window-<id>-<ts>.json` into the diagnostics directory
   (`~/.local/state/omniwm/diagnostics/`).
3. Copy that file here with a descriptive name (`<app>-<case>.json`).
4. **Scrub any private strings by hand** (titles, document names, URLs, AX values) — the dump
   is not redacted. If the decision depends on a title-matching rule, replace the title with a
   synthetic literal that still satisfies the rule so the fixture stays reproducible.
5. The dump already carries `omniwm.expected` captured live, so the fixture pins that decision
   on commit. The bulky `ax` tree is not read by the test and may be trimmed to empty nodes for
   hand-authored cases.
