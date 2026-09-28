# Verification Log

## 2026-09-27 - Synthetic datasets

- Added `test/support/orchard_fixture.dart` with deterministic 0/1k/21k/50k datasets, 20 zones, occurrence catalog, non-existent plants, invalid coordinates and dispersed/dense/coincident layouts.
- Seeding uses the existing local-store API, including a finalized pending inspection for nonempty datasets. No production services are contacted.
- `flutter test test/performance/orchard_fixture_test.dart`: 7 tests passed. All four sizes persisted and reopened with complete IDs, counts, zones, catalog and pending payload intact.
- `dart analyze test/support/orchard_fixture.dart test/performance/orchard_fixture_test.dart`: no issues.
- These are host correctness tests, not Android performance measurements. No startup, navigation, frame, PSS or ANR acceptance criterion is claimed.

## 2026-09-27 - Physical profile runs on synthetic 21k orchard

Device: Samsung SM-S926B, Android 16, 11,472,028 kB MemTotal. The benchmark uses the isolated package suffix `.benchmark` via `ORCHARDBENCHMARK=true`, a synthetic local SQLite cache and no production HTTP.

Preserved artifacts:

- `baseline-21000.json`: pre-optimization warm profile baseline.
- `bounded-maps-21000.json`: bounded map projection run before lifecycle coordination.
- `lifecycle-21000.json`: 50 navigation transition lifecycle run before the nonempty Inspection marker assertion.
- `profile-21000-short-inspection-markers.json`: short marker assertion run.
- `profile-21000-50nav-inspection-markers-valid.json`: valid 50 transition run rebuilt with `NAVIGATION_CYCLES=50`.

Valid 50-transition profile result:

- Plants: 21,000 synthetic records.
- Shell to navigable UI: 4,547 ms. This still fails the proposed p95 shell budget of <=2 s because the splash video remains full length.
- Navigation samples: 50, max 56 ms.
- Frame build: average 9.897 ms, p90 13.46 ms, p99 16.604 ms, worst 25.336 ms.
- Raster: average 4.61 ms, p90 8.269 ms, p99 14.024 ms, worst 29.733 ms.
- Diagnostics: `databaseOpen=1`, `localRead=2`, `decode=1`, `lifecycle=99`, `markers=8` recorded 35 times, `markers=0` recorded twice during map mount/teardown. Test assertions verified active Fazenda and Inspecao maps had nonempty markers and no map exceeded 1,000 marker objects.

This is strong evidence for the bounded map and lifecycle approach, but it is not the full acceptance matrix. Pending items include 0/1k/50k physical runs, 20 background/resume cycles, 10 process restarts, interrupted refresh/sync, release PSS stability, 60 seconds of pan/zoom, and the unresolved splash-duration decision.

## 2026-09-27 - Shared hydration and spatial prototype tests

- `flutter test test/core/data/shared_read_repository_test.dart test/core/diagnostics`: 15 tests passed after shared revision hydration, known-empty cache, project isolation and diagnostic coverage.
- Spatial worker tests cover 21k/50k bounded world projections, coincident cluster paging, viewport-specific queries, same-count coordinate replacement and dispose during startup.
- Decision recorded in `spatial-decision.md`: use `supercluster: 3.2.0` behind `PlantSpatialIndex`.

The diagnostics are connected to runtime stages and exportable from the About screen. Unit coverage now verifies bounded retention, handler chaining, timeout/failure classification, absence of error payloads and an allowlisted aggregate export shape for every diagnostic stage.

## 2026-09-28 - Shared inventory totals and deterministic pagination

- Inventory DI now uses the shared read repository for Supabase-backed app dependencies instead of creating independent farm/zone/inventory read paths.
- Inventory warm-cache totals are read from SQLite `cache_metadata` revision totals, with lazy backfill for upgraded caches, avoiding full plant snapshot hydration for summary counts.
- Warm inventory summaries reuse cached farm, zone and region references without remote GETs.
- Plant and open-occurrence pagination now orders by stable keys, advances by the number of rows actually returned, keeps requesting until an empty page, and fails on repeated or missing stable IDs. This covers Supabase/PostgREST cases where the server returns fewer rows than the requested range.
- Open occurrences select the real `id` column for pagination stability while continuing to expose `plant_id -> occurrence_type_id` state to the UI.

Verification:

- `flutter test test/features/farm/farm_remote_data_source_test.dart test/core/data/shared_read_repository_test.dart test/core/di/app_dependencies_test.dart test/features/inventory/supabase_inventory_repository_test.dart`: 24 tests passed.
- `dart analyze`: no issues found.
- `flutter test`: 147 tests passed after updating the SQLite migration expectation to schema version 3 and aligning the Hass tenant test with the current checked-in tenant configuration.
- `flutter run -d RXCY906F9HZ`: debug build installed and launched on Samsung SM-S926B.
- Flutter CLI hot reload on the physical device completed: `Reloaded 0 libraries in 400ms`.

Notes:

- Runtime logs still include Google Maps / Google Play Services warnings unrelated to Dart exceptions, including location permission and Google API manager messages.
- Dart MCP could not attach to the VM Service after CLI launch, so runtime-error inspection through MCP was not available in this pass.
- Supabase Dart select/range/order docs and the Supabase changelog were checked before changing pagination assumptions; no relevant pagination-breaking change was identified.

## 2026-09-28 - Staging, deadlines, lifecycle and bounded maps

