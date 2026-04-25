## [0.38.4]
- Added `delete({projectId, path})` to the Dart `Meshagent` client for project storage deletion (`/projects/:project_id/storage/delete`), throwing `NotFoundException` on 404.

## [0.38.3]
- Breaking: `ContainerImage` now exposes `references`/`preferredRef` plus timestamps/media type instead of `tags`/`size`, and `inspectImage` returns manifests/layers with content size.
- Meshagent client adds `canUseLlmProxy` and current-user LLM proxy usage, plus usage filters (users/room/provider/model/usage type).
- Participant models now emit change notifications on attribute and online status updates for reactive UI binding.
- Flutter dev containers UI adds image inspection sheets and updated summary columns (reference and updated time).
- Flutter shadcn adds email parsing with multi-select autocomplete/select-users dialog, and thread list views now react to participant changes.

## [0.38.2]
- RoomContainer now includes a `ports` list parsed from server responses.
- Flutter dev container table displays container ports using the updated container model.

## [0.38.1]
- Breaking: `updateUser` now requires `canUseLlmProxy`, and user-management calls accept the new permission flag.
- Flutter meeting connections now enable camera and microphone in parallel to improve join behavior and keep pending media state accurate.
- Dart examples were refreshed to use the `websocketProtocol` helper for room connections, add `SimpleValue` types and richer element descriptions in schema examples, and remove the schema-registry example.

## [0.38.0]
- Added `llm_proxy` to the full OAuth scope set.
- Breaking: `LoginScope` now defaults to the full OAuth scope rather than `profile` only.

## [0.37.2]
- Stability

## [0.37.1]
- Meeting controls now detect camera and microphone availability, track unavailable state, and reflect it in toggle styling and device settings.
- Added shared theme colors (custom green and foreground) and exported them from the Flutter package.
- Voice transcript paths now use human-friendly local timestamp filenames with helpers to format legacy transcript names.
- Transcript viewer now shows a header with date/time/duration, participant avatars, and per-segment timecodes using participant roles.
- Breaking: `TranscriptSegment` now requires a transcript start time parameter to render timecodes.

## [0.37.0]
- Breaking: Database client now supports `json`, `uuid`, `list`, and `struct` types with typed wrappers (DatabaseJson/DatabaseStruct/DatabaseExpression/DatabaseDate/UuidValue); list/struct values must be wrapped and SQL params use the new encoding.
- Breaking: Containers build now streams build contexts (start/data chunks) with `mountPath`/`chunks` and removes `startBuild`.
- Breaking: Toolkit/hosting refactor replaces RemoteToolkit with HostedToolkit/startHostedToolkit, removes ToolkitConfig and `supports_context`, and introduces room-bound toolkits with validationMode.
- Added MCP connector discovery helpers and chat UI capability negotiation (tool-choice and MCP selection) in Flutter Shadcn components.
- Participant tokens now support LLM grants, preserve extra payload fields, and ApiScope defaults include LLM.

## [0.36.3]
- Storage client now supports move operations and emits file moved events.
- Secrets client now supports existence checks.
- Project user add calls now omit permission fields unless explicitly set.
- Flutter shadcn file preview now loads markdown/PDF/code directly from room storage and surfaces download URL errors.

## [0.36.2]
- Breaking: Removed share-connect API from the Dart client (`connectShare` / RoomShareConnectionInfo).
- Added full OAuth scope constants and exported them from the main `meshagent` library.
- Auth defaults changed to `profile`; the Dart client now raises `ForbiddenException` on 403 profile access and Flutter auth signs out/restarts login (sign-out clears cached user).

## [0.36.1]
- File preview/viewer now recognizes `.thread` files as chat threads and renders them with the thread viewer rather than custom viewers.

## [0.36.0]
- Added room registry APIs and Flutter developer console UI for listing, retagging, and deleting registry images.
- Dart service models now include config mounts and agent email/heartbeat settings with typed prompt content.
- Breaking: container API key provisioning was removed from Dart container specs.
- Service template container mounts now round-trip project, image, file, empty-dir, and config mounts.
- Flutter chat threads now keep attachment-only messages visible and filter unsupported event kinds consistently.
- Service template editor now defaults enum variables to valid values and normalizes invalid selections.
- Added `visibility_detector` ^0.4.0+2 as a Flutter Shadcn dev dependency.

## [0.35.8]
- Live trace viewer and developer console now support trace search filtering across span metadata while preserving parent/child context.
- File preview components now reload code from room/url/text with error handling, load PDFs from room storage, improve image loading/error states, and recognize plaintext files as code.
- Context menus can optionally center within boundaries and refresh anchors on viewport changes.
- Dart SDK examples updated to use storage upload and decode bytes, with cleanup of empty example stubs.

