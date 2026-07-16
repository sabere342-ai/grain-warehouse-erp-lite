// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foundation_database.dart';

// ignore_for_file: type=lint
class $FoundationProbesTable extends FoundationProbes
    with TableInfo<$FoundationProbesTable, FoundationProbe> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoundationProbesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'foundation_probes';
  @override
  VerificationContext validateIntegrity(Insertable<FoundationProbe> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  FoundationProbe map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoundationProbe(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $FoundationProbesTable createAlias(String alias) {
    return $FoundationProbesTable(attachedDatabase, alias);
  }
}

class FoundationProbe extends DataClass implements Insertable<FoundationProbe> {
  final String key;
  final String value;
  const FoundationProbe({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  FoundationProbesCompanion toCompanion(bool nullToAbsent) {
    return FoundationProbesCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory FoundationProbe.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoundationProbe(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  FoundationProbe copyWith({String? key, String? value}) => FoundationProbe(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  FoundationProbe copyWithCompanion(FoundationProbesCompanion data) {
    return FoundationProbe(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoundationProbe(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoundationProbe &&
          other.key == this.key &&
          other.value == this.value);
}

class FoundationProbesCompanion extends UpdateCompanion<FoundationProbe> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const FoundationProbesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoundationProbesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<FoundationProbe> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoundationProbesCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return FoundationProbesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoundationProbesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _normalizedNameMeta =
      const VerificationMeta('normalizedName');
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
      'normalized_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _normalizedCodeMeta =
      const VerificationMeta('normalizedCode');
  @override
  late final GeneratedColumn<String> normalizedCode = GeneratedColumn<String>(
      'normalized_code', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'));
  static const VerificationMeta _defaultSalePricePiastersPerKgMeta =
      const VerificationMeta('defaultSalePricePiastersPerKg');
  @override
  late final GeneratedColumn<int> defaultSalePricePiastersPerKg =
      GeneratedColumn<int>(
          'default_sale_price_piasters_per_kg', aliasedName, true,
          type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _minimumSalePricePiastersPerKgMeta =
      const VerificationMeta('minimumSalePricePiastersPerKg');
  @override
  late final GeneratedColumn<int> minimumSalePricePiastersPerKg =
      GeneratedColumn<int>(
          'minimum_sale_price_piasters_per_kg', aliasedName, true,
          type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _referenceCostPricePiastersPerKgMeta =
      const VerificationMeta('referenceCostPricePiastersPerKg');
  @override
  late final GeneratedColumn<int> referenceCostPricePiastersPerKg =
      GeneratedColumn<int>(
          'reference_cost_price_piasters_per_kg', aliasedName, true,
          type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        normalizedName,
        code,
        normalizedCode,
        unit,
        isActive,
        defaultSalePricePiastersPerKg,
        minimumSalePricePiastersPerKg,
        referenceCostPricePiastersPerKg,
        notes,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(Insertable<Product> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
          _normalizedNameMeta,
          normalizedName.isAcceptableOrUnknown(
              data['normalized_name']!, _normalizedNameMeta));
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    }
    if (data.containsKey('normalized_code')) {
      context.handle(
          _normalizedCodeMeta,
          normalizedCode.isAcceptableOrUnknown(
              data['normalized_code']!, _normalizedCodeMeta));
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    } else if (isInserting) {
      context.missing(_isActiveMeta);
    }
    if (data.containsKey('default_sale_price_piasters_per_kg')) {
      context.handle(
          _defaultSalePricePiastersPerKgMeta,
          defaultSalePricePiastersPerKg.isAcceptableOrUnknown(
              data['default_sale_price_piasters_per_kg']!,
              _defaultSalePricePiastersPerKgMeta));
    }
    if (data.containsKey('minimum_sale_price_piasters_per_kg')) {
      context.handle(
          _minimumSalePricePiastersPerKgMeta,
          minimumSalePricePiastersPerKg.isAcceptableOrUnknown(
              data['minimum_sale_price_piasters_per_kg']!,
              _minimumSalePricePiastersPerKgMeta));
    }
    if (data.containsKey('reference_cost_price_piasters_per_kg')) {
      context.handle(
          _referenceCostPricePiastersPerKgMeta,
          referenceCostPricePiastersPerKg.isAcceptableOrUnknown(
              data['reference_cost_price_piasters_per_kg']!,
              _referenceCostPricePiastersPerKgMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      normalizedName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_name'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code']),
      normalizedCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}normalized_code']),
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      defaultSalePricePiastersPerKg: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}default_sale_price_piasters_per_kg']),
      minimumSalePricePiastersPerKg: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}minimum_sale_price_piasters_per_kg']),
      referenceCostPricePiastersPerKg: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}reference_cost_price_piasters_per_kg']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final String id;
  final String name;
  final String normalizedName;
  final String? code;
  final String? normalizedCode;
  final String unit;
  final bool isActive;
  final int? defaultSalePricePiastersPerKg;
  final int? minimumSalePricePiastersPerKg;
  final int? referenceCostPricePiastersPerKg;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Product(
      {required this.id,
      required this.name,
      required this.normalizedName,
      this.code,
      this.normalizedCode,
      required this.unit,
      required this.isActive,
      this.defaultSalePricePiastersPerKg,
      this.minimumSalePricePiastersPerKg,
      this.referenceCostPricePiastersPerKg,
      this.notes,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || normalizedCode != null) {
      map['normalized_code'] = Variable<String>(normalizedCode);
    }
    map['unit'] = Variable<String>(unit);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || defaultSalePricePiastersPerKg != null) {
      map['default_sale_price_piasters_per_kg'] =
          Variable<int>(defaultSalePricePiastersPerKg);
    }
    if (!nullToAbsent || minimumSalePricePiastersPerKg != null) {
      map['minimum_sale_price_piasters_per_kg'] =
          Variable<int>(minimumSalePricePiastersPerKg);
    }
    if (!nullToAbsent || referenceCostPricePiastersPerKg != null) {
      map['reference_cost_price_piasters_per_kg'] =
          Variable<int>(referenceCostPricePiastersPerKg);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      normalizedCode: normalizedCode == null && nullToAbsent
          ? const Value.absent()
          : Value(normalizedCode),
      unit: Value(unit),
      isActive: Value(isActive),
      defaultSalePricePiastersPerKg:
          defaultSalePricePiastersPerKg == null && nullToAbsent
              ? const Value.absent()
              : Value(defaultSalePricePiastersPerKg),
      minimumSalePricePiastersPerKg:
          minimumSalePricePiastersPerKg == null && nullToAbsent
              ? const Value.absent()
              : Value(minimumSalePricePiastersPerKg),
      referenceCostPricePiastersPerKg:
          referenceCostPricePiastersPerKg == null && nullToAbsent
              ? const Value.absent()
              : Value(referenceCostPricePiastersPerKg),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Product.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      code: serializer.fromJson<String?>(json['code']),
      normalizedCode: serializer.fromJson<String?>(json['normalizedCode']),
      unit: serializer.fromJson<String>(json['unit']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      defaultSalePricePiastersPerKg:
          serializer.fromJson<int?>(json['defaultSalePricePiastersPerKg']),
      minimumSalePricePiastersPerKg:
          serializer.fromJson<int?>(json['minimumSalePricePiastersPerKg']),
      referenceCostPricePiastersPerKg:
          serializer.fromJson<int?>(json['referenceCostPricePiastersPerKg']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'code': serializer.toJson<String?>(code),
      'normalizedCode': serializer.toJson<String?>(normalizedCode),
      'unit': serializer.toJson<String>(unit),
      'isActive': serializer.toJson<bool>(isActive),
      'defaultSalePricePiastersPerKg':
          serializer.toJson<int?>(defaultSalePricePiastersPerKg),
      'minimumSalePricePiastersPerKg':
          serializer.toJson<int?>(minimumSalePricePiastersPerKg),
      'referenceCostPricePiastersPerKg':
          serializer.toJson<int?>(referenceCostPricePiastersPerKg),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Product copyWith(
          {String? id,
          String? name,
          String? normalizedName,
          Value<String?> code = const Value.absent(),
          Value<String?> normalizedCode = const Value.absent(),
          String? unit,
          bool? isActive,
          Value<int?> defaultSalePricePiastersPerKg = const Value.absent(),
          Value<int?> minimumSalePricePiastersPerKg = const Value.absent(),
          Value<int?> referenceCostPricePiastersPerKg = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        normalizedName: normalizedName ?? this.normalizedName,
        code: code.present ? code.value : this.code,
        normalizedCode:
            normalizedCode.present ? normalizedCode.value : this.normalizedCode,
        unit: unit ?? this.unit,
        isActive: isActive ?? this.isActive,
        defaultSalePricePiastersPerKg: defaultSalePricePiastersPerKg.present
            ? defaultSalePricePiastersPerKg.value
            : this.defaultSalePricePiastersPerKg,
        minimumSalePricePiastersPerKg: minimumSalePricePiastersPerKg.present
            ? minimumSalePricePiastersPerKg.value
            : this.minimumSalePricePiastersPerKg,
        referenceCostPricePiastersPerKg: referenceCostPricePiastersPerKg.present
            ? referenceCostPricePiastersPerKg.value
            : this.referenceCostPricePiastersPerKg,
        notes: notes.present ? notes.value : this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      code: data.code.present ? data.code.value : this.code,
      normalizedCode: data.normalizedCode.present
          ? data.normalizedCode.value
          : this.normalizedCode,
      unit: data.unit.present ? data.unit.value : this.unit,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      defaultSalePricePiastersPerKg: data.defaultSalePricePiastersPerKg.present
          ? data.defaultSalePricePiastersPerKg.value
          : this.defaultSalePricePiastersPerKg,
      minimumSalePricePiastersPerKg: data.minimumSalePricePiastersPerKg.present
          ? data.minimumSalePricePiastersPerKg.value
          : this.minimumSalePricePiastersPerKg,
      referenceCostPricePiastersPerKg:
          data.referenceCostPricePiastersPerKg.present
              ? data.referenceCostPricePiastersPerKg.value
              : this.referenceCostPricePiastersPerKg,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('code: $code, ')
          ..write('normalizedCode: $normalizedCode, ')
          ..write('unit: $unit, ')
          ..write('isActive: $isActive, ')
          ..write(
              'defaultSalePricePiastersPerKg: $defaultSalePricePiastersPerKg, ')
          ..write(
              'minimumSalePricePiastersPerKg: $minimumSalePricePiastersPerKg, ')
          ..write(
              'referenceCostPricePiastersPerKg: $referenceCostPricePiastersPerKg, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      normalizedName,
      code,
      normalizedCode,
      unit,
      isActive,
      defaultSalePricePiastersPerKg,
      minimumSalePricePiastersPerKg,
      referenceCostPricePiastersPerKg,
      notes,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.code == this.code &&
          other.normalizedCode == this.normalizedCode &&
          other.unit == this.unit &&
          other.isActive == this.isActive &&
          other.defaultSalePricePiastersPerKg ==
              this.defaultSalePricePiastersPerKg &&
          other.minimumSalePricePiastersPerKg ==
              this.minimumSalePricePiastersPerKg &&
          other.referenceCostPricePiastersPerKg ==
              this.referenceCostPricePiastersPerKg &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<String?> code;
  final Value<String?> normalizedCode;
  final Value<String> unit;
  final Value<bool> isActive;
  final Value<int?> defaultSalePricePiastersPerKg;
  final Value<int?> minimumSalePricePiastersPerKg;
  final Value<int?> referenceCostPricePiastersPerKg;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.code = const Value.absent(),
    this.normalizedCode = const Value.absent(),
    this.unit = const Value.absent(),
    this.isActive = const Value.absent(),
    this.defaultSalePricePiastersPerKg = const Value.absent(),
    this.minimumSalePricePiastersPerKg = const Value.absent(),
    this.referenceCostPricePiastersPerKg = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsCompanion.insert({
    required String id,
    required String name,
    required String normalizedName,
    this.code = const Value.absent(),
    this.normalizedCode = const Value.absent(),
    required String unit,
    required bool isActive,
    this.defaultSalePricePiastersPerKg = const Value.absent(),
    this.minimumSalePricePiastersPerKg = const Value.absent(),
    this.referenceCostPricePiastersPerKg = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        normalizedName = Value(normalizedName),
        unit = Value(unit),
        isActive = Value(isActive),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Product> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<String>? code,
    Expression<String>? normalizedCode,
    Expression<String>? unit,
    Expression<bool>? isActive,
    Expression<int>? defaultSalePricePiastersPerKg,
    Expression<int>? minimumSalePricePiastersPerKg,
    Expression<int>? referenceCostPricePiastersPerKg,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (code != null) 'code': code,
      if (normalizedCode != null) 'normalized_code': normalizedCode,
      if (unit != null) 'unit': unit,
      if (isActive != null) 'is_active': isActive,
      if (defaultSalePricePiastersPerKg != null)
        'default_sale_price_piasters_per_kg': defaultSalePricePiastersPerKg,
      if (minimumSalePricePiastersPerKg != null)
        'minimum_sale_price_piasters_per_kg': minimumSalePricePiastersPerKg,
      if (referenceCostPricePiastersPerKg != null)
        'reference_cost_price_piasters_per_kg': referenceCostPricePiastersPerKg,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? normalizedName,
      Value<String?>? code,
      Value<String?>? normalizedCode,
      Value<String>? unit,
      Value<bool>? isActive,
      Value<int?>? defaultSalePricePiastersPerKg,
      Value<int?>? minimumSalePricePiastersPerKg,
      Value<int?>? referenceCostPricePiastersPerKg,
      Value<String?>? notes,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ProductsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      code: code ?? this.code,
      normalizedCode: normalizedCode ?? this.normalizedCode,
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
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (normalizedCode.present) {
      map['normalized_code'] = Variable<String>(normalizedCode.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (defaultSalePricePiastersPerKg.present) {
      map['default_sale_price_piasters_per_kg'] =
          Variable<int>(defaultSalePricePiastersPerKg.value);
    }
    if (minimumSalePricePiastersPerKg.present) {
      map['minimum_sale_price_piasters_per_kg'] =
          Variable<int>(minimumSalePricePiastersPerKg.value);
    }
    if (referenceCostPricePiastersPerKg.present) {
      map['reference_cost_price_piasters_per_kg'] =
          Variable<int>(referenceCostPricePiastersPerKg.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('code: $code, ')
          ..write('normalizedCode: $normalizedCode, ')
          ..write('unit: $unit, ')
          ..write('isActive: $isActive, ')
          ..write(
              'defaultSalePricePiastersPerKg: $defaultSalePricePiastersPerKg, ')
          ..write(
              'minimumSalePricePiastersPerKg: $minimumSalePricePiastersPerKg, ')
          ..write(
              'referenceCostPricePiastersPerKg: $referenceCostPricePiastersPerKg, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RepositorySequencesTable extends RepositorySequences
    with TableInfo<$RepositorySequencesTable, RepositorySequence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepositorySequencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _repositoryMeta =
      const VerificationMeta('repository');
  @override
  late final GeneratedColumn<String> repository = GeneratedColumn<String>(
      'repository', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nextValueMeta =
      const VerificationMeta('nextValue');
  @override
  late final GeneratedColumn<int> nextValue = GeneratedColumn<int>(
      'next_value', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [repository, nextValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'repository_sequences';
  @override
  VerificationContext validateIntegrity(Insertable<RepositorySequence> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('repository')) {
      context.handle(
          _repositoryMeta,
          repository.isAcceptableOrUnknown(
              data['repository']!, _repositoryMeta));
    } else if (isInserting) {
      context.missing(_repositoryMeta);
    }
    if (data.containsKey('next_value')) {
      context.handle(_nextValueMeta,
          nextValue.isAcceptableOrUnknown(data['next_value']!, _nextValueMeta));
    } else if (isInserting) {
      context.missing(_nextValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {repository};
  @override
  RepositorySequence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RepositorySequence(
      repository: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}repository'])!,
      nextValue: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}next_value'])!,
    );
  }

  @override
  $RepositorySequencesTable createAlias(String alias) {
    return $RepositorySequencesTable(attachedDatabase, alias);
  }
}

class RepositorySequence extends DataClass
    implements Insertable<RepositorySequence> {
  final String repository;
  final int nextValue;
  const RepositorySequence({required this.repository, required this.nextValue});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['repository'] = Variable<String>(repository);
    map['next_value'] = Variable<int>(nextValue);
    return map;
  }

  RepositorySequencesCompanion toCompanion(bool nullToAbsent) {
    return RepositorySequencesCompanion(
      repository: Value(repository),
      nextValue: Value(nextValue),
    );
  }

  factory RepositorySequence.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RepositorySequence(
      repository: serializer.fromJson<String>(json['repository']),
      nextValue: serializer.fromJson<int>(json['nextValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'repository': serializer.toJson<String>(repository),
      'nextValue': serializer.toJson<int>(nextValue),
    };
  }

  RepositorySequence copyWith({String? repository, int? nextValue}) =>
      RepositorySequence(
        repository: repository ?? this.repository,
        nextValue: nextValue ?? this.nextValue,
      );
  RepositorySequence copyWithCompanion(RepositorySequencesCompanion data) {
    return RepositorySequence(
      repository:
          data.repository.present ? data.repository.value : this.repository,
      nextValue: data.nextValue.present ? data.nextValue.value : this.nextValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepositorySequence(')
          ..write('repository: $repository, ')
          ..write('nextValue: $nextValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(repository, nextValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepositorySequence &&
          other.repository == this.repository &&
          other.nextValue == this.nextValue);
}

class RepositorySequencesCompanion extends UpdateCompanion<RepositorySequence> {
  final Value<String> repository;
  final Value<int> nextValue;
  final Value<int> rowid;
  const RepositorySequencesCompanion({
    this.repository = const Value.absent(),
    this.nextValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RepositorySequencesCompanion.insert({
    required String repository,
    required int nextValue,
    this.rowid = const Value.absent(),
  })  : repository = Value(repository),
        nextValue = Value(nextValue);
  static Insertable<RepositorySequence> custom({
    Expression<String>? repository,
    Expression<int>? nextValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (repository != null) 'repository': repository,
      if (nextValue != null) 'next_value': nextValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RepositorySequencesCompanion copyWith(
      {Value<String>? repository, Value<int>? nextValue, Value<int>? rowid}) {
    return RepositorySequencesCompanion(
      repository: repository ?? this.repository,
      nextValue: nextValue ?? this.nextValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (repository.present) {
      map['repository'] = Variable<String>(repository.value);
    }
    if (nextValue.present) {
      map['next_value'] = Variable<int>(nextValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepositorySequencesCompanion(')
          ..write('repository: $repository, ')
          ..write('nextValue: $nextValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomersTable extends Customers
    with TableInfo<$CustomersTable, Customer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _normalizedNameMeta =
      const VerificationMeta('normalizedName');
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
      'normalized_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _normalizedPhoneMeta =
      const VerificationMeta('normalizedPhone');
  @override
  late final GeneratedColumn<String> normalizedPhone = GeneratedColumn<String>(
      'normalized_phone', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        normalizedName,
        phone,
        normalizedPhone,
        notes,
        isActive,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customers';
  @override
  VerificationContext validateIntegrity(Insertable<Customer> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
          _normalizedNameMeta,
          normalizedName.isAcceptableOrUnknown(
              data['normalized_name']!, _normalizedNameMeta));
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('normalized_phone')) {
      context.handle(
          _normalizedPhoneMeta,
          normalizedPhone.isAcceptableOrUnknown(
              data['normalized_phone']!, _normalizedPhoneMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    } else if (isInserting) {
      context.missing(_isActiveMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Customer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Customer(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      normalizedName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_name'])!,
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      normalizedPhone: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_phone']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CustomersTable createAlias(String alias) {
    return $CustomersTable(attachedDatabase, alias);
  }
}

class Customer extends DataClass implements Insertable<Customer> {
  final String id;
  final String name;
  final String normalizedName;
  final String? phone;
  final String? normalizedPhone;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Customer(
      {required this.id,
      required this.name,
      required this.normalizedName,
      this.phone,
      this.normalizedPhone,
      this.notes,
      required this.isActive,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || normalizedPhone != null) {
      map['normalized_phone'] = Variable<String>(normalizedPhone);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CustomersCompanion toCompanion(bool nullToAbsent) {
    return CustomersCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      normalizedPhone: normalizedPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(normalizedPhone),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Customer(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      phone: serializer.fromJson<String?>(json['phone']),
      normalizedPhone: serializer.fromJson<String?>(json['normalizedPhone']),
      notes: serializer.fromJson<String?>(json['notes']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'phone': serializer.toJson<String?>(phone),
      'normalizedPhone': serializer.toJson<String?>(normalizedPhone),
      'notes': serializer.toJson<String?>(notes),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Customer copyWith(
          {String? id,
          String? name,
          String? normalizedName,
          Value<String?> phone = const Value.absent(),
          Value<String?> normalizedPhone = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          bool? isActive,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        normalizedName: normalizedName ?? this.normalizedName,
        phone: phone.present ? phone.value : this.phone,
        normalizedPhone: normalizedPhone.present
            ? normalizedPhone.value
            : this.normalizedPhone,
        notes: notes.present ? notes.value : this.notes,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Customer copyWithCompanion(CustomersCompanion data) {
    return Customer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      phone: data.phone.present ? data.phone.value : this.phone,
      normalizedPhone: data.normalizedPhone.present
          ? data.normalizedPhone.value
          : this.normalizedPhone,
      notes: data.notes.present ? data.notes.value : this.notes,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Customer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('phone: $phone, ')
          ..write('normalizedPhone: $normalizedPhone, ')
          ..write('notes: $notes, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, normalizedName, phone,
      normalizedPhone, notes, isActive, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Customer &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.phone == this.phone &&
          other.normalizedPhone == this.normalizedPhone &&
          other.notes == this.notes &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CustomersCompanion extends UpdateCompanion<Customer> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<String?> phone;
  final Value<String?> normalizedPhone;
  final Value<String?> notes;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CustomersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.phone = const Value.absent(),
    this.normalizedPhone = const Value.absent(),
    this.notes = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomersCompanion.insert({
    required String id,
    required String name,
    required String normalizedName,
    this.phone = const Value.absent(),
    this.normalizedPhone = const Value.absent(),
    this.notes = const Value.absent(),
    required bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        normalizedName = Value(normalizedName),
        isActive = Value(isActive),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Customer> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<String>? phone,
    Expression<String>? normalizedPhone,
    Expression<String>? notes,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (phone != null) 'phone': phone,
      if (normalizedPhone != null) 'normalized_phone': normalizedPhone,
      if (notes != null) 'notes': notes,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomersCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? normalizedName,
      Value<String?>? phone,
      Value<String?>? normalizedPhone,
      Value<String?>? notes,
      Value<bool>? isActive,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return CustomersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      phone: phone ?? this.phone,
      normalizedPhone: normalizedPhone ?? this.normalizedPhone,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (normalizedPhone.present) {
      map['normalized_phone'] = Variable<String>(normalizedPhone.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('phone: $phone, ')
          ..write('normalizedPhone: $normalizedPhone, ')
          ..write('notes: $notes, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SuppliersTable extends Suppliers
    with TableInfo<$SuppliersTable, Supplier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuppliersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _normalizedNameMeta =
      const VerificationMeta('normalizedName');
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
      'normalized_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _normalizedPhoneMeta =
      const VerificationMeta('normalizedPhone');
  @override
  late final GeneratedColumn<String> normalizedPhone = GeneratedColumn<String>(
      'normalized_phone', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        normalizedName,
        phone,
        normalizedPhone,
        address,
        notes,
        isActive,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'suppliers';
  @override
  VerificationContext validateIntegrity(Insertable<Supplier> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
          _normalizedNameMeta,
          normalizedName.isAcceptableOrUnknown(
              data['normalized_name']!, _normalizedNameMeta));
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('normalized_phone')) {
      context.handle(
          _normalizedPhoneMeta,
          normalizedPhone.isAcceptableOrUnknown(
              data['normalized_phone']!, _normalizedPhoneMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    } else if (isInserting) {
      context.missing(_isActiveMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Supplier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Supplier(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      normalizedName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_name'])!,
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      normalizedPhone: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}normalized_phone']),
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SuppliersTable createAlias(String alias) {
    return $SuppliersTable(attachedDatabase, alias);
  }
}

class Supplier extends DataClass implements Insertable<Supplier> {
  final String id;
  final String name;
  final String normalizedName;
  final String? phone;
  final String? normalizedPhone;
  final String? address;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Supplier(
      {required this.id,
      required this.name,
      required this.normalizedName,
      this.phone,
      this.normalizedPhone,
      this.address,
      this.notes,
      required this.isActive,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || normalizedPhone != null) {
      map['normalized_phone'] = Variable<String>(normalizedPhone);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SuppliersCompanion toCompanion(bool nullToAbsent) {
    return SuppliersCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      normalizedPhone: normalizedPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(normalizedPhone),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Supplier.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Supplier(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      phone: serializer.fromJson<String?>(json['phone']),
      normalizedPhone: serializer.fromJson<String?>(json['normalizedPhone']),
      address: serializer.fromJson<String?>(json['address']),
      notes: serializer.fromJson<String?>(json['notes']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'phone': serializer.toJson<String?>(phone),
      'normalizedPhone': serializer.toJson<String?>(normalizedPhone),
      'address': serializer.toJson<String?>(address),
      'notes': serializer.toJson<String?>(notes),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Supplier copyWith(
          {String? id,
          String? name,
          String? normalizedName,
          Value<String?> phone = const Value.absent(),
          Value<String?> normalizedPhone = const Value.absent(),
          Value<String?> address = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          bool? isActive,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Supplier(
        id: id ?? this.id,
        name: name ?? this.name,
        normalizedName: normalizedName ?? this.normalizedName,
        phone: phone.present ? phone.value : this.phone,
        normalizedPhone: normalizedPhone.present
            ? normalizedPhone.value
            : this.normalizedPhone,
        address: address.present ? address.value : this.address,
        notes: notes.present ? notes.value : this.notes,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Supplier copyWithCompanion(SuppliersCompanion data) {
    return Supplier(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      phone: data.phone.present ? data.phone.value : this.phone,
      normalizedPhone: data.normalizedPhone.present
          ? data.normalizedPhone.value
          : this.normalizedPhone,
      address: data.address.present ? data.address.value : this.address,
      notes: data.notes.present ? data.notes.value : this.notes,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Supplier(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('phone: $phone, ')
          ..write('normalizedPhone: $normalizedPhone, ')
          ..write('address: $address, ')
          ..write('notes: $notes, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, normalizedName, phone,
      normalizedPhone, address, notes, isActive, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Supplier &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.phone == this.phone &&
          other.normalizedPhone == this.normalizedPhone &&
          other.address == this.address &&
          other.notes == this.notes &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SuppliersCompanion extends UpdateCompanion<Supplier> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<String?> phone;
  final Value<String?> normalizedPhone;
  final Value<String?> address;
  final Value<String?> notes;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SuppliersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.phone = const Value.absent(),
    this.normalizedPhone = const Value.absent(),
    this.address = const Value.absent(),
    this.notes = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SuppliersCompanion.insert({
    required String id,
    required String name,
    required String normalizedName,
    this.phone = const Value.absent(),
    this.normalizedPhone = const Value.absent(),
    this.address = const Value.absent(),
    this.notes = const Value.absent(),
    required bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        normalizedName = Value(normalizedName),
        isActive = Value(isActive),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Supplier> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<String>? phone,
    Expression<String>? normalizedPhone,
    Expression<String>? address,
    Expression<String>? notes,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (phone != null) 'phone': phone,
      if (normalizedPhone != null) 'normalized_phone': normalizedPhone,
      if (address != null) 'address': address,
      if (notes != null) 'notes': notes,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SuppliersCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? normalizedName,
      Value<String?>? phone,
      Value<String?>? normalizedPhone,
      Value<String?>? address,
      Value<String?>? notes,
      Value<bool>? isActive,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SuppliersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      phone: phone ?? this.phone,
      normalizedPhone: normalizedPhone ?? this.normalizedPhone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (normalizedPhone.present) {
      map['normalized_phone'] = Variable<String>(normalizedPhone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SuppliersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('phone: $phone, ')
          ..write('normalizedPhone: $normalizedPhone, ')
          ..write('address: $address, ')
          ..write('notes: $notes, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InventoryMovementsTable extends InventoryMovements
    with TableInfo<$InventoryMovementsTable, InventoryMovement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InventoryMovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _movementTypeMeta =
      const VerificationMeta('movementType');
  @override
  late final GeneratedColumn<String> movementType = GeneratedColumn<String>(
      'movement_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityKgMeta =
      const VerificationMeta('quantityKg');
  @override
  late final GeneratedColumn<int> quantityKg = GeneratedColumn<int>(
      'quantity_kg', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdByUserIdMeta =
      const VerificationMeta('createdByUserId');
  @override
  late final GeneratedColumn<String> createdByUserId = GeneratedColumn<String>(
      'created_by_user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isVoidedMeta =
      const VerificationMeta('isVoided');
  @override
  late final GeneratedColumn<bool> isVoided = GeneratedColumn<bool>(
      'is_voided', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_voided" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _reversedMovementIdMeta =
      const VerificationMeta('reversedMovementId');
  @override
  late final GeneratedColumn<String> reversedMovementId =
      GeneratedColumn<String>('reversed_movement_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _originalDocumentIdMeta =
      const VerificationMeta('originalDocumentId');
  @override
  late final GeneratedColumn<String> originalDocumentId =
      GeneratedColumn<String>('original_document_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        productId,
        movementType,
        quantityKg,
        createdByUserId,
        createdAt,
        note,
        isVoided,
        reversedMovementId,
        originalDocumentId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_movements';
  @override
  VerificationContext validateIntegrity(Insertable<InventoryMovement> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('movement_type')) {
      context.handle(
          _movementTypeMeta,
          movementType.isAcceptableOrUnknown(
              data['movement_type']!, _movementTypeMeta));
    } else if (isInserting) {
      context.missing(_movementTypeMeta);
    }
    if (data.containsKey('quantity_kg')) {
      context.handle(
          _quantityKgMeta,
          quantityKg.isAcceptableOrUnknown(
              data['quantity_kg']!, _quantityKgMeta));
    } else if (isInserting) {
      context.missing(_quantityKgMeta);
    }
    if (data.containsKey('created_by_user_id')) {
      context.handle(
          _createdByUserIdMeta,
          createdByUserId.isAcceptableOrUnknown(
              data['created_by_user_id']!, _createdByUserIdMeta));
    } else if (isInserting) {
      context.missing(_createdByUserIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('is_voided')) {
      context.handle(_isVoidedMeta,
          isVoided.isAcceptableOrUnknown(data['is_voided']!, _isVoidedMeta));
    }
    if (data.containsKey('reversed_movement_id')) {
      context.handle(
          _reversedMovementIdMeta,
          reversedMovementId.isAcceptableOrUnknown(
              data['reversed_movement_id']!, _reversedMovementIdMeta));
    }
    if (data.containsKey('original_document_id')) {
      context.handle(
          _originalDocumentIdMeta,
          originalDocumentId.isAcceptableOrUnknown(
              data['original_document_id']!, _originalDocumentIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InventoryMovement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryMovement(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      movementType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}movement_type'])!,
      quantityKg: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity_kg'])!,
      createdByUserId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}created_by_user_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      isVoided: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_voided'])!,
      reversedMovementId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}reversed_movement_id']),
      originalDocumentId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}original_document_id']),
    );
  }

  @override
  $InventoryMovementsTable createAlias(String alias) {
    return $InventoryMovementsTable(attachedDatabase, alias);
  }
}

class InventoryMovement extends DataClass
    implements Insertable<InventoryMovement> {
  final String id;
  final String productId;
  final String movementType;
  final int quantityKg;
  final String createdByUserId;
  final DateTime createdAt;
  final String? note;
  final bool isVoided;
  final String? reversedMovementId;
  final String? originalDocumentId;
  const InventoryMovement(
      {required this.id,
      required this.productId,
      required this.movementType,
      required this.quantityKg,
      required this.createdByUserId,
      required this.createdAt,
      this.note,
      required this.isVoided,
      this.reversedMovementId,
      this.originalDocumentId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['movement_type'] = Variable<String>(movementType);
    map['quantity_kg'] = Variable<int>(quantityKg);
    map['created_by_user_id'] = Variable<String>(createdByUserId);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['is_voided'] = Variable<bool>(isVoided);
    if (!nullToAbsent || reversedMovementId != null) {
      map['reversed_movement_id'] = Variable<String>(reversedMovementId);
    }
    if (!nullToAbsent || originalDocumentId != null) {
      map['original_document_id'] = Variable<String>(originalDocumentId);
    }
    return map;
  }

  InventoryMovementsCompanion toCompanion(bool nullToAbsent) {
    return InventoryMovementsCompanion(
      id: Value(id),
      productId: Value(productId),
      movementType: Value(movementType),
      quantityKg: Value(quantityKg),
      createdByUserId: Value(createdByUserId),
      createdAt: Value(createdAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      isVoided: Value(isVoided),
      reversedMovementId: reversedMovementId == null && nullToAbsent
          ? const Value.absent()
          : Value(reversedMovementId),
      originalDocumentId: originalDocumentId == null && nullToAbsent
          ? const Value.absent()
          : Value(originalDocumentId),
    );
  }

  factory InventoryMovement.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryMovement(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      movementType: serializer.fromJson<String>(json['movementType']),
      quantityKg: serializer.fromJson<int>(json['quantityKg']),
      createdByUserId: serializer.fromJson<String>(json['createdByUserId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      note: serializer.fromJson<String?>(json['note']),
      isVoided: serializer.fromJson<bool>(json['isVoided']),
      reversedMovementId:
          serializer.fromJson<String?>(json['reversedMovementId']),
      originalDocumentId:
          serializer.fromJson<String?>(json['originalDocumentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'movementType': serializer.toJson<String>(movementType),
      'quantityKg': serializer.toJson<int>(quantityKg),
      'createdByUserId': serializer.toJson<String>(createdByUserId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'note': serializer.toJson<String?>(note),
      'isVoided': serializer.toJson<bool>(isVoided),
      'reversedMovementId': serializer.toJson<String?>(reversedMovementId),
      'originalDocumentId': serializer.toJson<String?>(originalDocumentId),
    };
  }

  InventoryMovement copyWith(
          {String? id,
          String? productId,
          String? movementType,
          int? quantityKg,
          String? createdByUserId,
          DateTime? createdAt,
          Value<String?> note = const Value.absent(),
          bool? isVoided,
          Value<String?> reversedMovementId = const Value.absent(),
          Value<String?> originalDocumentId = const Value.absent()}) =>
      InventoryMovement(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        movementType: movementType ?? this.movementType,
        quantityKg: quantityKg ?? this.quantityKg,
        createdByUserId: createdByUserId ?? this.createdByUserId,
        createdAt: createdAt ?? this.createdAt,
        note: note.present ? note.value : this.note,
        isVoided: isVoided ?? this.isVoided,
        reversedMovementId: reversedMovementId.present
            ? reversedMovementId.value
            : this.reversedMovementId,
        originalDocumentId: originalDocumentId.present
            ? originalDocumentId.value
            : this.originalDocumentId,
      );
  InventoryMovement copyWithCompanion(InventoryMovementsCompanion data) {
    return InventoryMovement(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      movementType: data.movementType.present
          ? data.movementType.value
          : this.movementType,
      quantityKg:
          data.quantityKg.present ? data.quantityKg.value : this.quantityKg,
      createdByUserId: data.createdByUserId.present
          ? data.createdByUserId.value
          : this.createdByUserId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      note: data.note.present ? data.note.value : this.note,
      isVoided: data.isVoided.present ? data.isVoided.value : this.isVoided,
      reversedMovementId: data.reversedMovementId.present
          ? data.reversedMovementId.value
          : this.reversedMovementId,
      originalDocumentId: data.originalDocumentId.present
          ? data.originalDocumentId.value
          : this.originalDocumentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryMovement(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('movementType: $movementType, ')
          ..write('quantityKg: $quantityKg, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('createdAt: $createdAt, ')
          ..write('note: $note, ')
          ..write('isVoided: $isVoided, ')
          ..write('reversedMovementId: $reversedMovementId, ')
          ..write('originalDocumentId: $originalDocumentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      productId,
      movementType,
      quantityKg,
      createdByUserId,
      createdAt,
      note,
      isVoided,
      reversedMovementId,
      originalDocumentId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryMovement &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.movementType == this.movementType &&
          other.quantityKg == this.quantityKg &&
          other.createdByUserId == this.createdByUserId &&
          other.createdAt == this.createdAt &&
          other.note == this.note &&
          other.isVoided == this.isVoided &&
          other.reversedMovementId == this.reversedMovementId &&
          other.originalDocumentId == this.originalDocumentId);
}

class InventoryMovementsCompanion extends UpdateCompanion<InventoryMovement> {
  final Value<String> id;
  final Value<String> productId;
  final Value<String> movementType;
  final Value<int> quantityKg;
  final Value<String> createdByUserId;
  final Value<DateTime> createdAt;
  final Value<String?> note;
  final Value<bool> isVoided;
  final Value<String?> reversedMovementId;
  final Value<String?> originalDocumentId;
  final Value<int> rowid;
  const InventoryMovementsCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.movementType = const Value.absent(),
    this.quantityKg = const Value.absent(),
    this.createdByUserId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.note = const Value.absent(),
    this.isVoided = const Value.absent(),
    this.reversedMovementId = const Value.absent(),
    this.originalDocumentId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventoryMovementsCompanion.insert({
    required String id,
    required String productId,
    required String movementType,
    required int quantityKg,
    required String createdByUserId,
    required DateTime createdAt,
    this.note = const Value.absent(),
    this.isVoided = const Value.absent(),
    this.reversedMovementId = const Value.absent(),
    this.originalDocumentId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        productId = Value(productId),
        movementType = Value(movementType),
        quantityKg = Value(quantityKg),
        createdByUserId = Value(createdByUserId),
        createdAt = Value(createdAt);
  static Insertable<InventoryMovement> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<String>? movementType,
    Expression<int>? quantityKg,
    Expression<String>? createdByUserId,
    Expression<DateTime>? createdAt,
    Expression<String>? note,
    Expression<bool>? isVoided,
    Expression<String>? reversedMovementId,
    Expression<String>? originalDocumentId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (movementType != null) 'movement_type': movementType,
      if (quantityKg != null) 'quantity_kg': quantityKg,
      if (createdByUserId != null) 'created_by_user_id': createdByUserId,
      if (createdAt != null) 'created_at': createdAt,
      if (note != null) 'note': note,
      if (isVoided != null) 'is_voided': isVoided,
      if (reversedMovementId != null)
        'reversed_movement_id': reversedMovementId,
      if (originalDocumentId != null)
        'original_document_id': originalDocumentId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InventoryMovementsCompanion copyWith(
      {Value<String>? id,
      Value<String>? productId,
      Value<String>? movementType,
      Value<int>? quantityKg,
      Value<String>? createdByUserId,
      Value<DateTime>? createdAt,
      Value<String?>? note,
      Value<bool>? isVoided,
      Value<String?>? reversedMovementId,
      Value<String?>? originalDocumentId,
      Value<int>? rowid}) {
    return InventoryMovementsCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      movementType: movementType ?? this.movementType,
      quantityKg: quantityKg ?? this.quantityKg,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      isVoided: isVoided ?? this.isVoided,
      reversedMovementId: reversedMovementId ?? this.reversedMovementId,
      originalDocumentId: originalDocumentId ?? this.originalDocumentId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (movementType.present) {
      map['movement_type'] = Variable<String>(movementType.value);
    }
    if (quantityKg.present) {
      map['quantity_kg'] = Variable<int>(quantityKg.value);
    }
    if (createdByUserId.present) {
      map['created_by_user_id'] = Variable<String>(createdByUserId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isVoided.present) {
      map['is_voided'] = Variable<bool>(isVoided.value);
    }
    if (reversedMovementId.present) {
      map['reversed_movement_id'] = Variable<String>(reversedMovementId.value);
    }
    if (originalDocumentId.present) {
      map['original_document_id'] = Variable<String>(originalDocumentId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryMovementsCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('movementType: $movementType, ')
          ..write('quantityKg: $quantityKg, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('createdAt: $createdAt, ')
          ..write('note: $note, ')
          ..write('isVoided: $isVoided, ')
          ..write('reversedMovementId: $reversedMovementId, ')
          ..write('originalDocumentId: $originalDocumentId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PurchasesTable extends Purchases
    with TableInfo<$PurchasesTable, Purchase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PurchasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _supplierIdMeta =
      const VerificationMeta('supplierId');
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
      'supplier_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _supplierNameMeta =
      const VerificationMeta('supplierName');
  @override
  late final GeneratedColumn<String> supplierName = GeneratedColumn<String>(
      'supplier_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _supplierPhoneMeta =
      const VerificationMeta('supplierPhone');
  @override
  late final GeneratedColumn<String> supplierPhone = GeneratedColumn<String>(
      'supplier_phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _supplierAddressMeta =
      const VerificationMeta('supplierAddress');
  @override
  late final GeneratedColumn<String> supplierAddress = GeneratedColumn<String>(
      'supplier_address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityKgMeta =
      const VerificationMeta('quantityKg');
  @override
  late final GeneratedColumn<int> quantityKg = GeneratedColumn<int>(
      'quantity_kg', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _entryUnitMeta =
      const VerificationMeta('entryUnit');
  @override
  late final GeneratedColumn<String> entryUnit = GeneratedColumn<String>(
      'entry_unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unitPricePiastersPerKgMeta =
      const VerificationMeta('unitPricePiastersPerKg');
  @override
  late final GeneratedColumn<int> unitPricePiastersPerKg = GeneratedColumn<int>(
      'unit_price_piasters_per_kg', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _totalAmountPiastersMeta =
      const VerificationMeta('totalAmountPiasters');
  @override
  late final GeneratedColumn<int> totalAmountPiasters = GeneratedColumn<int>(
      'total_amount_piasters', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdByUserIdMeta =
      const VerificationMeta('createdByUserId');
  @override
  late final GeneratedColumn<String> createdByUserId = GeneratedColumn<String>(
      'created_by_user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _stockMovementIdMeta =
      const VerificationMeta('stockMovementId');
  @override
  late final GeneratedColumn<String> stockMovementId = GeneratedColumn<String>(
      'stock_movement_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _financialAccountIdMeta =
      const VerificationMeta('financialAccountId');
  @override
  late final GeneratedColumn<String> financialAccountId =
      GeneratedColumn<String>('financial_account_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _paymentMethodMeta =
      const VerificationMeta('paymentMethod');
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
      'payment_method', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _paymentModeMeta =
      const VerificationMeta('paymentMode');
  @override
  late final GeneratedColumn<String> paymentMode = GeneratedColumn<String>(
      'payment_mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _paidAmountQirshMeta =
      const VerificationMeta('paidAmountQirsh');
  @override
  late final GeneratedColumn<int> paidAmountQirsh = GeneratedColumn<int>(
      'paid_amount_qirsh', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _negativeBalanceApprovalIdMeta =
      const VerificationMeta('negativeBalanceApprovalId');
  @override
  late final GeneratedColumn<String> negativeBalanceApprovalId =
      GeneratedColumn<String>('negative_balance_approval_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _operationRequestIdMeta =
      const VerificationMeta('operationRequestId');
  @override
  late final GeneratedColumn<String> operationRequestId =
      GeneratedColumn<String>('operation_request_id', aliasedName, true,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _requestFingerprintMeta =
      const VerificationMeta('requestFingerprint');
  @override
  late final GeneratedColumn<String> requestFingerprint =
      GeneratedColumn<String>('request_fingerprint', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cancelledAtMeta =
      const VerificationMeta('cancelledAt');
  @override
  late final GeneratedColumn<DateTime> cancelledAt = GeneratedColumn<DateTime>(
      'cancelled_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _cancelledByUserIdMeta =
      const VerificationMeta('cancelledByUserId');
  @override
  late final GeneratedColumn<String> cancelledByUserId =
      GeneratedColumn<String>('cancelled_by_user_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cancellationReasonMeta =
      const VerificationMeta('cancellationReason');
  @override
  late final GeneratedColumn<String> cancellationReason =
      GeneratedColumn<String>('cancellation_reason', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _reversalMovementIdsMeta =
      const VerificationMeta('reversalMovementIds');
  @override
  late final GeneratedColumn<String> reversalMovementIds =
      GeneratedColumn<String>('reversal_movement_ids', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        supplierId,
        supplierName,
        supplierPhone,
        supplierAddress,
        productId,
        quantityKg,
        entryUnit,
        unitPricePiastersPerKg,
        totalAmountPiasters,
        createdByUserId,
        createdAt,
        stockMovementId,
        notes,
        financialAccountId,
        paymentMethod,
        paymentMode,
        paidAmountQirsh,
        negativeBalanceApprovalId,
        operationRequestId,
        requestFingerprint,
        cancelledAt,
        cancelledByUserId,
        cancellationReason,
        reversalMovementIds
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'purchases';
  @override
  VerificationContext validateIntegrity(Insertable<Purchase> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
          _supplierIdMeta,
          supplierId.isAcceptableOrUnknown(
              data['supplier_id']!, _supplierIdMeta));
    } else if (isInserting) {
      context.missing(_supplierIdMeta);
    }
    if (data.containsKey('supplier_name')) {
      context.handle(
          _supplierNameMeta,
          supplierName.isAcceptableOrUnknown(
              data['supplier_name']!, _supplierNameMeta));
    }
    if (data.containsKey('supplier_phone')) {
      context.handle(
          _supplierPhoneMeta,
          supplierPhone.isAcceptableOrUnknown(
              data['supplier_phone']!, _supplierPhoneMeta));
    }
    if (data.containsKey('supplier_address')) {
      context.handle(
          _supplierAddressMeta,
          supplierAddress.isAcceptableOrUnknown(
              data['supplier_address']!, _supplierAddressMeta));
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('quantity_kg')) {
      context.handle(
          _quantityKgMeta,
          quantityKg.isAcceptableOrUnknown(
              data['quantity_kg']!, _quantityKgMeta));
    } else if (isInserting) {
      context.missing(_quantityKgMeta);
    }
    if (data.containsKey('entry_unit')) {
      context.handle(_entryUnitMeta,
          entryUnit.isAcceptableOrUnknown(data['entry_unit']!, _entryUnitMeta));
    } else if (isInserting) {
      context.missing(_entryUnitMeta);
    }
    if (data.containsKey('unit_price_piasters_per_kg')) {
      context.handle(
          _unitPricePiastersPerKgMeta,
          unitPricePiastersPerKg.isAcceptableOrUnknown(
              data['unit_price_piasters_per_kg']!,
              _unitPricePiastersPerKgMeta));
    } else if (isInserting) {
      context.missing(_unitPricePiastersPerKgMeta);
    }
    if (data.containsKey('total_amount_piasters')) {
      context.handle(
          _totalAmountPiastersMeta,
          totalAmountPiasters.isAcceptableOrUnknown(
              data['total_amount_piasters']!, _totalAmountPiastersMeta));
    } else if (isInserting) {
      context.missing(_totalAmountPiastersMeta);
    }
    if (data.containsKey('created_by_user_id')) {
      context.handle(
          _createdByUserIdMeta,
          createdByUserId.isAcceptableOrUnknown(
              data['created_by_user_id']!, _createdByUserIdMeta));
    } else if (isInserting) {
      context.missing(_createdByUserIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('stock_movement_id')) {
      context.handle(
          _stockMovementIdMeta,
          stockMovementId.isAcceptableOrUnknown(
              data['stock_movement_id']!, _stockMovementIdMeta));
    } else if (isInserting) {
      context.missing(_stockMovementIdMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('financial_account_id')) {
      context.handle(
          _financialAccountIdMeta,
          financialAccountId.isAcceptableOrUnknown(
              data['financial_account_id']!, _financialAccountIdMeta));
    }
    if (data.containsKey('payment_method')) {
      context.handle(
          _paymentMethodMeta,
          paymentMethod.isAcceptableOrUnknown(
              data['payment_method']!, _paymentMethodMeta));
    }
    if (data.containsKey('payment_mode')) {
      context.handle(
          _paymentModeMeta,
          paymentMode.isAcceptableOrUnknown(
              data['payment_mode']!, _paymentModeMeta));
    } else if (isInserting) {
      context.missing(_paymentModeMeta);
    }
    if (data.containsKey('paid_amount_qirsh')) {
      context.handle(
          _paidAmountQirshMeta,
          paidAmountQirsh.isAcceptableOrUnknown(
              data['paid_amount_qirsh']!, _paidAmountQirshMeta));
    }
    if (data.containsKey('negative_balance_approval_id')) {
      context.handle(
          _negativeBalanceApprovalIdMeta,
          negativeBalanceApprovalId.isAcceptableOrUnknown(
              data['negative_balance_approval_id']!,
              _negativeBalanceApprovalIdMeta));
    }
    if (data.containsKey('operation_request_id')) {
      context.handle(
          _operationRequestIdMeta,
          operationRequestId.isAcceptableOrUnknown(
              data['operation_request_id']!, _operationRequestIdMeta));
    }
    if (data.containsKey('request_fingerprint')) {
      context.handle(
          _requestFingerprintMeta,
          requestFingerprint.isAcceptableOrUnknown(
              data['request_fingerprint']!, _requestFingerprintMeta));
    }
    if (data.containsKey('cancelled_at')) {
      context.handle(
          _cancelledAtMeta,
          cancelledAt.isAcceptableOrUnknown(
              data['cancelled_at']!, _cancelledAtMeta));
    }
    if (data.containsKey('cancelled_by_user_id')) {
      context.handle(
          _cancelledByUserIdMeta,
          cancelledByUserId.isAcceptableOrUnknown(
              data['cancelled_by_user_id']!, _cancelledByUserIdMeta));
    }
    if (data.containsKey('cancellation_reason')) {
      context.handle(
          _cancellationReasonMeta,
          cancellationReason.isAcceptableOrUnknown(
              data['cancellation_reason']!, _cancellationReasonMeta));
    }
    if (data.containsKey('reversal_movement_ids')) {
      context.handle(
          _reversalMovementIdsMeta,
          reversalMovementIds.isAcceptableOrUnknown(
              data['reversal_movement_ids']!, _reversalMovementIdsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Purchase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Purchase(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      supplierId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}supplier_id'])!,
      supplierName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}supplier_name']),
      supplierPhone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}supplier_phone']),
      supplierAddress: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}supplier_address']),
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      quantityKg: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity_kg'])!,
      entryUnit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entry_unit'])!,
      unitPricePiastersPerKg: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}unit_price_piasters_per_kg'])!,
      totalAmountPiasters: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}total_amount_piasters'])!,
      createdByUserId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}created_by_user_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      stockMovementId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}stock_movement_id'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      financialAccountId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}financial_account_id']),
      paymentMethod: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payment_method']),
      paymentMode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payment_mode'])!,
      paidAmountQirsh: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}paid_amount_qirsh']),
      negativeBalanceApprovalId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}negative_balance_approval_id']),
      operationRequestId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}operation_request_id']),
      requestFingerprint: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}request_fingerprint']),
      cancelledAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cancelled_at']),
      cancelledByUserId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cancelled_by_user_id']),
      cancellationReason: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cancellation_reason']),
      reversalMovementIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}reversal_movement_ids']),
    );
  }

  @override
  $PurchasesTable createAlias(String alias) {
    return $PurchasesTable(attachedDatabase, alias);
  }
}

class Purchase extends DataClass implements Insertable<Purchase> {
  final String id;
  final String supplierId;
  final String? supplierName;
  final String? supplierPhone;
  final String? supplierAddress;
  final String productId;
  final int quantityKg;
  final String entryUnit;
  final int unitPricePiastersPerKg;
  final int totalAmountPiasters;
  final String createdByUserId;
  final DateTime createdAt;
  final String stockMovementId;
  final String? notes;
  final String? financialAccountId;
  final String? paymentMethod;
  final String paymentMode;
  final int? paidAmountQirsh;
  final String? negativeBalanceApprovalId;
  final String? operationRequestId;
  final String? requestFingerprint;
  final DateTime? cancelledAt;
  final String? cancelledByUserId;
  final String? cancellationReason;
  final String? reversalMovementIds;
  const Purchase(
      {required this.id,
      required this.supplierId,
      this.supplierName,
      this.supplierPhone,
      this.supplierAddress,
      required this.productId,
      required this.quantityKg,
      required this.entryUnit,
      required this.unitPricePiastersPerKg,
      required this.totalAmountPiasters,
      required this.createdByUserId,
      required this.createdAt,
      required this.stockMovementId,
      this.notes,
      this.financialAccountId,
      this.paymentMethod,
      required this.paymentMode,
      this.paidAmountQirsh,
      this.negativeBalanceApprovalId,
      this.operationRequestId,
      this.requestFingerprint,
      this.cancelledAt,
      this.cancelledByUserId,
      this.cancellationReason,
      this.reversalMovementIds});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['supplier_id'] = Variable<String>(supplierId);
    if (!nullToAbsent || supplierName != null) {
      map['supplier_name'] = Variable<String>(supplierName);
    }
    if (!nullToAbsent || supplierPhone != null) {
      map['supplier_phone'] = Variable<String>(supplierPhone);
    }
    if (!nullToAbsent || supplierAddress != null) {
      map['supplier_address'] = Variable<String>(supplierAddress);
    }
    map['product_id'] = Variable<String>(productId);
    map['quantity_kg'] = Variable<int>(quantityKg);
    map['entry_unit'] = Variable<String>(entryUnit);
    map['unit_price_piasters_per_kg'] = Variable<int>(unitPricePiastersPerKg);
    map['total_amount_piasters'] = Variable<int>(totalAmountPiasters);
    map['created_by_user_id'] = Variable<String>(createdByUserId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['stock_movement_id'] = Variable<String>(stockMovementId);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || financialAccountId != null) {
      map['financial_account_id'] = Variable<String>(financialAccountId);
    }
    if (!nullToAbsent || paymentMethod != null) {
      map['payment_method'] = Variable<String>(paymentMethod);
    }
    map['payment_mode'] = Variable<String>(paymentMode);
    if (!nullToAbsent || paidAmountQirsh != null) {
      map['paid_amount_qirsh'] = Variable<int>(paidAmountQirsh);
    }
    if (!nullToAbsent || negativeBalanceApprovalId != null) {
      map['negative_balance_approval_id'] =
          Variable<String>(negativeBalanceApprovalId);
    }
    if (!nullToAbsent || operationRequestId != null) {
      map['operation_request_id'] = Variable<String>(operationRequestId);
    }
    if (!nullToAbsent || requestFingerprint != null) {
      map['request_fingerprint'] = Variable<String>(requestFingerprint);
    }
    if (!nullToAbsent || cancelledAt != null) {
      map['cancelled_at'] = Variable<DateTime>(cancelledAt);
    }
    if (!nullToAbsent || cancelledByUserId != null) {
      map['cancelled_by_user_id'] = Variable<String>(cancelledByUserId);
    }
    if (!nullToAbsent || cancellationReason != null) {
      map['cancellation_reason'] = Variable<String>(cancellationReason);
    }
    if (!nullToAbsent || reversalMovementIds != null) {
      map['reversal_movement_ids'] = Variable<String>(reversalMovementIds);
    }
    return map;
  }

  PurchasesCompanion toCompanion(bool nullToAbsent) {
    return PurchasesCompanion(
      id: Value(id),
      supplierId: Value(supplierId),
      supplierName: supplierName == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierName),
      supplierPhone: supplierPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierPhone),
      supplierAddress: supplierAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierAddress),
      productId: Value(productId),
      quantityKg: Value(quantityKg),
      entryUnit: Value(entryUnit),
      unitPricePiastersPerKg: Value(unitPricePiastersPerKg),
      totalAmountPiasters: Value(totalAmountPiasters),
      createdByUserId: Value(createdByUserId),
      createdAt: Value(createdAt),
      stockMovementId: Value(stockMovementId),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      financialAccountId: financialAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(financialAccountId),
      paymentMethod: paymentMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentMethod),
      paymentMode: Value(paymentMode),
      paidAmountQirsh: paidAmountQirsh == null && nullToAbsent
          ? const Value.absent()
          : Value(paidAmountQirsh),
      negativeBalanceApprovalId:
          negativeBalanceApprovalId == null && nullToAbsent
              ? const Value.absent()
              : Value(negativeBalanceApprovalId),
      operationRequestId: operationRequestId == null && nullToAbsent
          ? const Value.absent()
          : Value(operationRequestId),
      requestFingerprint: requestFingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(requestFingerprint),
      cancelledAt: cancelledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(cancelledAt),
      cancelledByUserId: cancelledByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(cancelledByUserId),
      cancellationReason: cancellationReason == null && nullToAbsent
          ? const Value.absent()
          : Value(cancellationReason),
      reversalMovementIds: reversalMovementIds == null && nullToAbsent
          ? const Value.absent()
          : Value(reversalMovementIds),
    );
  }

  factory Purchase.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Purchase(
      id: serializer.fromJson<String>(json['id']),
      supplierId: serializer.fromJson<String>(json['supplierId']),
      supplierName: serializer.fromJson<String?>(json['supplierName']),
      supplierPhone: serializer.fromJson<String?>(json['supplierPhone']),
      supplierAddress: serializer.fromJson<String?>(json['supplierAddress']),
      productId: serializer.fromJson<String>(json['productId']),
      quantityKg: serializer.fromJson<int>(json['quantityKg']),
      entryUnit: serializer.fromJson<String>(json['entryUnit']),
      unitPricePiastersPerKg:
          serializer.fromJson<int>(json['unitPricePiastersPerKg']),
      totalAmountPiasters:
          serializer.fromJson<int>(json['totalAmountPiasters']),
      createdByUserId: serializer.fromJson<String>(json['createdByUserId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      stockMovementId: serializer.fromJson<String>(json['stockMovementId']),
      notes: serializer.fromJson<String?>(json['notes']),
      financialAccountId:
          serializer.fromJson<String?>(json['financialAccountId']),
      paymentMethod: serializer.fromJson<String?>(json['paymentMethod']),
      paymentMode: serializer.fromJson<String>(json['paymentMode']),
      paidAmountQirsh: serializer.fromJson<int?>(json['paidAmountQirsh']),
      negativeBalanceApprovalId:
          serializer.fromJson<String?>(json['negativeBalanceApprovalId']),
      operationRequestId:
          serializer.fromJson<String?>(json['operationRequestId']),
      requestFingerprint:
          serializer.fromJson<String?>(json['requestFingerprint']),
      cancelledAt: serializer.fromJson<DateTime?>(json['cancelledAt']),
      cancelledByUserId:
          serializer.fromJson<String?>(json['cancelledByUserId']),
      cancellationReason:
          serializer.fromJson<String?>(json['cancellationReason']),
      reversalMovementIds:
          serializer.fromJson<String?>(json['reversalMovementIds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'supplierId': serializer.toJson<String>(supplierId),
      'supplierName': serializer.toJson<String?>(supplierName),
      'supplierPhone': serializer.toJson<String?>(supplierPhone),
      'supplierAddress': serializer.toJson<String?>(supplierAddress),
      'productId': serializer.toJson<String>(productId),
      'quantityKg': serializer.toJson<int>(quantityKg),
      'entryUnit': serializer.toJson<String>(entryUnit),
      'unitPricePiastersPerKg': serializer.toJson<int>(unitPricePiastersPerKg),
      'totalAmountPiasters': serializer.toJson<int>(totalAmountPiasters),
      'createdByUserId': serializer.toJson<String>(createdByUserId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'stockMovementId': serializer.toJson<String>(stockMovementId),
      'notes': serializer.toJson<String?>(notes),
      'financialAccountId': serializer.toJson<String?>(financialAccountId),
      'paymentMethod': serializer.toJson<String?>(paymentMethod),
      'paymentMode': serializer.toJson<String>(paymentMode),
      'paidAmountQirsh': serializer.toJson<int?>(paidAmountQirsh),
      'negativeBalanceApprovalId':
          serializer.toJson<String?>(negativeBalanceApprovalId),
      'operationRequestId': serializer.toJson<String?>(operationRequestId),
      'requestFingerprint': serializer.toJson<String?>(requestFingerprint),
      'cancelledAt': serializer.toJson<DateTime?>(cancelledAt),
      'cancelledByUserId': serializer.toJson<String?>(cancelledByUserId),
      'cancellationReason': serializer.toJson<String?>(cancellationReason),
      'reversalMovementIds': serializer.toJson<String?>(reversalMovementIds),
    };
  }

  Purchase copyWith(
          {String? id,
          String? supplierId,
          Value<String?> supplierName = const Value.absent(),
          Value<String?> supplierPhone = const Value.absent(),
          Value<String?> supplierAddress = const Value.absent(),
          String? productId,
          int? quantityKg,
          String? entryUnit,
          int? unitPricePiastersPerKg,
          int? totalAmountPiasters,
          String? createdByUserId,
          DateTime? createdAt,
          String? stockMovementId,
          Value<String?> notes = const Value.absent(),
          Value<String?> financialAccountId = const Value.absent(),
          Value<String?> paymentMethod = const Value.absent(),
          String? paymentMode,
          Value<int?> paidAmountQirsh = const Value.absent(),
          Value<String?> negativeBalanceApprovalId = const Value.absent(),
          Value<String?> operationRequestId = const Value.absent(),
          Value<String?> requestFingerprint = const Value.absent(),
          Value<DateTime?> cancelledAt = const Value.absent(),
          Value<String?> cancelledByUserId = const Value.absent(),
          Value<String?> cancellationReason = const Value.absent(),
          Value<String?> reversalMovementIds = const Value.absent()}) =>
      Purchase(
        id: id ?? this.id,
        supplierId: supplierId ?? this.supplierId,
        supplierName:
            supplierName.present ? supplierName.value : this.supplierName,
        supplierPhone:
            supplierPhone.present ? supplierPhone.value : this.supplierPhone,
        supplierAddress: supplierAddress.present
            ? supplierAddress.value
            : this.supplierAddress,
        productId: productId ?? this.productId,
        quantityKg: quantityKg ?? this.quantityKg,
        entryUnit: entryUnit ?? this.entryUnit,
        unitPricePiastersPerKg:
            unitPricePiastersPerKg ?? this.unitPricePiastersPerKg,
        totalAmountPiasters: totalAmountPiasters ?? this.totalAmountPiasters,
        createdByUserId: createdByUserId ?? this.createdByUserId,
        createdAt: createdAt ?? this.createdAt,
        stockMovementId: stockMovementId ?? this.stockMovementId,
        notes: notes.present ? notes.value : this.notes,
        financialAccountId: financialAccountId.present
            ? financialAccountId.value
            : this.financialAccountId,
        paymentMethod:
            paymentMethod.present ? paymentMethod.value : this.paymentMethod,
        paymentMode: paymentMode ?? this.paymentMode,
        paidAmountQirsh: paidAmountQirsh.present
            ? paidAmountQirsh.value
            : this.paidAmountQirsh,
        negativeBalanceApprovalId: negativeBalanceApprovalId.present
            ? negativeBalanceApprovalId.value
            : this.negativeBalanceApprovalId,
        operationRequestId: operationRequestId.present
            ? operationRequestId.value
            : this.operationRequestId,
        requestFingerprint: requestFingerprint.present
            ? requestFingerprint.value
            : this.requestFingerprint,
        cancelledAt: cancelledAt.present ? cancelledAt.value : this.cancelledAt,
        cancelledByUserId: cancelledByUserId.present
            ? cancelledByUserId.value
            : this.cancelledByUserId,
        cancellationReason: cancellationReason.present
            ? cancellationReason.value
            : this.cancellationReason,
        reversalMovementIds: reversalMovementIds.present
            ? reversalMovementIds.value
            : this.reversalMovementIds,
      );
  Purchase copyWithCompanion(PurchasesCompanion data) {
    return Purchase(
      id: data.id.present ? data.id.value : this.id,
      supplierId:
          data.supplierId.present ? data.supplierId.value : this.supplierId,
      supplierName: data.supplierName.present
          ? data.supplierName.value
          : this.supplierName,
      supplierPhone: data.supplierPhone.present
          ? data.supplierPhone.value
          : this.supplierPhone,
      supplierAddress: data.supplierAddress.present
          ? data.supplierAddress.value
          : this.supplierAddress,
      productId: data.productId.present ? data.productId.value : this.productId,
      quantityKg:
          data.quantityKg.present ? data.quantityKg.value : this.quantityKg,
      entryUnit: data.entryUnit.present ? data.entryUnit.value : this.entryUnit,
      unitPricePiastersPerKg: data.unitPricePiastersPerKg.present
          ? data.unitPricePiastersPerKg.value
          : this.unitPricePiastersPerKg,
      totalAmountPiasters: data.totalAmountPiasters.present
          ? data.totalAmountPiasters.value
          : this.totalAmountPiasters,
      createdByUserId: data.createdByUserId.present
          ? data.createdByUserId.value
          : this.createdByUserId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      stockMovementId: data.stockMovementId.present
          ? data.stockMovementId.value
          : this.stockMovementId,
      notes: data.notes.present ? data.notes.value : this.notes,
      financialAccountId: data.financialAccountId.present
          ? data.financialAccountId.value
          : this.financialAccountId,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      paymentMode:
          data.paymentMode.present ? data.paymentMode.value : this.paymentMode,
      paidAmountQirsh: data.paidAmountQirsh.present
          ? data.paidAmountQirsh.value
          : this.paidAmountQirsh,
      negativeBalanceApprovalId: data.negativeBalanceApprovalId.present
          ? data.negativeBalanceApprovalId.value
          : this.negativeBalanceApprovalId,
      operationRequestId: data.operationRequestId.present
          ? data.operationRequestId.value
          : this.operationRequestId,
      requestFingerprint: data.requestFingerprint.present
          ? data.requestFingerprint.value
          : this.requestFingerprint,
      cancelledAt:
          data.cancelledAt.present ? data.cancelledAt.value : this.cancelledAt,
      cancelledByUserId: data.cancelledByUserId.present
          ? data.cancelledByUserId.value
          : this.cancelledByUserId,
      cancellationReason: data.cancellationReason.present
          ? data.cancellationReason.value
          : this.cancellationReason,
      reversalMovementIds: data.reversalMovementIds.present
          ? data.reversalMovementIds.value
          : this.reversalMovementIds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Purchase(')
          ..write('id: $id, ')
          ..write('supplierId: $supplierId, ')
          ..write('supplierName: $supplierName, ')
          ..write('supplierPhone: $supplierPhone, ')
          ..write('supplierAddress: $supplierAddress, ')
          ..write('productId: $productId, ')
          ..write('quantityKg: $quantityKg, ')
          ..write('entryUnit: $entryUnit, ')
          ..write('unitPricePiastersPerKg: $unitPricePiastersPerKg, ')
          ..write('totalAmountPiasters: $totalAmountPiasters, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('createdAt: $createdAt, ')
          ..write('stockMovementId: $stockMovementId, ')
          ..write('notes: $notes, ')
          ..write('financialAccountId: $financialAccountId, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('paymentMode: $paymentMode, ')
          ..write('paidAmountQirsh: $paidAmountQirsh, ')
          ..write('negativeBalanceApprovalId: $negativeBalanceApprovalId, ')
          ..write('operationRequestId: $operationRequestId, ')
          ..write('requestFingerprint: $requestFingerprint, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('cancelledByUserId: $cancelledByUserId, ')
          ..write('cancellationReason: $cancellationReason, ')
          ..write('reversalMovementIds: $reversalMovementIds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        supplierId,
        supplierName,
        supplierPhone,
        supplierAddress,
        productId,
        quantityKg,
        entryUnit,
        unitPricePiastersPerKg,
        totalAmountPiasters,
        createdByUserId,
        createdAt,
        stockMovementId,
        notes,
        financialAccountId,
        paymentMethod,
        paymentMode,
        paidAmountQirsh,
        negativeBalanceApprovalId,
        operationRequestId,
        requestFingerprint,
        cancelledAt,
        cancelledByUserId,
        cancellationReason,
        reversalMovementIds
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Purchase &&
          other.id == this.id &&
          other.supplierId == this.supplierId &&
          other.supplierName == this.supplierName &&
          other.supplierPhone == this.supplierPhone &&
          other.supplierAddress == this.supplierAddress &&
          other.productId == this.productId &&
          other.quantityKg == this.quantityKg &&
          other.entryUnit == this.entryUnit &&
          other.unitPricePiastersPerKg == this.unitPricePiastersPerKg &&
          other.totalAmountPiasters == this.totalAmountPiasters &&
          other.createdByUserId == this.createdByUserId &&
          other.createdAt == this.createdAt &&
          other.stockMovementId == this.stockMovementId &&
          other.notes == this.notes &&
          other.financialAccountId == this.financialAccountId &&
          other.paymentMethod == this.paymentMethod &&
          other.paymentMode == this.paymentMode &&
          other.paidAmountQirsh == this.paidAmountQirsh &&
          other.negativeBalanceApprovalId == this.negativeBalanceApprovalId &&
          other.operationRequestId == this.operationRequestId &&
          other.requestFingerprint == this.requestFingerprint &&
          other.cancelledAt == this.cancelledAt &&
          other.cancelledByUserId == this.cancelledByUserId &&
          other.cancellationReason == this.cancellationReason &&
          other.reversalMovementIds == this.reversalMovementIds);
}

class PurchasesCompanion extends UpdateCompanion<Purchase> {
  final Value<String> id;
  final Value<String> supplierId;
  final Value<String?> supplierName;
  final Value<String?> supplierPhone;
  final Value<String?> supplierAddress;
  final Value<String> productId;
  final Value<int> quantityKg;
  final Value<String> entryUnit;
  final Value<int> unitPricePiastersPerKg;
  final Value<int> totalAmountPiasters;
  final Value<String> createdByUserId;
  final Value<DateTime> createdAt;
  final Value<String> stockMovementId;
  final Value<String?> notes;
  final Value<String?> financialAccountId;
  final Value<String?> paymentMethod;
  final Value<String> paymentMode;
  final Value<int?> paidAmountQirsh;
  final Value<String?> negativeBalanceApprovalId;
  final Value<String?> operationRequestId;
  final Value<String?> requestFingerprint;
  final Value<DateTime?> cancelledAt;
  final Value<String?> cancelledByUserId;
  final Value<String?> cancellationReason;
  final Value<String?> reversalMovementIds;
  final Value<int> rowid;
  const PurchasesCompanion({
    this.id = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.supplierName = const Value.absent(),
    this.supplierPhone = const Value.absent(),
    this.supplierAddress = const Value.absent(),
    this.productId = const Value.absent(),
    this.quantityKg = const Value.absent(),
    this.entryUnit = const Value.absent(),
    this.unitPricePiastersPerKg = const Value.absent(),
    this.totalAmountPiasters = const Value.absent(),
    this.createdByUserId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.stockMovementId = const Value.absent(),
    this.notes = const Value.absent(),
    this.financialAccountId = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.paymentMode = const Value.absent(),
    this.paidAmountQirsh = const Value.absent(),
    this.negativeBalanceApprovalId = const Value.absent(),
    this.operationRequestId = const Value.absent(),
    this.requestFingerprint = const Value.absent(),
    this.cancelledAt = const Value.absent(),
    this.cancelledByUserId = const Value.absent(),
    this.cancellationReason = const Value.absent(),
    this.reversalMovementIds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PurchasesCompanion.insert({
    required String id,
    required String supplierId,
    this.supplierName = const Value.absent(),
    this.supplierPhone = const Value.absent(),
    this.supplierAddress = const Value.absent(),
    required String productId,
    required int quantityKg,
    required String entryUnit,
    required int unitPricePiastersPerKg,
    required int totalAmountPiasters,
    required String createdByUserId,
    required DateTime createdAt,
    required String stockMovementId,
    this.notes = const Value.absent(),
    this.financialAccountId = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    required String paymentMode,
    this.paidAmountQirsh = const Value.absent(),
    this.negativeBalanceApprovalId = const Value.absent(),
    this.operationRequestId = const Value.absent(),
    this.requestFingerprint = const Value.absent(),
    this.cancelledAt = const Value.absent(),
    this.cancelledByUserId = const Value.absent(),
    this.cancellationReason = const Value.absent(),
    this.reversalMovementIds = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        supplierId = Value(supplierId),
        productId = Value(productId),
        quantityKg = Value(quantityKg),
        entryUnit = Value(entryUnit),
        unitPricePiastersPerKg = Value(unitPricePiastersPerKg),
        totalAmountPiasters = Value(totalAmountPiasters),
        createdByUserId = Value(createdByUserId),
        createdAt = Value(createdAt),
        stockMovementId = Value(stockMovementId),
        paymentMode = Value(paymentMode);
  static Insertable<Purchase> custom({
    Expression<String>? id,
    Expression<String>? supplierId,
    Expression<String>? supplierName,
    Expression<String>? supplierPhone,
    Expression<String>? supplierAddress,
    Expression<String>? productId,
    Expression<int>? quantityKg,
    Expression<String>? entryUnit,
    Expression<int>? unitPricePiastersPerKg,
    Expression<int>? totalAmountPiasters,
    Expression<String>? createdByUserId,
    Expression<DateTime>? createdAt,
    Expression<String>? stockMovementId,
    Expression<String>? notes,
    Expression<String>? financialAccountId,
    Expression<String>? paymentMethod,
    Expression<String>? paymentMode,
    Expression<int>? paidAmountQirsh,
    Expression<String>? negativeBalanceApprovalId,
    Expression<String>? operationRequestId,
    Expression<String>? requestFingerprint,
    Expression<DateTime>? cancelledAt,
    Expression<String>? cancelledByUserId,
    Expression<String>? cancellationReason,
    Expression<String>? reversalMovementIds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supplierId != null) 'supplier_id': supplierId,
      if (supplierName != null) 'supplier_name': supplierName,
      if (supplierPhone != null) 'supplier_phone': supplierPhone,
      if (supplierAddress != null) 'supplier_address': supplierAddress,
      if (productId != null) 'product_id': productId,
      if (quantityKg != null) 'quantity_kg': quantityKg,
      if (entryUnit != null) 'entry_unit': entryUnit,
      if (unitPricePiastersPerKg != null)
        'unit_price_piasters_per_kg': unitPricePiastersPerKg,
      if (totalAmountPiasters != null)
        'total_amount_piasters': totalAmountPiasters,
      if (createdByUserId != null) 'created_by_user_id': createdByUserId,
      if (createdAt != null) 'created_at': createdAt,
      if (stockMovementId != null) 'stock_movement_id': stockMovementId,
      if (notes != null) 'notes': notes,
      if (financialAccountId != null)
        'financial_account_id': financialAccountId,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (paymentMode != null) 'payment_mode': paymentMode,
      if (paidAmountQirsh != null) 'paid_amount_qirsh': paidAmountQirsh,
      if (negativeBalanceApprovalId != null)
        'negative_balance_approval_id': negativeBalanceApprovalId,
      if (operationRequestId != null)
        'operation_request_id': operationRequestId,
      if (requestFingerprint != null) 'request_fingerprint': requestFingerprint,
      if (cancelledAt != null) 'cancelled_at': cancelledAt,
      if (cancelledByUserId != null) 'cancelled_by_user_id': cancelledByUserId,
      if (cancellationReason != null) 'cancellation_reason': cancellationReason,
      if (reversalMovementIds != null)
        'reversal_movement_ids': reversalMovementIds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PurchasesCompanion copyWith(
      {Value<String>? id,
      Value<String>? supplierId,
      Value<String?>? supplierName,
      Value<String?>? supplierPhone,
      Value<String?>? supplierAddress,
      Value<String>? productId,
      Value<int>? quantityKg,
      Value<String>? entryUnit,
      Value<int>? unitPricePiastersPerKg,
      Value<int>? totalAmountPiasters,
      Value<String>? createdByUserId,
      Value<DateTime>? createdAt,
      Value<String>? stockMovementId,
      Value<String?>? notes,
      Value<String?>? financialAccountId,
      Value<String?>? paymentMethod,
      Value<String>? paymentMode,
      Value<int?>? paidAmountQirsh,
      Value<String?>? negativeBalanceApprovalId,
      Value<String?>? operationRequestId,
      Value<String?>? requestFingerprint,
      Value<DateTime?>? cancelledAt,
      Value<String?>? cancelledByUserId,
      Value<String?>? cancellationReason,
      Value<String?>? reversalMovementIds,
      Value<int>? rowid}) {
    return PurchasesCompanion(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      supplierPhone: supplierPhone ?? this.supplierPhone,
      supplierAddress: supplierAddress ?? this.supplierAddress,
      productId: productId ?? this.productId,
      quantityKg: quantityKg ?? this.quantityKg,
      entryUnit: entryUnit ?? this.entryUnit,
      unitPricePiastersPerKg:
          unitPricePiastersPerKg ?? this.unitPricePiastersPerKg,
      totalAmountPiasters: totalAmountPiasters ?? this.totalAmountPiasters,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdAt: createdAt ?? this.createdAt,
      stockMovementId: stockMovementId ?? this.stockMovementId,
      notes: notes ?? this.notes,
      financialAccountId: financialAccountId ?? this.financialAccountId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentMode: paymentMode ?? this.paymentMode,
      paidAmountQirsh: paidAmountQirsh ?? this.paidAmountQirsh,
      negativeBalanceApprovalId:
          negativeBalanceApprovalId ?? this.negativeBalanceApprovalId,
      operationRequestId: operationRequestId ?? this.operationRequestId,
      requestFingerprint: requestFingerprint ?? this.requestFingerprint,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledByUserId: cancelledByUserId ?? this.cancelledByUserId,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      reversalMovementIds: reversalMovementIds ?? this.reversalMovementIds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (supplierName.present) {
      map['supplier_name'] = Variable<String>(supplierName.value);
    }
    if (supplierPhone.present) {
      map['supplier_phone'] = Variable<String>(supplierPhone.value);
    }
    if (supplierAddress.present) {
      map['supplier_address'] = Variable<String>(supplierAddress.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (quantityKg.present) {
      map['quantity_kg'] = Variable<int>(quantityKg.value);
    }
    if (entryUnit.present) {
      map['entry_unit'] = Variable<String>(entryUnit.value);
    }
    if (unitPricePiastersPerKg.present) {
      map['unit_price_piasters_per_kg'] =
          Variable<int>(unitPricePiastersPerKg.value);
    }
    if (totalAmountPiasters.present) {
      map['total_amount_piasters'] = Variable<int>(totalAmountPiasters.value);
    }
    if (createdByUserId.present) {
      map['created_by_user_id'] = Variable<String>(createdByUserId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (stockMovementId.present) {
      map['stock_movement_id'] = Variable<String>(stockMovementId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (financialAccountId.present) {
      map['financial_account_id'] = Variable<String>(financialAccountId.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (paymentMode.present) {
      map['payment_mode'] = Variable<String>(paymentMode.value);
    }
    if (paidAmountQirsh.present) {
      map['paid_amount_qirsh'] = Variable<int>(paidAmountQirsh.value);
    }
    if (negativeBalanceApprovalId.present) {
      map['negative_balance_approval_id'] =
          Variable<String>(negativeBalanceApprovalId.value);
    }
    if (operationRequestId.present) {
      map['operation_request_id'] = Variable<String>(operationRequestId.value);
    }
    if (requestFingerprint.present) {
      map['request_fingerprint'] = Variable<String>(requestFingerprint.value);
    }
    if (cancelledAt.present) {
      map['cancelled_at'] = Variable<DateTime>(cancelledAt.value);
    }
    if (cancelledByUserId.present) {
      map['cancelled_by_user_id'] = Variable<String>(cancelledByUserId.value);
    }
    if (cancellationReason.present) {
      map['cancellation_reason'] = Variable<String>(cancellationReason.value);
    }
    if (reversalMovementIds.present) {
      map['reversal_movement_ids'] =
          Variable<String>(reversalMovementIds.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PurchasesCompanion(')
          ..write('id: $id, ')
          ..write('supplierId: $supplierId, ')
          ..write('supplierName: $supplierName, ')
          ..write('supplierPhone: $supplierPhone, ')
          ..write('supplierAddress: $supplierAddress, ')
          ..write('productId: $productId, ')
          ..write('quantityKg: $quantityKg, ')
          ..write('entryUnit: $entryUnit, ')
          ..write('unitPricePiastersPerKg: $unitPricePiastersPerKg, ')
          ..write('totalAmountPiasters: $totalAmountPiasters, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('createdAt: $createdAt, ')
          ..write('stockMovementId: $stockMovementId, ')
          ..write('notes: $notes, ')
          ..write('financialAccountId: $financialAccountId, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('paymentMode: $paymentMode, ')
          ..write('paidAmountQirsh: $paidAmountQirsh, ')
          ..write('negativeBalanceApprovalId: $negativeBalanceApprovalId, ')
          ..write('operationRequestId: $operationRequestId, ')
          ..write('requestFingerprint: $requestFingerprint, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('cancelledByUserId: $cancelledByUserId, ')
          ..write('cancellationReason: $cancellationReason, ')
          ..write('reversalMovementIds: $reversalMovementIds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SalesTable extends Sales with TableInfo<$SalesTable, Sale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityKgMeta =
      const VerificationMeta('quantityKg');
  @override
  late final GeneratedColumn<int> quantityKg = GeneratedColumn<int>(
      'quantity_kg', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _salePriceQirshPerKgMeta =
      const VerificationMeta('salePriceQirshPerKg');
  @override
  late final GeneratedColumn<int> salePriceQirshPerKg = GeneratedColumn<int>(
      'sale_price_qirsh_per_kg', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _totalQirshMeta =
      const VerificationMeta('totalQirsh');
  @override
  late final GeneratedColumn<int> totalQirsh = GeneratedColumn<int>(
      'total_qirsh', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdByUserIdMeta =
      const VerificationMeta('createdByUserId');
  @override
  late final GeneratedColumn<String> createdByUserId = GeneratedColumn<String>(
      'created_by_user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdByUserNameMeta =
      const VerificationMeta('createdByUserName');
  @override
  late final GeneratedColumn<String> createdByUserName =
      GeneratedColumn<String>('created_by_user_name', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _stockMovementIdMeta =
      const VerificationMeta('stockMovementId');
  @override
  late final GeneratedColumn<String> stockMovementId = GeneratedColumn<String>(
      'stock_movement_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _paymentModeMeta =
      const VerificationMeta('paymentMode');
  @override
  late final GeneratedColumn<String> paymentMode = GeneratedColumn<String>(
      'payment_mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _customerIdMeta =
      const VerificationMeta('customerId');
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
      'customer_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _itemsJsonMeta =
      const VerificationMeta('itemsJson');
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
      'items_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _paidAmountQirshMeta =
      const VerificationMeta('paidAmountQirsh');
  @override
  late final GeneratedColumn<int> paidAmountQirsh = GeneratedColumn<int>(
      'paid_amount_qirsh', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _financialAccountIdMeta =
      const VerificationMeta('financialAccountId');
  @override
  late final GeneratedColumn<String> financialAccountId =
      GeneratedColumn<String>('financial_account_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _paymentMethodMeta =
      const VerificationMeta('paymentMethod');
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
      'payment_method', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _paymentAllocationsJsonMeta =
      const VerificationMeta('paymentAllocationsJson');
  @override
  late final GeneratedColumn<String> paymentAllocationsJson =
      GeneratedColumn<String>('payment_allocations_json', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationRequestIdMeta =
      const VerificationMeta('operationRequestId');
  @override
  late final GeneratedColumn<String> operationRequestId =
      GeneratedColumn<String>('operation_request_id', aliasedName, true,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _cancelledAtMeta =
      const VerificationMeta('cancelledAt');
  @override
  late final GeneratedColumn<DateTime> cancelledAt = GeneratedColumn<DateTime>(
      'cancelled_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _cancelledByUserIdMeta =
      const VerificationMeta('cancelledByUserId');
  @override
  late final GeneratedColumn<String> cancelledByUserId =
      GeneratedColumn<String>('cancelled_by_user_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cancellationReasonMeta =
      const VerificationMeta('cancellationReason');
  @override
  late final GeneratedColumn<String> cancellationReason =
      GeneratedColumn<String>('cancellation_reason', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _reversalMovementIdsJsonMeta =
      const VerificationMeta('reversalMovementIdsJson');
  @override
  late final GeneratedColumn<String> reversalMovementIdsJson =
      GeneratedColumn<String>('reversal_movement_ids_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        productId,
        quantityKg,
        salePriceQirshPerKg,
        totalQirsh,
        createdByUserId,
        createdByUserName,
        createdAt,
        stockMovementId,
        paymentMode,
        customerId,
        notes,
        itemsJson,
        paidAmountQirsh,
        financialAccountId,
        paymentMethod,
        paymentAllocationsJson,
        operationRequestId,
        cancelledAt,
        cancelledByUserId,
        cancellationReason,
        reversalMovementIdsJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sales';
  @override
  VerificationContext validateIntegrity(Insertable<Sale> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('quantity_kg')) {
      context.handle(
          _quantityKgMeta,
          quantityKg.isAcceptableOrUnknown(
              data['quantity_kg']!, _quantityKgMeta));
    } else if (isInserting) {
      context.missing(_quantityKgMeta);
    }
    if (data.containsKey('sale_price_qirsh_per_kg')) {
      context.handle(
          _salePriceQirshPerKgMeta,
          salePriceQirshPerKg.isAcceptableOrUnknown(
              data['sale_price_qirsh_per_kg']!, _salePriceQirshPerKgMeta));
    } else if (isInserting) {
      context.missing(_salePriceQirshPerKgMeta);
    }
    if (data.containsKey('total_qirsh')) {
      context.handle(
          _totalQirshMeta,
          totalQirsh.isAcceptableOrUnknown(
              data['total_qirsh']!, _totalQirshMeta));
    } else if (isInserting) {
      context.missing(_totalQirshMeta);
    }
    if (data.containsKey('created_by_user_id')) {
      context.handle(
          _createdByUserIdMeta,
          createdByUserId.isAcceptableOrUnknown(
              data['created_by_user_id']!, _createdByUserIdMeta));
    } else if (isInserting) {
      context.missing(_createdByUserIdMeta);
    }
    if (data.containsKey('created_by_user_name')) {
      context.handle(
          _createdByUserNameMeta,
          createdByUserName.isAcceptableOrUnknown(
              data['created_by_user_name']!, _createdByUserNameMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('stock_movement_id')) {
      context.handle(
          _stockMovementIdMeta,
          stockMovementId.isAcceptableOrUnknown(
              data['stock_movement_id']!, _stockMovementIdMeta));
    } else if (isInserting) {
      context.missing(_stockMovementIdMeta);
    }
    if (data.containsKey('payment_mode')) {
      context.handle(
          _paymentModeMeta,
          paymentMode.isAcceptableOrUnknown(
              data['payment_mode']!, _paymentModeMeta));
    } else if (isInserting) {
      context.missing(_paymentModeMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
          _customerIdMeta,
          customerId.isAcceptableOrUnknown(
              data['customer_id']!, _customerIdMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('items_json')) {
      context.handle(_itemsJsonMeta,
          itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta));
    } else if (isInserting) {
      context.missing(_itemsJsonMeta);
    }
    if (data.containsKey('paid_amount_qirsh')) {
      context.handle(
          _paidAmountQirshMeta,
          paidAmountQirsh.isAcceptableOrUnknown(
              data['paid_amount_qirsh']!, _paidAmountQirshMeta));
    }
    if (data.containsKey('financial_account_id')) {
      context.handle(
          _financialAccountIdMeta,
          financialAccountId.isAcceptableOrUnknown(
              data['financial_account_id']!, _financialAccountIdMeta));
    }
    if (data.containsKey('payment_method')) {
      context.handle(
          _paymentMethodMeta,
          paymentMethod.isAcceptableOrUnknown(
              data['payment_method']!, _paymentMethodMeta));
    }
    if (data.containsKey('payment_allocations_json')) {
      context.handle(
          _paymentAllocationsJsonMeta,
          paymentAllocationsJson.isAcceptableOrUnknown(
              data['payment_allocations_json']!, _paymentAllocationsJsonMeta));
    } else if (isInserting) {
      context.missing(_paymentAllocationsJsonMeta);
    }
    if (data.containsKey('operation_request_id')) {
      context.handle(
          _operationRequestIdMeta,
          operationRequestId.isAcceptableOrUnknown(
              data['operation_request_id']!, _operationRequestIdMeta));
    }
    if (data.containsKey('cancelled_at')) {
      context.handle(
          _cancelledAtMeta,
          cancelledAt.isAcceptableOrUnknown(
              data['cancelled_at']!, _cancelledAtMeta));
    }
    if (data.containsKey('cancelled_by_user_id')) {
      context.handle(
          _cancelledByUserIdMeta,
          cancelledByUserId.isAcceptableOrUnknown(
              data['cancelled_by_user_id']!, _cancelledByUserIdMeta));
    }
    if (data.containsKey('cancellation_reason')) {
      context.handle(
          _cancellationReasonMeta,
          cancellationReason.isAcceptableOrUnknown(
              data['cancellation_reason']!, _cancellationReasonMeta));
    }
    if (data.containsKey('reversal_movement_ids_json')) {
      context.handle(
          _reversalMovementIdsJsonMeta,
          reversalMovementIdsJson.isAcceptableOrUnknown(
              data['reversal_movement_ids_json']!,
              _reversalMovementIdsJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sale(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      quantityKg: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity_kg'])!,
      salePriceQirshPerKg: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}sale_price_qirsh_per_kg'])!,
      totalQirsh: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_qirsh'])!,
      createdByUserId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}created_by_user_id'])!,
      createdByUserName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}created_by_user_name']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      stockMovementId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}stock_movement_id'])!,
      paymentMode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payment_mode'])!,
      customerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer_id']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      itemsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}items_json'])!,
      paidAmountQirsh: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}paid_amount_qirsh']),
      financialAccountId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}financial_account_id']),
      paymentMethod: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payment_method']),
      paymentAllocationsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}payment_allocations_json'])!,
      operationRequestId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}operation_request_id']),
      cancelledAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cancelled_at']),
      cancelledByUserId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cancelled_by_user_id']),
      cancellationReason: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cancellation_reason']),
      reversalMovementIdsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}reversal_movement_ids_json']),
    );
  }

  @override
  $SalesTable createAlias(String alias) {
    return $SalesTable(attachedDatabase, alias);
  }
}

class Sale extends DataClass implements Insertable<Sale> {
  final String id;
  final String productId;
  final int quantityKg;
  final int salePriceQirshPerKg;
  final int totalQirsh;
  final String createdByUserId;
  final String? createdByUserName;
  final DateTime createdAt;
  final String stockMovementId;
  final String paymentMode;
  final String? customerId;
  final String? notes;
  final String itemsJson;
  final int? paidAmountQirsh;
  final String? financialAccountId;
  final String? paymentMethod;
  final String paymentAllocationsJson;
  final String? operationRequestId;
  final DateTime? cancelledAt;
  final String? cancelledByUserId;
  final String? cancellationReason;
  final String? reversalMovementIdsJson;
  const Sale(
      {required this.id,
      required this.productId,
      required this.quantityKg,
      required this.salePriceQirshPerKg,
      required this.totalQirsh,
      required this.createdByUserId,
      this.createdByUserName,
      required this.createdAt,
      required this.stockMovementId,
      required this.paymentMode,
      this.customerId,
      this.notes,
      required this.itemsJson,
      this.paidAmountQirsh,
      this.financialAccountId,
      this.paymentMethod,
      required this.paymentAllocationsJson,
      this.operationRequestId,
      this.cancelledAt,
      this.cancelledByUserId,
      this.cancellationReason,
      this.reversalMovementIdsJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['quantity_kg'] = Variable<int>(quantityKg);
    map['sale_price_qirsh_per_kg'] = Variable<int>(salePriceQirshPerKg);
    map['total_qirsh'] = Variable<int>(totalQirsh);
    map['created_by_user_id'] = Variable<String>(createdByUserId);
    if (!nullToAbsent || createdByUserName != null) {
      map['created_by_user_name'] = Variable<String>(createdByUserName);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['stock_movement_id'] = Variable<String>(stockMovementId);
    map['payment_mode'] = Variable<String>(paymentMode);
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['items_json'] = Variable<String>(itemsJson);
    if (!nullToAbsent || paidAmountQirsh != null) {
      map['paid_amount_qirsh'] = Variable<int>(paidAmountQirsh);
    }
    if (!nullToAbsent || financialAccountId != null) {
      map['financial_account_id'] = Variable<String>(financialAccountId);
    }
    if (!nullToAbsent || paymentMethod != null) {
      map['payment_method'] = Variable<String>(paymentMethod);
    }
    map['payment_allocations_json'] = Variable<String>(paymentAllocationsJson);
    if (!nullToAbsent || operationRequestId != null) {
      map['operation_request_id'] = Variable<String>(operationRequestId);
    }
    if (!nullToAbsent || cancelledAt != null) {
      map['cancelled_at'] = Variable<DateTime>(cancelledAt);
    }
    if (!nullToAbsent || cancelledByUserId != null) {
      map['cancelled_by_user_id'] = Variable<String>(cancelledByUserId);
    }
    if (!nullToAbsent || cancellationReason != null) {
      map['cancellation_reason'] = Variable<String>(cancellationReason);
    }
    if (!nullToAbsent || reversalMovementIdsJson != null) {
      map['reversal_movement_ids_json'] =
          Variable<String>(reversalMovementIdsJson);
    }
    return map;
  }

  SalesCompanion toCompanion(bool nullToAbsent) {
    return SalesCompanion(
      id: Value(id),
      productId: Value(productId),
      quantityKg: Value(quantityKg),
      salePriceQirshPerKg: Value(salePriceQirshPerKg),
      totalQirsh: Value(totalQirsh),
      createdByUserId: Value(createdByUserId),
      createdByUserName: createdByUserName == null && nullToAbsent
          ? const Value.absent()
          : Value(createdByUserName),
      createdAt: Value(createdAt),
      stockMovementId: Value(stockMovementId),
      paymentMode: Value(paymentMode),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      itemsJson: Value(itemsJson),
      paidAmountQirsh: paidAmountQirsh == null && nullToAbsent
          ? const Value.absent()
          : Value(paidAmountQirsh),
      financialAccountId: financialAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(financialAccountId),
      paymentMethod: paymentMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentMethod),
      paymentAllocationsJson: Value(paymentAllocationsJson),
      operationRequestId: operationRequestId == null && nullToAbsent
          ? const Value.absent()
          : Value(operationRequestId),
      cancelledAt: cancelledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(cancelledAt),
      cancelledByUserId: cancelledByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(cancelledByUserId),
      cancellationReason: cancellationReason == null && nullToAbsent
          ? const Value.absent()
          : Value(cancellationReason),
      reversalMovementIdsJson: reversalMovementIdsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(reversalMovementIdsJson),
    );
  }

  factory Sale.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sale(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      quantityKg: serializer.fromJson<int>(json['quantityKg']),
      salePriceQirshPerKg:
          serializer.fromJson<int>(json['salePriceQirshPerKg']),
      totalQirsh: serializer.fromJson<int>(json['totalQirsh']),
      createdByUserId: serializer.fromJson<String>(json['createdByUserId']),
      createdByUserName:
          serializer.fromJson<String?>(json['createdByUserName']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      stockMovementId: serializer.fromJson<String>(json['stockMovementId']),
      paymentMode: serializer.fromJson<String>(json['paymentMode']),
      customerId: serializer.fromJson<String?>(json['customerId']),
      notes: serializer.fromJson<String?>(json['notes']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      paidAmountQirsh: serializer.fromJson<int?>(json['paidAmountQirsh']),
      financialAccountId:
          serializer.fromJson<String?>(json['financialAccountId']),
      paymentMethod: serializer.fromJson<String?>(json['paymentMethod']),
      paymentAllocationsJson:
          serializer.fromJson<String>(json['paymentAllocationsJson']),
      operationRequestId:
          serializer.fromJson<String?>(json['operationRequestId']),
      cancelledAt: serializer.fromJson<DateTime?>(json['cancelledAt']),
      cancelledByUserId:
          serializer.fromJson<String?>(json['cancelledByUserId']),
      cancellationReason:
          serializer.fromJson<String?>(json['cancellationReason']),
      reversalMovementIdsJson:
          serializer.fromJson<String?>(json['reversalMovementIdsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'quantityKg': serializer.toJson<int>(quantityKg),
      'salePriceQirshPerKg': serializer.toJson<int>(salePriceQirshPerKg),
      'totalQirsh': serializer.toJson<int>(totalQirsh),
      'createdByUserId': serializer.toJson<String>(createdByUserId),
      'createdByUserName': serializer.toJson<String?>(createdByUserName),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'stockMovementId': serializer.toJson<String>(stockMovementId),
      'paymentMode': serializer.toJson<String>(paymentMode),
      'customerId': serializer.toJson<String?>(customerId),
      'notes': serializer.toJson<String?>(notes),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'paidAmountQirsh': serializer.toJson<int?>(paidAmountQirsh),
      'financialAccountId': serializer.toJson<String?>(financialAccountId),
      'paymentMethod': serializer.toJson<String?>(paymentMethod),
      'paymentAllocationsJson':
          serializer.toJson<String>(paymentAllocationsJson),
      'operationRequestId': serializer.toJson<String?>(operationRequestId),
      'cancelledAt': serializer.toJson<DateTime?>(cancelledAt),
      'cancelledByUserId': serializer.toJson<String?>(cancelledByUserId),
      'cancellationReason': serializer.toJson<String?>(cancellationReason),
      'reversalMovementIdsJson':
          serializer.toJson<String?>(reversalMovementIdsJson),
    };
  }

  Sale copyWith(
          {String? id,
          String? productId,
          int? quantityKg,
          int? salePriceQirshPerKg,
          int? totalQirsh,
          String? createdByUserId,
          Value<String?> createdByUserName = const Value.absent(),
          DateTime? createdAt,
          String? stockMovementId,
          String? paymentMode,
          Value<String?> customerId = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          String? itemsJson,
          Value<int?> paidAmountQirsh = const Value.absent(),
          Value<String?> financialAccountId = const Value.absent(),
          Value<String?> paymentMethod = const Value.absent(),
          String? paymentAllocationsJson,
          Value<String?> operationRequestId = const Value.absent(),
          Value<DateTime?> cancelledAt = const Value.absent(),
          Value<String?> cancelledByUserId = const Value.absent(),
          Value<String?> cancellationReason = const Value.absent(),
          Value<String?> reversalMovementIdsJson = const Value.absent()}) =>
      Sale(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        quantityKg: quantityKg ?? this.quantityKg,
        salePriceQirshPerKg: salePriceQirshPerKg ?? this.salePriceQirshPerKg,
        totalQirsh: totalQirsh ?? this.totalQirsh,
        createdByUserId: createdByUserId ?? this.createdByUserId,
        createdByUserName: createdByUserName.present
            ? createdByUserName.value
            : this.createdByUserName,
        createdAt: createdAt ?? this.createdAt,
        stockMovementId: stockMovementId ?? this.stockMovementId,
        paymentMode: paymentMode ?? this.paymentMode,
        customerId: customerId.present ? customerId.value : this.customerId,
        notes: notes.present ? notes.value : this.notes,
        itemsJson: itemsJson ?? this.itemsJson,
        paidAmountQirsh: paidAmountQirsh.present
            ? paidAmountQirsh.value
            : this.paidAmountQirsh,
        financialAccountId: financialAccountId.present
            ? financialAccountId.value
            : this.financialAccountId,
        paymentMethod:
            paymentMethod.present ? paymentMethod.value : this.paymentMethod,
        paymentAllocationsJson:
            paymentAllocationsJson ?? this.paymentAllocationsJson,
        operationRequestId: operationRequestId.present
            ? operationRequestId.value
            : this.operationRequestId,
        cancelledAt: cancelledAt.present ? cancelledAt.value : this.cancelledAt,
        cancelledByUserId: cancelledByUserId.present
            ? cancelledByUserId.value
            : this.cancelledByUserId,
        cancellationReason: cancellationReason.present
            ? cancellationReason.value
            : this.cancellationReason,
        reversalMovementIdsJson: reversalMovementIdsJson.present
            ? reversalMovementIdsJson.value
            : this.reversalMovementIdsJson,
      );
  Sale copyWithCompanion(SalesCompanion data) {
    return Sale(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      quantityKg:
          data.quantityKg.present ? data.quantityKg.value : this.quantityKg,
      salePriceQirshPerKg: data.salePriceQirshPerKg.present
          ? data.salePriceQirshPerKg.value
          : this.salePriceQirshPerKg,
      totalQirsh:
          data.totalQirsh.present ? data.totalQirsh.value : this.totalQirsh,
      createdByUserId: data.createdByUserId.present
          ? data.createdByUserId.value
          : this.createdByUserId,
      createdByUserName: data.createdByUserName.present
          ? data.createdByUserName.value
          : this.createdByUserName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      stockMovementId: data.stockMovementId.present
          ? data.stockMovementId.value
          : this.stockMovementId,
      paymentMode:
          data.paymentMode.present ? data.paymentMode.value : this.paymentMode,
      customerId:
          data.customerId.present ? data.customerId.value : this.customerId,
      notes: data.notes.present ? data.notes.value : this.notes,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      paidAmountQirsh: data.paidAmountQirsh.present
          ? data.paidAmountQirsh.value
          : this.paidAmountQirsh,
      financialAccountId: data.financialAccountId.present
          ? data.financialAccountId.value
          : this.financialAccountId,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      paymentAllocationsJson: data.paymentAllocationsJson.present
          ? data.paymentAllocationsJson.value
          : this.paymentAllocationsJson,
      operationRequestId: data.operationRequestId.present
          ? data.operationRequestId.value
          : this.operationRequestId,
      cancelledAt:
          data.cancelledAt.present ? data.cancelledAt.value : this.cancelledAt,
      cancelledByUserId: data.cancelledByUserId.present
          ? data.cancelledByUserId.value
          : this.cancelledByUserId,
      cancellationReason: data.cancellationReason.present
          ? data.cancellationReason.value
          : this.cancellationReason,
      reversalMovementIdsJson: data.reversalMovementIdsJson.present
          ? data.reversalMovementIdsJson.value
          : this.reversalMovementIdsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sale(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('quantityKg: $quantityKg, ')
          ..write('salePriceQirshPerKg: $salePriceQirshPerKg, ')
          ..write('totalQirsh: $totalQirsh, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('createdByUserName: $createdByUserName, ')
          ..write('createdAt: $createdAt, ')
          ..write('stockMovementId: $stockMovementId, ')
          ..write('paymentMode: $paymentMode, ')
          ..write('customerId: $customerId, ')
          ..write('notes: $notes, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('paidAmountQirsh: $paidAmountQirsh, ')
          ..write('financialAccountId: $financialAccountId, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('paymentAllocationsJson: $paymentAllocationsJson, ')
          ..write('operationRequestId: $operationRequestId, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('cancelledByUserId: $cancelledByUserId, ')
          ..write('cancellationReason: $cancellationReason, ')
          ..write('reversalMovementIdsJson: $reversalMovementIdsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        productId,
        quantityKg,
        salePriceQirshPerKg,
        totalQirsh,
        createdByUserId,
        createdByUserName,
        createdAt,
        stockMovementId,
        paymentMode,
        customerId,
        notes,
        itemsJson,
        paidAmountQirsh,
        financialAccountId,
        paymentMethod,
        paymentAllocationsJson,
        operationRequestId,
        cancelledAt,
        cancelledByUserId,
        cancellationReason,
        reversalMovementIdsJson
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sale &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.quantityKg == this.quantityKg &&
          other.salePriceQirshPerKg == this.salePriceQirshPerKg &&
          other.totalQirsh == this.totalQirsh &&
          other.createdByUserId == this.createdByUserId &&
          other.createdByUserName == this.createdByUserName &&
          other.createdAt == this.createdAt &&
          other.stockMovementId == this.stockMovementId &&
          other.paymentMode == this.paymentMode &&
          other.customerId == this.customerId &&
          other.notes == this.notes &&
          other.itemsJson == this.itemsJson &&
          other.paidAmountQirsh == this.paidAmountQirsh &&
          other.financialAccountId == this.financialAccountId &&
          other.paymentMethod == this.paymentMethod &&
          other.paymentAllocationsJson == this.paymentAllocationsJson &&
          other.operationRequestId == this.operationRequestId &&
          other.cancelledAt == this.cancelledAt &&
          other.cancelledByUserId == this.cancelledByUserId &&
          other.cancellationReason == this.cancellationReason &&
          other.reversalMovementIdsJson == this.reversalMovementIdsJson);
}

class SalesCompanion extends UpdateCompanion<Sale> {
  final Value<String> id;
  final Value<String> productId;
  final Value<int> quantityKg;
  final Value<int> salePriceQirshPerKg;
  final Value<int> totalQirsh;
  final Value<String> createdByUserId;
  final Value<String?> createdByUserName;
  final Value<DateTime> createdAt;
  final Value<String> stockMovementId;
  final Value<String> paymentMode;
  final Value<String?> customerId;
  final Value<String?> notes;
  final Value<String> itemsJson;
  final Value<int?> paidAmountQirsh;
  final Value<String?> financialAccountId;
  final Value<String?> paymentMethod;
  final Value<String> paymentAllocationsJson;
  final Value<String?> operationRequestId;
  final Value<DateTime?> cancelledAt;
  final Value<String?> cancelledByUserId;
  final Value<String?> cancellationReason;
  final Value<String?> reversalMovementIdsJson;
  final Value<int> rowid;
  const SalesCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.quantityKg = const Value.absent(),
    this.salePriceQirshPerKg = const Value.absent(),
    this.totalQirsh = const Value.absent(),
    this.createdByUserId = const Value.absent(),
    this.createdByUserName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.stockMovementId = const Value.absent(),
    this.paymentMode = const Value.absent(),
    this.customerId = const Value.absent(),
    this.notes = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.paidAmountQirsh = const Value.absent(),
    this.financialAccountId = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.paymentAllocationsJson = const Value.absent(),
    this.operationRequestId = const Value.absent(),
    this.cancelledAt = const Value.absent(),
    this.cancelledByUserId = const Value.absent(),
    this.cancellationReason = const Value.absent(),
    this.reversalMovementIdsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SalesCompanion.insert({
    required String id,
    required String productId,
    required int quantityKg,
    required int salePriceQirshPerKg,
    required int totalQirsh,
    required String createdByUserId,
    this.createdByUserName = const Value.absent(),
    required DateTime createdAt,
    required String stockMovementId,
    required String paymentMode,
    this.customerId = const Value.absent(),
    this.notes = const Value.absent(),
    required String itemsJson,
    this.paidAmountQirsh = const Value.absent(),
    this.financialAccountId = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    required String paymentAllocationsJson,
    this.operationRequestId = const Value.absent(),
    this.cancelledAt = const Value.absent(),
    this.cancelledByUserId = const Value.absent(),
    this.cancellationReason = const Value.absent(),
    this.reversalMovementIdsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        productId = Value(productId),
        quantityKg = Value(quantityKg),
        salePriceQirshPerKg = Value(salePriceQirshPerKg),
        totalQirsh = Value(totalQirsh),
        createdByUserId = Value(createdByUserId),
        createdAt = Value(createdAt),
        stockMovementId = Value(stockMovementId),
        paymentMode = Value(paymentMode),
        itemsJson = Value(itemsJson),
        paymentAllocationsJson = Value(paymentAllocationsJson);
  static Insertable<Sale> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<int>? quantityKg,
    Expression<int>? salePriceQirshPerKg,
    Expression<int>? totalQirsh,
    Expression<String>? createdByUserId,
    Expression<String>? createdByUserName,
    Expression<DateTime>? createdAt,
    Expression<String>? stockMovementId,
    Expression<String>? paymentMode,
    Expression<String>? customerId,
    Expression<String>? notes,
    Expression<String>? itemsJson,
    Expression<int>? paidAmountQirsh,
    Expression<String>? financialAccountId,
    Expression<String>? paymentMethod,
    Expression<String>? paymentAllocationsJson,
    Expression<String>? operationRequestId,
    Expression<DateTime>? cancelledAt,
    Expression<String>? cancelledByUserId,
    Expression<String>? cancellationReason,
    Expression<String>? reversalMovementIdsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (quantityKg != null) 'quantity_kg': quantityKg,
      if (salePriceQirshPerKg != null)
        'sale_price_qirsh_per_kg': salePriceQirshPerKg,
      if (totalQirsh != null) 'total_qirsh': totalQirsh,
      if (createdByUserId != null) 'created_by_user_id': createdByUserId,
      if (createdByUserName != null) 'created_by_user_name': createdByUserName,
      if (createdAt != null) 'created_at': createdAt,
      if (stockMovementId != null) 'stock_movement_id': stockMovementId,
      if (paymentMode != null) 'payment_mode': paymentMode,
      if (customerId != null) 'customer_id': customerId,
      if (notes != null) 'notes': notes,
      if (itemsJson != null) 'items_json': itemsJson,
      if (paidAmountQirsh != null) 'paid_amount_qirsh': paidAmountQirsh,
      if (financialAccountId != null)
        'financial_account_id': financialAccountId,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (paymentAllocationsJson != null)
        'payment_allocations_json': paymentAllocationsJson,
      if (operationRequestId != null)
        'operation_request_id': operationRequestId,
      if (cancelledAt != null) 'cancelled_at': cancelledAt,
      if (cancelledByUserId != null) 'cancelled_by_user_id': cancelledByUserId,
      if (cancellationReason != null) 'cancellation_reason': cancellationReason,
      if (reversalMovementIdsJson != null)
        'reversal_movement_ids_json': reversalMovementIdsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SalesCompanion copyWith(
      {Value<String>? id,
      Value<String>? productId,
      Value<int>? quantityKg,
      Value<int>? salePriceQirshPerKg,
      Value<int>? totalQirsh,
      Value<String>? createdByUserId,
      Value<String?>? createdByUserName,
      Value<DateTime>? createdAt,
      Value<String>? stockMovementId,
      Value<String>? paymentMode,
      Value<String?>? customerId,
      Value<String?>? notes,
      Value<String>? itemsJson,
      Value<int?>? paidAmountQirsh,
      Value<String?>? financialAccountId,
      Value<String?>? paymentMethod,
      Value<String>? paymentAllocationsJson,
      Value<String?>? operationRequestId,
      Value<DateTime?>? cancelledAt,
      Value<String?>? cancelledByUserId,
      Value<String?>? cancellationReason,
      Value<String?>? reversalMovementIdsJson,
      Value<int>? rowid}) {
    return SalesCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantityKg: quantityKg ?? this.quantityKg,
      salePriceQirshPerKg: salePriceQirshPerKg ?? this.salePriceQirshPerKg,
      totalQirsh: totalQirsh ?? this.totalQirsh,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByUserName: createdByUserName ?? this.createdByUserName,
      createdAt: createdAt ?? this.createdAt,
      stockMovementId: stockMovementId ?? this.stockMovementId,
      paymentMode: paymentMode ?? this.paymentMode,
      customerId: customerId ?? this.customerId,
      notes: notes ?? this.notes,
      itemsJson: itemsJson ?? this.itemsJson,
      paidAmountQirsh: paidAmountQirsh ?? this.paidAmountQirsh,
      financialAccountId: financialAccountId ?? this.financialAccountId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentAllocationsJson:
          paymentAllocationsJson ?? this.paymentAllocationsJson,
      operationRequestId: operationRequestId ?? this.operationRequestId,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledByUserId: cancelledByUserId ?? this.cancelledByUserId,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      reversalMovementIdsJson:
          reversalMovementIdsJson ?? this.reversalMovementIdsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (quantityKg.present) {
      map['quantity_kg'] = Variable<int>(quantityKg.value);
    }
    if (salePriceQirshPerKg.present) {
      map['sale_price_qirsh_per_kg'] = Variable<int>(salePriceQirshPerKg.value);
    }
    if (totalQirsh.present) {
      map['total_qirsh'] = Variable<int>(totalQirsh.value);
    }
    if (createdByUserId.present) {
      map['created_by_user_id'] = Variable<String>(createdByUserId.value);
    }
    if (createdByUserName.present) {
      map['created_by_user_name'] = Variable<String>(createdByUserName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (stockMovementId.present) {
      map['stock_movement_id'] = Variable<String>(stockMovementId.value);
    }
    if (paymentMode.present) {
      map['payment_mode'] = Variable<String>(paymentMode.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (paidAmountQirsh.present) {
      map['paid_amount_qirsh'] = Variable<int>(paidAmountQirsh.value);
    }
    if (financialAccountId.present) {
      map['financial_account_id'] = Variable<String>(financialAccountId.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (paymentAllocationsJson.present) {
      map['payment_allocations_json'] =
          Variable<String>(paymentAllocationsJson.value);
    }
    if (operationRequestId.present) {
      map['operation_request_id'] = Variable<String>(operationRequestId.value);
    }
    if (cancelledAt.present) {
      map['cancelled_at'] = Variable<DateTime>(cancelledAt.value);
    }
    if (cancelledByUserId.present) {
      map['cancelled_by_user_id'] = Variable<String>(cancelledByUserId.value);
    }
    if (cancellationReason.present) {
      map['cancellation_reason'] = Variable<String>(cancellationReason.value);
    }
    if (reversalMovementIdsJson.present) {
      map['reversal_movement_ids_json'] =
          Variable<String>(reversalMovementIdsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalesCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('quantityKg: $quantityKg, ')
          ..write('salePriceQirshPerKg: $salePriceQirshPerKg, ')
          ..write('totalQirsh: $totalQirsh, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('createdByUserName: $createdByUserName, ')
          ..write('createdAt: $createdAt, ')
          ..write('stockMovementId: $stockMovementId, ')
          ..write('paymentMode: $paymentMode, ')
          ..write('customerId: $customerId, ')
          ..write('notes: $notes, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('paidAmountQirsh: $paidAmountQirsh, ')
          ..write('financialAccountId: $financialAccountId, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('paymentAllocationsJson: $paymentAllocationsJson, ')
          ..write('operationRequestId: $operationRequestId, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('cancelledByUserId: $cancelledByUserId, ')
          ..write('cancellationReason: $cancellationReason, ')
          ..write('reversalMovementIdsJson: $reversalMovementIdsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$FoundationDatabase extends GeneratedDatabase {
  _$FoundationDatabase(QueryExecutor e) : super(e);
  $FoundationDatabaseManager get managers => $FoundationDatabaseManager(this);
  late final $FoundationProbesTable foundationProbes =
      $FoundationProbesTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $RepositorySequencesTable repositorySequences =
      $RepositorySequencesTable(this);
  late final $CustomersTable customers = $CustomersTable(this);
  late final $SuppliersTable suppliers = $SuppliersTable(this);
  late final $InventoryMovementsTable inventoryMovements =
      $InventoryMovementsTable(this);
  late final $PurchasesTable purchases = $PurchasesTable(this);
  late final $SalesTable sales = $SalesTable(this);
  late final Index inventoryMovementsProductIdx = Index(
      'inventory_movements_product_idx',
      'CREATE INDEX inventory_movements_product_idx ON inventory_movements (product_id)');
  late final Index inventoryMovementsCreatedIdx = Index(
      'inventory_movements_created_idx',
      'CREATE INDEX inventory_movements_created_idx ON inventory_movements (created_at, id)');
  late final Index inventoryMovementsDocumentIdx = Index(
      'inventory_movements_document_idx',
      'CREATE INDEX inventory_movements_document_idx ON inventory_movements (original_document_id)');
  late final Index purchasesSupplierIdx = Index('purchases_supplier_idx',
      'CREATE INDEX purchases_supplier_idx ON purchases (supplier_id)');
  late final Index purchasesCreatedIdx = Index('purchases_created_idx',
      'CREATE INDEX purchases_created_idx ON purchases (created_at, id)');
  late final Index purchasesProductIdx = Index('purchases_product_idx',
      'CREATE INDEX purchases_product_idx ON purchases (product_id)');
  late final Index purchasesRequestIdx = Index('purchases_request_idx',
      'CREATE INDEX purchases_request_idx ON purchases (operation_request_id)');
  late final Index salesCustomerIdx = Index('sales_customer_idx',
      'CREATE INDEX sales_customer_idx ON sales (customer_id)');
  late final Index salesCreatedIdx = Index('sales_created_idx',
      'CREATE INDEX sales_created_idx ON sales (created_at, id)');
  late final Index salesRequestIdx = Index('sales_request_idx',
      'CREATE INDEX sales_request_idx ON sales (operation_request_id)');
  late final Index salesCancelledIdx = Index('sales_cancelled_idx',
      'CREATE INDEX sales_cancelled_idx ON sales (cancelled_at)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        foundationProbes,
        products,
        repositorySequences,
        customers,
        suppliers,
        inventoryMovements,
        purchases,
        sales,
        inventoryMovementsProductIdx,
        inventoryMovementsCreatedIdx,
        inventoryMovementsDocumentIdx,
        purchasesSupplierIdx,
        purchasesCreatedIdx,
        purchasesProductIdx,
        purchasesRequestIdx,
        salesCustomerIdx,
        salesCreatedIdx,
        salesRequestIdx,
        salesCancelledIdx
      ];
}

typedef $$FoundationProbesTableCreateCompanionBuilder
    = FoundationProbesCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$FoundationProbesTableUpdateCompanionBuilder
    = FoundationProbesCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$FoundationProbesTableFilterComposer
    extends Composer<_$FoundationDatabase, $FoundationProbesTable> {
  $$FoundationProbesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$FoundationProbesTableOrderingComposer
    extends Composer<_$FoundationDatabase, $FoundationProbesTable> {
  $$FoundationProbesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$FoundationProbesTableAnnotationComposer
    extends Composer<_$FoundationDatabase, $FoundationProbesTable> {
  $$FoundationProbesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$FoundationProbesTableTableManager extends RootTableManager<
    _$FoundationDatabase,
    $FoundationProbesTable,
    FoundationProbe,
    $$FoundationProbesTableFilterComposer,
    $$FoundationProbesTableOrderingComposer,
    $$FoundationProbesTableAnnotationComposer,
    $$FoundationProbesTableCreateCompanionBuilder,
    $$FoundationProbesTableUpdateCompanionBuilder,
    (
      FoundationProbe,
      BaseReferences<_$FoundationDatabase, $FoundationProbesTable,
          FoundationProbe>
    ),
    FoundationProbe,
    PrefetchHooks Function()> {
  $$FoundationProbesTableTableManager(
      _$FoundationDatabase db, $FoundationProbesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoundationProbesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoundationProbesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoundationProbesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FoundationProbesCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              FoundationProbesCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FoundationProbesTableProcessedTableManager = ProcessedTableManager<
    _$FoundationDatabase,
    $FoundationProbesTable,
    FoundationProbe,
    $$FoundationProbesTableFilterComposer,
    $$FoundationProbesTableOrderingComposer,
    $$FoundationProbesTableAnnotationComposer,
    $$FoundationProbesTableCreateCompanionBuilder,
    $$FoundationProbesTableUpdateCompanionBuilder,
    (
      FoundationProbe,
      BaseReferences<_$FoundationDatabase, $FoundationProbesTable,
          FoundationProbe>
    ),
    FoundationProbe,
    PrefetchHooks Function()>;
typedef $$ProductsTableCreateCompanionBuilder = ProductsCompanion Function({
  required String id,
  required String name,
  required String normalizedName,
  Value<String?> code,
  Value<String?> normalizedCode,
  required String unit,
  required bool isActive,
  Value<int?> defaultSalePricePiastersPerKg,
  Value<int?> minimumSalePricePiastersPerKg,
  Value<int?> referenceCostPricePiastersPerKg,
  Value<String?> notes,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ProductsTableUpdateCompanionBuilder = ProductsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> normalizedName,
  Value<String?> code,
  Value<String?> normalizedCode,
  Value<String> unit,
  Value<bool> isActive,
  Value<int?> defaultSalePricePiastersPerKg,
  Value<int?> minimumSalePricePiastersPerKg,
  Value<int?> referenceCostPricePiastersPerKg,
  Value<String?> notes,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ProductsTableFilterComposer
    extends Composer<_$FoundationDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedCode => $composableBuilder(
      column: $table.normalizedCode,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get defaultSalePricePiastersPerKg => $composableBuilder(
      column: $table.defaultSalePricePiastersPerKg,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get minimumSalePricePiastersPerKg => $composableBuilder(
      column: $table.minimumSalePricePiastersPerKg,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get referenceCostPricePiastersPerKg => $composableBuilder(
      column: $table.referenceCostPricePiastersPerKg,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ProductsTableOrderingComposer
    extends Composer<_$FoundationDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedCode => $composableBuilder(
      column: $table.normalizedCode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get defaultSalePricePiastersPerKg => $composableBuilder(
      column: $table.defaultSalePricePiastersPerKg,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get minimumSalePricePiastersPerKg => $composableBuilder(
      column: $table.minimumSalePricePiastersPerKg,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get referenceCostPricePiastersPerKg =>
      $composableBuilder(
          column: $table.referenceCostPricePiastersPerKg,
          builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$FoundationDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get normalizedCode => $composableBuilder(
      column: $table.normalizedCode, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get defaultSalePricePiastersPerKg => $composableBuilder(
      column: $table.defaultSalePricePiastersPerKg,
      builder: (column) => column);

  GeneratedColumn<int> get minimumSalePricePiastersPerKg => $composableBuilder(
      column: $table.minimumSalePricePiastersPerKg,
      builder: (column) => column);

  GeneratedColumn<int> get referenceCostPricePiastersPerKg =>
      $composableBuilder(
          column: $table.referenceCostPricePiastersPerKg,
          builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProductsTableTableManager extends RootTableManager<
    _$FoundationDatabase,
    $ProductsTable,
    Product,
    $$ProductsTableFilterComposer,
    $$ProductsTableOrderingComposer,
    $$ProductsTableAnnotationComposer,
    $$ProductsTableCreateCompanionBuilder,
    $$ProductsTableUpdateCompanionBuilder,
    (Product, BaseReferences<_$FoundationDatabase, $ProductsTable, Product>),
    Product,
    PrefetchHooks Function()> {
  $$ProductsTableTableManager(_$FoundationDatabase db, $ProductsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> normalizedName = const Value.absent(),
            Value<String?> code = const Value.absent(),
            Value<String?> normalizedCode = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int?> defaultSalePricePiastersPerKg = const Value.absent(),
            Value<int?> minimumSalePricePiastersPerKg = const Value.absent(),
            Value<int?> referenceCostPricePiastersPerKg = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProductsCompanion(
            id: id,
            name: name,
            normalizedName: normalizedName,
            code: code,
            normalizedCode: normalizedCode,
            unit: unit,
            isActive: isActive,
            defaultSalePricePiastersPerKg: defaultSalePricePiastersPerKg,
            minimumSalePricePiastersPerKg: minimumSalePricePiastersPerKg,
            referenceCostPricePiastersPerKg: referenceCostPricePiastersPerKg,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String normalizedName,
            Value<String?> code = const Value.absent(),
            Value<String?> normalizedCode = const Value.absent(),
            required String unit,
            required bool isActive,
            Value<int?> defaultSalePricePiastersPerKg = const Value.absent(),
            Value<int?> minimumSalePricePiastersPerKg = const Value.absent(),
            Value<int?> referenceCostPricePiastersPerKg = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ProductsCompanion.insert(
            id: id,
            name: name,
            normalizedName: normalizedName,
            code: code,
            normalizedCode: normalizedCode,
            unit: unit,
            isActive: isActive,
            defaultSalePricePiastersPerKg: defaultSalePricePiastersPerKg,
            minimumSalePricePiastersPerKg: minimumSalePricePiastersPerKg,
            referenceCostPricePiastersPerKg: referenceCostPricePiastersPerKg,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProductsTableProcessedTableManager = ProcessedTableManager<
    _$FoundationDatabase,
    $ProductsTable,
    Product,
    $$ProductsTableFilterComposer,
    $$ProductsTableOrderingComposer,
    $$ProductsTableAnnotationComposer,
    $$ProductsTableCreateCompanionBuilder,
    $$ProductsTableUpdateCompanionBuilder,
    (Product, BaseReferences<_$FoundationDatabase, $ProductsTable, Product>),
    Product,
    PrefetchHooks Function()>;
typedef $$RepositorySequencesTableCreateCompanionBuilder
    = RepositorySequencesCompanion Function({
  required String repository,
  required int nextValue,
  Value<int> rowid,
});
typedef $$RepositorySequencesTableUpdateCompanionBuilder
    = RepositorySequencesCompanion Function({
  Value<String> repository,
  Value<int> nextValue,
  Value<int> rowid,
});

class $$RepositorySequencesTableFilterComposer
    extends Composer<_$FoundationDatabase, $RepositorySequencesTable> {
  $$RepositorySequencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get repository => $composableBuilder(
      column: $table.repository, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get nextValue => $composableBuilder(
      column: $table.nextValue, builder: (column) => ColumnFilters(column));
}

class $$RepositorySequencesTableOrderingComposer
    extends Composer<_$FoundationDatabase, $RepositorySequencesTable> {
  $$RepositorySequencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get repository => $composableBuilder(
      column: $table.repository, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get nextValue => $composableBuilder(
      column: $table.nextValue, builder: (column) => ColumnOrderings(column));
}

class $$RepositorySequencesTableAnnotationComposer
    extends Composer<_$FoundationDatabase, $RepositorySequencesTable> {
  $$RepositorySequencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get repository => $composableBuilder(
      column: $table.repository, builder: (column) => column);

  GeneratedColumn<int> get nextValue =>
      $composableBuilder(column: $table.nextValue, builder: (column) => column);
}

class $$RepositorySequencesTableTableManager extends RootTableManager<
    _$FoundationDatabase,
    $RepositorySequencesTable,
    RepositorySequence,
    $$RepositorySequencesTableFilterComposer,
    $$RepositorySequencesTableOrderingComposer,
    $$RepositorySequencesTableAnnotationComposer,
    $$RepositorySequencesTableCreateCompanionBuilder,
    $$RepositorySequencesTableUpdateCompanionBuilder,
    (
      RepositorySequence,
      BaseReferences<_$FoundationDatabase, $RepositorySequencesTable,
          RepositorySequence>
    ),
    RepositorySequence,
    PrefetchHooks Function()> {
  $$RepositorySequencesTableTableManager(
      _$FoundationDatabase db, $RepositorySequencesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RepositorySequencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RepositorySequencesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RepositorySequencesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> repository = const Value.absent(),
            Value<int> nextValue = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RepositorySequencesCompanion(
            repository: repository,
            nextValue: nextValue,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String repository,
            required int nextValue,
            Value<int> rowid = const Value.absent(),
          }) =>
              RepositorySequencesCompanion.insert(
            repository: repository,
            nextValue: nextValue,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RepositorySequencesTableProcessedTableManager = ProcessedTableManager<
    _$FoundationDatabase,
    $RepositorySequencesTable,
    RepositorySequence,
    $$RepositorySequencesTableFilterComposer,
    $$RepositorySequencesTableOrderingComposer,
    $$RepositorySequencesTableAnnotationComposer,
    $$RepositorySequencesTableCreateCompanionBuilder,
    $$RepositorySequencesTableUpdateCompanionBuilder,
    (
      RepositorySequence,
      BaseReferences<_$FoundationDatabase, $RepositorySequencesTable,
          RepositorySequence>
    ),
    RepositorySequence,
    PrefetchHooks Function()>;
typedef $$CustomersTableCreateCompanionBuilder = CustomersCompanion Function({
  required String id,
  required String name,
  required String normalizedName,
  Value<String?> phone,
  Value<String?> normalizedPhone,
  Value<String?> notes,
  required bool isActive,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$CustomersTableUpdateCompanionBuilder = CustomersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> normalizedName,
  Value<String?> phone,
  Value<String?> normalizedPhone,
  Value<String?> notes,
  Value<bool> isActive,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$CustomersTableFilterComposer
    extends Composer<_$FoundationDatabase, $CustomersTable> {
  $$CustomersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedPhone => $composableBuilder(
      column: $table.normalizedPhone,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CustomersTableOrderingComposer
    extends Composer<_$FoundationDatabase, $CustomersTable> {
  $$CustomersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedPhone => $composableBuilder(
      column: $table.normalizedPhone,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CustomersTableAnnotationComposer
    extends Composer<_$FoundationDatabase, $CustomersTable> {
  $$CustomersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get normalizedPhone => $composableBuilder(
      column: $table.normalizedPhone, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CustomersTableTableManager extends RootTableManager<
    _$FoundationDatabase,
    $CustomersTable,
    Customer,
    $$CustomersTableFilterComposer,
    $$CustomersTableOrderingComposer,
    $$CustomersTableAnnotationComposer,
    $$CustomersTableCreateCompanionBuilder,
    $$CustomersTableUpdateCompanionBuilder,
    (Customer, BaseReferences<_$FoundationDatabase, $CustomersTable, Customer>),
    Customer,
    PrefetchHooks Function()> {
  $$CustomersTableTableManager(_$FoundationDatabase db, $CustomersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> normalizedName = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> normalizedPhone = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CustomersCompanion(
            id: id,
            name: name,
            normalizedName: normalizedName,
            phone: phone,
            normalizedPhone: normalizedPhone,
            notes: notes,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String normalizedName,
            Value<String?> phone = const Value.absent(),
            Value<String?> normalizedPhone = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            required bool isActive,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CustomersCompanion.insert(
            id: id,
            name: name,
            normalizedName: normalizedName,
            phone: phone,
            normalizedPhone: normalizedPhone,
            notes: notes,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CustomersTableProcessedTableManager = ProcessedTableManager<
    _$FoundationDatabase,
    $CustomersTable,
    Customer,
    $$CustomersTableFilterComposer,
    $$CustomersTableOrderingComposer,
    $$CustomersTableAnnotationComposer,
    $$CustomersTableCreateCompanionBuilder,
    $$CustomersTableUpdateCompanionBuilder,
    (Customer, BaseReferences<_$FoundationDatabase, $CustomersTable, Customer>),
    Customer,
    PrefetchHooks Function()>;
typedef $$SuppliersTableCreateCompanionBuilder = SuppliersCompanion Function({
  required String id,
  required String name,
  required String normalizedName,
  Value<String?> phone,
  Value<String?> normalizedPhone,
  Value<String?> address,
  Value<String?> notes,
  required bool isActive,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SuppliersTableUpdateCompanionBuilder = SuppliersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> normalizedName,
  Value<String?> phone,
  Value<String?> normalizedPhone,
  Value<String?> address,
  Value<String?> notes,
  Value<bool> isActive,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SuppliersTableFilterComposer
    extends Composer<_$FoundationDatabase, $SuppliersTable> {
  $$SuppliersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get normalizedPhone => $composableBuilder(
      column: $table.normalizedPhone,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SuppliersTableOrderingComposer
    extends Composer<_$FoundationDatabase, $SuppliersTable> {
  $$SuppliersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get normalizedPhone => $composableBuilder(
      column: $table.normalizedPhone,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SuppliersTableAnnotationComposer
    extends Composer<_$FoundationDatabase, $SuppliersTable> {
  $$SuppliersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
      column: $table.normalizedName, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get normalizedPhone => $composableBuilder(
      column: $table.normalizedPhone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SuppliersTableTableManager extends RootTableManager<
    _$FoundationDatabase,
    $SuppliersTable,
    Supplier,
    $$SuppliersTableFilterComposer,
    $$SuppliersTableOrderingComposer,
    $$SuppliersTableAnnotationComposer,
    $$SuppliersTableCreateCompanionBuilder,
    $$SuppliersTableUpdateCompanionBuilder,
    (Supplier, BaseReferences<_$FoundationDatabase, $SuppliersTable, Supplier>),
    Supplier,
    PrefetchHooks Function()> {
  $$SuppliersTableTableManager(_$FoundationDatabase db, $SuppliersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SuppliersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SuppliersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SuppliersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> normalizedName = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> normalizedPhone = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SuppliersCompanion(
            id: id,
            name: name,
            normalizedName: normalizedName,
            phone: phone,
            normalizedPhone: normalizedPhone,
            address: address,
            notes: notes,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String normalizedName,
            Value<String?> phone = const Value.absent(),
            Value<String?> normalizedPhone = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            required bool isActive,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SuppliersCompanion.insert(
            id: id,
            name: name,
            normalizedName: normalizedName,
            phone: phone,
            normalizedPhone: normalizedPhone,
            address: address,
            notes: notes,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SuppliersTableProcessedTableManager = ProcessedTableManager<
    _$FoundationDatabase,
    $SuppliersTable,
    Supplier,
    $$SuppliersTableFilterComposer,
    $$SuppliersTableOrderingComposer,
    $$SuppliersTableAnnotationComposer,
    $$SuppliersTableCreateCompanionBuilder,
    $$SuppliersTableUpdateCompanionBuilder,
    (Supplier, BaseReferences<_$FoundationDatabase, $SuppliersTable, Supplier>),
    Supplier,
    PrefetchHooks Function()>;
typedef $$InventoryMovementsTableCreateCompanionBuilder
    = InventoryMovementsCompanion Function({
  required String id,
  required String productId,
  required String movementType,
  required int quantityKg,
  required String createdByUserId,
  required DateTime createdAt,
  Value<String?> note,
  Value<bool> isVoided,
  Value<String?> reversedMovementId,
  Value<String?> originalDocumentId,
  Value<int> rowid,
});
typedef $$InventoryMovementsTableUpdateCompanionBuilder
    = InventoryMovementsCompanion Function({
  Value<String> id,
  Value<String> productId,
  Value<String> movementType,
  Value<int> quantityKg,
  Value<String> createdByUserId,
  Value<DateTime> createdAt,
  Value<String?> note,
  Value<bool> isVoided,
  Value<String?> reversedMovementId,
  Value<String?> originalDocumentId,
  Value<int> rowid,
});

class $$InventoryMovementsTableFilterComposer
    extends Composer<_$FoundationDatabase, $InventoryMovementsTable> {
  $$InventoryMovementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get movementType => $composableBuilder(
      column: $table.movementType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantityKg => $composableBuilder(
      column: $table.quantityKg, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdByUserId => $composableBuilder(
      column: $table.createdByUserId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isVoided => $composableBuilder(
      column: $table.isVoided, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reversedMovementId => $composableBuilder(
      column: $table.reversedMovementId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originalDocumentId => $composableBuilder(
      column: $table.originalDocumentId,
      builder: (column) => ColumnFilters(column));
}

class $$InventoryMovementsTableOrderingComposer
    extends Composer<_$FoundationDatabase, $InventoryMovementsTable> {
  $$InventoryMovementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get movementType => $composableBuilder(
      column: $table.movementType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantityKg => $composableBuilder(
      column: $table.quantityKg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdByUserId => $composableBuilder(
      column: $table.createdByUserId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isVoided => $composableBuilder(
      column: $table.isVoided, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reversedMovementId => $composableBuilder(
      column: $table.reversedMovementId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originalDocumentId => $composableBuilder(
      column: $table.originalDocumentId,
      builder: (column) => ColumnOrderings(column));
}

class $$InventoryMovementsTableAnnotationComposer
    extends Composer<_$FoundationDatabase, $InventoryMovementsTable> {
  $$InventoryMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get movementType => $composableBuilder(
      column: $table.movementType, builder: (column) => column);

  GeneratedColumn<int> get quantityKg => $composableBuilder(
      column: $table.quantityKg, builder: (column) => column);

  GeneratedColumn<String> get createdByUserId => $composableBuilder(
      column: $table.createdByUserId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isVoided =>
      $composableBuilder(column: $table.isVoided, builder: (column) => column);

  GeneratedColumn<String> get reversedMovementId => $composableBuilder(
      column: $table.reversedMovementId, builder: (column) => column);

  GeneratedColumn<String> get originalDocumentId => $composableBuilder(
      column: $table.originalDocumentId, builder: (column) => column);
}

class $$InventoryMovementsTableTableManager extends RootTableManager<
    _$FoundationDatabase,
    $InventoryMovementsTable,
    InventoryMovement,
    $$InventoryMovementsTableFilterComposer,
    $$InventoryMovementsTableOrderingComposer,
    $$InventoryMovementsTableAnnotationComposer,
    $$InventoryMovementsTableCreateCompanionBuilder,
    $$InventoryMovementsTableUpdateCompanionBuilder,
    (
      InventoryMovement,
      BaseReferences<_$FoundationDatabase, $InventoryMovementsTable,
          InventoryMovement>
    ),
    InventoryMovement,
    PrefetchHooks Function()> {
  $$InventoryMovementsTableTableManager(
      _$FoundationDatabase db, $InventoryMovementsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InventoryMovementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InventoryMovementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InventoryMovementsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<String> movementType = const Value.absent(),
            Value<int> quantityKg = const Value.absent(),
            Value<String> createdByUserId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<bool> isVoided = const Value.absent(),
            Value<String?> reversedMovementId = const Value.absent(),
            Value<String?> originalDocumentId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InventoryMovementsCompanion(
            id: id,
            productId: productId,
            movementType: movementType,
            quantityKg: quantityKg,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            note: note,
            isVoided: isVoided,
            reversedMovementId: reversedMovementId,
            originalDocumentId: originalDocumentId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String productId,
            required String movementType,
            required int quantityKg,
            required String createdByUserId,
            required DateTime createdAt,
            Value<String?> note = const Value.absent(),
            Value<bool> isVoided = const Value.absent(),
            Value<String?> reversedMovementId = const Value.absent(),
            Value<String?> originalDocumentId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InventoryMovementsCompanion.insert(
            id: id,
            productId: productId,
            movementType: movementType,
            quantityKg: quantityKg,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            note: note,
            isVoided: isVoided,
            reversedMovementId: reversedMovementId,
            originalDocumentId: originalDocumentId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InventoryMovementsTableProcessedTableManager = ProcessedTableManager<
    _$FoundationDatabase,
    $InventoryMovementsTable,
    InventoryMovement,
    $$InventoryMovementsTableFilterComposer,
    $$InventoryMovementsTableOrderingComposer,
    $$InventoryMovementsTableAnnotationComposer,
    $$InventoryMovementsTableCreateCompanionBuilder,
    $$InventoryMovementsTableUpdateCompanionBuilder,
    (
      InventoryMovement,
      BaseReferences<_$FoundationDatabase, $InventoryMovementsTable,
          InventoryMovement>
    ),
    InventoryMovement,
    PrefetchHooks Function()>;
typedef $$PurchasesTableCreateCompanionBuilder = PurchasesCompanion Function({
  required String id,
  required String supplierId,
  Value<String?> supplierName,
  Value<String?> supplierPhone,
  Value<String?> supplierAddress,
  required String productId,
  required int quantityKg,
  required String entryUnit,
  required int unitPricePiastersPerKg,
  required int totalAmountPiasters,
  required String createdByUserId,
  required DateTime createdAt,
  required String stockMovementId,
  Value<String?> notes,
  Value<String?> financialAccountId,
  Value<String?> paymentMethod,
  required String paymentMode,
  Value<int?> paidAmountQirsh,
  Value<String?> negativeBalanceApprovalId,
  Value<String?> operationRequestId,
  Value<String?> requestFingerprint,
  Value<DateTime?> cancelledAt,
  Value<String?> cancelledByUserId,
  Value<String?> cancellationReason,
  Value<String?> reversalMovementIds,
  Value<int> rowid,
});
typedef $$PurchasesTableUpdateCompanionBuilder = PurchasesCompanion Function({
  Value<String> id,
  Value<String> supplierId,
  Value<String?> supplierName,
  Value<String?> supplierPhone,
  Value<String?> supplierAddress,
  Value<String> productId,
  Value<int> quantityKg,
  Value<String> entryUnit,
  Value<int> unitPricePiastersPerKg,
  Value<int> totalAmountPiasters,
  Value<String> createdByUserId,
  Value<DateTime> createdAt,
  Value<String> stockMovementId,
  Value<String?> notes,
  Value<String?> financialAccountId,
  Value<String?> paymentMethod,
  Value<String> paymentMode,
  Value<int?> paidAmountQirsh,
  Value<String?> negativeBalanceApprovalId,
  Value<String?> operationRequestId,
  Value<String?> requestFingerprint,
  Value<DateTime?> cancelledAt,
  Value<String?> cancelledByUserId,
  Value<String?> cancellationReason,
  Value<String?> reversalMovementIds,
  Value<int> rowid,
});

class $$PurchasesTableFilterComposer
    extends Composer<_$FoundationDatabase, $PurchasesTable> {
  $$PurchasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get supplierId => $composableBuilder(
      column: $table.supplierId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get supplierName => $composableBuilder(
      column: $table.supplierName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get supplierPhone => $composableBuilder(
      column: $table.supplierPhone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get supplierAddress => $composableBuilder(
      column: $table.supplierAddress,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantityKg => $composableBuilder(
      column: $table.quantityKg, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entryUnit => $composableBuilder(
      column: $table.entryUnit, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unitPricePiastersPerKg => $composableBuilder(
      column: $table.unitPricePiastersPerKg,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalAmountPiasters => $composableBuilder(
      column: $table.totalAmountPiasters,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdByUserId => $composableBuilder(
      column: $table.createdByUserId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stockMovementId => $composableBuilder(
      column: $table.stockMovementId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get financialAccountId => $composableBuilder(
      column: $table.financialAccountId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get paymentMode => $composableBuilder(
      column: $table.paymentMode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get paidAmountQirsh => $composableBuilder(
      column: $table.paidAmountQirsh,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get negativeBalanceApprovalId => $composableBuilder(
      column: $table.negativeBalanceApprovalId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operationRequestId => $composableBuilder(
      column: $table.operationRequestId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get requestFingerprint => $composableBuilder(
      column: $table.requestFingerprint,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cancelledAt => $composableBuilder(
      column: $table.cancelledAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cancelledByUserId => $composableBuilder(
      column: $table.cancelledByUserId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cancellationReason => $composableBuilder(
      column: $table.cancellationReason,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reversalMovementIds => $composableBuilder(
      column: $table.reversalMovementIds,
      builder: (column) => ColumnFilters(column));
}

class $$PurchasesTableOrderingComposer
    extends Composer<_$FoundationDatabase, $PurchasesTable> {
  $$PurchasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get supplierId => $composableBuilder(
      column: $table.supplierId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get supplierName => $composableBuilder(
      column: $table.supplierName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get supplierPhone => $composableBuilder(
      column: $table.supplierPhone,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get supplierAddress => $composableBuilder(
      column: $table.supplierAddress,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantityKg => $composableBuilder(
      column: $table.quantityKg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entryUnit => $composableBuilder(
      column: $table.entryUnit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unitPricePiastersPerKg => $composableBuilder(
      column: $table.unitPricePiastersPerKg,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalAmountPiasters => $composableBuilder(
      column: $table.totalAmountPiasters,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdByUserId => $composableBuilder(
      column: $table.createdByUserId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stockMovementId => $composableBuilder(
      column: $table.stockMovementId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get financialAccountId => $composableBuilder(
      column: $table.financialAccountId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get paymentMode => $composableBuilder(
      column: $table.paymentMode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paidAmountQirsh => $composableBuilder(
      column: $table.paidAmountQirsh,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get negativeBalanceApprovalId => $composableBuilder(
      column: $table.negativeBalanceApprovalId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operationRequestId => $composableBuilder(
      column: $table.operationRequestId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get requestFingerprint => $composableBuilder(
      column: $table.requestFingerprint,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cancelledAt => $composableBuilder(
      column: $table.cancelledAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cancelledByUserId => $composableBuilder(
      column: $table.cancelledByUserId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cancellationReason => $composableBuilder(
      column: $table.cancellationReason,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reversalMovementIds => $composableBuilder(
      column: $table.reversalMovementIds,
      builder: (column) => ColumnOrderings(column));
}

class $$PurchasesTableAnnotationComposer
    extends Composer<_$FoundationDatabase, $PurchasesTable> {
  $$PurchasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get supplierId => $composableBuilder(
      column: $table.supplierId, builder: (column) => column);

  GeneratedColumn<String> get supplierName => $composableBuilder(
      column: $table.supplierName, builder: (column) => column);

  GeneratedColumn<String> get supplierPhone => $composableBuilder(
      column: $table.supplierPhone, builder: (column) => column);

  GeneratedColumn<String> get supplierAddress => $composableBuilder(
      column: $table.supplierAddress, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<int> get quantityKg => $composableBuilder(
      column: $table.quantityKg, builder: (column) => column);

  GeneratedColumn<String> get entryUnit =>
      $composableBuilder(column: $table.entryUnit, builder: (column) => column);

  GeneratedColumn<int> get unitPricePiastersPerKg => $composableBuilder(
      column: $table.unitPricePiastersPerKg, builder: (column) => column);

  GeneratedColumn<int> get totalAmountPiasters => $composableBuilder(
      column: $table.totalAmountPiasters, builder: (column) => column);

  GeneratedColumn<String> get createdByUserId => $composableBuilder(
      column: $table.createdByUserId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get stockMovementId => $composableBuilder(
      column: $table.stockMovementId, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get financialAccountId => $composableBuilder(
      column: $table.financialAccountId, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod, builder: (column) => column);

  GeneratedColumn<String> get paymentMode => $composableBuilder(
      column: $table.paymentMode, builder: (column) => column);

  GeneratedColumn<int> get paidAmountQirsh => $composableBuilder(
      column: $table.paidAmountQirsh, builder: (column) => column);

  GeneratedColumn<String> get negativeBalanceApprovalId => $composableBuilder(
      column: $table.negativeBalanceApprovalId, builder: (column) => column);

  GeneratedColumn<String> get operationRequestId => $composableBuilder(
      column: $table.operationRequestId, builder: (column) => column);

  GeneratedColumn<String> get requestFingerprint => $composableBuilder(
      column: $table.requestFingerprint, builder: (column) => column);

  GeneratedColumn<DateTime> get cancelledAt => $composableBuilder(
      column: $table.cancelledAt, builder: (column) => column);

  GeneratedColumn<String> get cancelledByUserId => $composableBuilder(
      column: $table.cancelledByUserId, builder: (column) => column);

  GeneratedColumn<String> get cancellationReason => $composableBuilder(
      column: $table.cancellationReason, builder: (column) => column);

  GeneratedColumn<String> get reversalMovementIds => $composableBuilder(
      column: $table.reversalMovementIds, builder: (column) => column);
}

class $$PurchasesTableTableManager extends RootTableManager<
    _$FoundationDatabase,
    $PurchasesTable,
    Purchase,
    $$PurchasesTableFilterComposer,
    $$PurchasesTableOrderingComposer,
    $$PurchasesTableAnnotationComposer,
    $$PurchasesTableCreateCompanionBuilder,
    $$PurchasesTableUpdateCompanionBuilder,
    (Purchase, BaseReferences<_$FoundationDatabase, $PurchasesTable, Purchase>),
    Purchase,
    PrefetchHooks Function()> {
  $$PurchasesTableTableManager(_$FoundationDatabase db, $PurchasesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PurchasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PurchasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PurchasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> supplierId = const Value.absent(),
            Value<String?> supplierName = const Value.absent(),
            Value<String?> supplierPhone = const Value.absent(),
            Value<String?> supplierAddress = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<int> quantityKg = const Value.absent(),
            Value<String> entryUnit = const Value.absent(),
            Value<int> unitPricePiastersPerKg = const Value.absent(),
            Value<int> totalAmountPiasters = const Value.absent(),
            Value<String> createdByUserId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> stockMovementId = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> financialAccountId = const Value.absent(),
            Value<String?> paymentMethod = const Value.absent(),
            Value<String> paymentMode = const Value.absent(),
            Value<int?> paidAmountQirsh = const Value.absent(),
            Value<String?> negativeBalanceApprovalId = const Value.absent(),
            Value<String?> operationRequestId = const Value.absent(),
            Value<String?> requestFingerprint = const Value.absent(),
            Value<DateTime?> cancelledAt = const Value.absent(),
            Value<String?> cancelledByUserId = const Value.absent(),
            Value<String?> cancellationReason = const Value.absent(),
            Value<String?> reversalMovementIds = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchasesCompanion(
            id: id,
            supplierId: supplierId,
            supplierName: supplierName,
            supplierPhone: supplierPhone,
            supplierAddress: supplierAddress,
            productId: productId,
            quantityKg: quantityKg,
            entryUnit: entryUnit,
            unitPricePiastersPerKg: unitPricePiastersPerKg,
            totalAmountPiasters: totalAmountPiasters,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            stockMovementId: stockMovementId,
            notes: notes,
            financialAccountId: financialAccountId,
            paymentMethod: paymentMethod,
            paymentMode: paymentMode,
            paidAmountQirsh: paidAmountQirsh,
            negativeBalanceApprovalId: negativeBalanceApprovalId,
            operationRequestId: operationRequestId,
            requestFingerprint: requestFingerprint,
            cancelledAt: cancelledAt,
            cancelledByUserId: cancelledByUserId,
            cancellationReason: cancellationReason,
            reversalMovementIds: reversalMovementIds,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String supplierId,
            Value<String?> supplierName = const Value.absent(),
            Value<String?> supplierPhone = const Value.absent(),
            Value<String?> supplierAddress = const Value.absent(),
            required String productId,
            required int quantityKg,
            required String entryUnit,
            required int unitPricePiastersPerKg,
            required int totalAmountPiasters,
            required String createdByUserId,
            required DateTime createdAt,
            required String stockMovementId,
            Value<String?> notes = const Value.absent(),
            Value<String?> financialAccountId = const Value.absent(),
            Value<String?> paymentMethod = const Value.absent(),
            required String paymentMode,
            Value<int?> paidAmountQirsh = const Value.absent(),
            Value<String?> negativeBalanceApprovalId = const Value.absent(),
            Value<String?> operationRequestId = const Value.absent(),
            Value<String?> requestFingerprint = const Value.absent(),
            Value<DateTime?> cancelledAt = const Value.absent(),
            Value<String?> cancelledByUserId = const Value.absent(),
            Value<String?> cancellationReason = const Value.absent(),
            Value<String?> reversalMovementIds = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchasesCompanion.insert(
            id: id,
            supplierId: supplierId,
            supplierName: supplierName,
            supplierPhone: supplierPhone,
            supplierAddress: supplierAddress,
            productId: productId,
            quantityKg: quantityKg,
            entryUnit: entryUnit,
            unitPricePiastersPerKg: unitPricePiastersPerKg,
            totalAmountPiasters: totalAmountPiasters,
            createdByUserId: createdByUserId,
            createdAt: createdAt,
            stockMovementId: stockMovementId,
            notes: notes,
            financialAccountId: financialAccountId,
            paymentMethod: paymentMethod,
            paymentMode: paymentMode,
            paidAmountQirsh: paidAmountQirsh,
            negativeBalanceApprovalId: negativeBalanceApprovalId,
            operationRequestId: operationRequestId,
            requestFingerprint: requestFingerprint,
            cancelledAt: cancelledAt,
            cancelledByUserId: cancelledByUserId,
            cancellationReason: cancellationReason,
            reversalMovementIds: reversalMovementIds,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PurchasesTableProcessedTableManager = ProcessedTableManager<
    _$FoundationDatabase,
    $PurchasesTable,
    Purchase,
    $$PurchasesTableFilterComposer,
    $$PurchasesTableOrderingComposer,
    $$PurchasesTableAnnotationComposer,
    $$PurchasesTableCreateCompanionBuilder,
    $$PurchasesTableUpdateCompanionBuilder,
    (Purchase, BaseReferences<_$FoundationDatabase, $PurchasesTable, Purchase>),
    Purchase,
    PrefetchHooks Function()>;
typedef $$SalesTableCreateCompanionBuilder = SalesCompanion Function({
  required String id,
  required String productId,
  required int quantityKg,
  required int salePriceQirshPerKg,
  required int totalQirsh,
  required String createdByUserId,
  Value<String?> createdByUserName,
  required DateTime createdAt,
  required String stockMovementId,
  required String paymentMode,
  Value<String?> customerId,
  Value<String?> notes,
  required String itemsJson,
  Value<int?> paidAmountQirsh,
  Value<String?> financialAccountId,
  Value<String?> paymentMethod,
  required String paymentAllocationsJson,
  Value<String?> operationRequestId,
  Value<DateTime?> cancelledAt,
  Value<String?> cancelledByUserId,
  Value<String?> cancellationReason,
  Value<String?> reversalMovementIdsJson,
  Value<int> rowid,
});
typedef $$SalesTableUpdateCompanionBuilder = SalesCompanion Function({
  Value<String> id,
  Value<String> productId,
  Value<int> quantityKg,
  Value<int> salePriceQirshPerKg,
  Value<int> totalQirsh,
  Value<String> createdByUserId,
  Value<String?> createdByUserName,
  Value<DateTime> createdAt,
  Value<String> stockMovementId,
  Value<String> paymentMode,
  Value<String?> customerId,
  Value<String?> notes,
  Value<String> itemsJson,
  Value<int?> paidAmountQirsh,
  Value<String?> financialAccountId,
  Value<String?> paymentMethod,
  Value<String> paymentAllocationsJson,
  Value<String?> operationRequestId,
  Value<DateTime?> cancelledAt,
  Value<String?> cancelledByUserId,
  Value<String?> cancellationReason,
  Value<String?> reversalMovementIdsJson,
  Value<int> rowid,
});

class $$SalesTableFilterComposer
    extends Composer<_$FoundationDatabase, $SalesTable> {
  $$SalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantityKg => $composableBuilder(
      column: $table.quantityKg, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get salePriceQirshPerKg => $composableBuilder(
      column: $table.salePriceQirshPerKg,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalQirsh => $composableBuilder(
      column: $table.totalQirsh, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdByUserId => $composableBuilder(
      column: $table.createdByUserId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdByUserName => $composableBuilder(
      column: $table.createdByUserName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stockMovementId => $composableBuilder(
      column: $table.stockMovementId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get paymentMode => $composableBuilder(
      column: $table.paymentMode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemsJson => $composableBuilder(
      column: $table.itemsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get paidAmountQirsh => $composableBuilder(
      column: $table.paidAmountQirsh,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get financialAccountId => $composableBuilder(
      column: $table.financialAccountId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get paymentAllocationsJson => $composableBuilder(
      column: $table.paymentAllocationsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operationRequestId => $composableBuilder(
      column: $table.operationRequestId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cancelledAt => $composableBuilder(
      column: $table.cancelledAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cancelledByUserId => $composableBuilder(
      column: $table.cancelledByUserId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cancellationReason => $composableBuilder(
      column: $table.cancellationReason,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reversalMovementIdsJson => $composableBuilder(
      column: $table.reversalMovementIdsJson,
      builder: (column) => ColumnFilters(column));
}

class $$SalesTableOrderingComposer
    extends Composer<_$FoundationDatabase, $SalesTable> {
  $$SalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantityKg => $composableBuilder(
      column: $table.quantityKg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get salePriceQirshPerKg => $composableBuilder(
      column: $table.salePriceQirshPerKg,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalQirsh => $composableBuilder(
      column: $table.totalQirsh, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdByUserId => $composableBuilder(
      column: $table.createdByUserId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdByUserName => $composableBuilder(
      column: $table.createdByUserName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stockMovementId => $composableBuilder(
      column: $table.stockMovementId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get paymentMode => $composableBuilder(
      column: $table.paymentMode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemsJson => $composableBuilder(
      column: $table.itemsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paidAmountQirsh => $composableBuilder(
      column: $table.paidAmountQirsh,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get financialAccountId => $composableBuilder(
      column: $table.financialAccountId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get paymentAllocationsJson => $composableBuilder(
      column: $table.paymentAllocationsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operationRequestId => $composableBuilder(
      column: $table.operationRequestId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cancelledAt => $composableBuilder(
      column: $table.cancelledAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cancelledByUserId => $composableBuilder(
      column: $table.cancelledByUserId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cancellationReason => $composableBuilder(
      column: $table.cancellationReason,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reversalMovementIdsJson => $composableBuilder(
      column: $table.reversalMovementIdsJson,
      builder: (column) => ColumnOrderings(column));
}

class $$SalesTableAnnotationComposer
    extends Composer<_$FoundationDatabase, $SalesTable> {
  $$SalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<int> get quantityKg => $composableBuilder(
      column: $table.quantityKg, builder: (column) => column);

  GeneratedColumn<int> get salePriceQirshPerKg => $composableBuilder(
      column: $table.salePriceQirshPerKg, builder: (column) => column);

  GeneratedColumn<int> get totalQirsh => $composableBuilder(
      column: $table.totalQirsh, builder: (column) => column);

  GeneratedColumn<String> get createdByUserId => $composableBuilder(
      column: $table.createdByUserId, builder: (column) => column);

  GeneratedColumn<String> get createdByUserName => $composableBuilder(
      column: $table.createdByUserName, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get stockMovementId => $composableBuilder(
      column: $table.stockMovementId, builder: (column) => column);

  GeneratedColumn<String> get paymentMode => $composableBuilder(
      column: $table.paymentMode, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<int> get paidAmountQirsh => $composableBuilder(
      column: $table.paidAmountQirsh, builder: (column) => column);

  GeneratedColumn<String> get financialAccountId => $composableBuilder(
      column: $table.financialAccountId, builder: (column) => column);

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
      column: $table.paymentMethod, builder: (column) => column);

  GeneratedColumn<String> get paymentAllocationsJson => $composableBuilder(
      column: $table.paymentAllocationsJson, builder: (column) => column);

  GeneratedColumn<String> get operationRequestId => $composableBuilder(
      column: $table.operationRequestId, builder: (column) => column);

  GeneratedColumn<DateTime> get cancelledAt => $composableBuilder(
      column: $table.cancelledAt, builder: (column) => column);

  GeneratedColumn<String> get cancelledByUserId => $composableBuilder(
      column: $table.cancelledByUserId, builder: (column) => column);

  GeneratedColumn<String> get cancellationReason => $composableBuilder(
      column: $table.cancellationReason, builder: (column) => column);

  GeneratedColumn<String> get reversalMovementIdsJson => $composableBuilder(
      column: $table.reversalMovementIdsJson, builder: (column) => column);
}

class $$SalesTableTableManager extends RootTableManager<
    _$FoundationDatabase,
    $SalesTable,
    Sale,
    $$SalesTableFilterComposer,
    $$SalesTableOrderingComposer,
    $$SalesTableAnnotationComposer,
    $$SalesTableCreateCompanionBuilder,
    $$SalesTableUpdateCompanionBuilder,
    (Sale, BaseReferences<_$FoundationDatabase, $SalesTable, Sale>),
    Sale,
    PrefetchHooks Function()> {
  $$SalesTableTableManager(_$FoundationDatabase db, $SalesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<int> quantityKg = const Value.absent(),
            Value<int> salePriceQirshPerKg = const Value.absent(),
            Value<int> totalQirsh = const Value.absent(),
            Value<String> createdByUserId = const Value.absent(),
            Value<String?> createdByUserName = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> stockMovementId = const Value.absent(),
            Value<String> paymentMode = const Value.absent(),
            Value<String?> customerId = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String> itemsJson = const Value.absent(),
            Value<int?> paidAmountQirsh = const Value.absent(),
            Value<String?> financialAccountId = const Value.absent(),
            Value<String?> paymentMethod = const Value.absent(),
            Value<String> paymentAllocationsJson = const Value.absent(),
            Value<String?> operationRequestId = const Value.absent(),
            Value<DateTime?> cancelledAt = const Value.absent(),
            Value<String?> cancelledByUserId = const Value.absent(),
            Value<String?> cancellationReason = const Value.absent(),
            Value<String?> reversalMovementIdsJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SalesCompanion(
            id: id,
            productId: productId,
            quantityKg: quantityKg,
            salePriceQirshPerKg: salePriceQirshPerKg,
            totalQirsh: totalQirsh,
            createdByUserId: createdByUserId,
            createdByUserName: createdByUserName,
            createdAt: createdAt,
            stockMovementId: stockMovementId,
            paymentMode: paymentMode,
            customerId: customerId,
            notes: notes,
            itemsJson: itemsJson,
            paidAmountQirsh: paidAmountQirsh,
            financialAccountId: financialAccountId,
            paymentMethod: paymentMethod,
            paymentAllocationsJson: paymentAllocationsJson,
            operationRequestId: operationRequestId,
            cancelledAt: cancelledAt,
            cancelledByUserId: cancelledByUserId,
            cancellationReason: cancellationReason,
            reversalMovementIdsJson: reversalMovementIdsJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String productId,
            required int quantityKg,
            required int salePriceQirshPerKg,
            required int totalQirsh,
            required String createdByUserId,
            Value<String?> createdByUserName = const Value.absent(),
            required DateTime createdAt,
            required String stockMovementId,
            required String paymentMode,
            Value<String?> customerId = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            required String itemsJson,
            Value<int?> paidAmountQirsh = const Value.absent(),
            Value<String?> financialAccountId = const Value.absent(),
            Value<String?> paymentMethod = const Value.absent(),
            required String paymentAllocationsJson,
            Value<String?> operationRequestId = const Value.absent(),
            Value<DateTime?> cancelledAt = const Value.absent(),
            Value<String?> cancelledByUserId = const Value.absent(),
            Value<String?> cancellationReason = const Value.absent(),
            Value<String?> reversalMovementIdsJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SalesCompanion.insert(
            id: id,
            productId: productId,
            quantityKg: quantityKg,
            salePriceQirshPerKg: salePriceQirshPerKg,
            totalQirsh: totalQirsh,
            createdByUserId: createdByUserId,
            createdByUserName: createdByUserName,
            createdAt: createdAt,
            stockMovementId: stockMovementId,
            paymentMode: paymentMode,
            customerId: customerId,
            notes: notes,
            itemsJson: itemsJson,
            paidAmountQirsh: paidAmountQirsh,
            financialAccountId: financialAccountId,
            paymentMethod: paymentMethod,
            paymentAllocationsJson: paymentAllocationsJson,
            operationRequestId: operationRequestId,
            cancelledAt: cancelledAt,
            cancelledByUserId: cancelledByUserId,
            cancellationReason: cancellationReason,
            reversalMovementIdsJson: reversalMovementIdsJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SalesTableProcessedTableManager = ProcessedTableManager<
    _$FoundationDatabase,
    $SalesTable,
    Sale,
    $$SalesTableFilterComposer,
    $$SalesTableOrderingComposer,
    $$SalesTableAnnotationComposer,
    $$SalesTableCreateCompanionBuilder,
    $$SalesTableUpdateCompanionBuilder,
    (Sale, BaseReferences<_$FoundationDatabase, $SalesTable, Sale>),
    Sale,
    PrefetchHooks Function()>;

class $FoundationDatabaseManager {
  final _$FoundationDatabase _db;
  $FoundationDatabaseManager(this._db);
  $$FoundationProbesTableTableManager get foundationProbes =>
      $$FoundationProbesTableTableManager(_db, _db.foundationProbes);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$RepositorySequencesTableTableManager get repositorySequences =>
      $$RepositorySequencesTableTableManager(_db, _db.repositorySequences);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db, _db.customers);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db, _db.suppliers);
  $$InventoryMovementsTableTableManager get inventoryMovements =>
      $$InventoryMovementsTableTableManager(_db, _db.inventoryMovements);
  $$PurchasesTableTableManager get purchases =>
      $$PurchasesTableTableManager(_db, _db.purchases);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db, _db.sales);
}
