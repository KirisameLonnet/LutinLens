LUT Feature TODO

This document tracks remaining work to deliver a robust, real-time LUT pipeline across preview, capture, and management. Includes a Done section to reflect progress.

Done

- [x] Software LUT overlay on CameraPreview (downsampled YUV -> RGBA -> LUT -> canvas overlay)
  - File: `lib/src/lut/simple_lut_preview.dart`
- [x] Provider → preview wiring and selection persistence (name/path)
  - Files: `lib/src/provider/lut_provider.dart`, `lib/src/utils/preferences.dart`
- [x] Default LUT path now uses user luts directory
  - File: `lib/src/lut/lut_preview_manager.dart`
- [x] Exposed image stream stop/resume hooks for coordination
  - Files: `lib/src/lut/simple_lut_preview.dart`, `lib/src/lut/lut_preview_manager.dart`
- [x] Remove all video functionality; app is photo-only
  - Files: `lib/src/pages/camera_page.dart`, `lib/src/widgets/capture_control.dart`

P0 — Must Fix/Implement

- [x] Wire provider to preview manager
  - Selecting a LUT via selector/management switches the preview overlay and persists selection (name/path).

- [x] Default LUT copy logic and CSV name
  - Dynamic discovery of available LUTs; no hardcoding.
  - Accepts both `describe.csv` and legacy `discribe.csv`; generates per-LUT `*_describe.csv` and supports generic `describe.csv` for updates.
  - File: `lib/src/utils/lut_manager.dart`
  - Acceptance: Fresh init copies whatever default LUTs exist without errors and provides description metadata.

 - [x] Preview/image stream coordination for capture
  - Implemented in `lib/src/pages/camera_page.dart` within `takePicture()` using `LutPreviewManager.instance.stopImageStream()` / `resumeImageStream()`.
  - Acceptance: Taking pictures works reliably with LUT preview enabled (no concurrent stream errors).

 - [x] Orientation and mirror correctness for overlay
  - Implemented in `lib/src/lut/simple_lut_preview.dart` painter: rotates by `deviceOrientation` and mirrors for front camera.
  - Acceptance: Overlay aligns with preview across orientations and front/back cameras.

- [ ] Handle controller changes
  - When the active `CameraController` changes (camera switch), ensure the previous image stream is stopped and the new one is started if needed.
  - Acceptance: Switching cameras keeps preview stable; no orphaned streams.
  
  Status: Implemented
  - [x] Stop/resume around camera switch and controller init; notify provider to resync LUT
  - Files: `lib/src/pages/camera_page.dart` (onNewCameraSelected, _initializeCameraController), `lib/src/provider/lut_provider.dart:onCameraControllerChanged`

P1 — Next Up

- [ ] Persist preview state
  - [x] Persist selected LUT (name/path)
  - [x] Persist mix strength
  - [x] Persist enabled flag
  - [x] Initialize from persisted state during app start.
  - Files: `lib/src/lut/lut_preview_manager.dart`, `lib/src/provider/lut_provider.dart`, `lib/src/utils/preferences.dart`.
  - Acceptance: App restores last used LUT and strength/enable after restart.

- [x] Wire `LutMixControl` to persistence
  - `setMixStrength` persists via `LutPreviewManager`; slider reads current value from manager.
  - Acceptance: Mix slider reflects persisted value on launch and changes survive restarts.

- [ ] Unify LUT settings/management flow
  - Implement import in `lib/src/lut/lut_settings_page.dart` via `LutProvider.importLut(...)`.
  - Prefer a single entry point in camera UI (e.g., `CompactLutSelector`) for selection and quick access to management.
  - Acceptance: No duplicated responsibilities; import works and updates the preview.

- [ ] Permission checks for import/export
  - Use `permission_handler` to request storage/media permissions before import/export.
  - Files: `lib/src/pages/lut_management_page.dart`, `lib/src/utils/lut_manager.dart`.
  - Acceptance: Import/export succeeds across API levels with proper prompts.

- [ ] Improve cube parser resilience
  - Support optional `DOMAIN_MIN`/`DOMAIN_MAX` and stricter error messages with line context.
  - File: `lib/src/lut/cube_loader.dart`.
  - Acceptance: Wider .cube compatibility and clearer error logs.

- [ ] UV plane compatibility toggle
  - Provide a fallback to swap U/V if colors are off on certain devices; optionally support BT.709.
  - File: `lib/src/lut/simple_lut_preview.dart`.
  - Acceptance: Color accuracy fix available for affected devices.

- [ ] Asset declarations cleanup
  - In `pubspec.yaml`, avoid listing the entire `lib/src/lut/` as assets; only include required resources (e.g., `lut_shader.glsl`) if needed.
  - Acceptance: Smaller asset bundle; no runtime missing asset issues.

- [ ] Remove video remnants
  - Drop `video_thumbnail` dependency from `pubspec.yaml`, remove unused l10n strings and any video-related settings toggles.
  - Acceptance: Build has no unused video deps/strings; settings show only photo-related options.

- [ ] Tests for LUT and stream coordination
  - Add/complete tests for: default LUT copy/describe fallback, import/delete flow, and stop/resume image stream around capture.
  - Files: `test/lut_manager_test.dart`, `test/image_stream_coordination_test.dart`.
  - Acceptance: Tests pass and cover the main flows.

P2 — Later/Enhancements

- [ ] GPU-based real-time LUT preview
  - Implement a `LutRenderer` using `flutter_gl` and `lib/src/lut/lut_shader.glsl`:
    - Upload Y/U/V as textures, LUT as 3D texture (or 2D strip) and render with shader mixing.
    - Replace software overlay for better performance and fidelity.
  - Files: `lib/src/lut/lut_preview.dart` (refactor), new renderer service.
  - Acceptance: Smooth 30/60fps preview with low CPU usage.

- [ ] Offline LUT application on captured photos
  - After capture, apply LUT with `SoftwareLutProcessor` in an isolate (or GPU) before saving.
  - File: `lib/src/pages/camera_page.dart`.
  - Acceptance: Saved photo matches preview look (within reason/transfer function).

- [ ] Clean up `lib/src/lut/lut_preview.dart`
  - Remove half-finished GL snippets and rebuild around the renderer service.
  - Acceptance: No dead code; clear, maintainable pipeline.

- [ ] Diagnostics & toggles
  - Add a debug panel: show frame time, target size, UV mode; toggle between software/GPU paths when both exist.
  - Acceptance: Easier QA across devices.

Notes / References

- Preview overlay implementation: `lib/src/lut/simple_lut_preview.dart`
- Provider and state: `lib/src/provider/lut_provider.dart`
- Manager: `lib/src/lut/lut_preview_manager.dart`
- LUT files and copy: `lib/src/utils/lut_manager.dart`
- Cube parser: `lib/src/lut/cube_loader.dart`
- Shader (future GPU path): `lib/src/lut/lut_shader.glsl`
- Camera page (capture & UI): `lib/src/pages/camera_page.dart`
