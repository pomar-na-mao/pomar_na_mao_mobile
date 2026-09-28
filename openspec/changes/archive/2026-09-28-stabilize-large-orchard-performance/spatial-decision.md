# Spatial Index Decision

## Decision

Use `supercluster: 3.2.0` behind a reusable Dart worker owned by `PlantSpatialIndex`.

## Why

- Compatible with the current dependency graph and pinned in `pubspec.lock`.
- Supports clustered viewport queries before data crosses into `google_maps_flutter`.
- Keeps the map feed bounded to 1,000 plant objects without truncating records.
- Preserves access to coincident points through paged cluster membership.

## Verification

- `test/features/farm/plant_spatial_index_test.dart` validates 21,000 and 50,000 plant fixtures at zoom 0, 10 and 20 with every valid plant represented by individual markers or clusters and a maximum of 1,000 returned objects.
- The same test suite validates 2,100 coincident points, member paging at 50 items per page, coordinate changes with unchanged total count, viewport-specific results and dispose behavior during worker startup.
- Physical profile runs on Samsung SM-S926B / Android 16 with 21,000 synthetic plants passed map navigation checks with nonempty Fazenda and Inspecao markers:
  - `profile-21000-50nav-inspection-markers-valid.json`
  - 50 navigation transitions, max navigation sample 56 ms.
  - p99 UI 16.604 ms, p99 raster 14.024 ms.

## Limits

This decision covers the spatial library and worker prototype. It does not complete the SQLite staging pipeline, incremental ID-level map updates, the full 0/1k/21k/50k Android matrix, or release memory stability acceptance.
