import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/ui/ui.dart';
import './developer_console_layout.dart';
import './ansi.dart';

import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

bool _usesAdaptiveTextSelectionToolbar() {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android => true,
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => false,
  };
}

Widget _adaptiveInputContextMenuBuilder(
  BuildContext context,
  EditableTextState editableTextState,
) {
  if (_usesAdaptiveTextSelectionToolbar()) {
    return TextFieldTapRegion(
      groupId: editableTextState.widget.groupId,
      child: AdaptiveTextSelectionToolbar.editableText(
        editableTextState: editableTextState,
      ),
    );
  }

  return ShadInputState.defaultContextMenuBuilder(context, editableTextState);
}

const double _flowDialogGroupGap = 12;
const double _flowDialogInlineGap = 8;
const double _flowDialogCompactMobileSectionGap = _flowDialogGroupGap * 3;
const double _flowDialogCompactMobileTextGroupGap = _flowDialogGroupGap * 3;
const double _flowDialogCompactMobileTextInlineGap = _flowDialogInlineGap * 2;
const double _flowDialogCompactMobileFieldInset = 4;
const double _flowDialogCompactMobileSelectInset = 8;

bool _usesCompactMobileDialogFormLayout(BuildContext context) {
  if (kIsWeb) {
    return false;
  }

  final screenSize = MediaQuery.maybeOf(context)?.size;
  if (screenSize == null) {
    return false;
  }

  final isMobilePlatform = switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android => true,
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => false,
  };

  return isMobilePlatform && screenSize.shortestSide < 600;
}

TextStyle _flowDialogContentTitleStyle(BuildContext context) {
  if (!_usesCompactMobileDialogFormLayout(context)) {
    return _flowDialogDesktopHeadingStyle(context);
  }

  final theme = ShadTheme.of(context);
  return GoogleFonts.inter(
    textStyle: DefaultTextStyle.of(context).style,
    color: theme.colorScheme.foreground,
    fontWeight: FontWeight.w600,
  );
}

TextStyle _flowDialogDesktopHeadingStyle(BuildContext context) {
  final theme = ShadTheme.of(context);
  return GoogleFonts.inter(
    color: theme.colorScheme.foreground,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 1.10,
  );
}

TextStyle _flowDialogDesktopHelperStyle(BuildContext context) {
  final theme = ShadTheme.of(context);
  return GoogleFonts.inter(
    color: theme.colorScheme.mutedForeground,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.35,
  );
}

TextStyle _flowDialogSecondaryTextStyle(BuildContext context) {
  if (!_usesCompactMobileDialogFormLayout(context)) {
    return _flowDialogDesktopHelperStyle(context);
  }

  final theme = ShadTheme.of(context);
  return theme.textTheme.muted.copyWith(
    color: theme.colorScheme.mutedForeground,
  );
}

TextStyle _flowDialogInputLabelStyle(BuildContext context) {
  if (_usesCompactMobileDialogFormLayout(context)) {
    return _flowDialogContentTitleStyle(context);
  }

  return _flowDialogDesktopHeadingStyle(context);
}

String _capitalizeFirstWord(String value) {
  final trimmed = value.trimLeft();
  if (trimmed.isEmpty) {
    return value;
  }

  final leadingWhitespaceLength = value.length - trimmed.length;
  return value.substring(0, leadingWhitespaceLength) +
      trimmed[0].toUpperCase() +
      trimmed.substring(1);
}

Widget _tableIconButtonChild({
  required Widget icon,
  required String tooltip,
  required VoidCallback? onPressed,
}) {
  return ShadTooltip(
    builder: (context) => Text(tooltip),
    child: ShadIconButton.ghost(
      icon: icon,
      iconSize: 18,
      width: developerIconButtonSize,
      height: developerIconButtonSize,
      padding: EdgeInsets.zero,
      decoration: const ShadDecoration(shape: BoxShape.circle),
      enabled: onPressed != null,
      onPressed: onPressed,
    ),
  );
}

Widget _tableIconButton({
  required IconData icon,
  required String tooltip,
  required VoidCallback? onPressed,
}) {
  return _tableIconButtonChild(
    icon: Icon(icon),
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

Widget _developerDataTable({
  required List<DataColumn> Function(double width) columns,
  required List<DataRow> Function(double width) rows,
  ValueChanged<bool?>? onSelectAll,
  bool showCheckboxColumn = true,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SizedBox(
          width: width,
          child: SelectionArea(
            child: DataTable(
              horizontalMargin: developerTableHorizontalMargin,
              columnSpacing: developerTableColumnSpacing,
              columns: columns(width),
              onSelectAll: onSelectAll,
              rows: rows(width),
              showCheckboxColumn: showCheckboxColumn,
            ),
          ),
        ),
      );
    },
  );
}

DataColumn _iconColumn() {
  return const DataColumn(
    columnWidth: FixedColumnWidth(developerIconColumnWidth),
    label: SizedBox.shrink(),
  );
}

DataColumn _actionsColumn() {
  return const DataColumn(label: SizedBox.shrink());
}

DataColumn _fixedTextColumn(String label, double width) {
  return DataColumn(
    columnWidth: FixedColumnWidth(width),
    label: _ellipsisText(label),
  );
}

DataColumn _flexTextColumn(String label, {double flex = 1}) {
  return DataColumn(
    columnWidth: FlexColumnWidth(flex),
    label: _ellipsisText(label),
  );
}

Widget _ellipsisText(String text) {
  return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
}

class TerminalLaunchOptions {
  const TerminalLaunchOptions({required this.command, this.mounts});

  final String command;
  final ContainerMountSpec? mounts;
}

Future<TerminalLaunchOptions?> promptForContainerTerminal(
  BuildContext context,
) async {
  return showShadDialog<TerminalLaunchOptions>(
    context: context,
    builder: (context) => const _TerminalLaunchDialog(),
  );
}

Future<TerminalLaunchOptions?> promptForImageTerminal(
  BuildContext context, {
  String initialCommand = "/bin/bash -il",
  List<RoomStorageMountSpec> initialRoomMounts = const [],
  List<ImageStorageMountSpec> initialImageMounts = const [],
}) async {
  return showShadDialog<TerminalLaunchOptions>(
    context: context,
    builder: (context) => _TerminalLaunchDialog(
      allowRoomMounts: true,
      allowImageMounts: true,
      initialCommand: initialCommand,
      initialRoomMounts: initialRoomMounts,
      initialImageMounts: initialImageMounts,
    ),
  );
}

class _EditableRoomMount {
  _EditableRoomMount({
    String path = "",
    String subpath = "",
    this.readOnly = false,
  }) : pathController = TextEditingController(text: path),
       subpathController = TextEditingController(text: subpath);

  final TextEditingController pathController;
  final TextEditingController subpathController;
  bool readOnly;

  void dispose() {
    pathController.dispose();
    subpathController.dispose();
  }
}

class _EditableImageMount {
  _EditableImageMount({
    String image = "",
    String path = "",
    this.readOnly = true,
  }) : imageController = TextEditingController(text: image),
       pathController = TextEditingController(text: path);

  final TextEditingController imageController;
  final TextEditingController pathController;
  bool readOnly;

  void dispose() {
    imageController.dispose();
    pathController.dispose();
  }
}

class _TerminalLaunchDialog extends StatefulWidget {
  const _TerminalLaunchDialog({
    this.allowRoomMounts = false,
    this.allowImageMounts = false,
    this.initialCommand = "/bin/bash -il",
    this.initialRoomMounts = const [],
    this.initialImageMounts = const [],
  });

  final bool allowRoomMounts;
  final bool allowImageMounts;
  final String initialCommand;
  final List<RoomStorageMountSpec> initialRoomMounts;
  final List<ImageStorageMountSpec> initialImageMounts;

  @override
  State<_TerminalLaunchDialog> createState() => _TerminalLaunchDialogState();
}

