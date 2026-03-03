import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meshagent/meshagent.dart';
import './ansi.dart';

import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

Future<String?> promptForCommand(BuildContext context) async {
  String messageText = "/bin/bash -il";
  return await showShadDialog(
    context: context,
    builder: (context) => ShadDialog.alert(
      actions: [
        ShadButton.secondary(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text("Cancel"),
        ),
        ShadButton(
          onPressed: () {
            Navigator.of(context).pop(messageText);
          },
          child: Text("Send"),
        ),
      ],
      title: Text("Launch Terminal"),
      description: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 400),
        child: ShadInputFormField(
          initialValue: "/bin/bash -il",
          description: Text(
            "Enter an interactive terminal command to launch it in a terminal",
          ),
          onChanged: (value) {
            messageText = value;
          },
          textAlign: TextAlign.start,

          style: GoogleFonts.sourceCodePro(
            color: Color.from(alpha: 1, red: .8, green: .8, blue: .8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
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

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), _onTick);
    _imagesFuture = widget.client.containers.listImages().then(
      (images) => images..sort((a, b) => a.tags[0].compareTo(b.tags[0])),
    );
  }

  late Timer _timer;

  void _onTick(Timer t) {
    widget.client.containers.listImages().then((images) {
      images.sort((a, b) => a.tags[0].compareTo(b.tags[0]));
      if (mounted) {
        setState(() {
          _imagesFuture = SynchronousFuture(images);
        });
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  /// Force a re‑query after an image is removed
  Future<void> _reload() async {
    setState(() {
      _imagesFuture = widget.client.containers.listImages().then(
        (images) => images..sort((a, b) => a.tags[0].compareTo(b.tags[0])),
      );
    });
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

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            columns: const [
              DataColumn(label: Text("")),
              DataColumn(label: Text('Tag')),
              DataColumn(label: Text('Size (MB)')),
              DataColumn(label: Text('')),
            ],
            rows: [
              for (final img in images)
                DataRow(
                  cells: [
                    DataCell(
                      IconButton(
                        icon: const Icon(LucideIcons.play),
                        tooltip: 'Run',
                        onPressed: () async {
                          try {
                            final command = await promptForCommand(context);
                            if (command == null) {
                              return;
                            }

                            final containerId = await widget.client.containers
                                .run(
                                  command: "sleep infinity",
                                  image: img.tags.isNotEmpty
                                      ? img.tags.first
                                      : img.id,
                                  writableRootFs: true,
                                );

                            final tty = widget.client.containers.exec(
                              containerId: containerId,
                              tty: true,
                              command: command,
                            );

                            if (!mounted) return;

                            widget.onRun(tty);

                            ShadToaster.of(context).show(
                              const ShadToast(
                                description: Text('Starting container'),
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

                    DataCell(
                      Row(
                        children: [
                          SizedBox(width: 10),
                          Expanded(
                            child: SelectableText(
                              img.tags.isNotEmpty
                                  ? img.tags.first
                                  : '(untagged)',
                              style: TextStyle(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        img.size != null
                            ? (img.size! / (1024 * 1024)).toStringAsFixed(1)
                            : '‑',
                      ),
                    ),

                    DataCell(
                      IconButton(
                        icon: const Icon(LucideIcons.delete),
                        tooltip: 'Delete',
                        onPressed: () async {
                          final confirm =
                              await showShadDialog<bool>(
                                context: context,
                                builder: (ctx) => ShadDialog(
                                  title: const Text('Delete image?'),
                                  child: Text(
                                    img.tags.isNotEmpty
                                        ? img.tags.first
                                        : img.id,
                                  ),
                                  actions: [
                                    ShadButton.secondary(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ShadButton.destructive(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                          if (!confirm) return;

                          try {
                            await widget.client.containers.deleteImage(
                              image: img.tags.isNotEmpty
                                  ? img.tags.first
                                  : img.id,
                            );
                            ShadToaster.of(context).show(
                              const ShadToast(
                                description: Text('Deleted image'),
                              ),
                            );
                            _reload();
                          } catch (e) {
                            ShadToaster.of(context).show(
                              ShadToast(description: Text('Delete failed: $e')),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
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
        .then(
          (containers) => containers
            ..sort(
              (a, b) => (a.name?.toLowerCase() ?? a.id.toLowerCase()).compareTo(
                b.name?.toLowerCase() ?? b.id.toLowerCase(),
              ),
            ),
        ),
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
                  : LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text("")),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Image')),
                            DataColumn(label: Text('Started by')),
                            DataColumn(label: Text('')), // stop‑button column
                          ],
                          rows: [
                            for (final c in containersResource.state.value!)
                              DataRow(
                                cells: [
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(LucideIcons.play),
                                      tooltip: 'Run',
                                      onPressed: () async {
                                        try {
                                          final command =
                                              await promptForCommand(context);
                                          if (command == null) {
                                            return;
                                          }
                                          final tty = widget.client.containers
                                              .exec(
                                                containerId: c.id,
                                                tty: true,
                                                command: command,
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

                                  DataCell(Text(c.state)),
                                  DataCell(
                                    Row(
                                      spacing: 8,
                                      children: [
                                        if (c.private)
                                          Icon(LucideIcons.lock, size: 16),
                                        Expanded(
                                          child: Text(
                                            c.name ?? "",
                                            style: TextStyle(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: constraints.maxWidth * .75,
                                      ),
                                      child: Text(
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        [c.image].join(' '),
                                        style: TextStyle(color: null),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(c.startedBy.name, style: TextStyle()),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(LucideIcons.logs),
                                          tooltip: "Logs",
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
                                                title: Text("Container logs"),
                                                child: ContainerLogs(
                                                  client: widget.client,
                                                  containerId: c.id,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            LucideIcons.circleStop,
                                          ),
                                          tooltip: 'Stop',
                                          onPressed: c.state == "EXITED"
                                              ? null
                                              : () async {
                                                  final confirm =
                                                      await showShadDialog<
                                                        bool
                                                      >(
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
                                                    await widget
                                                        .client
                                                        .containers
                                                        .stop(
                                                          containerId: c.id,
                                                        );
                                                    ShadToaster.of(
                                                      context,
                                                    ).show(
                                                      const ShadToast(
                                                        description: Text(
                                                          'Container stopped',
                                                        ),
                                                      ),
                                                    );
                                                    containersResource
                                                        .refresh();
                                                  } catch (e) {
                                                    ShadToaster.of(
                                                      context,
                                                    ).show(
                                                      ShadToast(
                                                        description: Text(
                                                          'Stop failed: $e',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                        ),

                                        IconButton(
                                          icon: const Icon(LucideIcons.trash),
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
                                                          'Delete',
                                                        ),
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

        return LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              columns: const [
                DataColumn(label: Text("State")),
                DataColumn(label: Text("Name")),
                DataColumn(label: Text("Image")),
                DataColumn(label: Text("Container")),
                DataColumn(label: Text("Started")),
                DataColumn(label: Text("Restart In")),
                DataColumn(label: Text("Restarts")),
                DataColumn(label: Text("")),
              ],
              rows: [
                for (final service in services)
                  () {
                    final serviceId = service.id;
                    final state = serviceId == null
                        ? null
                        : response.serviceStates[serviceId];
                    final stateLabel = state?.state ?? "unknown";
                    final showRestartSpinner =
                        stateLabel == "restarting" || stateLabel == "scheduled";
                    final containerId = state?.containerId;
                    final containerSpec = service.container;
                    final image = containerSpec?.image ?? "—";
                    final canRestart =
                        serviceId != null &&
                        containerSpec != null &&
                        containerSpec.onDemand != true;
                    final isRestarting = stateLabel == "restarting";
                    final isRestartInFlight =
                        serviceId != null &&
                        _restartInFlightServiceIds.contains(serviceId);

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
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
                              Text(stateLabel),
                            ],
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth * .2,
                            ),
                            child: Text(
                              service.metadata.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth * .3,
                            ),
                            child: Text(
                              image,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            containerId == null
                                ? "—"
                                : containerId.length > 12
                                ? containerId.substring(0, 12)
                                : containerId,
                          ),
                        ),
                        DataCell(Text(_formatTimestamp(state?.startedAtTime))),
                        DataCell(
                          Text(_formatRestartIn(state?.restartScheduledAtTime)),
                        ),
                        DataCell(Text("${state?.restartCount ?? 0}")),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: isRestartInFlight
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.restart_alt),
                                tooltip: "Restart",
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
                                                "Restart requested for ${service.metadata.name}",
                                              ),
                                            ),
                                          );
                                          servicesResource.refresh();
                                        } catch (e) {
                                          if (!mounted) return;
                                          ShadToaster.of(context).show(
                                            ShadToast(
                                              description: Text(
                                                "Restart failed: $e",
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
                              IconButton(
                                icon: const Icon(LucideIcons.logs),
                                tooltip: "Logs",
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
                                            title: Text("Service logs"),
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
              ],
            ),
          ),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (manifest.metadata.description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    manifest.metadata.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                    ),
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
  "database": "Interact with database tables",
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
  const ServiceInfoCard({super.key, required this.manifest});
  final ServiceTemplateSpec manifest;

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
    final labelStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
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
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showsInstallSummary) ...[
            Text('This package will install:', style: labelStyle),
            Padding(
              padding: EdgeInsets.only(left: 8, top: 8, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final a in manifest.agents) ...[
                    if (a.annotations["meshagent.agent.type"] == "ChatBot")
                      Text("• A chatbot"),
                    if (a.annotations["meshagent.agent.type"] == "Mailbot")
                      Text("• A mailbot"),
                    if (a.annotations["meshagent.agent.type"] == "VoiceBot")
                      Text("• A voicebot"),
                    if (a.annotations["meshagent.agent.type"] == "Shell")
                      Text("• A terminal based agent"),
                    if (a.annotations["meshagent.agent.widget"] != null)
                      Text("• A custom interface"),
                    if (a.annotations["meshagent.agent.database.schema"] !=
                        null)
                      Text("• A custom database"),
                    if (a.annotations["meshagent.agent.schedule"] != null)
                      Text("• Scheduled tasks"),
                  ],
                  if (summary.installsMcp) Text("• An MCP connector"),
                  if (summary.installsMcp && hasFilteredAgentName)
                    Text(
                      "• This MCP connector will only be installed for agent '$filteredAgentName'",
                    ),
                ],
              ),
            ),
          ],
          if (permissionLines.isNotEmpty) ...[
            Text(
              'Installing this agent will grant it permission to:',
              style: labelStyle,
            ),
            Padding(
              padding: EdgeInsets.only(left: 8, top: 8),
              child: Text(
                permissionLines.map((line) => "• $line").join("\n"),
                style: TextStyle(height: 1.75),
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
  });

  final ServiceTemplateSpec spec;
  final Map<String, String>? prefilledVars;
  final List<String> routeDomains;
  final List<Widget> customActions;
  final List<Widget> header;

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
    final initial = <String, String>{};
    for (final v in widget.spec.variables ?? []) {
      initial[v.name] = '';
    }
    if (widget.prefilledVars != null) {
      initial.addAll(widget.prefilledVars!);
    }
    _vars = initial;
    _routeSubdomains = {};
    _routeSuffixes = {};
    _initRouteParts();
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
      return variable.name;
    }
    return title;
  }

  bool _validate() {
    return _formKey.currentState?.validate(
          autoScrollWhenFocusOnInvalid: true,
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    final mailDomain = const String.fromEnvironment("MESHAGENT_MAIL_DOMAIN");
    final emailSuffix = mailDomain.isEmpty ? "" : "@$mailDomain";
    final routeDomains = _routeDomains;

    return ShadForm(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 12),
              children: [
                ...widget.header,
                if (widget.spec.variables?.isNotEmpty ?? false) ...[
                  for (final v
                      in widget.spec.variables ?? <ServiceTemplateVariable>[])
                    switch (v.type) {
                      "email" => Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShadInputFormField(
                            id: v.name,
                            constraints: BoxConstraints(maxWidth: 400),
                            padding: EdgeInsets.only(
                              left: 8,
                              top: 0,
                              bottom: 0,
                              right: 0,
                            ),
                            label: Text(
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
                                    color: ShadTheme.of(
                                      context,
                                    ).colorScheme.muted,
                                    padding: EdgeInsets.all(8),
                                    child: Text(emailSuffix),
                                  ),
                          ),
                          if (v.description != null)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 7),
                              child: Text(v.description ?? ''),
                            ),
                        ],
                      ),
                      "route" => Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (routeDomains.isEmpty)
                            ShadInputFormField(
                              id: "${v.name}_domain",
                              label: Text(
                                '${_variableTitle(v)} (${v.optional ? 'optional' : 'required'})',
                                style: labelStyle,
                              ),
                              initialValue: _vars[v.name] ?? "",
                              description: v.description == null
                                  ? null
                                  : Text(v.description ?? ''),
                              validator: v.optional
                                  ? null
                                  : (txt) => (txt.trim().isEmpty)
                                        ? '${_variableTitle(v)} is required'
                                        : null,
                              onChanged: (txt) =>
                                  setState(() => _vars[v.name] = txt.trim()),
                            )
                          else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                ShadInputFormField(
                                  constraints: BoxConstraints(maxWidth: 300),
                                  padding: EdgeInsets.only(left: 8),
                                  gap: 0,
                                  id: "${v.name}_subdomain",
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  label: Text(
                                    '${_variableTitle(v)} (${v.optional ? 'optional' : 'required'})',
                                    style: labelStyle,
                                  ),
                                  initialValue: _routeSubdomains[v.name] ?? "",
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
                                    color: ShadTheme.of(
                                      context,
                                    ).colorScheme.muted,
                                    padding: EdgeInsets.all(8),
                                    child: Text(".${routeDomains.first}"),
                                  ),
                                ),
                              ],
                            ),
                            if (v.description != null)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 7),
                                child: Text(v.description ?? ''),
                              ),
                          ],
                        ],
                      ),
                      _ =>
                        v.enumValues == null
                            ? ShadInputFormField(
                                id: v.name,
                                label: Text(
                                  '${_variableTitle(v)} (${v.optional ? 'optional' : 'required'})',
                                  style: labelStyle,
                                ),
                                obscureText: v.obscure,
                                initialValue: _vars[v.name] ?? '',
                                description: v.description == null
                                    ? null
                                    : Text(v.description ?? ''),
                                validator: (txt) {
                                  final val = txt.trim();
                                  if (v.optional) return null;
                                  final msg = val.isEmpty
                                      ? '${_variableTitle(v)} is required'
                                      : null;
                                  return msg;
                                },
                                onChanged: (txt) =>
                                    setState(() => _vars[v.name] = txt.trim()),
                              )
                            : ShadSelectFormField<String>(
                                label: Text(
                                  _variableTitle(v),
                                  style: labelStyle,
                                ),
                                id: v.name,
                                initialValue:
                                    _vars[v.name] ?? v.enumValues!.first,
                                selectedOptionBuilder: (context, value) =>
                                    Text(value),
                                options: [
                                  ...v.enumValues!.map(
                                    (val) => ShadOption<String>(
                                      value: val,
                                      child: Text(val),
                                    ),
                                  ),
                                ],
                                description: v.description == null
                                    ? null
                                    : Text(v.description ?? ''),
                                validator: v.optional
                                    ? null
                                    : (txt) {
                                        final msg =
                                            (txt?.trim().isEmpty == true ||
                                                txt == null)
                                            ? '${_variableTitle(v)} is required'
                                            : null;
                                        return msg;
                                      },
                                onChanged: (txt) =>
                                    setState(() => _vars[v.name] = txt!),
                              ),
                    },
                ],
                if (widget.spec.container != null) ...[
                  if (widget.spec.container!.storage != null &&
                      widget.spec.container!.storage?.room != null) ...[
                    for (final rs in widget.spec.container!.storage!.room!) ...[
                      Text(
                        rs.subpath == null
                            ? "Mounts entire room's storage to"
                            : "Mounts only ${rs.subpath} to",
                        style: labelStyle,
                      ),
                      Text(rs.path),
                    ],
                  ],
                ],
              ].map((x) => Container(margin: EdgeInsets.only(bottom: 10), child: x)).toList(),
            ),
          ),
          Row(
            spacing: 8,
            children: [
              ...widget.customActions,
              Spacer(),
              ...widget.actionsBuilder(context, _vars, _validate),
            ],
          ),
        ],
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
