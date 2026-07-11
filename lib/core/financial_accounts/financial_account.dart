enum FinancialAccountType {
  treasury,
  bank,
  electronicWallet;

  String get labelAr {
    switch (this) {
      case FinancialAccountType.treasury:
        return 'خزينة';
      case FinancialAccountType.bank:
        return 'حساب بنكي';
      case FinancialAccountType.electronicWallet:
        return 'محفظة إلكترونية';
    }
  }

  String get iconEmoji {
    switch (this) {
      case FinancialAccountType.treasury:
        return '\uD83D\uDCB0';
      case FinancialAccountType.bank:
        return '\uD83C\uDFE6';
      case FinancialAccountType.electronicWallet:
        return '\uD83D\uDCF1';
    }
  }
}

class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.name,
    required this.type,
    this.isActive = true,
    this.allowNegativeBalance = false,
    this.openingBalanceQirsh = 0,
    this.openingBalanceDate,
    this.referenceInfo,
    this.notes,
    required this.createdByUserId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final FinancialAccountType type;
  final bool isActive;
  final bool allowNegativeBalance;
  final int openingBalanceQirsh;
  final DateTime? openingBalanceDate;
  final String? referenceInfo;
  final String? notes;
  final String createdByUserId;
  final DateTime createdAt;

  bool get hasValidId => id.trim().isNotEmpty;
}

class FinancialAccountDraft {
  const FinancialAccountDraft({
    required this.name,
    required this.type,
    this.allowNegativeBalance = false,
    this.referenceInfo,
    this.notes,
    required this.createdByUserId,
  });

  final String name;
  final FinancialAccountType type;
  final bool allowNegativeBalance;
  final String? referenceInfo;
  final String? notes;
  final String createdByUserId;
}
