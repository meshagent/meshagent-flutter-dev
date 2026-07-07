import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_dev/meshagent_flutter_dev.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Widget _buildHarness({
  required ServiceTemplateSpec spec,
  Map<String, String>? prefilledVars,
  List<String> routeDomains = const [],
  required void Function(Map<String, String> vars) onVars,
}) {
  return ShadApp(
    home: Scaffold(
      body: SizedBox.expand(
        child: ConfigureServiceTemplate(
          spec: spec,
          prefilledVars: prefilledVars,
          routeDomains: routeDomains,
          actionsBuilder: (context, vars, validate) {
            onVars(Map<String, String>.from(vars));
            return const [SizedBox.shrink()];
          },
        ),
      ),
    ),
  );
}

void main() {
  final spec = ServiceTemplateSpec.fromJson({
    'version': 'v1',
    'kind': 'ServiceTemplate',
    'metadata': {'name': 'assistant'},
    'variables': [
      {
        'name': 'provider',
        'enum': ['OpenAI', 'Anthropic'],
      },
      {
        'name': 'heartbeat',
        'enum': ['off', 'on'],
      },
    ],
  });

  testWidgets('enum template variables default to the first option', (
    tester,
  ) async {
    Map<String, String>? seenVars;

    await tester.pumpWidget(
      _buildHarness(spec: spec, onVars: (vars) => seenVars = vars),
    );

    expect(seenVars, isNotNull);
    expect(seenVars!['provider'], 'OpenAI');
    expect(seenVars!['heartbeat'], 'off');
  });

  testWidgets('invalid prefilled enum values are normalized before submit', (
    tester,
  ) async {
    Map<String, String>? seenVars;

    await tester.pumpWidget(
      _buildHarness(
        spec: spec,
        prefilledVars: const {'provider': '', 'heartbeat': 'bad'},
        onVars: (vars) => seenVars = vars,
      ),
    );

    expect(seenVars, isNotNull);
    expect(seenVars!['provider'], 'OpenAI');
    expect(seenVars!['heartbeat'], 'off');
  });

  testWidgets('route template variables with a domain layout on desktop', (
    tester,
  ) async {
    Map<String, String>? seenVars;
    final routeSpec = ServiceTemplateSpec.fromJson({
      'version': 'v1',
      'kind': 'ServiceTemplate',
      'metadata': {'name': 'assistant'},
      'variables': [
        {'name': 'route', 'type': 'route'},
      ],
    });

    await tester.pumpWidget(
      _buildHarness(
        spec: routeSpec,
        routeDomains: const ['agents.example.com'],
        onVars: (vars) => seenVars = vars,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(seenVars, isNotNull);
  });
}