## [0.35.7]
- Added container build lifecycle support in the Dart SDK (start/build returning `build_id`, list/cancel/delete builds, build logs, image load) plus exec stderr streaming and stricter status decoding.
- Breaking: container build APIs now return build IDs and BuildInfo fields changed; container stop defaults to non-forced.
- Added storage upgrades: `stat`, upload MIME-type inference, storage entries now include created/updated timestamps, and stricter download metadata validation.
- Added secrets client enhancements: async OAuth/secret request handlers, optional client ID, flexible get/set secret by id/type/name, and requestOAuthToken returns null when no token is provided.
- Added database version metadata (TableVersion now includes metadata) and improved where-clause encoding.
- Added RoomClient helpers to inspect participant tokens and API grants.
- Breaking: messaging stream APIs removed (stream callbacks and MessageStream types); use streaming toolkits instead.

## [0.35.6]
- Dart StorageClient now honors server-provided `chunk_size` pull headers when streaming uploads.
- Flutter developer tools now sort containers by name/image/starter for stable ordering, and the trace viewer deduplicates span updates with improved timeline layout and timestamp formatting.
- New coordinated context-menu system adds adaptive anchoring and shared controller coordination across chat, attachments, and file previews.
- Chat UI refinements improve reaction/attachment menus, action visibility timing, and context-menu boundaries for cleaner interactions.
- Meeting controls are redesigned with pending mic/camera states, error toasts, responsive layouts, and a unified device settings dialog.
- Participant tiles now use camera publications and updated overlays, while voice agent calling adds start-session error handling and responsive waveform/controls.

## [0.35.5]
- Chat threads now keep a dedicated scroll controller and auto-scroll to the latest message after send.
- Chat bubble context menus now coordinate a single active menu and close on outside taps, with improved controller cleanup.

## [0.35.4]
- Stability

## [0.35.3]
- Stability

## [0.35.2]
- Stability

## [0.35.1]
- Flutter dev tooling now provides a mount-aware terminal launch dialog for image/container sessions (room/image mounts) and integrates it into the developer console, with improved image list sorting/labels.
- Flutter ShadCN attachment previews now key by file path and surface upload failures with toast + destructive styling.

## [0.35.0]
- Managed secret APIs were added with project/room CRUD, base64 payloads, managed secret models, and external OAuth registration CRUD for project and room scopes.
- Meshagent client now accepts an optional custom HTTP client, and legacy secret helpers now wrap the managed secret APIs.
- Room memory client now provides typed models and operations for inspect/query/upsert/ingest/recall/delete/optimize, including decoding of row-based results and binary values.
- Breaking: chat thread widgets now support toggling completed tool-call events, and `ChatThreadMessages` requires a `showCompletedToolCalls` flag (with `initialShowCompletedToolCalls` on `ChatThread`).

## [0.34.0]
- WebSocket protocol now surfaces close codes/reasons via a dedicated exception, and RoomServerException includes a retryable flag for Try-Again-Later closes.
- RoomConnectionScope adds retry/backoff for retryable connection errors, supports custom RoomClient factories, and exposes a retrying builder.
- Web runtime entrypoint injection is idempotent to avoid duplicate script loads.
- Shadcn chat widgets now allow cross-room file attachments/importing and sorted file browsing, with agent-aware input placeholders.
- Shadcn chat/event rendering filters completed tool-call noise, adds empty-state customization and visibility hooks, and refines empty states for transcript and voice views.

## [0.33.3]
- Stability

## [0.33.2]
- Stability

## [0.33.1]
- Stability

## [0.33.0]
- Stability

## [0.32.0]
- Stability

## [0.31.4]
- Stability

## [0.31.3]
- Stability

## [0.31.2]
- Stability

## [0.31.1]
- Stability

## [0.31.0]
- Stability

## [0.30.1]
- Stability

## [0.30.0]
- Breaking: tool invocation moved to toolkit-based `room.invoke` with `room.*` tool-call events and streaming tool-call chunks.
- Added containers and services clients to the Dart RoomClient, with container exec/log streaming and service list/restart support.
- Storage and database clients now support streaming upload/download and streaming query/insert/search with chunked inputs; Sync client uses streaming open/update.
- Dependency update: added `async ^2.13.0`.

## [0.29.4]
- Stability

## [0.29.3]
- Stability

## [0.29.2]
- Stability

## [0.29.1]
- Stability

## [0.29.0]
- Stability

## [0.28.16]
- Stability

## [0.28.15]
- Stability

## [0.28.14]
- Stability

## [0.28.13]
- Stability

## [0.28.12]
- Stability

## [0.28.11]
- Stability

## [0.28.10]
- Stability

## [0.28.9]
- Stability

## [0.28.8]
- Stability

## [0.28.7]
- Stability

## [0.28.6]
- Stability

## [0.28.5]
- Stability

## [0.28.4]
- Stability

## [0.28.3]
- Stability

## [0.28.2]
- Stability

## [0.28.1]
- Stability

## [0.28.0]
- BREAKING: ToolOutput was renamed to ToolCallOutput, ContentTool.execute now returns ToolCallOutput, and AgentsClient.toolCallResponseContents was removed.
- Tool-call streaming now uses ControlContent close status codes/messages with RoomServerException.statusCode; InvalidToolDataException signals validation failures and closes streams with status 1007.
- Flutter chat UI now reads thread status text/mode attributes, supports steerable threads (sends "steer" messages), and exposes cancel while processing.

