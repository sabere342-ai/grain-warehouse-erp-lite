final class SupabaseRuntimeConfig {
  SupabaseRuntimeConfig({
    required String url,
    required String publishableKey,
  })  : url = _validatedUrl(url),
        publishableKey = _validatedKey(publishableKey);

  final Uri url;
  final String publishableKey;

  static SupabaseRuntimeConfig? fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (url.trim().isEmpty && key.trim().isEmpty) return null;
    return SupabaseRuntimeConfig(url: url, publishableKey: key);
  }

  static Uri _validatedUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                (uri.host == 'localhost' || uri.host == '127.0.0.1')))) {
      throw ArgumentError.value(value, 'url', 'Invalid Supabase URL.');
    }
    return uri;
  }

  static String _validatedKey(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.startsWith('sb_secret_') ||
        normalized.startsWith('service_role')) {
      throw ArgumentError.value(
        '<redacted>',
        'publishableKey',
        'A non-secret publishable client key is required.',
      );
    }
    return normalized;
  }
}
