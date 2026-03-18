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

