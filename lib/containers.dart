import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_dev/terminal.dart';
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
                                builder:
                                    (context) => ConfigureServiceTemplateDialog(
                                      spec: img.manifest!,
                                    ),
                              );

                              if (vars == null) {
                                return;
                              }

                              widget.client.containers.run(
                                image:
                                    img.tags.isNotEmpty
                                        ? img.tags.first
                                        : img.id,
                                variables: vars,
                              );
                            } else {
                              final tty = widget.client.containers.tty(
                                image:
                                    img.tags.isNotEmpty
                                        ? img.tags.first
                                        : img.id,
                                command: "/bin/bash",
                              );

                              await showShadDialog(
                                context: context,
                                builder: (context) {
                                  tty.result.then((value) {
                                    if (context.mounted) {
                                      Navigator.of(context).pop(value);
                                    }
                                  });
                                  return ShadDialog(
                                    constraints: BoxConstraints.tight(
                                      Size(1200, 800),
                                    ),
                                    title: Text("Container Terminal"),
                                    child: SizedBox(
                                      width: 1200,
                                      height: 800,
                                      child: ContainerTerminal(tty: tty),
                                    ),
                                  );
                                },
                              );

                              // TODO: kill it
                            }

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
                          img.manifest != null
                              ? Icon(LucideIcons.bot, color: Colors.green)
                              : Icon(LucideIcons.disc),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              img.tags.isNotEmpty
                                  ? img.tags.first
                                  : '(untagged)',
                              style: TextStyle(
                                color:
                                    img.manifest != null ? Colors.green : null,
                              ),
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
                                builder:
                                    (ctx) => ShadDialog(
                                      title: const Text('Delete image?'),
                                      child: Text(
                                        img.tags.isNotEmpty
                                            ? img.tags.first
                                            : img.id,
                                      ),
                                      actions: [
                                        ShadButton.secondary(
                                          onPressed:
                                              () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ShadButton.destructive(
                                          onPressed:
                                              () => Navigator.pop(ctx, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                              ) ??
                              false;
                          if (!confirm) return;

                          try {
                            await widget.client.containers.deleteImage(
                              image:
                                  img.tags.isNotEmpty ? img.tags.first : img.id,
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
                    DataCell(
                      Text(
                        ((c.entrypoint != null)
                                ? [
                                  ...c.entrypoint!,
                                  if (c.command != null) ...c.command!,
                                ]
                                : [c.image])
                            .join(' '),
                      ),
                    ),
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
                            icon: const Icon(LucideIcons.circleStop),
                            tooltip: 'Stop',
                            onPressed: () async {
                              final confirm =
                                  await showShadDialog<bool>(
                                    context: context,
                                    builder:
                                        (ctx) => ShadDialog(
                                          title: const Text('Stop container?'),
                                          child: Text(
                                            'Container ${c.id.substring(0, 12)}',
                                          ),
                                          actions: [
                                            ShadButton.secondary(
                                              onPressed:
                                                  () =>
                                                      Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ShadButton.destructive(
                                              onPressed:
                                                  () =>
                                                      Navigator.pop(ctx, true),
                                              child: const Text('Stop'),
                                            ),
                                          ],
                                        ),
                                  ) ??
                                  false;
                              if (!confirm) return;

                              try {
                                await widget.client.containers.stop(
                                  containerId: c.id,
                                );
                                ShadToaster.of(context).show(
                                  const ShadToast(
                                    description: Text('Container stopped'),
                                  ),
                                );
                                _reload();
                              } catch (e) {
                                ShadToaster.of(context).show(
                                  ShadToast(
                                    description: Text('Stop failed: $e'),
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
                    DataCell(
                      Text(
                        b.error ??
                            (b.result != null ? b.result.toString() : '—'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
                                          title: const Text(
                                            'Cancel this build?',
                                          ),
                                          content: Text(b.tag),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () =>
                                                      Navigator.pop(ctx, false),
                                              child: const Text('No'),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  () =>
                                                      Navigator.pop(ctx, true),
                                              child: const Text('Yes'),
                                            ),
                                          ],
                                        ),
                                  ) ??
                                  false;
                              if (!confirm) return;

                              try {
                                await widget.client.containers.stopBuild(
                                  requestId: b.requestId,
                                );
                                ShadToaster.of(context).show(
                                  const ShadToast(
                                    description: Text('Build cancelled'),
                                  ),
                                );
                                _reload();
                              } catch (e) {
                                ShadToaster.of(context).show(
                                  ShadToast(
                                    description: Text('Cancel failed: $e'),
                                  ),
                                );
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

class _ConfigureServiceTemplateDialog
    extends State<ConfigureServiceTemplateDialog> {
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
                  child:
                      v.enumValues == null
                          ? ShadInputFormField(
                            label: Text(v.name),
                            obscureText: v.obscure,
                            description:
                                v.description == null
                                    ? null
                                    : Text(v.description ?? ''),

                            validator:
                                v.optional
                                    ? null
                                    : (txt) =>
                                        (txt.trim().isEmpty)
                                            ? '${v.name} is required'
                                            : null,
                            onChanged:
                                (txt) => setState(() => _vars[v.name] = txt),
                          )
                          : ShadSelectFormField<String>(
                            label: Text(v.name),
                            initialValue: v.enumValues![0],
                            selectedOptionBuilder:
                                (context, value) => Text(value),
                            options: [
                              ...v.enumValues!.map(
                                (v) => ShadOption<String>(
                                  value: v,
                                  child: Text(v),
                                ),
                              ),
                            ],
                            description:
                                v.description == null
                                    ? null
                                    : Text(v.description ?? ''),
                            validator:
                                v.optional
                                    ? null
                                    : (txt) =>
                                        (txt?.trim().isEmpty == true ||
                                                txt == null)
                                            ? '${v.name} is required'
                                            : null,
                            onChanged:
                                (txt) => setState(() => _vars[v.name] = txt!),
                          ),
                ),
              ),

            // ── Command preview ─────────────────────────────────────────────
            if (widget.spec.command != null) ...[
              const SizedBox(height: 16),
              Text(
                'Command to execute',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _renderCommand().isEmpty
                    ? '— complete the variables above —'
                    : _renderCommand(),
              ),
            ],

            const SizedBox(height: 16),
            Text(
              'Room storage',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),

            if (widget.spec.storage == null ||
                widget.spec.storage?.room == null)
              Text("No storage mount"),

            if (widget.spec.storage != null &&
                widget.spec.storage?.room != null) ...[
              for (final rs in widget.spec.storage!.room!) ...[
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
                            '• ${e.path}  →  ${e.identity}  (${e.type ?? "unspecified"})',
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
    final inProgress =
        progress.entries
            .where(
              (entry) =>
                  entry.value.current != null && entry.value.total != null,
            )
            .toList();
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

class BuildImage extends StatefulWidget {
  const BuildImage({super.key, required this.room});

  final RoomClient room;

  @override
  State<BuildImage> createState() => _BuildImage();
}

class _BuildImage extends State<BuildImage> {
  List<DockerSecret> currentCredentials = [];
  LogStream? logs;

  Future<bool> buildImage() async {
    if (!formKey.currentState!.validate()) {
      return false;
    }

    BuildSource? source;

    setState(() {
      error = null;
    });

    final gitUrl = formKey.currentState!.value["git_url"] as String?;
    if (gitUrl != null && gitUrl.isNotEmpty) {
      String gitPassword = formKey.currentState!.value["git_password"];
      String gitUsername = formKey.currentState!.value["git_username"];
      String gitRef = formKey.currentState!.value["git_ref"];
      String gitPath = formKey.currentState!.value["git_path"];

      source = BuildSourceGit(
        url: "https://$gitUrl",
        username: gitUsername == "" ? null : gitUsername,
        password: gitPassword == "" ? null : gitPassword,
        ref: gitRef == "" ? null : gitRef,
        path: gitPath == "" ? null : gitPath,
      );
    } else {
      return false;
    }

    /*
    Stream<TarEntry> entries = Stream.value(
      TarEntry.data(
        TarHeader(name: 'Dockerfile', mode: int.parse('644', radix: 8)),
        utf8.encode("""FROM python:3.13-slim-bookworm
        ENV VIRTUAL_ENV=/src/venv
        RUN python3 -m venv \$VIRTUAL_ENV
        ENV PATH="\$VIRTUAL_ENV/bin:\$PATH"

        RUN pip3 install meshagent[all]

        ENTRYPOINT [ "meshagent", "chatbot", "join" ]
        """),
      ),
    );

    final builder = BytesBuilder(copy: false);
    await for (final entry in entries.transform(tarWriter)) {
      builder.add(entry);
    }
    final data = Uint8List.fromList(await GZip().compress(builder.takeBytes()));

        final file = await widget.room.storage.open("docker.tar.gz", overwrite: true);
    await widget.room.storage.write(file, data);
    await widget.room.storage.close(file);

*/
    final image = formKey.currentState!.value["git_url"];

    try {
      // final buildLogs = widget.room.containers.build(tag: image, source: BuildSourceContext(context: Uint8List.fromList(data)));
      //final buildLogs = widget.room.containers.build(tag: image, source: BuildSourceRoom(path: "/sample"));
      final buildLogs = widget.room.containers.build(
        tag: image,
        source: source,
        credentials: currentCredentials,
      );
      if (!mounted) return false;
      setState(() {
        logs = buildLogs;
      });

      await buildLogs.result;

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
      title: Text("Build an Image"),
      description: Text("Build an image to use for containers in your room"),

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
                if (await buildImage()) {
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
            child: Text("Build Image"),
          ),
      ],
      child: SizedBox(
        width: 1000,
        height: 650,
        child:
            error != null
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
                                    Text(
                                      "Source",
                                      style:
                                          ShadTheme.of(context).textTheme.muted,
                                    ),
                                    ShadInputFormField(
                                      id: "git_url",
                                      leading: Text("https://"),
                                      gap: 0,
                                      label: Text("git repository url"),
                                      placeholder: Text(
                                        "github.com/meshagent/examples",
                                      ),
                                      validator:
                                          (value) =>
                                              value.isEmpty
                                                  ? "git url is required"
                                                  : null,
                                    ),

                                    Text(
                                      "Optional Configuration Options",
                                      style:
                                          ShadTheme.of(context).textTheme.muted,
                                    ),

                                    Row(
                                      spacing: 8,
                                      children: [
                                        Expanded(
                                          child: ShadInputFormField(
                                            id: "git_username",
                                            label: Text("username"),
                                            placeholder: Text(
                                              "your git username",
                                            ),
                                            initialValue: "",
                                          ),
                                        ),

                                        Expanded(
                                          child: ShadInputFormField(
                                            id: "git_password",
                                            label: Text("password"),
                                            placeholder: Text(
                                              "a personal access token or git password",
                                            ),
                                            obscureText: true,
                                            initialValue: "",
                                          ),
                                        ),
                                      ],
                                    ),

                                    ShadInputFormField(
                                      id: "git_ref",
                                      label: Text("branch"),
                                      obscureText: true,
                                      initialValue: "",
                                      placeholder: Text(
                                        "a branch name or reference to build from",
                                      ),
                                    ),

                                    ShadInputFormField(
                                      id: "git_path",
                                      label: Text("path"),
                                      obscureText: true,
                                      initialValue: "",
                                      placeholder: Text(
                                        "build from a subdirectory within the repository",
                                      ),
                                    ),

                                    Text(
                                      "docker credentials (for pulling base images)",
                                      style:
                                          ShadTheme.of(context).textTheme.small,
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
      // final buildLogs = widget.room.containers.build(tag: image, source: BuildSourceContext(context: Uint8List.fromList(data)));
      //final buildLogs = widget.room.containers.build(tag: image, source: BuildSourceRoom(path: "/sample"));
      final buildLogs = widget.room.containers.pullImage(
        tag: tag,
        credentials: currentCredentials,
      );
      if (!mounted) return false;
      setState(() {
        logs = buildLogs;
      });

      await buildLogs.result;
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
        child:
            error != null
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
                                      validator:
                                          (value) =>
                                              value.isEmpty
                                                  ? "image tag is required"
                                                  : null,
                                    ),

                                    Text(
                                      "registry credentials",
                                      style:
                                          ShadTheme.of(context).textTheme.small,
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
