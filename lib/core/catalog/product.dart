import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.code,
    this.defaultSalePricePiastersPerKg,
    this.minimumSalePricePiastersPerKg,
    this.referenceCostPricePiastersPerKg,
    this.notes,
  });

  final String id;
  final String name;
  final String? code;
  final GrainUnit unit;
  final bool isActive;
  final int? defaultSalePricePiastersPerKg;
  final int? minimumSalePricePiastersPerKg;
  final int? referenceCostPricePiastersPerKg;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasValidId => id.trim().isNotEmpty;

  Product copyWith({
    String? id,
    String? name,
    String? code,
    GrainUnit? unit,
    bool? isActive,
    int? defaultSalePricePiastersPerKg,
    int? minimumSalePricePiastersPerKg,
    int? referenceCostPricePiastersPerKg,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
      defaultSalePricePiastersPerKg:
          defaultSalePricePiastersPerKg ?? this.defaultSalePricePiastersPerKg,
      minimumSalePricePiastersPerKg:
          minimumSalePricePiastersPerKg ?? this.minimumSalePricePiastersPerKg,
      referenceCostPricePiastersPerKg: referenceCostPricePiastersPerKg ??
          this.referenceCostPricePiastersPerKg,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.unit,
    this.code,
    this.defaultSalePricePiastersPerKg,
    this.minimumSalePricePiastersPerKg,
    this.referenceCostPricePiastersPerKg,
    this.notes,
  });

  final String name;
  final String? code;
  final GrainUnit unit;
  final int? defaultSalePricePiastersPerKg;
  final int? minimumSalePricePiastersPerKg;
  final int? referenceCostPricePiastersPerKg;
  final String? notes;
}
