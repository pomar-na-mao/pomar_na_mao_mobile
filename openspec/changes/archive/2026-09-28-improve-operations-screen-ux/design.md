## Context

See `proposal.md` for motivation. The existing Operations screen is a Flutter Material 3 screen with an app bar, a short header and a responsive grid of operation cards. Only Inspecao is enabled; the other operations are intentionally listed but unavailable.

The change is UI/UX focused and should follow the app's existing Flutter/Material style. It should feel like a field operations tool: compact, scan-friendly and action-oriented, not like a marketing landing page.

## Goals / Non-Goals

**Goals:**

- Make Inspecao the obvious primary action.
- Preserve visibility of future operations without giving them equal action weight.
- Improve accessibility and semantic clarity for enabled and disabled states.
- Keep the layout responsive from 320 px mobile widths through tablet/desktop widths.
- Preserve the current navigation behavior and tests around opening Inspecao.

**Non-Goals:**

- Add new operational modules for Pulverizacao, Irrigacao, Colheita or Analise de Solo.
- Change inspection data, map behavior, offline sync, Supabase access or persistence.
- Add external UI dependencies.
- Redesign the app shell or bottom navigation.

## Decisions

### Decision: Split the catalog into primary and future sections

Inspecao should be rendered as the primary available operation, followed by a secondary section for future operations. This gives the user a clear first action while preserving the catalog.

Alternative considered: keep a uniform grid and only adjust colors. That keeps implementation small, but the action priority remains ambiguous because enabled and disabled operations still occupy the same hierarchy.

### Decision: Use compact operational summary instead of a large hero

The top of the screen should provide a concise status summary such as available routines and future routines, but it should not dominate the viewport. On small screens, the primary action should appear quickly after the app bar.

Alternative considered: larger illustrated header. That would look richer but is less appropriate for repeated operational use and consumes valuable mobile height.

### Decision: Keep Material iconography and card patterns

Use built-in Material icons already present in the codebase or existing icon metadata from `OperationDefinition`. Maintain consistent icon size, color roles and shape language. Avoid emoji icons and decorative imagery.

Alternative considered: introduce custom asset illustrations. That is unnecessary for this small catalog and would add maintenance cost without improving task completion.

### Decision: Disabled cards remain focusable/understandable but non-navigating

Future operation cards should expose status text and disabled semantics. They may provide visual feedback appropriate to disabled content, but tapping them must not navigate. If a lightweight message is added later, it must not be required by the spec.

Alternative considered: hide unavailable operations. That would simplify the screen but remove useful roadmap/context from the catalog.

### Decision: Tests should verify behavior and layout contracts, not pixel styling

Widget tests should cover primary action hierarchy, disabled operation semantics, no navigation for unavailable cards, and responsive behavior at 320 px, tablet and wide widths. Visual details can be verified through golden or manual review only if the implementation makes that worthwhile.

Alternative considered: assert exact colors and dimensions. That would make tests brittle and slow iteration without improving behavioral confidence.

## Risks / Trade-offs

- [Risk] The primary card could become too large and push future operations too far down on 320 px screens. -> Mitigation: constrain the header and primary card height; test at 320 px.
- [Risk] Disabled operations could look too muted and become unreadable. -> Mitigation: require status text, sufficient contrast and accessibility semantics.
- [Risk] Existing tests that expect one uniform grid may need updates. -> Mitigation: update tests around behavior and responsive contracts rather than implementation-specific grid structure.
- [Risk] Rewriting the screen could disturb navigation into Inspecao. -> Mitigation: keep `_openOperation` behavior unchanged and cover it with existing navigation tests.

## Migration Plan

1. Update operation metadata only as needed for subtitles, status labels or grouping.
2. Refactor the Operations screen layout into compact summary, primary action and future operations sections.
3. Update `OperationCard` or introduce small section-specific widgets if that keeps semantics clearer.
4. Update widget tests for hierarchy, responsiveness and disabled semantics.
5. Run Flutter widget tests and static analysis.

Rollback is straightforward: revert the UI/layout changes and keep the existing operation definitions and navigation behavior.
