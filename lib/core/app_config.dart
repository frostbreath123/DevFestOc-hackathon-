/// Build-time configuration. Nothing secret is stored here.
///
/// Pass values with `--dart-define`:
///  * `RAILOCITY_AI_ENDPOINT` - URL of the AI proxy (see `tools/ai_proxy`).
///    The app never holds an AI provider key. The proxy holds it.
///  * `RAILOCITY_DEMO_DATA` - `true` (default) uses simulated railway data.
///    `false` uses the real-data service, which is not connected yet.
class AppConfig {
  const AppConfig({this.aiEndpoint, this.useDemoData = true});

  factory AppConfig.fromEnvironment() {
    const endpoint = String.fromEnvironment('RAILOCITY_AI_ENDPOINT');
    const demo = bool.fromEnvironment(
      'RAILOCITY_DEMO_DATA',
      defaultValue: true,
    );
    return AppConfig(
      aiEndpoint: endpoint.isEmpty ? null : Uri.tryParse(endpoint),
      useDemoData: demo,
    );
  }

  final Uri? aiEndpoint;
  final bool useDemoData;
}