class _TerminalLaunchDialogState extends State<_TerminalLaunchDialog> {
  late final TextEditingController _commandController;
  late final List<_EditableRoomMount> _roomMounts;
  late final List<_EditableImageMount> _imageMounts;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _commandController = TextEditingController(text: widget.initialCommand);
    _roomMounts = [
      for (final mount in widget.initialRoomMounts)
        _EditableRoomMount(
          path: mount.path,
          subpath: mount.subpath ?? "",
          readOnly: mount.readOnly ?? false,
        ),
    ];
    _imageMounts = [
      for (final mount in widget.initialImageMounts)
        _EditableImageMount(
          image: mount.image,
          path: mount.path,
          readOnly: mount.readOnly,
        ),
    ];
  }

  @override
  void dispose() {
    _commandController.dispose();
    for (final mount in _roomMounts) {
      mount.dispose();
    }
    for (final mount in _imageMounts) {
      mount.dispose();
    }
    super.dispose();
  }

  TerminalLaunchOptions? _buildLaunchOptions() {
    final roomMounts = <RoomStorageMountSpec>[];
    for (final mount in _roomMounts) {
      final path = mount.pathController.text.trim();
      final subpath = mount.subpathController.text.trim();
      if (path.isEmpty && subpath.isEmpty) {
        continue;
      }
      if (path.isEmpty) {
        _validationError = "Room mount path is required.";
        return null;
      }
      roomMounts.add(
        RoomStorageMountSpec(
          path: path,
          subpath: subpath.isEmpty ? null : subpath,
          readOnly: mount.readOnly,
        ),
      );
    }

    final imageMounts = <ImageStorageMountSpec>[];
    for (final mount in _imageMounts) {
      final image = mount.imageController.text.trim();
      final path = mount.pathController.text.trim();
      if (image.isEmpty && path.isEmpty) {
        continue;
      }
      if (image.isEmpty || path.isEmpty) {
        _validationError = "Image mounts require both an image and a path.";
        return null;
      }
      imageMounts.add(
        ImageStorageMountSpec(
          image: image,
          path: path,
          readOnly: mount.readOnly,
        ),
      );
    }

    _validationError = null;
    final hasMounts = roomMounts.isNotEmpty || imageMounts.isNotEmpty;
    final mounts = ContainerMountSpec(
      room: roomMounts.isEmpty ? null : roomMounts,
      images: imageMounts.isEmpty ? null : imageMounts,
    );
    return TerminalLaunchOptions(
      command: _commandController.text,
      mounts: hasMounts ? mounts : null,
    );
  }

  Widget _mountSection({
    required String title,
    required String description,
    required VoidCallback onAdd,
    required String addLabel,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ShadTheme.of(context).textTheme.large),
        const SizedBox(height: 4),
        Text(description, style: ShadTheme.of(context).textTheme.muted),
        const SizedBox(height: 12),
        if (children.isEmpty)
          Text(
            "No mounts configured.",
            style: ShadTheme.of(context).textTheme.muted,
          )
        else
          ...children,
        const SizedBox(height: 12),
        ShadButton.outline(
          onPressed: onAdd,
          leading: const Icon(LucideIcons.plus),
          child: Text(addLabel),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: const Text("Launch Terminal"),
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
      child: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShadInputFormField(
                controller: _commandController,
                description: const Text(
                  "Enter an interactive terminal command to launch it in a terminal",
                ),
                textAlign: TextAlign.start,
                style: GoogleFonts.sourceCodePro(
                  color: const Color.from(
                    alpha: 1,
                    red: .8,
                    green: .8,
                    blue: .8,
                  ),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.allowRoomMounts) ...[
                const SizedBox(height: 20),
                _mountSection(
                  title: "Room Mounts",
                  description:
                      "Mount room storage paths into the launched container.",
                  onAdd: () {
                    setState(() {
                      _roomMounts.add(_EditableRoomMount());
                    });
                  },
                  addLabel: "Add room mount",
                  children: [
                    for (final mount in _roomMounts)
                      Padding(
                        key: ObjectKey(mount),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RoomMountEditor(
                          mount: mount,
                          onChanged: () => setState(() {}),
                          onRemove: () {
                            setState(() {
                              _roomMounts.remove(mount);
                              mount.dispose();
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ],
              if (widget.allowImageMounts) ...[
                const SizedBox(height: 20),
                _mountSection(
                  title: "Image Mounts",
                  description:
                      "Mount the contents of other images into the launched container.",
                  onAdd: () {
                    setState(() {
                      _imageMounts.add(_EditableImageMount());
                    });
                  },
                  addLabel: "Add image mount",
                  children: [
                    for (final mount in _imageMounts)
                      Padding(
                        key: ObjectKey(mount),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ImageMountEditor(
                          mount: mount,
                          onChanged: () => setState(() {}),
                          onRemove: () {
                            setState(() {
                              _imageMounts.remove(mount);
                              mount.dispose();
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ],
              if (_validationError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _validationError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        ShadButton.secondary(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("Cancel"),
        ),
        ShadButton(
          onPressed: () {
            final options = _buildLaunchOptions();
            if (options == null) {
              setState(() {});
              return;
            }
            Navigator.of(context).pop(options);
          },
          child: const Text("Send"),
        ),
      ],
    );
  }
}

class _RoomMountEditor extends StatelessWidget {
  const _RoomMountEditor({
    required this.mount,
    required this.onChanged,
    required this.onRemove,
  });

  final _EditableRoomMount mount;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShadInputFormField(
              controller: mount.pathController,
              label: const Text("Path"),
              description: const Text(
                "Mount path inside the launched container.",
              ),
            ),
            const SizedBox(height: 12),
            ShadInputFormField(
              controller: mount.subpathController,
              label: const Text("Subpath"),
              description: const Text("Optional room storage subpath."),
            ),
            const SizedBox(height: 12),
            ShadCheckboxFormField(
              initialValue: mount.readOnly,
              onChanged: (value) {
                mount.readOnly = value;
                onChanged();
              },
              inputLabel: const Text("Read only"),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ShadButton.outline(
                onPressed: onRemove,
                leading: const Icon(Icons.delete_outline),
                child: const Text("Remove"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageMountEditor extends StatelessWidget {
  const _ImageMountEditor({
    required this.mount,
    required this.onChanged,
    required this.onRemove,
  });

  final _EditableImageMount mount;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShadInputFormField(
              controller: mount.imageController,
              label: const Text("Image"),
              description: const Text("Image tag to mount into the container."),
            ),
            const SizedBox(height: 12),
            ShadInputFormField(
              controller: mount.pathController,
              label: const Text("Path"),
              description: const Text(
                "Mount path inside the launched container.",
              ),
            ),
            const SizedBox(height: 12),
            ShadCheckboxFormField(
              initialValue: mount.readOnly,
              onChanged: (value) {
                mount.readOnly = value;
                onChanged();
              },
              inputLabel: const Text("Read only"),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ShadButton.outline(
                onPressed: onRemove,
                leading: const Icon(Icons.delete_outline),
                child: const Text("Remove"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageTable extends StatefulWidget {
  const ImageTable({super.key, required this.client, required this.onRun});

  final RoomClient client;
  final void Function(ExecSession run) onRun;

  @override
  State<ImageTable> createState() => _ImageTableState();
}

class _ImageTableState extends State<ImageTable> {
  late Future<List<ContainerImage>> _imagesFuture;
  List<ContainerImage> _images = const [];
  final Set<String> _selectedImageIds = <String>{};
  bool _isDeletingImages = false;

  String _displayImageRef(ContainerImage image) {
    if (image.preferredRef != null && image.preferredRef!.isNotEmpty) {
      return image.preferredRef!;
    }
    if (image.references.isNotEmpty) {
      return image.references.first;
    }
    return image.id;
  }

  List<ContainerImage> _sortImages(List<ContainerImage> images) {
    images.sort((a, b) => _displayImageRef(a).compareTo(_displayImageRef(b)));
    return images;
  }

  Future<List<ContainerImage>> _loadImages() {
    return widget.client.containers.listImages().then((images) {
      _images = _sortImages(images);
      return _images;
    });
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), _onTick);
    _imagesFuture = _loadImages();
  }

  late Timer _timer;

  void _onTick(Timer t) {
    widget.client.containers.listImages().then((images) {
      if (mounted) {
        setState(() {
          _images = _sortImages(images);
          _imagesFuture = SynchronousFuture(_images);
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  Future<void> _reload() async {
    setState(() {
      _imagesFuture = _loadImages();
    });
  }

  List<ContainerImage> _selectedImages(List<ContainerImage> images) {
    return [
      for (final image in images)
        if (_selectedImageIds.contains(image.id)) image,
    ];
  }

  Future<bool> _confirmDeleteImages(List<ContainerImage> images) async {
    final imageCount = images.length;
    final preview = images.take(5).map(_displayImageRef).join('\n');
    final remainingCount = imageCount - 5;
    final body = remainingCount > 0
        ? '$preview\n...and $remainingCount more'
        : preview;

    return await showShadDialog<bool>(
          context: context,
          builder: (ctx) => ShadDialog(
            title: Text(imageCount == 1 ? 'Delete image?' : 'Delete images?'),
            child: Text(body),
            actions: [
              ShadButton.secondary(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ShadButton.destructive(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(imageCount == 1 ? 'Delete' : 'Delete all'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteImages(List<ContainerImage> images) async {
    if (images.isEmpty || _isDeletingImages) {
      return;
    }

    final confirm = await _confirmDeleteImages(images);
    if (!confirm || !mounted) {
      return;
    }

    setState(() {
      _isDeletingImages = true;
    });

    var deletedCount = 0;
    var failedCount = 0;
    Object? firstError;
    final deletedImageIds = <String>[];

    try {
      for (final image in images) {
        try {
          await widget.client.containers.deleteImage(
            image: _displayImageRef(image),
          );
          deletedCount += 1;
          deletedImageIds.add(image.id);
        } catch (e) {
          failedCount += 1;
          firstError ??= e;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImageIds.removeAll(deletedImageIds);
        if (deletedImageIds.isNotEmpty) {
          final deletedImageIdSet = deletedImageIds.toSet();
          _images = [
            for (final image in _images)
              if (!deletedImageIdSet.contains(image.id)) image,
          ];
          _imagesFuture = SynchronousFuture(_images);
        }
      });

      if (failedCount == 0) {
        ShadToaster.of(context).show(
          ShadToast(
            description: Text(
              deletedCount == 1
                  ? 'Deleted image'
                  : 'Deleted $deletedCount images',
            ),
          ),
        );
      } else {
        ShadToaster.of(context).show(
          ShadToast(
            description: Text(
              'Deleted $deletedCount images; failed to delete $failedCount: $firstError',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingImages = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ContainerImage>>(
      future: _imagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final images = snapshot.data!;
        if (images.isEmpty) {
          return const Center(child: Text('No images found'));
        }

        final visibleImageIds = images.map((image) => image.id).toSet();
        final selectedImages = _selectedImages(images);
        final selectedCount = selectedImages.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selectedCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  developerTableHorizontalMargin,
                  0,
                  developerTableHorizontalMargin,
                  8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedCount == 1
                            ? '1 image selected'
                            : '$selectedCount images selected',
                      ),
                    ),
                    ShadButton.destructive(
                      enabled: !_isDeletingImages,
                      leading: const Icon(LucideIcons.delete),
                      onPressed: () => _deleteImages(selectedImages),
                      child: Text(
                        _isDeletingImages ? 'Deleting...' : 'Delete selected',
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _developerDataTable(
                onSelectAll: (selected) {
                  setState(() {
                    if (selected ?? false) {
                      _selectedImageIds.addAll(visibleImageIds);
                    } else {
                      _selectedImageIds.removeAll(visibleImageIds);
                    }
                  });
                },
                columns: (_) => [
                  _iconColumn(),
                  _flexTextColumn('Reference'),
                  _fixedTextColumn('Updated', 130),
                  _actionsColumn(),
                ],
                rows: (_) => [
                  for (final img in images)
                    DataRow(
                      selected: _selectedImageIds.contains(img.id),
                      onSelectChanged: _isDeletingImages
                          ? null
                          : (selected) {
                              setState(() {
                                if (selected ?? false) {
                                  _selectedImageIds.add(img.id);
                                } else {
                                  _selectedImageIds.remove(img.id);
                                }
                              });
                            },
                      cells: [
                        DataCell(
                          _tableIconButton(
                            icon: LucideIcons.play,
                            tooltip: 'Run',
                            onPressed: _isDeletingImages
                                ? null
                                : () async {
                                    try {
                                      final launchOptions =
                                          await promptForImageTerminal(context);
                                      if (launchOptions == null) {
                                        return;
                                      }

                                      final containerId = await widget
                                          .client
                                          .containers
                                          .run(
                                            command: "sleep infinity",
                                            image: _displayImageRef(img),
                                            writableRootFs: true,
                                            mounts: launchOptions.mounts,
                                          );

                                      final tty = widget.client.containers.exec(
                                        containerId: containerId,
                                        tty: true,
                                        command: launchOptions.command,
                                      );

                                      if (!mounted) return;

                                      widget.onRun(tty);

                                      ShadToaster.of(context).show(
                                        const ShadToast(
                                          description: Text(
                                            'Starting container',
                                          ),
                                        ),
                                      );
                                      _reload();
                                    } catch (e) {
                                      ShadToaster.of(context).show(
                                        ShadToast(
                                          description: Text(
                                            'Unable to start container: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ),
                        DataCell(_ellipsisText(_displayImageRef(img))),
                        DataCell(Text(_formatImageTimeAgo(img.updatedAt))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _tableIconButton(
                                icon: LucideIcons.info,
                                tooltip: 'Inspect',
                                onPressed: _isDeletingImages
                                    ? null
                                    : () {
                                        showShadSheet(
                                          side: ShadSheetSide.right,
                                          context: context,
                                          builder: (context) {
                                            final sheetWidth =
                                                MediaQuery.sizeOf(
                                                  context,
                                                ).width *
                                                0.94;
                                            return ShadSheet(
                                              title: Text(
                                                _displayImageRef(img),
                                              ),
                                              constraints: BoxConstraints(
                                                minWidth: sheetWidth,
                                                maxWidth: sheetWidth,
                                              ),
                                              child: _ImageDetailsSheet(
                                                client: widget.client,
                                                imageId: img.id,
                                              ),
                                            );
                                          },
                                        );
                                      },
                              ),
                              _tableIconButton(
                                icon: LucideIcons.delete,
                                tooltip: 'Delete',
                                onPressed: _isDeletingImages
                                    ? null
                                    : () => _deleteImages([img]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

String _formatImageTimeAgo(DateTime? value) {
  if (value == null) {
    return '—';
  }
  return timeAgo(value.toLocal());
}

String _formatImageBytes(int? value) {
  if (value == null) {
    return '—';
  }
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = value.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  final fractionDigits = unitIndex == 0 ? 0 : 1;
  return '${size.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}

class _ImageDetailsSheet extends StatelessWidget {
  const _ImageDetailsSheet({required this.client, required this.imageId});

  final RoomClient client;
  final String imageId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ContainerImageInspection>(
      future: client.containers.inspectImage(imageId: imageId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Unable to load image details: ${snapshot.error}');
        }

        final inspection = snapshot.data!;
        final image = inspection.image;

        return SelectionArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ImageInfoTable(
                  rows: [
                    MapEntry('Reference', image.preferredRef ?? image.id),
                    MapEntry('ID', image.id),
                    MapEntry('Created', _formatImageTimeAgo(image.createdAt)),
                    MapEntry('Updated', _formatImageTimeAgo(image.updatedAt)),
                    MapEntry('Target Media Type', image.targetMediaType ?? '—'),
                    MapEntry(
                      'Content Size',
                      _formatImageBytes(inspection.contentSize),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (image.labels.isNotEmpty) ...[
                  Text('Labels', style: ShadTheme.of(context).textTheme.large),
                  const SizedBox(height: 8),
                  _ImageKeyValueTable(values: image.labels),
                  const SizedBox(height: 20),
                ],
                if (inspection.manifests.isNotEmpty) ...[
                  Text(
                    'Manifests',
                    style: ShadTheme.of(context).textTheme.large,
                  ),
                  const SizedBox(height: 8),
                  _ImageManifestTable(manifests: inspection.manifests),
                  const SizedBox(height: 20),
                ],
                Text('Layers', style: ShadTheme.of(context).textTheme.large),
                const SizedBox(height: 8),
                _ImageDescriptorTable(descriptors: inspection.layers),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ImageInfoTable extends StatelessWidget {
  const _ImageInfoTable({required this.rows});

  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        for (final row in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 8),
                child: Text(
                  '${row.key}:',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(row.value),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ImageKeyValueTable extends StatelessWidget {
  const _ImageKeyValueTable({required this.values});

  final Map<String, String> values;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Key')),
          DataColumn(label: Text('Value')),
        ],
        rows: [
          for (final entry in values.entries)
            DataRow(
              cells: [
                DataCell(SelectableText(entry.key)),
                DataCell(SelectableText(entry.value)),
              ],
            ),
        ],
      ),
    );
  }
}

class _ImageManifestTable extends StatelessWidget {
  const _ImageManifestTable({required this.manifests});

  final List<ContainerImageManifest> manifests;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Digest')),
          DataColumn(label: Text('Media Type')),
          DataColumn(label: Text('Size')),
          DataColumn(label: Text('Platform')),
        ],
        rows: [
          for (final manifest in manifests)
            DataRow(
              cells: [
                DataCell(SelectableText(manifest.descriptor.digest)),
                DataCell(SelectableText(manifest.descriptor.mediaType ?? '—')),
                DataCell(Text(_formatImageBytes(manifest.descriptor.size))),
                DataCell(
                  Text(() {
                    final platform = [
                      manifest.platformOs,
                      manifest.platformArchitecture,
                      manifest.platformVariant,
                    ].whereType<String>().join('/');
                    return platform.isEmpty ? '—' : platform;
                  }()),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ImageDescriptorTable extends StatelessWidget {
  const _ImageDescriptorTable({required this.descriptors});

  final List<ContainerImageDescriptor> descriptors;

  @override
  Widget build(BuildContext context) {
    if (descriptors.isEmpty) {
      return const Text('No descriptors');
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Digest')),
          DataColumn(label: Text('Media Type')),
          DataColumn(label: Text('Size')),
        ],
        rows: [
          for (final descriptor in descriptors)
            DataRow(
              cells: [
                DataCell(SelectableText(descriptor.digest)),
                DataCell(SelectableText(descriptor.mediaType ?? '—')),
                DataCell(Text(_formatImageBytes(descriptor.size))),
              ],
            ),
        ],
      ),
    );
  }
}

/// Pass your existing ContainersClient instance.
class ContainerTable extends StatefulWidget {
  const ContainerTable({super.key, required this.client, required this.onRun});

  final void Function(ExecSession run) onRun;

  final RoomClient client;

  @override
  State<ContainerTable> createState() => _ContainerTableState();
}

class _ContainerTableState extends State<ContainerTable> {
  String _containerSortName(RoomContainer container) =>
      (container.name?.trim().isNotEmpty ?? false)
      ? container.name!.toLowerCase()
      : container.id.toLowerCase();

  String _containerSortImage(RoomContainer container) =>
      container.image.toLowerCase();

  String _containerSortStartedBy(RoomContainer container) =>
      container.startedBy.name.toLowerCase();

  int _compareContainers(RoomContainer a, RoomContainer b) {
    var cmp = _containerSortName(a).compareTo(_containerSortName(b));
    if (cmp != 0) {
      return cmp;
    }

    cmp = _containerSortImage(a).compareTo(_containerSortImage(b));
    if (cmp != 0) {
      return cmp;
    }

    cmp = _containerSortStartedBy(a).compareTo(_containerSortStartedBy(b));
    if (cmp != 0) {
      return cmp;
    }

    return a.id.toLowerCase().compareTo(b.id.toLowerCase());
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), _onTick);
  }

  late Timer _timer;

  bool all = false;

  void _onTick(Timer t) {
    containersResource.refresh();
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  late final containersResource = Resource<List<RoomContainer>>(
    () => widget.client.containers
        .list(all: all)
        .then((containers) => containers..sort(_compareContainers)),
  );

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, snapshot) {
        if (!containersResource.state.isReady) {
          return const Center(child: CircularProgressIndicator());
        }
        if (containersResource.state.error != null) {
          return Center(
            child: Text('Error: ${containersResource.state.error}'),
          );
        }

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ShadCheckboxFormField(
                    initialValue: all,
                    onChanged: (v) {
                      all = v;
                      containersResource.refresh();
                    },
                    inputLabel: Text("include stopped containers"),
                  ),
                ],
              ),
            ),
            Expanded(
              child: containersResource.state.value!.isEmpty
                  ? const Center(child: Text('No running containers'))
                  : _developerDataTable(
                      columns: (_) => [
                        _iconColumn(),
                        _fixedTextColumn('Status', 100),
                        _fixedTextColumn('Name', 140),
                        _flexTextColumn('Image'),
                        _fixedTextColumn('Ports', 100),
                        _fixedTextColumn('Started by', 100),
                        _actionsColumn(),
                      ],
                      rows: (_) => [
                        for (final c in containersResource.state.value!)
                          DataRow(
                            cells: [
                              DataCell(
                                _tableIconButton(
                                  icon: LucideIcons.play,
                                  tooltip: 'Run',
                                  onPressed: () async {
                                    try {
                                      final launchOptions =
                                          await promptForContainerTerminal(
                                            context,
                                          );
                                      if (launchOptions == null) {
                                        return;
                                      }
                                      final tty = widget.client.containers.exec(
                                        containerId: c.id,
                                        tty: true,
                                        command: launchOptions.command,
                                      );

                                      if (!mounted) return;

                                      widget.onRun(tty);

                                      ShadToaster.of(context).show(
                                        const ShadToast(
                                          description: Text(
                                            'Starting container',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      ShadToaster.of(context).show(
                                        ShadToast(
                                          description: Text(
                                            'Unable to start container: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                              DataCell(_ellipsisText(c.state)),
                              DataCell(
                                Row(
                                  spacing: 8,
                                  children: [
                                    if (c.private)
                                      Icon(LucideIcons.lock, size: 16),
                                    Expanded(
                                      child: _ellipsisText(
                                        c.name?.isNotEmpty == true
                                            ? c.name!
                                            : c.id.substring(0, 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(_ellipsisText(c.image)),
                              DataCell(
                                _ellipsisText(
                                  c.ports.isEmpty ? '' : c.ports.join(', '),
                                ),
                              ),
                              DataCell(_ellipsisText(c.startedBy.name)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _tableIconButton(
                                      icon: LucideIcons.logs,
                                      tooltip: 'Logs',
                                      onPressed: () {
                                        showShadDialog(
                                          context: context,
                                          builder: (context) => ShadDialog(
                                            scrollable: false,
                                            constraints: BoxConstraints(
                                              minWidth: 1024,
                                              minHeight: 600,
                                              maxHeight: 700,
                                              maxWidth: 1024,
                                            ),
                                            title: Text('Container logs'),
                                            child: ContainerLogs(
                                              client: widget.client,
                                              containerId: c.id,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    _tableIconButton(
                                      icon: LucideIcons.circleStop,
                                      tooltip: 'Stop',
                                      onPressed: c.state == 'EXITED'
                                          ? null
                                          : () async {
                                              final confirm =
                                                  await showShadDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => ShadDialog(
                                                      title: const Text(
                                                        'Stop container?',
                                                      ),
                                                      child: Text(
                                                        'Container ${c.id.substring(0, 12)}',
                                                      ),
                                                      actions: [
                                                        ShadButton.secondary(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                ctx,
                                                                false,
                                                              ),
                                                          child: const Text(
                                                            'Cancel',
                                                          ),
                                                        ),
                                                        ShadButton.destructive(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                ctx,
                                                                true,
                                                              ),
                                                          child: const Text(
                                                            'Stop',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ) ??
                                                  false;
                                              if (!confirm) return;

                                              try {
                                                await widget.client.containers
                                                    .stop(containerId: c.id);
                                                ShadToaster.of(context).show(
                                                  const ShadToast(
                                                    description: Text(
                                                      'Container stopped',
                                                    ),
                                                  ),
                                                );
                                                containersResource.refresh();
                                              } catch (e) {
                                                ShadToaster.of(context).show(
                                                  ShadToast(
                                                    description: Text(
                                                      'Stop failed: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                    ),
                                    _tableIconButton(
                                      icon: LucideIcons.trash,
                                      tooltip: 'Delete',
                                      onPressed: () async {
                                        final confirm =
                                            await showShadDialog<bool>(
                                              context: context,
                                              builder: (ctx) => ShadDialog(
                                                title: const Text(
                                                  'Delete container?',
                                                ),
                                                child: Text(
                                                  'Container ${c.id.substring(0, 12)}',
                                                ),
                                                actions: [
                                                  ShadButton.secondary(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          false,
                                                        ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ShadButton.destructive(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          true,
                                                        ),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            ) ??
                                            false;
                                        if (!confirm) return;

                                        try {
                                          await widget.client.containers
                                              .deleteContainer(
                                                containerId: c.id,
                                              );
                                          ShadToaster.of(context).show(
                                            const ShadToast(
                                              description: Text(
                                                'Container deleted',
                                              ),
                                            ),
                                          );
                                          containersResource.refresh();
                                        } catch (e) {
                                          ShadToaster.of(context).show(
                                            ShadToast(
                                              description: Text(
                                                'Delete failed: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class ServiceTable extends StatefulWidget {
  const ServiceTable({super.key, required this.client});

  final RoomClient client;

  @override
  State<ServiceTable> createState() => _ServiceTableState();
}

class _ServiceTableState extends State<ServiceTable> {
  final Set<String> _restartInFlightServiceIds = <String>{};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), _onTick);
  }

  late Timer _timer;

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _onTick(Timer timer) {
    servicesResource.refresh();
  }

  late final servicesResource = Resource<ListServicesResult>(
    () => widget.client.services.listWithState(),
  );

  String _formatTimestamp(DateTime? value) {
    if (value == null) {
      return "—";
    }
    String two(int part) => part.toString().padLeft(2, "0");
    return "${value.year}-${two(value.month)}-${two(value.day)} "
        "${two(value.hour)}:${two(value.minute)}:${two(value.second)}";
  }

  String _formatRemaining(Duration duration) {
    final totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0) {
      return "now";
    }
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return "${hours}h ${minutes}m ${seconds}s";
    }
    if (minutes > 0) {
      return "${minutes}m ${seconds}s";
    }
    return "${seconds}s";
  }

  String _formatRestartIn(DateTime? value) {
    if (value == null) {
      return "—";
    }
    final now = DateTime.now();
    return _formatRemaining(value.difference(now));
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, snapshot) {
        if (!servicesResource.state.isReady) {
          return const Center(child: CircularProgressIndicator());
        }
        if (servicesResource.state.error != null) {
          return Center(child: Text("Error: ${servicesResource.state.error}"));
        }

        final response = servicesResource.state.value!;
        final services = [...response.services]
          ..sort(
            (a, b) => a.metadata.name.toLowerCase().compareTo(
              b.metadata.name.toLowerCase(),
            ),
          );

        if (services.isEmpty) {
          return const Center(child: Text("No services configured"));
        }

        bool showContainer(double width) => width >= 820;
        bool showStarted(double width) => width >= 940;

        return _developerDataTable(
          columns: (width) => [
            _fixedTextColumn('State', 130),
            _fixedTextColumn('Name', 130),
            _flexTextColumn('Image'),
            if (showContainer(width)) _fixedTextColumn('Container', 130),
            if (showStarted(width)) _fixedTextColumn('Started', 180),
            _fixedTextColumn('Restart In', 80),
            _fixedTextColumn('Restarts', 70),
            _actionsColumn(),
          ],
          rows: (width) {
            return [
              for (final service in services)
                () {
                  final serviceId = service.id;
                  final state = serviceId == null
                      ? null
                      : response.serviceStates[serviceId];
                  final stateLabel = state?.state ?? 'unknown';
                  final showRestartSpinner =
                      stateLabel == 'restarting' || stateLabel == 'scheduled';
                  final containerId = state?.containerId;
                  final containerSpec = service.container;
                  final image = containerSpec?.image ?? '—';
                  final canRestart =
                      serviceId != null &&
                      containerSpec != null &&
                      containerSpec.onDemand != true;
                  final isRestarting = stateLabel == 'restarting';
                  final isRestartInFlight =
                      serviceId != null &&
                      _restartInFlightServiceIds.contains(serviceId);

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: showRestartSpinner
                                  ? const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                stateLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(_ellipsisText(service.metadata.name)),
                      DataCell(_ellipsisText(image)),
                      if (showContainer(width))
                        DataCell(
                          _ellipsisText(
                            containerId == null
                                ? '—'
                                : containerId.length > 12
                                ? containerId.substring(0, 12)
                                : containerId,
                          ),
                        ),
                      if (showStarted(width))
                        DataCell(
                          _ellipsisText(_formatTimestamp(state?.startedAtTime)),
                        ),
                      DataCell(
                        _ellipsisText(
                          _formatRestartIn(state?.restartScheduledAtTime),
                        ),
                      ),
                      DataCell(Text('${state?.restartCount ?? 0}')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _tableIconButtonChild(
                              icon: isRestartInFlight
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.restart_alt),
                              tooltip: 'Restart',
                              onPressed:
                                  !canRestart ||
                                      isRestarting ||
                                      isRestartInFlight
                                  ? null
                                  : () async {
                                      final id = serviceId;
                                      setState(() {
                                        _restartInFlightServiceIds.add(id);
                                      });
                                      try {
                                        await widget.client.services.restart(
                                          serviceId: id,
                                        );
                                        if (!mounted) return;
                                        ShadToaster.of(context).show(
                                          ShadToast(
                                            description: Text(
                                              'Restart requested for ${service.metadata.name}',
                                            ),
                                          ),
                                        );
                                        servicesResource.refresh();
                                      } catch (e) {
                                        if (!mounted) return;
                                        ShadToaster.of(context).show(
                                          ShadToast(
                                            description: Text(
                                              'Restart failed: $e',
                                            ),
                                          ),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _restartInFlightServiceIds.remove(
                                              id,
                                            );
                                          });
                                        }
                                      }
                                    },
                            ),
                            _tableIconButton(
                              icon: LucideIcons.logs,
                              tooltip: 'Logs',
                              onPressed: containerId == null
                                  ? null
                                  : () {
                                      showShadDialog(
                                        context: context,
                                        builder: (context) => ShadDialog(
                                          scrollable: false,
                                          constraints: BoxConstraints(
                                            minWidth: 1024,
                                            minHeight: 600,
                                            maxHeight: 700,
                                            maxWidth: 1024,
                                          ),
                                          title: Text('Service logs'),
                                          child: ContainerLogs(
                                            client: widget.client,
                                            containerId: containerId,
                                          ),
                                        ),
                                      );
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }(),
            ];
          },
        );
      },
    );
  }
}

class ConfigureServiceTemplateDialog extends StatelessWidget {
  const ConfigureServiceTemplateDialog({
    super.key,
    required this.spec,
    required this.actionsBuilder,
    this.prefilledVars,
    this.routeDomains = const [],
    this.header = const [],
    this.customActions = const [],
    this.dialogTitle,
    this.dialogDescription,
  });

  final ServiceTemplateSpec spec;
  final Map<String, String>? prefilledVars;
  final List<String> routeDomains;
  final List<Widget> header;
  final List<Widget> customActions;
  final String? dialogTitle;
  final String? dialogDescription;

  final List<Widget> Function(
    BuildContext,
    Map<String, String>,
    bool Function() validate,
  )
  actionsBuilder;

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      useSafeArea: false,
      expandActionsWhenTiny: false,
      actionsAxis: Axis.horizontal,
      constraints: BoxConstraints(maxWidth: 600, minWidth: 600),
      scrollable: false,
      title: Text(dialogTitle ?? "Install agent"),
      description: Text(
        dialogDescription ??
            "Installing this agent will grant it access to your room. Review the details before continuing.",
      ),
      child: SizedBox(
        height: 500,
        child: ConfigureServiceTemplate(
          spec: spec,
          prefilledVars: prefilledVars,
          routeDomains: routeDomains,
          customActions: customActions,
          header: [
            const SizedBox(height: 8),
            ServiceNameCard(manifest: spec),
            const SizedBox(height: 8),
            ServiceInfoCard(manifest: spec),
            ...header,
          ],
          actionsBuilder: actionsBuilder,
        ),
      ),
    );
  }
}

class ServiceNameCard extends StatelessWidget {
  const ServiceNameCard({super.key, required this.manifest});
  final ServiceTemplateSpec manifest;

  @override
  Widget build(BuildContext context) {
    final contentTitleStyle = _flowDialogContentTitleStyle(context);
    final secondaryTextStyle = _flowDialogSecondaryTextStyle(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: ShadTheme.of(context).colorScheme.border,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manifest.metadata.name,
                  style: contentTitleStyle,
                  overflow: TextOverflow.ellipsis,
                ),
                if (manifest.metadata.description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    manifest.metadata.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: secondaryTextStyle,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ShadTheme.of(context).colorScheme.foreground,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.bot,
              color: ShadTheme.of(context).colorScheme.background,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

final permissionHelp = {
  "agents": "Use tools in the room or talk to other agents",
  "containers": "Run custom code in sandboxed containers",
  "datasets": "Interact with dataset tables",
  "developer": "Watch logs in the room",
  "livekit": "Join meetings",
  "messaging": "Communicate with users and agents",
  "sync": "Interact with threads and synchronized documents",
  "storage": "Interact with files in the room",
  "secrets": "Interact with secrets in the room",
  "queues": "Interact with job queues",
};

class _ServiceInstallSummary {
  const _ServiceInstallSummary({
    required this.permissionKeys,
    required this.installsMcp,
    required this.tokenIdentities,
  });

  final List<String> permissionKeys;
  final bool installsMcp;
  final List<String> tokenIdentities;
}

class ServiceInfoCard extends StatelessWidget {
  const ServiceInfoCard({
    super.key,
    required this.manifest,
    this.desktopContentGroupGap,
  });
  final ServiceTemplateSpec manifest;
  final double? desktopContentGroupGap;

  _ServiceInstallSummary _summarize(List<PortSpec> ports) {
    final keys = <String>{};
    final tokenIdentities = <String>{};
    var installsMcp = false;

    for (final p in ports) {
      for (final e in p.endpoints) {
        if (e.meshagent != null) {
          final scope = e.meshagent!.api ?? ApiScope.agentDefault();
          final asJson = scope.toJson();
          keys.addAll(asJson.keys);
        }
        if (e.mcp != null) {
          installsMcp = true;
        }
      }
    }

    for (final env
        in manifest.container?.environment ?? <TemplateEnvironmentVariable>[]) {
      final token = env.token;
      if (token == null) {
        continue;
      }

      tokenIdentities.add(token.identity);
      final tokenApi = token.api;
      if (tokenApi != null) {
        keys.addAll(tokenApi.toJson().keys);
      }
    }

    return _ServiceInstallSummary(
      permissionKeys: keys.toList(),
      installsMcp: installsMcp,
      tokenIdentities: tokenIdentities.toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = _flowDialogInputLabelStyle(context);
    final secondaryTextStyle = _flowDialogSecondaryTextStyle(context);
    final usesCompactMobileLayout = _usesCompactMobileDialogFormLayout(context);
    final bulletTextStyle = usesCompactMobileLayout
        ? secondaryTextStyle
        : secondaryTextStyle.copyWith(height: 1.5);
    final contentGroupGap = usesCompactMobileLayout
        ? _flowDialogCompactMobileTextGroupGap
        : (desktopContentGroupGap ?? _flowDialogGroupGap);
    final contentInlineGap = usesCompactMobileLayout
        ? _flowDialogCompactMobileTextInlineGap
        : _flowDialogInlineGap;
    final summary = _summarize(manifest.ports);
    final showsInstallSummary =
        manifest.agents.isNotEmpty || summary.installsMcp;
    final filteredAgentName = manifest
        .metadata
        .annotations["meshagent.service.filter.agent"]
        ?.trim();
    final hasFilteredAgentName =
        filteredAgentName != null && filteredAgentName.isNotEmpty;
    final permissionLines = <String>[
      ...summary.permissionKeys.map((t) => permissionHelp[t] ?? t),
      ...summary.tokenIdentities.map((identity) => "Create environment token"),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: usesCompactMobileLayout ? 0 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showsInstallSummary) ...[
            Text('This package will install:', style: labelStyle),
            Padding(
              padding: EdgeInsets.only(
                left: usesCompactMobileLayout ? 0 : 8,
                top: contentInlineGap,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final a in manifest.agents) ...[
                    if (a.annotations["meshagent.agent.type"] == "ChatBot")
                      Text("• A chatbot", style: bulletTextStyle),
                    if (a.annotations["meshagent.agent.type"] == "Mailbot")
                      Text("• A mailbot", style: bulletTextStyle),
                    if (a.annotations["meshagent.agent.type"] == "VoiceBot")
                      Text("• A voicebot", style: bulletTextStyle),
                    if (a.annotations["meshagent.agent.type"] == "Shell")
                      Text("• A terminal based agent", style: bulletTextStyle),
                    if (a.annotations["meshagent.agent.widget"] != null)
                      Text("• A custom interface", style: bulletTextStyle),
                    if (a.annotations["meshagent.agent.dataset.schema"] != null)
                      Text("• A custom dataset", style: bulletTextStyle),
                    if (a.annotations["meshagent.agent.database.schema"] !=
                        null)
                      Text("• A custom database", style: bulletTextStyle),
                    if (a.annotations["meshagent.agent.schedule"] != null)
                      Text("• Scheduled tasks", style: bulletTextStyle),
                  ],
                  if (summary.installsMcp)
                    Text("• An MCP connector", style: bulletTextStyle),
                  if (summary.installsMcp && hasFilteredAgentName)
                    Text(
                      "• This MCP connector will only be installed for agent '$filteredAgentName'",
                      style: bulletTextStyle,
                    ),
                ],
              ),
            ),
            if (permissionLines.isNotEmpty) SizedBox(height: contentGroupGap),
          ],
          if (permissionLines.isNotEmpty) ...[
            Text(
              'Installing this agent will grant it permission to:',
              style: labelStyle,
            ),
            Padding(
              padding: EdgeInsets.only(
                left: usesCompactMobileLayout ? 0 : 8,
                top: contentInlineGap,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final line in permissionLines)
                    Text("• $line", style: bulletTextStyle),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ConfigureServiceTemplate extends StatefulWidget {
  const ConfigureServiceTemplate({
    super.key,
    required this.spec,
    required this.actionsBuilder,
    this.prefilledVars,
    this.routeDomains = const [],
    this.customActions = const [],
    this.header = const [],
    this.showActionRow = true,
    this.desktopHorizontalPadding = 12,
    this.desktopSectionSpacing = 10,
    this.desktopHeaderBottomSpacing,
    this.onFormStateChanged,
  });

  final ServiceTemplateSpec spec;
  final Map<String, String>? prefilledVars;
  final List<String> routeDomains;
  final List<Widget> customActions;
  final List<Widget> header;
  final bool showActionRow;
  final double desktopHorizontalPadding;
  final double desktopSectionSpacing;
  final double? desktopHeaderBottomSpacing;
  final void Function(Map<String, String> vars, bool Function() validate)?
  onFormStateChanged;

  final List<Widget> Function(
    BuildContext,
    Map<String, String>,
    bool Function() validate,
  )
  actionsBuilder;

  @override
  State createState() => _ConfigureServiceTemplateState();
}

class _ConfigureServiceTemplateState extends State<ConfigureServiceTemplate> {
  final _formKey = GlobalKey<ShadFormState>();
  late Map<String, String> _vars;
  late Map<String, String> _routeSubdomains;
  late Map<String, String> _routeSuffixes;

  @override
  void initState() {
    super.initState();
    final initial = <String, String>{
      for (final variable
          in widget.spec.variables ?? <ServiceTemplateVariable>[])
        variable.name: _initialVariableValue(variable),
    };
    if (widget.prefilledVars != null) {
      initial.addAll(widget.prefilledVars!);
    }
    _normalizeEnumValues(initial);
    _vars = initial;
    _routeSubdomains = {};
    _routeSuffixes = {};
    _initRouteParts();
  }

  String _initialVariableValue(ServiceTemplateVariable variable) {
    final enumValues = variable.enumValues;
    if (enumValues != null && enumValues.isNotEmpty) {
      return enumValues.first;
    }
    return '';
  }

  void _normalizeEnumValues(Map<String, String> values) {
    for (final variable
        in widget.spec.variables ?? <ServiceTemplateVariable>[]) {
      final enumValues = variable.enumValues;
      if (enumValues == null || enumValues.isEmpty) {
        continue;
      }
      final currentValue = values[variable.name]?.trim() ?? '';
      values[variable.name] = enumValues.contains(currentValue)
          ? currentValue
          : enumValues.first;
    }
  }

  List<String> get _routeDomains => widget.routeDomains;

  void _initRouteParts() {
    final suffixes = _routeDomains;
    if (suffixes.isEmpty) return;
    for (final variable
        in widget.spec.variables ?? <ServiceTemplateVariable>[]) {
      if (variable.type != "route") continue;
      final rawValue = _vars[variable.name]?.trim() ?? "";
      final matchedSuffix =
          _matchRouteSuffix(rawValue, suffixes) ??
          (suffixes.isNotEmpty ? suffixes.first : "");
      _routeSuffixes[variable.name] = matchedSuffix;
      _routeSubdomains[variable.name] = _routeSubdomain(
        rawValue,
        matchedSuffix,
      );
      _syncRouteValue(variable.name);
    }
  }

  String? _matchRouteSuffix(String value, List<String> suffixes) {
    if (value.isEmpty) return null;
    final sorted = List<String>.from(suffixes)
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final suffix in sorted) {
      if (value == suffix) return suffix;
      if (value.endsWith(".$suffix")) return suffix;
    }
    return null;
  }

  String _routeSubdomain(String value, String suffix) {
    if (value.isEmpty || suffix.isEmpty) return value;
    final suffixWithDot = ".$suffix";
    if (!value.endsWith(suffixWithDot)) return value;
    return value.substring(0, value.length - suffixWithDot.length);
  }

  void _syncRouteValue(String name) {
    final subdomain = _routeSubdomains[name]?.trim() ?? "";
    final suffix = _routeSuffixes[name]?.trim() ?? "";
    if (subdomain.isEmpty || suffix.isEmpty) {
      _vars[name] = "";
      return;
    }
    _vars[name] = "$subdomain.$suffix";
  }

  String _variableTitle(ServiceTemplateVariable variable) {
    final title = variable.title?.trim();
    if (title == null || title.isEmpty) {
      return _capitalizeFirstWord(variable.name);
    }
    return _capitalizeFirstWord(title);
  }

  bool _validate() {
    return _formKey.currentState?.validate(
          autoScrollWhenFocusOnInvalid: true,
        ) ??
        false;
  }

  String? _variableDescription(ServiceTemplateVariable variable) {
    final description = variable.description;
    if (description == null || description.trim().isEmpty) {
      return null;
    }

    return _capitalizeFirstWord(description);
  }

  @override
  Widget build(BuildContext context) {
    final usesCompactMobileLayout = _usesCompactMobileDialogFormLayout(context);
    final theme = ShadTheme.of(context);
    final labelStyle = _flowDialogInputLabelStyle(context);
    final contentTitleStyle = _flowDialogContentTitleStyle(context);
    final secondaryTextStyle = _flowDialogSecondaryTextStyle(context);
    final compactMobileInputPadding = usesCompactMobileLayout
        ? const EdgeInsets.only(left: 12, top: 0, bottom: 0, right: 0)
        : const EdgeInsets.only(left: 8, top: 0, bottom: 0, right: 0);
    final suffixTextStyle = theme.textTheme.small.copyWith(
      color: theme.colorScheme.mutedForeground,
      fontSize: usesCompactMobileLayout ? 14 : null,
    );
    final mailDomain = const String.fromEnvironment("MESHAGENT_MAIL_DOMAIN");
    final emailSuffix = mailDomain.isEmpty ? "" : "@$mailDomain";
    final routeDomains = _routeDomains;
    void dismissFocusedField(PointerDownEvent _) {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    Widget wrapCompactMobileField(Widget child) {
      child = SizedBox(width: double.infinity, child: child);

      if (!usesCompactMobileLayout) {
        return child;
      }

      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: _flowDialogCompactMobileFieldInset,
        ),
        child: child,
      );
    }

    Widget wrapCompactMobileSelectField(Widget child) {
      child = SizedBox(width: double.infinity, child: child);

      if (!usesCompactMobileLayout) {
        return child;
      }

      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: _flowDialogCompactMobileSelectInset,
        ),
        child: child,
      );
    }

    Widget wrapDesktopFieldGroup(Widget child) {
      if (usesCompactMobileLayout) {
        return child;
      }

      return Padding(padding: const EdgeInsets.only(bottom: 7), child: child);
    }

    final actions = widget.actionsBuilder(context, _vars, _validate);
    widget.onFormStateChanged?.call(
      Map<String, String>.unmodifiable(_vars),
      _validate,
    );
    final headerFields = List<Widget>.of(widget.header);
    final desktopHeaderBottomSpacing =
        widget.desktopHeaderBottomSpacing ?? widget.desktopSectionSpacing;
    final contentFields =
        [
              if (widget.spec.variables?.isNotEmpty ?? false) ...[
                for (final v
                    in widget.spec.variables ?? <ServiceTemplateVariable>[])
                  switch (v.type) {
                    "email" => Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (usesCompactMobileLayout)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${_variableTitle(v)} (${v.optional ? 'optional' : 'required'})',
                              style: labelStyle,
                            ),
                          ),
                        wrapCompactMobileField(
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: usesCompactMobileLayout ? 4 : 4,
                            ),
                            child: ShadInputFormField(
                              id: v.name,
                              onPressedOutside: dismissFocusedField,
                              contextMenuBuilder:
                                  _adaptiveInputContextMenuBuilder,
                              groupId: v.name,
                              constraints: null,
                              padding: compactMobileInputPadding,
                              label: usesCompactMobileLayout
                                  ? null
                                  : Text(
                                      '${_variableTitle(v)} (${v.optional ? 'optional' : 'required'})',
                                      style: labelStyle,
                                    ),
                              obscureText: v.obscure,
                              initialValue: emailSuffix.isEmpty
                                  ? (_vars[v.name] ?? '')
                                  : (_vars[v.name] ?? '').replaceAll(
                                      emailSuffix,
                                      '',
                                    ),
                              onChanged: (txt) => setState(() {
                                final normalized = txt.trim();
                                if (normalized.isEmpty) {
                                  _vars[v.name] = "";
                                } else if (emailSuffix.isEmpty) {
                                  _vars[v.name] = normalized;
                                } else {
                                  _vars[v.name] = "$normalized$emailSuffix";
                                }
                              }),
                              trailing: emailSuffix.isEmpty
                                  ? null
                                  : Container(
                                      color: theme.colorScheme.muted,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        emailSuffix,
                                        style: suffixTextStyle,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        if (_variableDescription(v) case final description?)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 7),
                            child: Text(description, style: secondaryTextStyle),
                          ),
                      ],
                    ),
                    "route" => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (routeDomains.isEmpty)
                          wrapCompactMobileField(
                            ShadInputFormField(
                              id: "${v.name}_domain",
                              onPressedOutside: dismissFocusedField,
                              contextMenuBuilder:
                                  _adaptiveInputContextMenuBuilder,
                              groupId: "${v.name}_domain",
                              label: Text(
                                '${_variableTitle(v)} (${v.optional ? 'optional' : 'required'})',
                                style: labelStyle,
                              ),
                              initialValue: _vars[v.name] ?? "",
                              description: _variableDescription(v) == null
                                  ? null
                                  : Text(
                                      _variableDescription(v)!,
                                      style: secondaryTextStyle,
                                    ),
                              validator: v.optional
                                  ? null
                                  : (txt) => (txt.trim().isEmpty)
                                        ? '${_variableTitle(v)} is required'
                                        : null,
                              onChanged: (txt) =>
                                  setState(() => _vars[v.name] = txt.trim()),
                            ),
                          )
                        else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (usesCompactMobileLayout)
                                Expanded(
                                  child: wrapCompactMobileField(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: ShadInputFormField(
                                        onPressedOutside: dismissFocusedField,
                                        contextMenuBuilder:
                                            _adaptiveInputContextMenuBuilder,
                                        groupId: "${v.name}_subdomain",
                                        constraints: null,
                                        padding: compactMobileInputPadding,
                                        gap: 0,
                                        id: "${v.name}_subdomain",
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        label: Text(
                                          '${_variableTitle(v)} (${v.optional ? 'optional' : 'required'})',
                                          style: labelStyle,
                                        ),
                                        initialValue:
                                            _routeSubdomains[v.name] ?? "",
                                        validator: v.optional
                                            ? null
                                            : (txt) => (txt.trim().isEmpty)
                                                  ? '${_variableTitle(v)} is required'
                                                  : null,
                                        onChanged: (txt) {
                                          setState(() {
                                            _routeSubdomains[v.name] = txt
                                                .trim();
                                            _syncRouteValue(v.name);
                                          });
                                        },
                                        trailing: Container(
                                          color: theme.colorScheme.muted,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            ".${routeDomains.first}",
                                            style: suffixTextStyle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                wrapCompactMobileField(
                                  ShadInputFormField(
                                    onPressedOutside: dismissFocusedField,
                                    contextMenuBuilder:
                                        _adaptiveInputContextMenuBuilder,
                                    groupId: "${v.name}_subdomain",
                                    constraints: null,
                                    padding: compactMobileInputPadding,
                                    gap: 0,
                                    id: "${v.name}_subdomain",
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    label: Text(
                                      '${_variableTitle(v)} (${v.optional ? 'optional' : 'required'})',
                                      style: labelStyle,
                                    ),
                                    initialValue:
                                        _routeSubdomains[v.name] ?? "",
                                    validator: v.optional
                                        ? null
                                        : (txt) => (txt.trim().isEmpty)
                                              ? '${_variableTitle(v)} is required'
                                              : null,
                                    onChanged: (txt) {
                                      setState(() {
                                        _routeSubdomains[v.name] = txt.trim();
                                        _syncRouteValue(v.name);
                                      });
                                    },
                                    trailing: Container(
                                      color: theme.colorScheme.muted,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        ".${routeDomains.first}",
                                        style: suffixTextStyle,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_variableDescription(v) case final description?)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 7),
                              child: Text(
                                description,
                                style: secondaryTextStyle,
                              ),
                            ),
                        ],
                      ],
                    ),
                    _ =>
                      v.enumValues == null
                          ? wrapDesktopFieldGroup(
                              wrapCompactMobileField(
                                ShadInputFormField(
                                  id: v.name,
                                  onPressedOutside: dismissFocusedField,
                                  contextMenuBuilder:
                                      _adaptiveInputContextMenuBuilder,
                                  groupId: v.name,
                                  label: Text(
                                    '${_variableTitle(v)} (${v.optional ? 'optional' : 'required'})',
                                    style: labelStyle,
                                  ),
                                  obscureText: v.obscure,
                                  initialValue: _vars[v.name] ?? '',
                                  description: _variableDescription(v) == null
                                      ? null
                                      : Text(
                                          _variableDescription(v)!,
                                          style: secondaryTextStyle,
                                        ),
                                  validator: (txt) {
                                    final val = txt.trim();
                                    if (v.optional) return null;
                                    final msg = val.isEmpty
                                        ? '${_variableTitle(v)} is required'
                                        : null;
                                    return msg;
                                  },
                                  onChanged: (txt) => setState(
                                    () => _vars[v.name] = txt.trim(),
                                  ),
                                ),
                              ),
                            )
                          : wrapDesktopFieldGroup(
                              wrapCompactMobileSelectField(
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final fieldWidth = constraints.maxWidth;
                                    return ShadSelectFormField<String>(
                                      label: Text(
                                        _variableTitle(v),
                                        style: labelStyle,
                                      ),
                                      id: v.name,
                                      initialValue:
                                          v.enumValues!.contains(_vars[v.name])
                                          ? _vars[v.name]
                                          : v.enumValues!.first,
                                      minWidth: fieldWidth,
                                      maxWidth: fieldWidth,
                                      selectedOptionBuilder: (context, value) =>
                                          Text(
                                            value,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      options: [
                                        ...v.enumValues!.map(
                                          (val) => ShadOption<String>(
                                            value: val,
                                            child: Text(val),
                                          ),
                                        ),
                                      ],
                                      description:
                                          _variableDescription(v) == null
                                          ? null
                                          : Text(
                                              _variableDescription(v)!,
                                              style: secondaryTextStyle,
                                            ),
                                      validator: v.optional
                                          ? null
                                          : (txt) {
                                              final msg =
                                                  (txt?.trim().isEmpty ==
                                                          true ||
                                                      txt == null)
                                                  ? '${_variableTitle(v)} is required'
                                                  : null;
                                              return msg;
                                            },
                                      onChanged: (txt) =>
                                          setState(() => _vars[v.name] = txt!),
                                    );
                                  },
                                ),
                              ),
                            ),
                  },
              ],
              if (widget.spec.container != null) ...[
                if (widget.spec.container!.storage != null &&
                    widget.spec.container!.storage?.room != null) ...[
                  for (final rs in widget.spec.container!.storage!.room!)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rs.subpath == null
                              ? "Mounts entire room's storage to"
                              : "Mounts only ${rs.subpath} to",
                          style: contentTitleStyle,
                        ),
                        const SizedBox(height: _flowDialogInlineGap),
                        Text(
                          rs.path,
                          style: _flowDialogSecondaryTextStyle(context),
                        ),
                      ],
                    ),
                ],
              ],
            ]
            .map(
              (x) => Container(
                margin: EdgeInsets.only(
                  bottom: usesCompactMobileLayout
                      ? _flowDialogCompactMobileSectionGap
                      : widget.desktopSectionSpacing,
                ),
                child: x,
              ),
            )
            .toList();

    final formFields = usesCompactMobileLayout
        ? <Widget>[
            if (headerFields.isNotEmpty)
              const SizedBox(height: _flowDialogCompactMobileSectionGap),
            ...headerFields,
            if (headerFields.isNotEmpty && contentFields.isNotEmpty)
              const SizedBox(height: _flowDialogCompactMobileSectionGap),
            ...contentFields,
          ]
        : <Widget>[
            for (var i = 0; i < headerFields.length; i++)
              Container(
                margin: EdgeInsets.only(
                  bottom: i == headerFields.length - 1
                      ? 0
                      : widget.desktopSectionSpacing,
                ),
                child: headerFields[i],
              ),
            if (headerFields.isNotEmpty && contentFields.isNotEmpty)
              SizedBox(height: desktopHeaderBottomSpacing),
            ...contentFields,
          ];

    return ShadForm(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedHeight = constraints.maxHeight.isFinite;

          return Column(
            mainAxisSize: hasBoundedHeight
                ? MainAxisSize.max
                : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              if (hasBoundedHeight)
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: usesCompactMobileLayout
                          ? 0
                          : widget.desktopHorizontalPadding,
                    ),
                    children: formFields,
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: usesCompactMobileLayout
                        ? 0
                        : widget.desktopHorizontalPadding,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: formFields,
                  ),
                ),
              if (widget.showActionRow)
                Row(
                  spacing: 8,
                  children: [...widget.customActions, Spacer(), ...actions],
                ),
            ],
          );
        },
      ),
    );
  }
}

class ContainerLogStream extends StatefulWidget {
  const ContainerLogStream({super.key, required this.logs});

  final LogStream logs;

  @override
  State createState() => _ContainerLogStream();
}

class _ContainerLogStream extends State<ContainerLogStream> {
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  final progress = Map<String, LogProgress>();
  void reload() {
    logSub?.cancel();
    logSub = widget.logs.stream.listen((l) {
      setState(() {
        logs.add(l.trim());

        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.jumpTo(controller.position.maxScrollExtent);
        });
      });
    });

    progressSub?.cancel();
    progressSub = widget.logs.progress.listen((p) {
      setState(() {
        if (p.layer != null) {
          progress[p.layer!] = p;
        }
      });
    });
  }

  @override
  void didUpdateWidget(ContainerLogStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logs != widget.logs) {
      reload();
    }
  }

  StreamSubscription? logSub;
  StreamSubscription? progressSub;

  ScrollController controller = ScrollController();

  @override
  void dispose() {
    logSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inProgress = progress.entries
        .where(
          (entry) => entry.value.current != null && entry.value.total != null,
        )
        .toList();
    final baseStyle = GoogleFonts.sourceCodePro(
      fontWeight: FontWeight.w500,
      fontSize: 12,
      color: ShadTheme.of(context).colorScheme.foreground,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SelectionArea(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: ShadTheme.of(context).colorScheme.secondary,
              ),
              child: SuperListView(
                controller: controller,
                padding: EdgeInsets.all(24),
                children: [
                  for (final l in logs)
                    Text.rich(ansiToTextSpan(l, baseStyle: baseStyle)),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(8),
          child: Wrap(
            alignment: WrapAlignment.start,
            spacing: 10,
            children: [
              for (final entry in inProgress) ...[
                ShadBadge.outline(
                  child: Row(
                    spacing: 8,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.layers),
                      Text("${entry.value.message} (${entry.value.layer})"),

                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          strokeCap: StrokeCap.round,
                          color: Colors.green,
                          value:
                              entry.value.current!.toDouble() /
                              entry.value.total!.toDouble(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ContainerLogs extends StatefulWidget {
  const ContainerLogs({
    super.key,
    required this.client,
    required this.containerId,
  });

  final RoomClient client;
  final String containerId;
  @override
  State<ContainerLogs> createState() => _ContainerLogsState();
}

class _ContainerLogsState extends State<ContainerLogs> {
  @override
  void initState() {
    super.initState();
    logs = widget.client.containers.logs(
      containerId: widget.containerId,
      follow: true,
    );
  }

  @override
  void dispose() {
    super.dispose();
    logs.cancel();
  }

  late final LogStream logs;

  @override
  Widget build(BuildContext context) {
    return ContainerLogStream(logs: logs);
  }
}

class PullImage extends StatefulWidget {
  const PullImage({super.key, required this.room});

  final RoomClient room;

  @override
  State<PullImage> createState() => _PullImage();
}

class _PullImage extends State<PullImage> {
  List<DockerSecret> currentCredentials = [];
  LogStream? logs;

  Future<bool> pullImage() async {
    if (!formKey.currentState!.validate()) {
      return false;
    }
    setState(() {
      error = null;
    });

    final tag = formKey.currentState!.value["tag"] as String;

    try {
      await widget.room.containers.pullImage(
        tag: tag,
        credentials: currentCredentials,
      );
      return true;
    } catch (ex) {
      if (mounted) {
        setState(() {
          error = ex;
        });
      }
      return false;
    }
  }

  Object? error;

  bool building = false;
  var formKey = GlobalKey<ShadFormState>();

  Future<List<Map<String, dynamic>>>? pullSecrets;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      constraints: BoxConstraints.tight(Size(1000, 750)),
      title: Text("Pull an Image"),
      description: Text(
        "Pull an image from a docker repository to use for containers in your room",
      ),

      actions: [
        SizedBox(
          width: 20,
          height: 20,
          child: building ? CircularProgressIndicator() : null,
        ),
        SizedBox(width: 10),
        if (error == null && logs == null)
          ShadButton(
            enabled: !building,
            onPressed: () async {
              setState(() {
                building = true;
              });
              try {
                if (await pullImage()) {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              } finally {
                if (mounted) {
                  setState(() {
                    building = false;
                  });
                }
              }
            },
            child: Text("Pull Image"),
          ),
      ],
      child: SizedBox(
        width: 1000,
        height: 650,
        child: error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "$error",
                      style: TextStyle(
                        color: ShadTheme.of(context).colorScheme.destructive,
                      ),
                    ),
                    ShadButton(
                      onPressed: () {
                        setState(() {
                          error = null;
                          logs = null;
                        });
                      },
                      child: Text("Back"),
                    ),
                  ],
                ),
              )
            : logs != null
            ? ContainerLogStream(logs: logs!)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 16, top: 16),
                      child: ShadForm(
                        key: formKey,
                        child: Container(
                          child: Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: SingleChildScrollView(
                              padding: EdgeInsets.only(
                                left: 4,
                                right: 16,
                                bottom: 48,
                              ),
                              child: Column(
                                spacing: 16,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShadInputFormField(
                                    id: "tag",
                                    label: Text("image tag"),
                                    initialValue: "",
                                    validator: (value) => value.isEmpty
                                        ? "image tag is required"
                                        : null,
                                  ),

                                  Text(
                                    "registry credentials",
                                    style: ShadTheme.of(
                                      context,
                                    ).textTheme.small,
                                  ),
                                  DockerSecretsEditor(
                                    initialSecrets: [],
                                    onChanged: (c) {
                                      currentCredentials = c;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

extension SecretCopy on DockerSecret {
  DockerSecret copyWith({
    String? username,
    String? password,
    String? registry,
    String? email,
  }) => DockerSecret(
    username: username ?? this.username,
    password: password ?? this.password,
    registry: registry ?? this.registry,
    email: email ?? this.email,
  );
}

class DockerSecretsEditor extends StatefulWidget {
  const DockerSecretsEditor({
    super.key,
    required this.initialSecrets,
    this.onChanged,
  });

  /// Existing secrets to edit
  final List<DockerSecret> initialSecrets;

  /// Notify parent when the list mutates
  final ValueChanged<List<DockerSecret>>? onChanged;

  @override
  State<DockerSecretsEditor> createState() => _DockerSecretsEditorState();
}

class _DockerSecretsEditorState extends State<DockerSecretsEditor> {
  late List<DockerSecret> _secrets;

  @override
  void initState() {
    super.initState();
    _secrets = [...widget.initialSecrets];
  }

  void _notify() => widget.onChanged?.call(List.unmodifiable(_secrets));

  void _addEmpty() {
    setState(() {
      _secrets.add(
        const DockerSecret(username: '', password: '', registry: '', email: ''),
      );
      _notify();
    });
  }

  void _removeAt(int index) {
    setState(() {
      _secrets.removeAt(index);
      _notify();
    });
  }

  void _update(int index, DockerSecret updated) {
    setState(() {
      _secrets[index] = updated;
      _notify();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // List of editable secrets
        for (final (i, _) in _secrets.indexed)
          _DockerSecretCard(
            key: ValueKey(i),
            secret: _secrets[i],
            onChanged: (s) => _update(i, s),
            onDelete: () => _removeAt(i),
          ),
        const SizedBox(height: 16),
        // + Add button
        ShadButton(onPressed: _addEmpty, child: const Text('Add credential')),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Single‑secret card
/// ---------------------------------------------------------------------------
class _DockerSecretCard extends StatefulWidget {
  const _DockerSecretCard({
    super.key,
    required this.secret,
    required this.onChanged,
    required this.onDelete,
  });

  final DockerSecret secret;
  final ValueChanged<DockerSecret> onChanged;
  final VoidCallback onDelete;

  @override
  State<_DockerSecretCard> createState() => _DockerSecretCardState();
}

class _DockerSecretCardState extends State<_DockerSecretCard> {
  late TextEditingController _userCtl;
  late TextEditingController _passCtl;
  late TextEditingController _regCtl;
  late TextEditingController _emailCtl;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _userCtl = TextEditingController(text: widget.secret.username);
    _passCtl = TextEditingController(text: widget.secret.password);
    _regCtl = TextEditingController(text: widget.secret.registry);
    _emailCtl = TextEditingController(text: widget.secret.email);
  }

  void _emit() => widget.onChanged(
    widget.secret.copyWith(
      username: _userCtl.text,
      password: _passCtl.text,
      registry: _regCtl.text,
      email: _emailCtl.text,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Username
          ShadInputFormField(
            controller: _userCtl,
            label: Text('Username'),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 12),
          // Password  +  reveal icon
          ShadInputFormField(
            controller: _passCtl,
            label: Text('Password'),
            obscureText: _obscure,
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 12),
          // Registry
          ShadInputFormField(
            controller: _regCtl,
            label: Text('Registry'),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 12),
          // E‑mail
          ShadInputFormField(
            controller: _emailCtl,
            label: Text('E‑mail'),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 16),
          // Delete button
          Align(
            alignment: Alignment.centerRight,
            child: ShadButton.outline(
              onPressed: widget.onDelete,
              leading: const Icon(Icons.delete_outline),
              child: const Text('Remove'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _userCtl.dispose();
    _passCtl.dispose();
    _regCtl.dispose();
    _emailCtl.dispose();
    super.dispose();
  }
}
