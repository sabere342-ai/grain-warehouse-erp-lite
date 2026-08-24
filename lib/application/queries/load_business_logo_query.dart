import 'dart:typed_data';

import 'package:grain_warehouse_erp_lite/application/queries/application_query.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';

final class LoadBusinessLogoQuery {
  const LoadBusinessLogoQuery({required this.managedFileName});

  final String managedFileName;
}

final class LoadBusinessLogoQueryHandler
    implements ApplicationQueryHandler<LoadBusinessLogoQuery, Uint8List?> {
  const LoadBusinessLogoQueryHandler({
    required BusinessIdentityRepository repository,
  }) : _repository = repository;

  final BusinessIdentityRepository _repository;

  @override
  Future<ApplicationQueryResult<Uint8List?>> execute(
    LoadBusinessLogoQuery query,
  ) async {
    if (query.managedFileName.isEmpty) {
      return const ApplicationQueryResult(
        value: null,
        metadata: LocalQueryResultMetadata(
          readAuthority: LocalReadAuthority.managedFile,
        ),
      );
    }

    final bytes = await _repository.loadLogoBytes(query.managedFileName);
    return ApplicationQueryResult(
      value: bytes,
      metadata: const LocalQueryResultMetadata(
        readAuthority: LocalReadAuthority.managedFile,
      ),
    );
  }
}
