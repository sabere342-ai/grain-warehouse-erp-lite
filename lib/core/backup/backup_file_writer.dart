import 'dart:io';

abstract class BackupFileWriter {
  Future<BackupFileSaveResult> save({
    required String fileName,
    required String jsonText,
  });
}

class LocalBackupFileWriter implements BackupFileWriter {
  const LocalBackupFileWriter({String? baseFolderPath})
      : _baseFolderPath = baseFolderPath;

  final String? _baseFolderPath;

  @override
  Future<BackupFileSaveResult> save({
    required String fileName,
    required String jsonText,
  }) async {
    final folder = Directory(_baseFolderPath ?? _defaultBackupFolderPath());
    await folder.create(recursive: true);

    final file = File('${folder.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(jsonText);

    return BackupFileSaveResult(
      fileName: fileName,
      filePath: file.path,
      folderPath: folder.path,
    );
  }

  String _defaultBackupFolderPath() {
    final userProfile = Platform.environment['USERPROFILE'];
    if (Platform.isWindows &&
        userProfile != null &&
        userProfile.trim().isNotEmpty) {
      return '$userProfile${Platform.pathSeparator}Documents'
          '${Platform.pathSeparator}grain-warehouse-erp-lite-backups';
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return '$home${Platform.pathSeparator}grain-warehouse-erp-lite-backups';
    }

    return '${Directory.current.path}${Platform.pathSeparator}backups';
  }
}

class BackupFileSaveResult {
  const BackupFileSaveResult({
    required this.fileName,
    required this.filePath,
    required this.folderPath,
  });

  final String fileName;
  final String filePath;
  final String folderPath;
}
