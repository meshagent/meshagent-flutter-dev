import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meshagent/meshagent.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class ImageTable extends StatefulWidget {
  const ImageTable({super.key, required this.client});

  final RoomClient client;

  @override
  State<ImageTable> createState() => _ImageTableState();
}

class _ImageTableState extends State<ImageTable> {
  late Future<List<DockerImage>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), _onTick);
    _imagesFuture = widget.client.containers.listImages();
  }

  late Timer _timer;

  void _onTick(Timer t) {
    widget.client.containers.listImages().then((images) {
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
      _imagesFuture = widget.client.containers.listImages();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DockerImage>>(
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
                            Map<String, String>? vars;
                            if (img.manifest != null) {
                              vars = await showShadDialog(
                                context: context,
                                builder: (context) => ConfigureServiceTemplateDialog(spec: img.manifest!),
                              );

                              if (vars == null) {
                                return;
                              }
                            }
                            widget.client.containers.run(image: img.tags.isNotEmpty ? img.tags.first : img.id, variables: vars);

                            ShadToaster.of(context).show(const ShadToast(description: Text('Starting container')));
                            _reload();
                          } catch (e) {
                            ShadToaster.of(context).show(ShadToast(description: Text('Unable to start container: $e')));
                          }
                        },
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          img.manifest != null ? Icon(LucideIcons.bot, color: Colors.green) : Icon(LucideIcons.disc),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              img.tags.isNotEmpty ? img.tags.first : '(untagged)',
                              style: TextStyle(color: img.manifest != null ? Colors.green : null),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(img.size != null ? (img.size! / (1024 * 1024)).toStringAsFixed(1) : '‑')),

                    DataCell(
                      IconButton(
                        icon: const Icon(LucideIcons.delete),
                        tooltip: 'Delete',
                        onPressed: () async {
                          final confirm =
                              await showDialog<bool>(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      title: const Text('Delete image?'),
                                      content: Text(img.tags.isNotEmpty ? img.tags.first : img.id),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                      ],
                                    ),
                              ) ??
                              false;
                          if (!confirm) return;

                          try {
                            await widget.client.containers.deleteImage(image: img.tags.isNotEmpty ? img.tags.first : img.id);
                            ShadToaster.of(context).show(const ShadToast(description: Text('Deleted image')));
                            _reload();
                          } catch (e) {
                            ShadToaster.of(context).show(ShadToast(description: Text('Delete failed: $e')));
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
  const ContainerTable({super.key, required this.client});

  final RoomClient client;

  @override
  State<ContainerTable> createState() => _ContainerTableState();
}

class _ContainerTableState extends State<ContainerTable> {
  late Future<List<RoomContainer>> _containersFuture;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), _onTick);
    _containersFuture = widget.client.containers.list();
  }

  late Timer _timer;

  void _onTick(Timer t) {
    widget.client.containers.list().then((containers) {
      if (mounted) {
        setState(() {
          _containersFuture = SynchronousFuture(containers);
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
      _containersFuture = widget.client.containers.list();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RoomContainer>>(
      future: _containersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final containers = snapshot.data!;
        if (containers.isEmpty) {
          return const Center(child: Text('No running containers'));
        }

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Image')),
              DataColumn(label: Text('Started by')),
              DataColumn(label: Text('')), // stop‑button column
            ],
            rows: [
              for (final c in containers)
                DataRow(
                  cells: [
                    DataCell(Text(((c.entrypoint != null) ? [...c.entrypoint!, ...c.command] : [c.image]).join(' '))),
                    DataCell(Text(c.startedBy.name)),
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
                                builder:
                                    (context) => ShadDialog(
                                      constraints: BoxConstraints(minWidth: 1024, minHeight: 600, maxHeight: 700, maxWidth: 1024),
                                      title: Text("Container logs"),
                                      child: ContainerLogs(client: widget.client, containerId: c.id),
                                    ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.circleStop),
                            tooltip: 'Stop',
                            onPressed: () async {
                              final confirm =
                                  await showDialog<bool>(
                                    context: context,
                                    builder:
                                        (ctx) => AlertDialog(
                                          title: const Text('Stop container?'),
                                          content: Text('Container ${c.id.substring(0, 12)}'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Stop')),
                                          ],
                                        ),
                                  ) ??
                                  false;
                              if (!confirm) return;

                              try {
                                await widget.client.containers.stop(containerId: c.id);
                                ShadToaster.of(context).show(const ShadToast(description: Text('Container stopped')));
                                _reload();
                              } catch (e) {
                                ShadToaster.of(context).show(ShadToast(description: Text('Stop failed: $e')));
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
        );
      },
    );
  }
}

class BuildTable extends StatefulWidget {
  const BuildTable({super.key, required this.client});

  final RoomClient client;

  @override
  State<BuildTable> createState() => _BuildTableState();
}

class _BuildTableState extends State<BuildTable> {
  late Future<List<BuildInfo>> _buildsFuture;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), _onTick);
    _buildsFuture = widget.client.containers.listBuilds();
  }

  late Timer _timer;

  void _onTick(Timer t) {
    widget.client.containers.listBuilds().then((builds) {
      if (mounted) {
        setState(() {
          _buildsFuture = SynchronousFuture(builds);
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
      _buildsFuture = widget.client.containers.listBuilds();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BuildInfo>>(
      future: _buildsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final builds = snapshot.data!;
        if (builds.isEmpty) {
          return const Center(child: Text('No builds yet'));
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          scrollDirection: Axis.vertical,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Tag')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Error / Result')),
              DataColumn(label: Text('')),
            ],
            rows: [
              for (final b in builds)
                DataRow(
                  cells: [
                    DataCell(Text(b.tag)),
                    DataCell(Text(b.status)),
                    DataCell(Text(b.error ?? (b.result != null ? b.result.toString() : '—'), overflow: TextOverflow.ellipsis)),
                    DataCell(
                      b.status == 'running'
                          ? IconButton(
                            icon: const Icon(LucideIcons.circleStop),
                            tooltip: 'Cancel build',
                            onPressed: () async {
                              final confirm =
                                  await showDialog<bool>(
                                    context: context,
                                    builder:
                                        (ctx) => AlertDialog(
                                          title: const Text('Cancel this build?'),
                                          content: Text(b.tag),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
                                          ],
                                        ),
                                  ) ??
                                  false;
                              if (!confirm) return;

                              try {
                                await widget.client.containers.stopBuild(requestId: b.requestId);
                                ShadToaster.of(context).show(const ShadToast(description: Text('Build cancelled')));
                                _reload();
                              } catch (e) {
                                ShadToaster.of(context).show(ShadToast(description: Text('Cancel failed: $e')));
                              }
                            },
                          )
                          : const SizedBox.shrink(),
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

/// Accepts a fully‑parsed ServiceTemplateSpec and fires [onSubmit]
/// once all variables are filled in and the user presses **Continue**.
class ConfigureServiceTemplateDialog extends StatefulWidget {
  final ServiceTemplateSpec spec;
  const ConfigureServiceTemplateDialog({super.key, required this.spec});

  @override
  State createState() => _ConfigureServiceTemplateDialog();
}

class _ConfigureServiceTemplateDialog extends State<ConfigureServiceTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, String> _vars; // {varName: value}

  @override
  void initState() {
    super.initState();
    // Initialise every variable with an empty string
    _vars = {for (final v in widget.spec.variables ?? <ServiceTemplateVariable>[]) v.name: ''};
  }

  /// Replace `${VAR}` or `{{VAR}}` tokens in [spec.command] with current values.
  String _renderCommand() {
    var cmd = widget.spec.command ?? '';
    _vars.forEach((key, value) {
      cmd = cmd.replaceAll('\${$key}', value).replaceAll('{{${key}}}', value);
    });
    return cmd.trim();
  }

  bool get _ready => _vars.values.every((v) => v.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final hasVars = widget.spec.variables?.isNotEmpty ?? false;

    return ShadDialog(
      padding: const EdgeInsets.all(20),
      title: Text("Run MeshAgent Service"),
      description: Text(
        "This container contains a MeshAgent service. Running this service will grant it access to your room. Review the service details before continuing.",
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            const SizedBox(height: 16),
            Text(widget.spec.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            if (widget.spec.description != null) Text(widget.spec.description!),
            const SizedBox(height: 16),
            // ── Variable inputs ─────────────────────────────────────────────
            if (hasVars) Text("Required variables", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            ...widget.spec.variables!.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child:
                    v.enumValues == null
                        ? ShadInputFormField(
                          label: Text(v.name),
                          obscureText: v.obscure,
                          description: v.description == null ? null : Text(v.description ?? ''),

                          validator: v.optional ? null : (txt) => (txt.trim().isEmpty) ? '${v.name} is required' : null,
                          onChanged: (txt) => setState(() => _vars[v.name] = txt),
                        )
                        : ShadSelectFormField<String>(
                          label: Text(v.name),
                          initialValue: v.enumValues![0],
                          selectedOptionBuilder: (context, value) => Text(value),
                          options: [...v.enumValues!.map((v) => ShadOption<String>(value: v, child: Text(v)))],
                          description: v.description == null ? null : Text(v.description ?? ''),
                          validator:
                              v.optional ? null : (txt) => (txt?.trim().isEmpty == true || txt == null) ? '${v.name} is required' : null,
                          onChanged: (txt) => setState(() => _vars[v.name] = txt!),
                        ),
              ),
            ),

            // ── Command preview ─────────────────────────────────────────────
            if (widget.spec.command != null) ...[
              const SizedBox(height: 16),
              Text('Command to execute', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(_renderCommand().isEmpty ? '— complete the variables above —' : _renderCommand()),
            ],

            const SizedBox(height: 16),
            Text('Room storage', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            if (widget.spec.roomStoragePath == null) Text("No storage mount"),

            if (widget.spec.roomStoragePath != null) ...[
              Text(
                widget.spec.roomStorageSubpath == null
                    ? "Mounts entire room's storage"
                    : "Mounts only to ${widget.spec.roomStorageSubpath}",
              ),
              Text(widget.spec.roomStoragePath!),
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
                      Text('Port ${p.num.value ?? "auto assigned"} ${p.type ?? ""}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ...p.endpoints.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('• ${e.path}  →  ${e.identity}  (${e.type ?? "unspecified"})'),
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
                Expanded(
                  child: ShadButton.destructive(
                    enabled: _ready,
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Deny'),
                  ),
                ),
                Expanded(
                  child: ShadButton(
                    enabled: _ready,
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        Navigator.of(context).pop(_vars);
                      }
                    },
                    child: const Text('Allow'),
                  ),
                ),
              ],
            ),
          ],
        ),
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

  LogProgress? progress;
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
        progress = p;
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
    return Column(
      children: [
        if (progress != null) ...[
          Text(progress!.message),
          if (progress!.current != null && progress!.total != null)
            LinearProgressIndicator(value: progress!.current!.toDouble() / progress!.total!.toDouble()),
        ],
        Expanded(
          child: SelectionArea(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), color: ShadTheme.of(context).colorScheme.secondary),
              child: SuperListView(
                controller: controller,
                padding: EdgeInsets.all(24),
                children: [
                  for (final l in logs)
                    Text(
                      l,
                      style: GoogleFonts.sourceCodePro(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: ShadTheme.of(context).colorScheme.foreground,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ContainerLogs extends StatefulWidget {
  const ContainerLogs({super.key, required this.client, required this.containerId});

  final RoomClient client;
  final String containerId;
  @override
  State<ContainerLogs> createState() => _ContainerLogsState();
}

class _ContainerLogsState extends State<ContainerLogs> {
  @override
  void initState() {
    super.initState();
    logs = widget.client.containers.logs(containerId: widget.containerId, follow: true);
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
