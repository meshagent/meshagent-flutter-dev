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
                    final image = service.container?.image ?? "—";

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

/// Accepts a fully‑parsed ServiceTemplateSpec and fires [onSubmit]
/// once all variables are filled in and the user presses **Continue**.
class ConfigureServiceTemplateDialog extends StatelessWidget {
  const ConfigureServiceTemplateDialog({
    super.key,
    required this.spec,
    required this.actionsBuilder,
  });

  final ServiceTemplateSpec spec;

  final List<Widget> Function(
    BuildContext,
    Map<String, String>,
    bool Function() validate,
  )
  actionsBuilder;

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      padding: const EdgeInsets.all(20),
      title: Text("Configure Service"),
      description: Text(
        "This container contains a MeshAgent service. Running this service will grant it access to your room. Review the service details before continuing.",
      ),
      constraints: BoxConstraints(minWidth: 600, maxWidth: 600),
      child: ConfigureServiceTemplate(
        spec: spec,
        actionsBuilder: actionsBuilder,
      ),
    );
  }
}

class ConfigureServiceTemplate extends StatefulWidget {
  const ConfigureServiceTemplate({
    super.key,
    required this.spec,
    required this.actionsBuilder,
  });

  final ServiceTemplateSpec spec;

  final List<Widget> Function(
    BuildContext,
    Map<String, String>,
    bool Function() validate,
  )
  actionsBuilder;

  @override
  State createState() => _ConfigureServiceTemplate();
}

class _ConfigureServiceTemplate extends State<ConfigureServiceTemplate> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, String> _vars; // {varName: value}

  @override
  void initState() {
    super.initState();
    // Initialise every variable with an empty string
    _vars = {
      for (final v in widget.spec.variables ?? <ServiceTemplateVariable>[])
        v.name: '',
    };
  }

  /// Replace `${VAR}` or `{{VAR}}` tokens in [spec.command] with current values.
  String _renderCommand() {
    var cmd = widget.spec.container?.command ?? '';
    _vars.forEach((key, value) {
      cmd = cmd.replaceAll('\${$key}', value).replaceAll('{{${key}}}', value);
    });
    return cmd.trim();
  }

  @override
  Widget build(BuildContext context) {
    final hasVars = widget.spec.variables?.isNotEmpty ?? false;

    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        children: [
          const SizedBox(height: 16),
          Text(
            widget.spec.metadata.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          if (widget.spec.metadata.description != null)
            Text(widget.spec.metadata.description!),
          const SizedBox(height: 16),
          // ── Variable inputs ─────────────────────────────────────────────
          if (hasVars)
            Text(
              "Required variables",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const SizedBox(height: 4),
          if (widget.spec.variables != null)
            ...widget.spec.variables!.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: v.enumValues == null
                    ? ShadInputFormField(
                        label: Text(v.name),
                        obscureText: v.obscure,
                        description: v.description == null
                            ? null
                            : Text(v.description ?? ''),

                        validator: v.optional
                            ? null
                            : (txt) => (txt.trim().isEmpty)
                                  ? '${v.name} is required'
                                  : null,
                        onChanged: (txt) => setState(() => _vars[v.name] = txt),
                      )
                    : ShadSelectFormField<String>(
                        label: Text(v.name),
                        initialValue: v.enumValues![0],
                        selectedOptionBuilder: (context, value) => Text(value),
                        options: [
                          ...v.enumValues!.map(
                            (v) => ShadOption<String>(value: v, child: Text(v)),
                          ),
                        ],
                        description: v.description == null
                            ? null
                            : Text(v.description ?? ''),
                        validator: v.optional
                            ? null
                            : (txt) =>
                                  (txt?.trim().isEmpty == true || txt == null)
                                  ? '${v.name} is required'
                                  : null,
                        onChanged: (txt) =>
                            setState(() => _vars[v.name] = txt!),
                      ),
              ),
            ),

          // ── Command preview ─────────────────────────────────────────────
          if (widget.spec.container?.command != null) ...[
            const SizedBox(height: 16),
            Text('Base Image', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            SelectableText(widget.spec.container?.image ?? ""),
            const SizedBox(height: 16),
            Text(
              'Command to execute',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            SelectableText(
              _renderCommand().isEmpty
                  ? '— complete the variables above —'
                  : _renderCommand(),
            ),
          ],

          const SizedBox(height: 16),
          Text('Room storage', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),

          if (widget.spec.container?.storage == null ||
              widget.spec.container?.storage?.room == null)
            Text("No storage mount"),

          if (widget.spec.container?.storage != null &&
              widget.spec.container?.storage?.room != null) ...[
            for (final rs in widget.spec.container?.storage?.room ?? []) ...[
              if (rs.subpath != null) ...[
                Text(
                  rs.subpath == null
                      ? "Mounts entire room's storage to"
                      : "Mounts only ${rs.subpath} to",
                ),
                Text(rs.path),
              ],
            ],
          ],

          // ── Ports & endpoints summary ──────────────────────────────────
          if (widget.spec.ports.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Endpoints', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...widget.spec.ports.map(
              (p) => ShadCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Port ${p.num.value ?? "auto assigned"} ${p.type ?? ""}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    ...p.endpoints.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          (e.meshagent != null)
                              ? '• ${e.path}  →  ${e.meshagent?.identity}'
                              : (e.mcp != null ? "${e.path} → mcp" : e.path),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Continue button ─────────────────────────────────────────────
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 8,
            children: [
              ...widget.actionsBuilder(
                context,
                _vars,
                () => _formKey.currentState?.validate() ?? false,
              ),
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
