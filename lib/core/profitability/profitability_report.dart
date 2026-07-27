import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';

class ProfitabilityReport {
  const ProfitabilityReport.notAvailable({
    required this.messageAr,
    required this.activation,
  })  : start = null,
        end = null,
        salesRevenueQirsh = null,
        cashRevenueQirsh = null,
        creditRevenueQirsh = null,
        costOfGoodsSoldQirsh = null,
        grossProfitQirsh = null,
        operatingExpensesQirsh = null,
        netOperatingProfitQirsh = null;

  const ProfitabilityReport.available({
    required this.activation,
    required this.start,
    required this.end,
    required this.salesRevenueQirsh,
    required this.cashRevenueQirsh,
    required this.creditRevenueQirsh,
    required this.costOfGoodsSoldQirsh,
    required this.grossProfitQirsh,
    required this.operatingExpensesQirsh,
    required this.netOperatingProfitQirsh,
  }) : messageAr = null;

  static const unavailableBeforeActivationAr =
      'غير متاحة محاسبيًا — لا توجد بيانات تكلفة تاريخية كافية';
  static const cashWarningAr = 'صافي حركة النقدية لا يساوي صافي الربح.';

  final ProfitabilityActivation activation;
  final String? messageAr;
  final DateTime? start;
  final DateTime? end;
  final int? salesRevenueQirsh;
  final int? cashRevenueQirsh;
  final int? creditRevenueQirsh;
  final int? costOfGoodsSoldQirsh;
  final int? grossProfitQirsh;
  final int? operatingExpensesQirsh;
  final int? netOperatingProfitQirsh;

  bool get isAvailable => netOperatingProfitQirsh != null;
  String get cashWarning => cashWarningAr;
}
