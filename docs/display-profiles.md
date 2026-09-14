# Display Profiles

Display Profiles let workspace assignments follow a Mac between desks, a single external display, and Sidecar. Configure them in **Settings → Monitors → Display Profiles**.

A profile contains a name, the displays that must be connected, and workspace-to-monitor assignments. Profiles affect workspace homes; they do not change macOS display geometry, resolution, or which monitor is primary.

## Selection and activation

Profiles are evaluated in list order. With automatic switching enabled, the first eligible profile wins. All required displays and assignment destinations must be available; additional connected displays are allowed. Reorder profiles to resolve overlapping setups explicitly.

Selecting a profile in the editor does not activate it. **Apply** activates it manually and pauses automatic switching. Resume automatic switching to return to display-based selection. **Use Base Assignments** pauses automation and removes the active profile overlay without deleting saved profiles.

Profiles overlay workspace monitor assignments while preserving workspace IDs, display names, layout types, and base configuration. Workspaces settings shows a notice when a profile overrides its base monitor assignments. An unmatched topology uses base assignments. Automatic switching is off by default for existing installations.

A monitor may receive zero workspaces. For example, assign all five workspaces to an ultrawide monitor while leaving the built-in display connected with no assigned workspaces. This is separate from the monitor setup wizard's workspace-coverage guidance.

## Example setups

| Profile | Required displays | Assignments |
| --- | --- | --- |
| Ultrawide | Ultrawide monitor | Workspaces 1–5 on ultrawide; none on built-in |
| Home / Sidecar | Built-in and Sidecar | 1–3 on built-in; 4–5 on Sidecar |
| Work | Three external monitors | 1–3 on center; 4 on left; 5 on right |

Keep Ultrawide above other profiles if it should win whenever connected. Display requirements use hardware identities rather than display names so identically named displays are not confused.

## Trying a development build

Use the development workflow in [CONTRIBUTING.md](../CONTRIBUTING.md). **OmniWM Dev** has separate settings and permissions from the normal app. Create or configure profiles in Dev before enabling automatic switching.

If an external script also rewrites workspace assignments, pause that script before testing native automatic switching. Restore it when switching back to a release that does not contain Display Profiles. Never run two window-manager copies together.

Before sharing a development result, verify startup, reconnect, overlapping matches, no match, manual apply, pause/resume, and zero-workspace displays. Check actual live workspace assignments, not only the selected profile label. Native fullscreen transitions may defer movement until it is safe.
