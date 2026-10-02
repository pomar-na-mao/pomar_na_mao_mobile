## Context

See `proposal.md` for motivation. The inspection feature already uses an offline-first stack with `InspectionView`, `InspectionViewModel`, `InspectionRepository`, `InspectionLocalStore`, `InspectionDatabase`, and `InspectionRemoteDataSource`. Existing inspection edits sync through `sync_manual_inspection_v2`, while the new flow must insert rows into `plants` without becoming part of an inspection payload.

The `plants` table requires `latitude` and `longitude`, has `non_existent` with a default, and also includes local sync metadata columns (`local_id`, `device_id`, `sync_status`, `synced_at`) used elsewhere in the project. The user requirement is that plant data beyond latitude, longitude, and `non_existent` should use database defaults; this design treats sync metadata as operational metadata, not agronomic plant data, so it may be populated only to preserve retry safety.

The `ui-ux-pro-max` helper script referenced by the skill is not present in this checkout, so the UI approach uses the skill's general mobile UX guidance: icon buttons with tooltips/semantics, stable touch targets, no layout-shifting hover/press states, and responsive constraints. The relevant Flutter/Dart guidance is to keep layouts constraint-driven and add unit/widget tests mirroring the existing test structure.

## Goals / Non-Goals

**Goals:**

- Keep added plants independent from saved inspections in local storage, UI, and remote sync.
- Add map long-press capture, a confirmation modal, a separate list modal, double-tap removal, and a separate sync action without making the action row cramped on mobile.
- Insert remote `plants` rows through a dedicated RPC that sets only coordinates, `non_existent`, optional `zone_id`, and minimal sync metadata.
- Update `database.md` in both the detailed RPC section and the query unica block.
- Preserve current inspection occurrence editing and `sync_manual_inspection_v2` behavior.

**Non-Goals:**

- No automatic variety, planting date, description, occurrence, or operation history inference for added plants (zone is explicitly selected or defaults to the active filter).
- No change to the existing plant editor modal for already-registered plants beyond avoiding gesture conflicts.
- No automatic app launch or dev-server/device management; the app is already running locally.

## Decisions

1. Use a new local queue for added plants.

   Added plants should live in a new SQLite table such as `local_added_plants`, not in `local_inspections`. This keeps list rendering, retry, delete/review behavior, and sync status independent from inspection batches.

   Alternative considered: encode added plants as a special inspection payload. Rejected because it would mix semantics, force `field_operations` creation, and conflict with the requested separate list and sync.

2. Add repository and remote methods dedicated to added plants.

   Extend the inspection repository boundary with methods to create, list, sync, and mark added plants. Keep the remote data source call separate from `syncInspection`, with an injectable RPC name such as `sync_inspection_added_plants`.

   Alternative considered: call Supabase `plants.insert` directly from the client. Rejected because the project centralizes multi-row/offline writes in RPCs and the user explicitly requested a new RPC.

3. Use a compact four-action layout with adaptive behavior.

   The current action card has three equally sized icon buttons. Add an icon-only button for plants added, and expose sync inside the added-plants modal or as a primary icon in that modal. If four buttons do not fit comfortably at small widths, use `LayoutBuilder` to keep touch targets at least 48 logical pixels and wrap into two rows inside the existing action surface.

   Alternative considered: add visible explanatory text or a large second card. Rejected because field use benefits from a compact map-first layout and the project already uses icon tooltips in this area.

4. Map long press opens a confirmation modal before persistence.

   The map layer should expose an `onAddPlantAt(LatLng)` style callback alongside existing plant selection. The callback must fire only for map background long-press events, not marker taps or cluster taps. The modal writes to local storage only after confirmation.

   Alternative considered: create a pending marker immediately on tap and edit inline. Rejected because cancel semantics are cleaner when no durable row exists until confirmation.

5. Double tap removes local added plants.

   Added plant markers and their separate list cards should support double tap to remove the local added-plant row from the queue. Removing a synced local row does not issue a remote delete; it only removes the local queue/list marker.

6. RPC inserts plant rows with defaults and sync metadata.

   Proposed contract: `public.sync_inspection_added_plants(p_payload jsonb)` returns one row per local item with `local_id`, `plant_id`, `latitude`, `longitude`, `non_existent`, `zone_id`, and `sync_status`. For each item it inserts into `public.plants` with `latitude`, `longitude`, `non_existent`, optional `zone_id`, plus `local_id`, `device_id`, `sync_status = 'synced'`, and `synced_at = now()` for idempotent retries. All other plant columns are omitted so database defaults apply.

   To make retries safe, add or document a unique partial index for `plants(device_id, local_id)` where both are not null, if it does not already exist. The function should use qualified object names, `security definer`, `set search_path = ''`, validation for coordinate ranges, revoke from `public`, and grant execute to the same client roles used for mobile offline writes if the app must work before authenticated sessions are available.

   Alternative considered: omit `local_id` and `device_id` from the insert to interpret "all other data defaults" literally. Rejected for the planned implementation because a lost RPC response could create duplicate plants on retry.

## Risks / Trade-offs

- More actions in the inspection action area -> Use responsive constraints and keep sync inside the list modal if four top-level buttons feel crowded.
- Remote duplicate risk if sync metadata is not stored -> Use `device_id` + `local_id` idempotency, or revisit with the user before implementation if strict default-only inserts are mandatory.
- Accidental map taps while panning -> Trigger add only on completed long-press events provided by the map plugin, not camera movement, simple taps, marker taps, or cluster gestures.
- Added plants may not appear in shared plant cache immediately -> After successful sync, merge returned rows into local cache or require the existing Carregar plantas action to refresh, with clear status in the added-plants list.
- RPC grants can widen write access -> Validate payload shape/ranges inside the function, keep direct table writes controlled by existing RLS/grants, and document the intentional exposure in `database.md`.

## Migration Plan

1. Add SQLite migration for the local added-plants queue and reset any `syncing` rows to retryable on open, matching existing inspection behavior.
2. Add the detailed RPC section to `database.md`, then add the same executable definition/grants to the query unica block.
3. Deploy the RPC and supporting unique index before enabling the mobile sync call.
4. Implement Flutter/Dart model, store, repository, remote data source, view model, modal/list widgets, and map callback wiring.
5. Verify with existing operations tests plus new unit/widget tests. Run static analysis and Flutter tests. If connected to the running app through Dart tooling, perform hot reload after code changes.

Rollback: keep the mobile feature hidden or disabled until the RPC exists. If rollback is needed after deployment, stop calling the RPC from the app; local pending rows remain on device and no existing inspection sync contract changes.
