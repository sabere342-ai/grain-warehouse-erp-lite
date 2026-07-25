import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';

class BusinessIdentityController extends ChangeNotifier {
  BusinessIdentityController({required BusinessIdentityRepository repository})
      : _repository = repository;

  final BusinessIdentityRepository _repository;
  BusinessIdentity _identity = BusinessIdentity.empty;
  bool _isLoading = false;
  String? _message;

  BusinessIdentity get identity => _identity;
  bool get isLoading => _isLoading;
  String? get message => _message;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    _identity = await _repository.loadIdentity();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveEstablishmentName(String value) async {
    final trimmed = value.trim();
    _identity = _identity.copyWith(
      establishmentName: trimmed.isEmpty ? null : trimmed,
    );
    _message = null;
    notifyListeners();
    try {
      await _repository.saveIdentity(_identity);
      _message = 'تم حفظ اسم المنشأة.';
    } catch (_) {
      _message = 'تم تطبيق اسم المنشأة الآن، لكن تعذر حفظه للجلسة القادمة.';
    }
    notifyListeners();
  }

  Future<void> saveProfileDetails({
    String? taxNumber,
    String? address,
    String? phone,
  }) async {
    final trimmedTax = taxNumber?.trim();
    final trimmedAddress = address?.trim();
    final trimmedPhone = phone?.trim();
    _identity = _identity.copyWith(
      taxNumber: trimmedTax?.isEmpty == true ? null : trimmedTax,
      address: trimmedAddress?.isEmpty == true ? null : trimmedAddress,
      phone: trimmedPhone?.isEmpty == true ? null : trimmedPhone,
    );
    _message = null;
    notifyListeners();
    try {
      await _repository.saveIdentity(_identity);
      _message = 'تم حفظ بيانات المنشأة الإضافية.';
    } catch (_) {
      _message = 'تم تطبيق البيانات، لكن تعذر حفظها للجلسة القادمة.';
    }
    notifyListeners();
  }

  Future<void> saveLogo(Uint8List bytes, String mimeType) async {
    _isLoading = true;
    _message = null;
    notifyListeners();
    try {
      final oldLogo = _identity.logo;
      final metadata = await _repository.saveLogoBytes(bytes, mimeType);
      if (metadata == null) {
        _message = 'تعذر حفظ الشعار. تحقق من الملف.';
        _isLoading = false;
        notifyListeners();
        return;
      }
      _identity = _identity.copyWith(logo: metadata);
      await _repository.saveIdentity(_identity);
      if (oldLogo != null &&
          oldLogo.managedFileName != metadata.managedFileName) {
        await _repository.deleteLogoFile(oldLogo.managedFileName);
      }
      _message = 'تم حفظ الشعار بنجاح.';
    } catch (_) {
      _message = 'تعذر حفظ الشعار.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> removeLogo() async {
    final oldLogo = _identity.logo;
    _identity = _identity.copyWith(clearLogo: true);
    _message = null;
    notifyListeners();
    try {
      await _repository.saveIdentity(_identity);
      if (oldLogo != null) {
        await _repository.deleteLogoFile(oldLogo.managedFileName);
      }
      _message = 'تم إزالة الشعار.';
    } catch (_) {
      _message = 'تمت إزالة الشعار من العرض، لكن تعذر الحفظ.';
    }
    notifyListeners();
  }
}

class BusinessIdentityScope
    extends InheritedNotifier<BusinessIdentityController> {
  const BusinessIdentityScope({
    super.key,
    required BusinessIdentityController controller,
    required super.child,
  }) : super(notifier: controller);

  static BusinessIdentityController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<BusinessIdentityScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('BusinessIdentityScope was not found.');
    }
    return scope.notifier!;
  }

  static BusinessIdentityController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<BusinessIdentityScope>()
        ?.notifier;
  }
}
