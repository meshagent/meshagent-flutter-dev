import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent_flutter_dev/typography.dart';

void main() {
  test('developer code typography uses the bundled Source Code Pro family', () {
    expect(meshagentDeveloperCodeFontFamily, 'SourceCodePro');
    expect(
      meshagentDeveloperCodeTextStyle.fontFamily,
      meshagentDeveloperCodeFontFamily,
    );
  });
}
