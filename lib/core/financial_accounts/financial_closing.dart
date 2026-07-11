import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';

enum FinancialClosingKind { daily, period }

class FinancialClosingLine {
  const FinancialClosingLine(
      {required this.accountId,
      required this.expectedBalanceQirsh,
      required this.actualBalanceQirsh});
  final String accountId;
  final int expectedBalanceQirsh;
  final int actualBalanceQirsh;
  int get differenceQirsh => actualBalanceQirsh - expectedBalanceQirsh;
}

class FinancialClosing {
  const FinancialClosing(
      {required this.id,
      required this.kind,
      required this.fromDate,
      required this.toDate,
      required this.lines,
      required this.createdAt,
      required this.createdByUserId,
      this.note,
      this.reopenedAt,
      this.reopenedByUserId,
      this.reopenReason});
  final String id;
  final FinancialClosingKind kind;
  final DateTime fromDate;
  final DateTime toDate;
  final List<FinancialClosingLine> lines;
  final DateTime createdAt;
  final String createdByUserId;
  final String? note;
  final DateTime? reopenedAt;
  final String? reopenedByUserId;
  final String? reopenReason;
  bool get isOpen => reopenedAt != null;
  int get totalDifferenceQirsh =>
      lines.fold(0, (sum, line) => sum + line.differenceQirsh);
}

class FinancialClosingDraft {
  const FinancialClosingDraft(
      {required this.kind,
      required this.fromDate,
      required this.toDate,
      required this.actualBalancesQirsh,
      this.note});
  final FinancialClosingKind kind;
  final DateTime fromDate;
  final DateTime toDate;
  final Map<String, int> actualBalancesQirsh;
  final String? note;
}

class FinancialClosingAccountView {
  const FinancialClosingAccountView(
      {required this.account, required this.expectedBalanceQirsh});
  final FinancialAccount account;
  final int expectedBalanceQirsh;
}
