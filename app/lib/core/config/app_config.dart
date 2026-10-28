/// Build-time configuration via --dart-define. Only PUBLIC values belong here:
/// the Supabase URL and publishable (anon) key are designed to be shipped in
/// clients and are protected by Row Level Security. Gemini and Make.com secrets
/// live only in Supabase Edge Function secrets — never in this app.
class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseKey, required this.forceDemo});

  factory AppConfig.fromEnvironment() => const AppConfig(
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabaseKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
        forceDemo: bool.fromEnvironment('DEMO_MODE'),
      );

  final String supabaseUrl;
  final String supabaseKey;
  final bool forceDemo;

  bool get liveConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Demo mode runs entirely on-device with synthetic data.
  bool get demoMode => forceDemo || !liveConfigured;
}
