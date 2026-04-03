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

