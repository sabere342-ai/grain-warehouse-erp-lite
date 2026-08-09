import 'dart:convert';

/// The integrity contract used by every supported application backup version.
///
/// The checksum is Adler-32 over the UTF-8 bytes of the two-space-indented JSON
/// serialization of the top-level backup object before `checksum` and
/// `checksumNote` are added. The encoded checksum is exactly eight lowercase
/// hexadecimal characters.
class BackupChecksum {
  const BackupChecksum._();

  static final RegExp _encodedPattern = RegExp(r'^[0-9a-f]{8}$');

  static bool isWellFormed(Object? value) {
    return value is String && _encodedPattern.hasMatch(value);
  }

  static String computePayload(Map<String, Object?> payload) {
    final serialized = const JsonEncoder.withIndent('  ').convert(payload);
    return _adler32(serialized);
  }

  static String computeEnvelope(Map<String, Object?> envelope) {
    final payload = <String, Object?>{
      for (final entry in envelope.entries)
        if (entry.key != 'checksum' && entry.key != 'checksumNote')
          entry.key: entry.value,
    };
    return computePayload(payload);
  }

  static String _adler32(String input) {
    const modulus = 65521;
    var a = 1;
    var b = 0;
    for (final byte in utf8.encode(input)) {
      a = (a + byte) % modulus;
      b = (b + a) % modulus;
    }
    return ((b << 16) | a).toRadixString(16).padLeft(8, '0');
  }
}
