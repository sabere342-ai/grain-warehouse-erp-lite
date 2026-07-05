import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/grain_warehouse_app.dart';

void main() {
  testWidgets('renders Arabic login shell', (tester) async {
    await tester.pumpWidget(const GrainWarehouseApp());

    expect(find.text('Grain Warehouse ERP Lite'), findsOneWidget);
    expect(find.text('نظام مبسط لمخزن حبوب واحد'), findsOneWidget);
    expect(find.text('دخول للواجهة التجريبية'), findsOneWidget);
  });

  testWidgets('opens placeholder dashboard shell', (tester) async {
    await tester.pumpWidget(const GrainWarehouseApp());

    await tester.tap(find.text('دخول للواجهة التجريبية'));
    await tester.pumpAndSettle();

    expect(find.text('لوحة المتابعة'), findsOneWidget);
    expect(find.text('المبيعات'), findsWidgets);
  });
}