- SQLite schema advanced to v4 with additive `cache_generations` and `staged_plants` tables. Incomplete staged generations are removed on reopen without touching the last complete cache or inspection queue.
- Plant refresh now writes remote pages directly into staging, then publishes in a short final transaction after overlaying pending local edits. Refresh failure, duplicate IDs, timeout or obsolete generation discard staging and keep the previous revision.
- Shared remote reads now use a two-slot async limiter and per-request deadline, defaulting to 30 seconds.
- Navigation/lifecycle behavior remains local to the operation: bottom navigation is usable during shared loads, inactive map surfaces unmount, foreground/background transitions suspend map surfaces, and Fazenda/Inspecao GPS subscriptions are idempotent.
- Bounded map projection is integrated in Fazenda and Inspecao via `PlantSpatialIndex` and `BoundedPlantMarkers`, with viewport/zoom queries, 150 ms camera-idle debounce, generation discard, <=1,000 plant objects and paginated cluster members.

Verification:

- `flutter test test/core/data/shared_read_repository_test.dart`: 18 tests passed, including staged page publication, remote concurrency <=2, timeout cleanup, previous revision retention and local edit during refresh.
- `flutter test test/features/operations/inspection_database_test.dart`: 6 tests passed, including v1/v2 upgrade to v4 and staging cleanup on reopen.
- `flutter test test/core/ui/map_activity_test.dart test/app/main_shell_test.dart test/features/farm/zone_regions_test.dart test/features/farm/plant_spatial_index_test.dart test/features/operations/inspection_view_model_test.dart test/features/operations/inspection_widgets_test.dart`: 35 tests passed.
- `dart analyze`: no issues found after updating integration fakes for paged plant reads.
- `flutter test`: 153 tests passed.
- `openspec validate stabilize-large-orchard-performance --strict`: passed.
- `flutter run -d RXCY906F9HZ`: debug build installed and launched on Samsung SM-S926B; CLI hot reload completed with `Reloaded 0 libraries in 426ms`.

Remaining limitations:

- The complete Android acceptance matrix for 0/1k/21k/50k, PSS stability, 20 hot opens, process kills and interrupted sync still needs physical execution before final acceptance.

## 2026-09-28 - Codec worker, precomputed bounds and Android profile stress

Implementation updates:

- Added `lib/core/data/json_codec_worker.dart` for batched JSON decode/encode in worker isolates, defaulting to 500-item batches.
- `InspectionLocalStore.readSharedPlantRows` now decodes complete plant snapshots through the worker instead of decoding the whole revision on the UI isolate.
- Plant staging now encodes staged snapshots through the same worker before the SQLite write transaction.
- `PlantSpatialIndex.load` now precomputes valid-coordinate bounds in the spatial worker and returns them with the loaded revision.
- Fazenda and Inspecao camera fitting now reuse those precomputed bounds instead of rematerializing all visible plant coordinates just to compute map bounds.
- `BoundedPlantMarkers.dispose` still clears cached cluster icons, disposes the spatial worker and invalidates in-flight generations. Marker icon `Picture`/`Image` instances are disposed after conversion.
- `integration_test/orchard_performance_test.dart` now waits for the asynchronous map projection to settle before asserting nonempty markers, matching the worker-based rendering path.

Host verification:

- `dart analyze`: no issues found after the worker/bounds changes.
- `flutter test`: 153 tests passed.
- Spatial worker tests still cover 21k/50k bounded world projections, same-count coordinate replacement, coincident cluster paging and dispose during startup.

Physical Android device:

- Device: Samsung SM-S926B (`RXCY906F9HZ`), Android 16 / API 36.
- RAM: `/proc/meminfo` `MemTotal: 11472028 kB`.
- Build mode: `flutter drive --profile --no-dds` with synthetic local cache and no production HTTP.
- First profile attempt failed only because `watchPerformance` could not connect through DDS; rerun with `--no-dds` passed.

Profile run, 21,000 plants, 50 navigation cycles:

- Command: `flutter drive --profile --no-dds -d RXCY906F9HZ --driver=test_driver/orchard_performance.dart --target=integration_test/orchard_performance_test.dart --dart-define=PLANT_COUNT=21000 --dart-define=NAVIGATION_CYCLES=50`
- Result: `All tests passed`.
- Frame build: average 9.911 ms, p90 14.621 ms, p99 16.572 ms, worst 18.421 ms.
- Raster: average 4.415 ms, p90 7.785 ms, p99 9.489 ms, worst 36.108 ms.
- Marker assertions verified active Fazenda and Inspecao maps had nonempty marker sets and no GoogleMap exceeded 1,000 plant objects.
- Logcat scan around the run did not show app `FATAL EXCEPTION`, ANR, `am_crash` or low-memory kill entries. Google Maps/Play Services emitted noisy renderer, permission and developer-error warnings unrelated to a Dart crash.

Profile stress run, 50,000 plants, 50 navigation cycles:

- Command: `flutter drive --profile --no-dds -d RXCY906F9HZ --driver=test_driver/orchard_performance.dart --target=integration_test/orchard_performance_test.dart --dart-define=PLANT_COUNT=50000 --dart-define=NAVIGATION_CYCLES=50`
- Result: `All tests passed`.
- Frame build: average 10.171 ms, p90 14.738 ms, p99 17.645 ms, worst 32.576 ms.
- Raster: average 4.220 ms, p90 7.652 ms, p99 10.609 ms, worst 30.221 ms.
- Marker assertions again verified nonempty active maps and the <=1,000 object limit.

Remaining acceptance gaps:

- PSS could not be captured after `flutter drive` completion because the driver terminated the benchmark package before `dumpsys meminfo`; a live release/profile memory harness is still needed.
- The full matrix still lacks 0 and 1,000 plant physical profile runs in this latest implementation pass.
- 20 background/resume cycles, 10 kill/reopen cycles, interrupted refresh/sync scenarios, and 60 seconds of pan/zoom frame capture remain unvalidated on physical Android.
- The shell p95 <=2 s target is still constrained by the existing splash video behavior unless product accepts changing that startup experience.
