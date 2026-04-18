class PumpReadings {
  const PumpReadings({
    required this.petrol,
    required this.diesel,
    required this.twoT,
  });

  final double petrol;
  final double diesel;
  final double twoT;

  factory PumpReadings.fromJson(Map<String, dynamic> json) {
    return PumpReadings(
      petrol: (json['petrol'] as num?)?.toDouble() ?? 0,
      diesel: (json['diesel'] as num?)?.toDouble() ?? 0,
      twoT: (json['twoT'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'petrol': petrol, 'diesel': diesel, 'twoT': twoT};
  }
}

class PaymentBreakdownModel {
  const PaymentBreakdownModel({
    required this.cash,
    required this.check,
    required this.upi,
  });

  final double cash;
  final double check;
  final double upi;

  factory PaymentBreakdownModel.fromJson(Map<String, dynamic> json) {
    return PaymentBreakdownModel(
      cash: (json['cash'] as num?)?.toDouble() ?? 0,
      check: (json['check'] as num?)?.toDouble() ?? 0,
      upi: (json['upi'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'cash': cash, 'check': check, 'upi': upi};
  }
}

class PumpPaymentBreakdownModel {
  const PumpPaymentBreakdownModel({
    required this.cash,
    required this.check,
    required this.upi,
    required this.credit,
  });

  final double cash;
  final double check;
  final double upi;
  final double credit;

  double get total => cash + check + upi + credit;

  factory PumpPaymentBreakdownModel.fromJson(Map<String, dynamic> json) {
    return PumpPaymentBreakdownModel(
      cash: (json['cash'] as num?)?.toDouble() ?? 0,
      check: (json['check'] as num?)?.toDouble() ?? 0,
      upi: (json['upi'] as num?)?.toDouble() ?? 0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'cash': cash, 'check': check, 'upi': upi, 'credit': credit};
  }
}

class CreditEntryModel {
  const CreditEntryModel({
    this.pumpId = '',
    required this.customerId,
    required this.name,
    required this.amount,
  });

  final String pumpId;
  final String customerId;
  final String name;
  final double amount;

  factory CreditEntryModel.fromJson(Map<String, dynamic> json) {
    return CreditEntryModel(
      pumpId: json['pumpId']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pumpId': pumpId,
      'customerId': customerId,
      'name': name,
      'amount': amount,
    };
  }
}

class CreditCollectionModel {
  const CreditCollectionModel({
    required this.customerId,
    required this.name,
    required this.amount,
    required this.date,
    required this.paymentMode,
    this.note = '',
  });

  final String customerId;
  final String name;
  final double amount;
  final String date;
  final String paymentMode;
  final String note;

  factory CreditCollectionModel.fromJson(Map<String, dynamic> json) {
    return CreditCollectionModel(
      customerId: json['customerId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: json['date']?.toString() ?? '',
      paymentMode: json['paymentMode']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'name': name,
      'amount': amount,
      'date': date,
      'paymentMode': paymentMode,
      'note': note,
    };
  }
}

double parseTestingQuantity(dynamic value) {
  if (value == true) {
    return 5;
  }
  if (value == false || value == null) {
    return 0;
  }
  if (value is num) {
    return value > 0 ? value.toDouble() : 0;
  }
  final parsed = double.tryParse(value.toString().trim());
  if (parsed == null || parsed <= 0) {
    return 0;
  }
  return parsed;
}

class PumpTestingModel {
  const PumpTestingModel({
    required this.petrol,
    required this.diesel,
    this.addToInventory = false,
  });

  final double petrol;
  final double diesel;
  final bool addToInventory;

  bool get enabled => petrol > 0 || diesel > 0;

  Map<String, dynamic> toJson() {
    return {
      'petrol': petrol,
      'diesel': diesel,
      'addToInventory': addToInventory,
    };
  }
}

PumpTestingModel parsePumpTesting(dynamic value) {
  if (value is Map<String, dynamic>) {
    return PumpTestingModel(
      petrol: parseTestingQuantity(value['petrol']),
      diesel: parseTestingQuantity(value['diesel']),
      addToInventory: value['addToInventory'] == true,
    );
  }
  if (value is Map) {
    return PumpTestingModel(
      petrol: parseTestingQuantity(value['petrol']),
      diesel: parseTestingQuantity(value['diesel']),
      addToInventory: value['addToInventory'] == true,
    );
  }
  final quantity = parseTestingQuantity(value);
  return PumpTestingModel(petrol: quantity, diesel: quantity);
}

class DailyEntryDraft {
  const DailyEntryDraft({
    required this.date,
    required this.closingReadings,
    required this.pumpAttendants,
    required this.pumpTesting,
    required this.pumpPayments,
    required this.pumpCollections,
    required this.paymentBreakdown,
    required this.creditEntries,
    required this.creditCollections,
    this.pumpMismatchReasons = const {},
    this.mismatchReason = '',
  });

  final String date;
  final Map<String, PumpReadings> closingReadings;
  final Map<String, String> pumpAttendants;
  final Map<String, PumpTestingModel> pumpTesting;
  final Map<String, PumpPaymentBreakdownModel> pumpPayments;
  final Map<String, double> pumpCollections;
  final PaymentBreakdownModel paymentBreakdown;
  final List<CreditEntryModel> creditEntries;
  final List<CreditCollectionModel> creditCollections;
  final Map<String, String> pumpMismatchReasons;
  final String mismatchReason;

  DailyEntryDraft copyWith({
    String? date,
    Map<String, PumpReadings>? closingReadings,
    Map<String, String>? pumpAttendants,
    Map<String, PumpTestingModel>? pumpTesting,
    Map<String, PumpPaymentBreakdownModel>? pumpPayments,
    Map<String, double>? pumpCollections,
    PaymentBreakdownModel? paymentBreakdown,
    List<CreditEntryModel>? creditEntries,
    List<CreditCollectionModel>? creditCollections,
    Map<String, String>? pumpMismatchReasons,
    String? mismatchReason,
  }) {
    return DailyEntryDraft(
      date: date ?? this.date,
      closingReadings: closingReadings ?? this.closingReadings,
      pumpAttendants: pumpAttendants ?? this.pumpAttendants,
      pumpTesting: pumpTesting ?? this.pumpTesting,
      pumpPayments: pumpPayments ?? this.pumpPayments,
      pumpCollections: pumpCollections ?? this.pumpCollections,
      paymentBreakdown: paymentBreakdown ?? this.paymentBreakdown,
      creditEntries: creditEntries ?? this.creditEntries,
      creditCollections: creditCollections ?? this.creditCollections,
      pumpMismatchReasons: pumpMismatchReasons ?? this.pumpMismatchReasons,
      mismatchReason: mismatchReason ?? this.mismatchReason,
    );
  }
}

class PumpEntryDraft {
  const PumpEntryDraft({
    required this.attendant,
    required this.closingReadings,
    required this.testing,
    required this.payments,
    this.creditEntries = const [],
    this.mismatchReason = '',
  });

  final String attendant;
  final PumpReadings? closingReadings;
  final PumpTestingModel testing;
  final PumpPaymentBreakdownModel payments;
  final List<CreditEntryModel> creditEntries;
  final String mismatchReason;

  bool get testingEnabled => testing.enabled;
}

class PaymentEntryDraft {
  const PaymentEntryDraft({
    required this.paymentBreakdown,
    required this.creditEntries,
    required this.creditCollections,
  });

  final PaymentBreakdownModel paymentBreakdown;
  final List<CreditEntryModel> creditEntries;
  final List<CreditCollectionModel> creditCollections;
}

class FuelTotals {
  const FuelTotals({
    required this.petrol,
    required this.diesel,
    required this.twoT,
  });

  final double petrol;
  final double diesel;
  final double twoT;

  factory FuelTotals.fromJson(Map<String, dynamic> json) {
    return FuelTotals(
      petrol: (json['petrol'] as num?)?.toDouble() ?? 0,
      diesel: (json['diesel'] as num?)?.toDouble() ?? 0,
      twoT: (json['twoT'] as num?)?.toDouble() ?? 0,
    );
  }
}

class EntryTotals {
  const EntryTotals({
    required this.opening,
    required this.closing,
    required this.sold,
  });

  final FuelTotals opening;
  final FuelTotals closing;
  final FuelTotals sold;

  factory EntryTotals.fromJson(Map<String, dynamic> json) {
    return EntryTotals(
      opening: FuelTotals.fromJson(
        json['opening'] as Map<String, dynamic>? ?? const {},
      ),
      closing: FuelTotals.fromJson(
        json['closing'] as Map<String, dynamic>? ?? const {},
      ),
      sold: FuelTotals.fromJson(
        json['sold'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class FuelTypeModel {
  const FuelTypeModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required this.color,
    required this.icon,
    required this.active,
    this.createdAt = '',
  });

  final String id;
  final String name;
  final String shortName;
  final String description;
  final String color;
  final String icon;
  final bool active;
  final String createdAt;

  factory FuelTypeModel.fromJson(Map<String, dynamic> json) {
    return FuelTypeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      shortName: json['shortName']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      color: json['color']?.toString() ?? '#1E5CBA',
      icon: json['icon']?.toString() ?? 'local_gas_station',
      active: json['active'] as bool? ?? true,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'shortName': shortName,
      'description': description,
      'color': color,
      'icon': icon,
      'active': active,
      'createdAt': createdAt,
    };
  }
}

String _fuelPriceDateKeyForNow() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

String _normalizedFuelPriceDateKey(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.length >= 10) {
    final prefix = trimmed.substring(0, 10);
    final matched = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(prefix);
    if (matched) {
      return prefix;
    }
  }
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) {
    return '';
  }
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day';
}

int _compareFuelPricePeriods(
  FuelPricePeriodModel left,
  FuelPricePeriodModel right,
) {
  final leftFrom = _normalizedFuelPriceDateKey(left.effectiveFrom);
  final rightFrom = _normalizedFuelPriceDateKey(right.effectiveFrom);
  final fromCompare = leftFrom.compareTo(rightFrom);
  if (fromCompare != 0) {
    return fromCompare;
  }
  final leftTo = _normalizedFuelPriceDateKey(left.effectiveTo);
  final rightTo = _normalizedFuelPriceDateKey(right.effectiveTo);
  return leftTo.compareTo(rightTo);
}

bool _fuelPricePeriodAppliesOn(
  FuelPricePeriodModel period,
  String referenceDate,
) {
  if (period.isDeleted) {
    return false;
  }
  final effectiveFrom = _normalizedFuelPriceDateKey(period.effectiveFrom);
  if (effectiveFrom.isEmpty || effectiveFrom.compareTo(referenceDate) > 0) {
    return false;
  }
  final effectiveTo = _normalizedFuelPriceDateKey(period.effectiveTo);
  return effectiveTo.isEmpty || effectiveTo.compareTo(referenceDate) >= 0;
}

FuelPricePeriodModel? _resolveActiveFuelPricePeriod(
  List<FuelPricePeriodModel> periods,
) {
  if (periods.isEmpty) {
    return null;
  }
  final sorted =
      periods.where((period) => !period.isDeleted).toList()
        ..sort(_compareFuelPricePeriods);
  final todayKey = _fuelPriceDateKeyForNow();
  final applicable = sorted.where(
    (period) => _fuelPricePeriodAppliesOn(period, todayKey),
  );
  if (applicable.isNotEmpty) {
    return applicable.last;
  }
  final started = sorted.where(
    (period) =>
        _normalizedFuelPriceDateKey(period.effectiveFrom).compareTo(todayKey) <=
        0,
  );
  if (started.isNotEmpty) {
    return started.last;
  }
  return sorted.first;
}

class FuelPriceModel {
  const FuelPriceModel({
    required this.fuelTypeId,
    required this.costPrice,
    required this.sellingPrice,
    required this.updatedAt,
    required this.updatedBy,
    this.effectiveFrom = '',
    this.effectiveTo = '',
    this.periods = const [],
  });

  final String fuelTypeId;
  final double costPrice;
  final double sellingPrice;
  final String updatedAt;
  final String updatedBy;
  final String effectiveFrom;
  final String effectiveTo;
  final List<FuelPricePeriodModel> periods;

  FuelPricePeriodModel? get activePeriod {
    return _resolveActiveFuelPricePeriod(periods);
  }

  factory FuelPriceModel.fromJson(Map<String, dynamic> json) {
    final parsedPeriods =
        (json['periods'] as List<dynamic>? ?? const [])
            .map(
              (item) => FuelPricePeriodModel.fromJson(
                item as Map<String, dynamic>? ?? const {},
              ),
            )
            .toList();
    final periods =
        parsedPeriods.isNotEmpty
            ? parsedPeriods
            : [
              FuelPricePeriodModel(
                effectiveFrom: json['effectiveFrom']?.toString() ?? '',
                effectiveTo: json['effectiveTo']?.toString() ?? '',
                costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
                sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0,
                updatedAt: json['updatedAt']?.toString() ?? '',
                updatedBy: json['updatedBy']?.toString() ?? '',
              ),
            ];
    return FuelPriceModel(
      fuelTypeId: json['fuelTypeId']?.toString() ?? '',
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0,
      updatedAt: json['updatedAt']?.toString() ?? '',
      updatedBy: json['updatedBy']?.toString() ?? '',
      effectiveFrom: json['effectiveFrom']?.toString() ?? '',
      effectiveTo: json['effectiveTo']?.toString() ?? '',
      periods: periods,
    );
  }

  FuelPriceModel copyWith({
    String? fuelTypeId,
    double? costPrice,
    double? sellingPrice,
    String? updatedAt,
    String? updatedBy,
    String? effectiveFrom,
    String? effectiveTo,
    List<FuelPricePeriodModel>? periods,
  }) {
    return FuelPriceModel(
      fuelTypeId: fuelTypeId ?? this.fuelTypeId,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      periods: periods ?? this.periods,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fuelTypeId': fuelTypeId,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
      'effectiveFrom': effectiveFrom,
      'effectiveTo': effectiveTo,
      'periods': periods.map((item) => item.toJson()).toList(),
    };
  }
}

class FuelPricePeriodModel {
  const FuelPricePeriodModel({
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.costPrice,
    required this.sellingPrice,
    required this.updatedAt,
    required this.updatedBy,
    this.deletedAt = '',
    this.deletedBy = '',
    this.deletedByName = '',
  });

  final String effectiveFrom;
  final String effectiveTo;
  final double costPrice;
  final double sellingPrice;
  final String updatedAt;
  final String updatedBy;
  final String deletedAt;
  final String deletedBy;
  final String deletedByName;

  bool get isDeleted => deletedAt.trim().isNotEmpty;

  factory FuelPricePeriodModel.fromJson(Map<String, dynamic> json) {
    return FuelPricePeriodModel(
      effectiveFrom: json['effectiveFrom']?.toString() ?? '',
      effectiveTo: json['effectiveTo']?.toString() ?? '',
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0,
      updatedAt: json['updatedAt']?.toString() ?? '',
      updatedBy: json['updatedBy']?.toString() ?? '',
      deletedAt: json['deletedAt']?.toString() ?? '',
      deletedBy: json['deletedBy']?.toString() ?? '',
      deletedByName: json['deletedByName']?.toString() ?? '',
    );
  }

  FuelPricePeriodModel copyWith({
    String? effectiveFrom,
    String? effectiveTo,
    double? costPrice,
    double? sellingPrice,
    String? updatedAt,
    String? updatedBy,
    String? deletedAt,
    String? deletedBy,
    String? deletedByName,
  }) {
    return FuelPricePeriodModel(
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      deletedByName: deletedByName ?? this.deletedByName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'effectiveFrom': effectiveFrom,
      'effectiveTo': effectiveTo,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
      'deletedAt': deletedAt,
      'deletedBy': deletedBy,
      'deletedByName': deletedByName,
    };
  }
}

class StationPumpModel {
  const StationPumpModel({required this.id, required this.label});

  final String id;
  final String label;

  factory StationPumpModel.fromJson(Map<String, dynamic> json) {
    return StationPumpModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label};
  }
}

class InventoryPlanningModel {
  const InventoryPlanningModel({
    required this.openingStock,
    required this.currentStock,
    required this.deliveryLeadDays,
    required this.alertBeforeDays,
    required this.updatedAt,
  });

  final Map<String, double> openingStock;
  final Map<String, double> currentStock;
  final int deliveryLeadDays;
  final int alertBeforeDays;
  final String updatedAt;

  factory InventoryPlanningModel.fromJson(Map<String, dynamic> json) {
    final openingStock =
        json['openingStock'] as Map<String, dynamic>? ??
        json['currentStock'] as Map<String, dynamic>? ??
        const {};
    final currentStock =
        json['currentStock'] as Map<String, dynamic>? ??
        json['openingStock'] as Map<String, dynamic>? ??
        const {};
    return InventoryPlanningModel(
      openingStock: {
        'petrol': (openingStock['petrol'] as num?)?.toDouble() ?? 0,
        'diesel': (openingStock['diesel'] as num?)?.toDouble() ?? 0,
        'two_t_oil': (openingStock['two_t_oil'] as num?)?.toDouble() ?? 0,
      },
      currentStock: {
        'petrol': (currentStock['petrol'] as num?)?.toDouble() ?? 0,
        'diesel': (currentStock['diesel'] as num?)?.toDouble() ?? 0,
        'two_t_oil': (currentStock['two_t_oil'] as num?)?.toDouble() ?? 0,
      },
      deliveryLeadDays: (json['deliveryLeadDays'] as num?)?.toInt() ?? 0,
      alertBeforeDays: (json['alertBeforeDays'] as num?)?.toInt() ?? 0,
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'openingStock': openingStock,
      'currentStock': currentStock,
      'deliveryLeadDays': deliveryLeadDays,
      'alertBeforeDays': alertBeforeDays,
      'updatedAt': updatedAt,
    };
  }
}

class InventoryStockSnapshotModel {
  const InventoryStockSnapshotModel({
    required this.id,
    required this.stationId,
    required this.effectiveDate,
    required this.stock,
    required this.note,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    this.deletedAt = '',
    this.deletedBy = '',
    this.deletedByName = '',
  });

  final String id;
  final String stationId;
  final String effectiveDate;
  final Map<String, double> stock;
  final String note;
  final String createdAt;
  final String createdBy;
  final String createdByName;
  final String deletedAt;
  final String deletedBy;
  final String deletedByName;

  bool get isDeleted => deletedAt.trim().isNotEmpty;

  factory InventoryStockSnapshotModel.fromJson(Map<String, dynamic> json) {
    final stock = json['stock'] as Map<String, dynamic>? ?? const {};
    return InventoryStockSnapshotModel(
      id: json['id']?.toString() ?? '',
      stationId: json['stationId']?.toString() ?? '',
      effectiveDate: json['effectiveDate']?.toString() ?? '',
      stock: {
        'petrol': (stock['petrol'] as num?)?.toDouble() ?? 0,
        'diesel': (stock['diesel'] as num?)?.toDouble() ?? 0,
        'two_t_oil': (stock['two_t_oil'] as num?)?.toDouble() ?? 0,
      },
      note: json['note']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? '',
      createdByName: json['createdByName']?.toString() ?? '',
      deletedAt: json['deletedAt']?.toString() ?? '',
      deletedBy: json['deletedBy']?.toString() ?? '',
      deletedByName: json['deletedByName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationId': stationId,
      'effectiveDate': effectiveDate,
      'stock': stock,
      'note': note,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'deletedAt': deletedAt,
      'deletedBy': deletedBy,
      'deletedByName': deletedByName,
    };
  }
}

class PumpOpeningReadingLogModel {
  const PumpOpeningReadingLogModel({
    required this.id,
    required this.stationId,
    required this.effectiveDate,
    required this.readings,
    required this.note,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    this.deletedAt = '',
    this.deletedBy = '',
    this.deletedByName = '',
  });

  final String id;
  final String stationId;
  final String effectiveDate;
  final Map<String, PumpReadings> readings;
  final String note;
  final String createdAt;
  final String createdBy;
  final String createdByName;
  final String deletedAt;
  final String deletedBy;
  final String deletedByName;

  bool get isDeleted => deletedAt.trim().isNotEmpty;

  factory PumpOpeningReadingLogModel.fromJson(Map<String, dynamic> json) {
    final readingsJson = json['readings'] as Map<String, dynamic>? ?? const {};
    return PumpOpeningReadingLogModel(
      id: json['id']?.toString() ?? '',
      stationId: json['stationId']?.toString() ?? '',
      effectiveDate: json['effectiveDate']?.toString() ?? '',
      readings: readingsJson.map(
        (key, value) =>
            MapEntry(key, PumpReadings.fromJson(value as Map<String, dynamic>)),
      ),
      note: json['note']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? '',
      createdByName: json['createdByName']?.toString() ?? '',
      deletedAt: json['deletedAt']?.toString() ?? '',
      deletedBy: json['deletedBy']?.toString() ?? '',
      deletedByName: json['deletedByName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationId': stationId,
      'effectiveDate': effectiveDate,
      'readings': readings.map((key, value) => MapEntry(key, value.toJson())),
      'note': note,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'deletedAt': deletedAt,
      'deletedBy': deletedBy,
      'deletedByName': deletedByName,
    };
  }
}

class StationDaySetupModel {
  const StationDaySetupModel({
    required this.id,
    required this.stationId,
    required this.effectiveDate,
    required this.openingReadings,
    required this.startingStock,
    required this.fuelPrices,
    required this.note,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    this.updatedAt = '',
    this.updatedBy = '',
    this.updatedByName = '',
    this.deletedAt = '',
    this.deletedBy = '',
    this.deletedByName = '',
    this.lockedAt = '',
    this.lockedBy = '',
    this.lockedByName = '',
  });

  final String id;
  final String stationId;
  final String effectiveDate;
  final Map<String, PumpReadings> openingReadings;
  final Map<String, double> startingStock;
  final Map<String, Map<String, double>> fuelPrices;
  final String note;
  final String createdAt;
  final String createdBy;
  final String createdByName;
  final String updatedAt;
  final String updatedBy;
  final String updatedByName;
  final String deletedAt;
  final String deletedBy;
  final String deletedByName;
  final String lockedAt;
  final String lockedBy;
  final String lockedByName;

  bool get isDeleted => deletedAt.trim().isNotEmpty;
  bool get isLocked => lockedAt.trim().isNotEmpty;

  factory StationDaySetupModel.fromJson(Map<String, dynamic> json) {
    final openingJson =
        json['openingReadings'] as Map<String, dynamic>? ?? const {};
    final stockJson =
        json['startingStock'] as Map<String, dynamic>? ?? const {};
    final pricesJson = json['fuelPrices'] as Map<String, dynamic>? ?? const {};
    return StationDaySetupModel(
      id: json['id']?.toString() ?? '',
      stationId: json['stationId']?.toString() ?? '',
      effectiveDate: json['effectiveDate']?.toString() ?? '',
      openingReadings: openingJson.map(
        (key, value) =>
            MapEntry(key, PumpReadings.fromJson(value as Map<String, dynamic>)),
      ),
      startingStock: {
        'petrol': (stockJson['petrol'] as num?)?.toDouble() ?? 0,
        'diesel': (stockJson['diesel'] as num?)?.toDouble() ?? 0,
        'two_t_oil': (stockJson['two_t_oil'] as num?)?.toDouble() ?? 0,
      },
      fuelPrices: pricesJson.map((key, value) {
        final priceJson = value as Map<String, dynamic>? ?? const {};
        return MapEntry(key, {
          'costPrice': (priceJson['costPrice'] as num?)?.toDouble() ?? 0,
          'sellingPrice': (priceJson['sellingPrice'] as num?)?.toDouble() ?? 0,
        });
      }),
      note: json['note']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? '',
      createdByName: json['createdByName']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
      updatedBy: json['updatedBy']?.toString() ?? '',
      updatedByName: json['updatedByName']?.toString() ?? '',
      deletedAt: json['deletedAt']?.toString() ?? '',
      deletedBy: json['deletedBy']?.toString() ?? '',
      deletedByName: json['deletedByName']?.toString() ?? '',
      lockedAt: json['lockedAt']?.toString() ?? '',
      lockedBy: json['lockedBy']?.toString() ?? '',
      lockedByName: json['lockedByName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationId': stationId,
      'effectiveDate': effectiveDate,
      'openingReadings': openingReadings.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'startingStock': startingStock,
      'fuelPrices': fuelPrices,
      'note': note,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
      'updatedByName': updatedByName,
      'deletedAt': deletedAt,
      'deletedBy': deletedBy,
      'deletedByName': deletedByName,
      'lockedAt': lockedAt,
      'lockedBy': lockedBy,
      'lockedByName': lockedByName,
    };
  }
}

class FuelPriceUpdateRequestModel {
  const FuelPriceUpdateRequestModel({
    required this.id,
    required this.stationId,
    required this.effectiveDate,
    required this.currentPrices,
    required this.requestedPrices,
    required this.note,
    required this.status,
    required this.requestedAt,
    required this.requestedBy,
    required this.requestedByName,
    this.reviewedAt = '',
    this.reviewedBy = '',
    this.reviewedByName = '',
    this.reviewNote = '',
  });

  final String id;
  final String stationId;
  final String effectiveDate;
  final Map<String, Map<String, double>> currentPrices;
  final Map<String, Map<String, double>> requestedPrices;
  final String note;
  final String status;
  final String requestedAt;
  final String requestedBy;
  final String requestedByName;
  final String reviewedAt;
  final String reviewedBy;
  final String reviewedByName;
  final String reviewNote;

  bool get isPending => status.trim().toLowerCase() == 'pending';
  bool get isApproved => status.trim().toLowerCase() == 'approved';
  bool get isRejected => status.trim().toLowerCase() == 'rejected';

  factory FuelPriceUpdateRequestModel.fromJson(Map<String, dynamic> json) {
    return FuelPriceUpdateRequestModel(
      id: json['id']?.toString() ?? '',
      stationId: json['stationId']?.toString() ?? '',
      effectiveDate: json['effectiveDate']?.toString() ?? '',
      currentPrices: _parseFuelPriceMap(json['currentPrices']),
      requestedPrices: _parseFuelPriceMap(json['requestedPrices']),
      note: json['note']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      requestedAt: json['requestedAt']?.toString() ?? '',
      requestedBy: json['requestedBy']?.toString() ?? '',
      requestedByName: json['requestedByName']?.toString() ?? '',
      reviewedAt: json['reviewedAt']?.toString() ?? '',
      reviewedBy: json['reviewedBy']?.toString() ?? '',
      reviewedByName: json['reviewedByName']?.toString() ?? '',
      reviewNote: json['reviewNote']?.toString() ?? '',
    );
  }
}

Map<String, Map<String, double>> _parseFuelPriceMap(dynamic value) {
  final json = value as Map<String, dynamic>? ?? const {};
  return json.map((key, item) {
    final price = item as Map<String, dynamic>? ?? const {};
    return MapEntry(key, {
      'costPrice': (price['costPrice'] as num?)?.toDouble() ?? 0,
      'sellingPrice': (price['sellingPrice'] as num?)?.toDouble() ?? 0,
    });
  });
}

class StationConfigModel {
  const StationConfigModel({
    required this.id,
    required this.name,
    required this.code,
    required this.city,
    required this.shifts,
    required this.pumps,
    required this.baseReadings,
    required this.meterLimits,
    required this.inventoryPlanning,
    this.flagThreshold = 0.01,
  });

  final String id;
  final String name;
  final String code;
  final String city;
  final List<String> shifts;
  final List<StationPumpModel> pumps;
  final Map<String, PumpReadings> baseReadings;
  final Map<String, PumpReadings> meterLimits;
  final InventoryPlanningModel inventoryPlanning;
  final double flagThreshold;

  factory StationConfigModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> baseReadingsJson =
        json['baseReadings'] as Map<String, dynamic>? ?? const {};
    final Map<String, dynamic> meterLimitsJson =
        json['meterLimits'] as Map<String, dynamic>? ?? const {};
    final rawShifts =
        (json['shifts'] as List<dynamic>? ?? const [])
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
    return StationConfigModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      shifts: rawShifts.toSet().toList(),
      pumps:
          (json['pumps'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    StationPumpModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      baseReadings: baseReadingsJson.map(
        (key, value) =>
            MapEntry(key, PumpReadings.fromJson(value as Map<String, dynamic>)),
      ),
      meterLimits: meterLimitsJson.map(
        (key, value) =>
            MapEntry(key, PumpReadings.fromJson(value as Map<String, dynamic>)),
      ),
      inventoryPlanning: InventoryPlanningModel.fromJson(
        json['inventoryPlanning'] as Map<String, dynamic>? ?? const {},
      ),
      flagThreshold: (json['flagThreshold'] as num?)?.toDouble() ?? 0.01,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'city': city,
      'shifts': shifts.toSet().toList(),
      'pumps': pumps.map((pump) => pump.toJson()).toList(),
      'baseReadings': baseReadings.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'meterLimits': meterLimits.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'inventoryPlanning': inventoryPlanning.toJson(),
      'flagThreshold': flagThreshold,
    };
  }
}

class DeliveryReceiptModel {
  const DeliveryReceiptModel({
    required this.id,
    required this.stationId,
    required this.fuelTypeId,
    required this.date,
    required this.quantity,
    required this.quantities,
    required this.note,
    required this.purchasedByName,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String stationId;
  final String fuelTypeId;
  final String date;
  final double quantity;
  final Map<String, double> quantities;
  final String note;
  final String purchasedByName;
  final String createdBy;
  final String createdAt;

  factory DeliveryReceiptModel.fromJson(Map<String, dynamic> json) {
    final quantitiesJson =
        json['quantities'] as Map<String, dynamic>? ??
        {
          json['fuelTypeId']?.toString() ?? 'petrol':
              (json['quantity'] as num?)?.toDouble() ?? 0,
        };
    return DeliveryReceiptModel(
      id: json['id']?.toString() ?? '',
      stationId: json['stationId']?.toString() ?? '',
      fuelTypeId: json['fuelTypeId']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      quantities: {
        'petrol': (quantitiesJson['petrol'] as num?)?.toDouble() ?? 0,
        'diesel': (quantitiesJson['diesel'] as num?)?.toDouble() ?? 0,
        'two_t_oil': (quantitiesJson['two_t_oil'] as num?)?.toDouble() ?? 0,
      },
      note: json['note']?.toString() ?? '',
      purchasedByName: json['purchasedByName']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class FuelInventoryForecastModel {
  const FuelInventoryForecastModel({
    required this.fuelTypeId,
    required this.label,
    required this.currentStock,
    required this.averageDailySales,
    required this.daysRemaining,
    required this.projectedRunoutDate,
    required this.recommendedOrderDate,
    required this.shouldAlert,
    required this.alertMessage,
  });

  final String fuelTypeId;
  final String label;
  final double currentStock;
  final double averageDailySales;
  final double? daysRemaining;
  final String projectedRunoutDate;
  final String recommendedOrderDate;
  final bool shouldAlert;
  final String alertMessage;

  factory FuelInventoryForecastModel.fromJson(Map<String, dynamic> json) {
    return FuelInventoryForecastModel(
      fuelTypeId: json['fuelTypeId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      currentStock: (json['currentStock'] as num?)?.toDouble() ?? 0,
      averageDailySales: (json['averageDailySales'] as num?)?.toDouble() ?? 0,
      daysRemaining: (json['daysRemaining'] as num?)?.toDouble(),
      projectedRunoutDate: json['projectedRunoutDate']?.toString() ?? '',
      recommendedOrderDate: json['recommendedOrderDate']?.toString() ?? '',
      shouldAlert: json['shouldAlert'] as bool? ?? false,
      alertMessage: json['alertMessage']?.toString() ?? '',
    );
  }
}

class InventoryDashboardModel {
  const InventoryDashboardModel({
    required this.station,
    required this.inventoryPlanning,
    required this.forecast,
    required this.deliveries,
    this.activeStockSnapshot,
  });

  final StationConfigModel station;
  final InventoryPlanningModel inventoryPlanning;
  final List<FuelInventoryForecastModel> forecast;
  final List<DeliveryReceiptModel> deliveries;
  final InventoryStockSnapshotModel? activeStockSnapshot;

  factory InventoryDashboardModel.fromJson(Map<String, dynamic> json) {
    return InventoryDashboardModel(
      station: StationConfigModel.fromJson(
        json['station'] as Map<String, dynamic>? ?? const {},
      ),
      inventoryPlanning: InventoryPlanningModel.fromJson(
        json['inventoryPlanning'] as Map<String, dynamic>? ?? const {},
      ),
      forecast:
          (json['forecast'] as List<dynamic>? ?? const [])
              .map(
                (item) => FuelInventoryForecastModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      deliveries:
          (json['deliveries'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    DeliveryReceiptModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      activeStockSnapshot:
          json['activeStockSnapshot'] is Map<String, dynamic>
              ? InventoryStockSnapshotModel.fromJson(
                json['activeStockSnapshot'] as Map<String, dynamic>,
              )
              : null,
    );
  }
}

class ShiftEntryModel {
  const ShiftEntryModel({
    required this.id,
    required this.stationId,
    required this.date,
    required this.shift,
    required this.status,
    required this.flagged,
    required this.varianceNote,
    required this.submittedBy,
    required this.submittedByName,
    required this.reviewedBy,
    required this.approvedAt,
    required this.submittedAt,
    required this.updatedAt,
    required this.openingReadings,
    required this.closingReadings,
    required this.soldByPump,
    required this.pumpAttendants,
    required this.pumpTesting,
    required this.pumpPayments,
    required this.pumpCollections,
    required this.paymentBreakdown,
    required this.creditEntries,
    required this.creditCollections,
    required this.totals,
    required this.inventoryTotals,
    required this.revenue,
    required this.computedRevenue,
    required this.paymentTotal,
    required this.salesSettlementTotal,
    required this.creditCollectionTotal,
    required this.mismatchAmount,
    required this.mismatchReason,
    required this.profit,
    this.priceSnapshot = const {},
  });

  final String id;
  final String stationId;
  final String date;
  final String shift;
  final String status;
  final bool flagged;
  final String varianceNote;
  final String submittedBy;
  final String submittedByName;
  final String reviewedBy;
  final String approvedAt;
  final String submittedAt;
  final String updatedAt;
  final Map<String, PumpReadings> openingReadings;
  final Map<String, PumpReadings> closingReadings;
  final Map<String, PumpReadings> soldByPump;
  final Map<String, String> pumpAttendants;
  final Map<String, PumpTestingModel> pumpTesting;
  final Map<String, PumpPaymentBreakdownModel> pumpPayments;
  final Map<String, double> pumpCollections;
  final PaymentBreakdownModel paymentBreakdown;
  final List<CreditEntryModel> creditEntries;
  final List<CreditCollectionModel> creditCollections;
  final EntryTotals totals;
  final FuelTotals inventoryTotals;
  final double revenue;
  final double computedRevenue;
  final double paymentTotal;
  final double salesSettlementTotal;
  final double creditCollectionTotal;
  final double mismatchAmount;
  final String mismatchReason;
  final double profit;

  /// Keys: 'petrol', 'diesel', 'two_t_oil' — values have 'sellingPrice', 'costPrice'
  final Map<String, Map<String, double>> priceSnapshot;

  bool get isFinalized {
    if (status.trim() == 'preview') {
      return false;
    }
    return approvedAt.trim().isNotEmpty || status.trim() == 'approved';
  }

  String get latestActivityTimestamp {
    final timestamps = [approvedAt.trim(), updatedAt.trim(), submittedAt.trim()]
      ..removeWhere((value) => value.isEmpty);
    timestamps.sort();
    return timestamps.isEmpty ? '' : timestamps.last;
  }

  factory ShiftEntryModel.fromJson(Map<String, dynamic> json) {
    Map<String, PumpReadings> parseReadings(String key) {
      final source = json[key] as Map<String, dynamic>? ?? const {};
      return source.map(
        (entryKey, value) => MapEntry(
          entryKey,
          PumpReadings.fromJson(value as Map<String, dynamic>),
        ),
      );
    }

    return ShiftEntryModel(
      id: json['id']?.toString() ?? '',
      stationId: json['stationId']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      shift: json['shift']?.toString() ?? '',
      status: json['status']?.toString() ?? 'submitted',
      flagged: json['flagged'] as bool? ?? false,
      varianceNote: json['varianceNote']?.toString() ?? '',
      submittedBy: json['submittedBy']?.toString() ?? '',
      submittedByName: json['submittedByName']?.toString() ?? '',
      reviewedBy: json['reviewedBy']?.toString() ?? '',
      approvedAt: json['approvedAt']?.toString() ?? '',
      submittedAt: json['submittedAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
      openingReadings: parseReadings('openingReadings'),
      closingReadings: parseReadings('closingReadings'),
      soldByPump: parseReadings('soldByPump'),
      pumpAttendants: (json['pumpAttendants'] as Map<String, dynamic>? ??
              const {})
          .map((key, value) => MapEntry(key, value?.toString() ?? '')),
      pumpTesting: (json['pumpTesting'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, parsePumpTesting(value))),
      pumpPayments: (json['pumpPayments'] as Map<String, dynamic>? ?? const {})
          .map(
            (key, value) => MapEntry(
              key,
              PumpPaymentBreakdownModel.fromJson(
                value as Map<String, dynamic>? ?? const {},
              ),
            ),
          ),
      pumpCollections: (json['pumpCollections'] as Map<String, dynamic>? ??
              const {})
          .map((key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0)),
      paymentBreakdown: PaymentBreakdownModel.fromJson(
        json['paymentBreakdown'] as Map<String, dynamic>? ?? const {},
      ),
      creditEntries:
          (json['creditEntries'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    CreditEntryModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      creditCollections:
          (json['creditCollections'] as List<dynamic>? ?? const [])
              .map(
                (item) => CreditCollectionModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      totals: EntryTotals.fromJson(
        json['totals'] as Map<String, dynamic>? ?? const {},
      ),
      inventoryTotals: FuelTotals.fromJson(
        json['inventoryTotals'] as Map<String, dynamic>? ??
            {
              'petrol':
                  ((json['totals'] as Map<String, dynamic>? ?? const {})['sold']
                          as Map<String, dynamic>? ??
                      const {})['petrol'],
              'diesel':
                  ((json['totals'] as Map<String, dynamic>? ?? const {})['sold']
                          as Map<String, dynamic>? ??
                      const {})['diesel'],
              'twoT':
                  ((json['totals'] as Map<String, dynamic>? ?? const {})['sold']
                          as Map<String, dynamic>? ??
                      const {})['twoT'],
            },
      ),
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      computedRevenue: (json['computedRevenue'] as num?)?.toDouble() ?? 0,
      paymentTotal: (json['paymentTotal'] as num?)?.toDouble() ?? 0,
      salesSettlementTotal:
          (json['salesSettlementTotal'] as num?)?.toDouble() ?? 0,
      creditCollectionTotal:
          (json['creditCollectionTotal'] as num?)?.toDouble() ?? 0,
      mismatchAmount: (json['mismatchAmount'] as num?)?.toDouble() ?? 0,
      mismatchReason: json['mismatchReason']?.toString() ?? '',
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      priceSnapshot: (json['priceSnapshot'] as Map<String, dynamic>? ??
              const {})
          .map((key, value) {
            final entry = value as Map<String, dynamic>? ?? const {};
            return MapEntry(key, {
              'sellingPrice': (entry['sellingPrice'] as num?)?.toDouble() ?? 0,
              'costPrice': (entry['costPrice'] as num?)?.toDouble() ?? 0,
            });
          }),
    );
  }
}

class CreditCustomerModel {
  const CreditCustomerModel({
    required this.id,
    required this.stationId,
    required this.name,
    required this.normalizedName,
    required this.createdAt,
    required this.updatedAt,
    required this.lastUsedAt,
  });

  final String id;
  final String stationId;
  final String name;
  final String normalizedName;
  final String createdAt;
  final String updatedAt;
  final String lastUsedAt;

  factory CreditCustomerModel.fromJson(Map<String, dynamic> json) {
    return CreditCustomerModel(
      id: json['id']?.toString() ?? '',
      stationId: json['stationId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      normalizedName: json['normalizedName']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
      lastUsedAt: json['lastUsedAt']?.toString() ?? '',
    );
  }
}

class CreditCustomerSummaryModel {
  const CreditCustomerSummaryModel({
    required this.customer,
    required this.currentBalance,
    required this.status,
    required this.totalIssued,
    required this.totalCollected,
    required this.issuedInRange,
    required this.collectedInRange,
    required this.openedAt,
    required this.lastClosedAt,
    required this.lastActivityDate,
  });

  final CreditCustomerModel customer;
  final double currentBalance;
  final String status;
  final double totalIssued;
  final double totalCollected;
  final double issuedInRange;
  final double collectedInRange;
  final String openedAt;
  final String lastClosedAt;
  final String lastActivityDate;

  factory CreditCustomerSummaryModel.fromJson(Map<String, dynamic> json) {
    return CreditCustomerSummaryModel(
      customer: CreditCustomerModel.fromJson(
        json['customer'] as Map<String, dynamic>? ?? const {},
      ),
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'closed',
      totalIssued: (json['totalIssued'] as num?)?.toDouble() ?? 0,
      totalCollected: (json['totalCollected'] as num?)?.toDouble() ?? 0,
      issuedInRange: (json['issuedInRange'] as num?)?.toDouble() ?? 0,
      collectedInRange: (json['collectedInRange'] as num?)?.toDouble() ?? 0,
      openedAt: json['openedAt']?.toString() ?? '',
      lastClosedAt: json['lastClosedAt']?.toString() ?? '',
      lastActivityDate: json['lastActivityDate']?.toString() ?? '',
    );
  }
}

class CreditLedgerSummaryModel {
  const CreditLedgerSummaryModel({
    required this.openCustomerCount,
    required this.openBalanceTotal,
    required this.collectedInRangeTotal,
  });

  final int openCustomerCount;
  final double openBalanceTotal;
  final double collectedInRangeTotal;

  factory CreditLedgerSummaryModel.fromJson(Map<String, dynamic> json) {
    return CreditLedgerSummaryModel(
      openCustomerCount: (json['openCustomerCount'] as num?)?.toInt() ?? 0,
      openBalanceTotal: (json['openBalanceTotal'] as num?)?.toDouble() ?? 0,
      collectedInRangeTotal:
          (json['collectedInRangeTotal'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CreditTransactionModel {
  const CreditTransactionModel({
    required this.id,
    required this.stationId,
    required this.customerId,
    required this.customerNameSnapshot,
    required this.type,
    required this.amount,
    required this.date,
    required this.paymentMode,
    required this.entryId,
    required this.createdBy,
    required this.createdAt,
    required this.note,
    required this.runningBalance,
  });

  final String id;
  final String stationId;
  final String customerId;
  final String customerNameSnapshot;
  final String type;
  final double amount;
  final String date;
  final String paymentMode;
  final String entryId;
  final String createdBy;
  final String createdAt;
  final String note;
  final double runningBalance;

  factory CreditTransactionModel.fromJson(Map<String, dynamic> json) {
    return CreditTransactionModel(
      id: json['id']?.toString() ?? '',
      stationId: json['stationId']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      customerNameSnapshot: json['customerNameSnapshot']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: json['date']?.toString() ?? '',
      paymentMode: json['paymentMode']?.toString() ?? '',
      entryId: json['entryId']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      runningBalance: (json['runningBalance'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CreditCustomerDetailModel {
  const CreditCustomerDetailModel({
    required this.customer,
    required this.currentBalance,
    required this.status,
    required this.totalIssued,
    required this.totalCollected,
    required this.issuedInRange,
    required this.collectedInRange,
    required this.openedAt,
    required this.lastClosedAt,
    required this.lastActivityDate,
    required this.transactions,
  });

  final CreditCustomerModel customer;
  final double currentBalance;
  final String status;
  final double totalIssued;
  final double totalCollected;
  final double issuedInRange;
  final double collectedInRange;
  final String openedAt;
  final String lastClosedAt;
  final String lastActivityDate;
  final List<CreditTransactionModel> transactions;

  factory CreditCustomerDetailModel.fromJson(Map<String, dynamic> json) {
    return CreditCustomerDetailModel(
      customer: CreditCustomerModel.fromJson(
        json['customer'] as Map<String, dynamic>? ?? const {},
      ),
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'closed',
      totalIssued: (json['totalIssued'] as num?)?.toDouble() ?? 0,
      totalCollected: (json['totalCollected'] as num?)?.toDouble() ?? 0,
      issuedInRange: (json['issuedInRange'] as num?)?.toDouble() ?? 0,
      collectedInRange: (json['collectedInRange'] as num?)?.toDouble() ?? 0,
      openedAt: json['openedAt']?.toString() ?? '',
      lastClosedAt: json['lastClosedAt']?.toString() ?? '',
      lastActivityDate: json['lastActivityDate']?.toString() ?? '',
      transactions:
          (json['transactions'] as List<dynamic>? ?? const [])
              .map(
                (item) => CreditTransactionModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }
}

class SalesDashboardModel {
  const SalesDashboardModel({
    required this.station,
    required this.date,
    required this.setupExists,
    required this.allowedEntryDate,
    required this.activeSetupDate,
    required this.entryLockedReason,
    required this.openingReadings,
    required this.selectedEntry,
    required this.entryExists,
    required this.revenue,
    required this.paymentTotal,
    required this.profit,
    required this.petrolSold,
    required this.dieselSold,
    required this.twoTSold,
    required this.entriesCompleted,
    required this.todaysEntries,
    this.priceSnapshot = const {},
  });

  final StationConfigModel station;
  final String date;
  final bool setupExists;
  final String allowedEntryDate;
  final String activeSetupDate;
  final String entryLockedReason;
  final Map<String, PumpReadings> openingReadings;
  final ShiftEntryModel? selectedEntry;
  final bool entryExists;
  final double revenue;
  final double paymentTotal;
  final double profit;
  final double petrolSold;
  final double dieselSold;
  final double twoTSold;
  final int entriesCompleted;
  final List<ShiftEntryModel> todaysEntries;
  final Map<String, Map<String, double>> priceSnapshot;

  factory SalesDashboardModel.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};
    final readings =
        json['openingReadings'] as Map<String, dynamic>? ?? const {};
    return SalesDashboardModel(
      station: StationConfigModel.fromJson(
        json['station'] as Map<String, dynamic>? ?? const {},
      ),
      date: json['date']?.toString() ?? '',
      setupExists: json['setupExists'] as bool? ?? false,
      allowedEntryDate: json['allowedEntryDate']?.toString() ?? '',
      activeSetupDate: json['activeSetupDate']?.toString() ?? '',
      entryLockedReason: json['entryLockedReason']?.toString() ?? '',
      openingReadings: readings.map(
        (key, value) =>
            MapEntry(key, PumpReadings.fromJson(value as Map<String, dynamic>)),
      ),
      selectedEntry:
          json['selectedEntry'] == null
              ? null
              : ShiftEntryModel.fromJson(
                json['selectedEntry'] as Map<String, dynamic>,
              ),
      entryExists: json['entryExists'] as bool? ?? false,
      revenue: (totals['revenue'] as num?)?.toDouble() ?? 0,
      paymentTotal: (totals['paymentTotal'] as num?)?.toDouble() ?? 0,
      profit: (totals['profit'] as num?)?.toDouble() ?? 0,
      petrolSold: (totals['petrolSold'] as num?)?.toDouble() ?? 0,
      dieselSold: (totals['dieselSold'] as num?)?.toDouble() ?? 0,
      twoTSold: (totals['twoTSold'] as num?)?.toDouble() ?? 0,
      entriesCompleted:
          (totals['entriesCompleted'] as num?)?.toInt() ??
          (totals['shiftsCompleted'] as num?)?.toInt() ??
          0,
      todaysEntries:
          (json['todaysEntries'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    ShiftEntryModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      priceSnapshot: (json['priceSnapshot'] as Map<String, dynamic>? ??
              const {})
          .map((key, value) {
            final entry = value as Map<String, dynamic>? ?? const {};
            return MapEntry(key, {
              'sellingPrice': (entry['sellingPrice'] as num?)?.toDouble() ?? 0,
              'costPrice': (entry['costPrice'] as num?)?.toDouble() ?? 0,
            });
          }),
    );
  }
}

class DaySetupStateModel {
  const DaySetupStateModel({
    required this.setupExists,
    required this.allowedEntryDate,
    required this.nextAllowedSetupDate,
    required this.activeSetupDate,
    required this.entryLockedReason,
    required this.setups,
  });

  final bool setupExists;
  final String allowedEntryDate;
  final String nextAllowedSetupDate;
  final String activeSetupDate;
  final String entryLockedReason;
  final List<StationDaySetupModel> setups;

  factory DaySetupStateModel.fromJson(Map<String, dynamic> json) {
    return DaySetupStateModel(
      setupExists: json['setupExists'] as bool? ?? false,
      allowedEntryDate: json['allowedEntryDate']?.toString() ?? '',
      nextAllowedSetupDate: json['nextAllowedSetupDate']?.toString() ?? '',
      activeSetupDate: json['activeSetupDate']?.toString() ?? '',
      entryLockedReason: json['entryLockedReason']?.toString() ?? '',
      setups:
          (json['setups'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    StationDaySetupModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}

class DashboardRangeModel {
  const DashboardRangeModel({
    required this.label,
    required this.preset,
    required this.fromDate,
    required this.toDate,
  });

  final String label;
  final String preset;
  final String fromDate;
  final String toDate;

  bool get isSingleDay => fromDate == toDate;

  factory DashboardRangeModel.fromJson(Map<String, dynamic> json) {
    return DashboardRangeModel(
      label: json['label']?.toString() ?? '',
      preset: json['preset']?.toString() ?? 'today',
      fromDate: json['fromDate']?.toString() ?? '',
      toDate: json['toDate']?.toString() ?? '',
    );
  }
}

class PumpPerformanceModel {
  const PumpPerformanceModel({
    required this.pumpId,
    required this.pumpLabel,
    required this.liters,
    required this.totalLiters,
    required this.collectedAmount,
    required this.computedSalesValue,
    required this.variance,
    required this.attendantsSeen,
  });

  final String pumpId;
  final String pumpLabel;
  final PumpReadings liters;
  final double totalLiters;
  final double collectedAmount;
  final double computedSalesValue;
  final double variance;
  final List<String> attendantsSeen;

  factory PumpPerformanceModel.fromJson(Map<String, dynamic> json) {
    return PumpPerformanceModel(
      pumpId: json['pumpId']?.toString() ?? '',
      pumpLabel: json['pumpLabel']?.toString() ?? '',
      liters: PumpReadings.fromJson(
        json['liters'] as Map<String, dynamic>? ?? const {},
      ),
      totalLiters: (json['totalLiters'] as num?)?.toDouble() ?? 0,
      collectedAmount: (json['collectedAmount'] as num?)?.toDouble() ?? 0,
      computedSalesValue: (json['computedSalesValue'] as num?)?.toDouble() ?? 0,
      variance: (json['variance'] as num?)?.toDouble() ?? 0,
      attendantsSeen:
          (json['attendantsSeen'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
    );
  }
}

class AttendantPerformanceModel {
  const AttendantPerformanceModel({
    required this.attendantName,
    required this.liters,
    required this.totalLiters,
    required this.collectedAmount,
    required this.computedSalesValue,
    required this.variance,
    required this.activeDays,
    required this.pumpsWorked,
  });

  final String attendantName;
  final PumpReadings liters;
  final double totalLiters;
  final double collectedAmount;
  final double computedSalesValue;
  final double variance;
  final int activeDays;
  final List<String> pumpsWorked;

  factory AttendantPerformanceModel.fromJson(Map<String, dynamic> json) {
    return AttendantPerformanceModel(
      attendantName: json['attendantName']?.toString() ?? '',
      liters: PumpReadings.fromJson(
        json['liters'] as Map<String, dynamic>? ?? const {},
      ),
      totalLiters: (json['totalLiters'] as num?)?.toDouble() ?? 0,
      collectedAmount: (json['collectedAmount'] as num?)?.toDouble() ?? 0,
      computedSalesValue: (json['computedSalesValue'] as num?)?.toDouble() ?? 0,
      variance: (json['variance'] as num?)?.toDouble() ?? 0,
      activeDays: (json['activeDays'] as num?)?.toInt() ?? 0,
      pumpsWorked:
          (json['pumpsWorked'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
    );
  }
}

class DashboardTrendPointModel {
  const DashboardTrendPointModel({
    required this.date,
    required this.totalLiters,
    required this.petrolSold,
    required this.dieselSold,
    required this.collectedAmount,
    required this.computedSalesValue,
    required this.approvedEntries,
  });

  final String date;
  final double totalLiters;
  final double petrolSold;
  final double dieselSold;
  final double collectedAmount;
  final double computedSalesValue;
  final int approvedEntries;

  factory DashboardTrendPointModel.fromJson(Map<String, dynamic> json) {
    return DashboardTrendPointModel(
      date: json['date']?.toString() ?? '',
      totalLiters: (json['totalLiters'] as num?)?.toDouble() ?? 0,
      petrolSold: (json['petrolSold'] as num?)?.toDouble() ?? 0,
      dieselSold: (json['dieselSold'] as num?)?.toDouble() ?? 0,
      collectedAmount: (json['collectedAmount'] as num?)?.toDouble() ?? 0,
      computedSalesValue: (json['computedSalesValue'] as num?)?.toDouble() ?? 0,
      approvedEntries: (json['approvedEntries'] as num?)?.toInt() ?? 0,
    );
  }
}

class ManagementDashboardModel {
  const ManagementDashboardModel({
    required this.station,
    required this.today,
    required this.range,
    required this.pendingRequests,
    required this.varianceCount,
    required this.revenue,
    required this.paymentTotal,
    required this.profit,
    required this.petrolSold,
    required this.dieselSold,
    required this.twoTSold,
    required this.flaggedCount,
    required this.entriesCompleted,
    required this.pumpPerformance,
    required this.attendantPerformance,
    required this.trend,
    required this.recentEntries,
    required this.fuelTypes,
    required this.prices,
  });

  final StationConfigModel station;
  final String today;
  final DashboardRangeModel range;
  final int pendingRequests;
  final int varianceCount;
  final double revenue;
  final double paymentTotal;
  final double profit;
  final double petrolSold;
  final double dieselSold;
  final double twoTSold;
  final int flaggedCount;
  final int entriesCompleted;
  final List<PumpPerformanceModel> pumpPerformance;
  final List<AttendantPerformanceModel> attendantPerformance;
  final List<DashboardTrendPointModel> trend;
  final List<ShiftEntryModel> recentEntries;
  final List<FuelTypeModel> fuelTypes;
  final List<FuelPriceModel> prices;

  factory ManagementDashboardModel.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};
    return ManagementDashboardModel(
      station: StationConfigModel.fromJson(
        json['station'] as Map<String, dynamic>? ?? const {},
      ),
      today: json['today']?.toString() ?? '',
      range: DashboardRangeModel.fromJson(
        json['range'] as Map<String, dynamic>? ?? const {},
      ),
      pendingRequests: (json['pendingRequests'] as num?)?.toInt() ?? 0,
      varianceCount: (json['varianceCount'] as num?)?.toInt() ?? 0,
      revenue: (totals['revenue'] as num?)?.toDouble() ?? 0,
      paymentTotal: (totals['paymentTotal'] as num?)?.toDouble() ?? 0,
      profit: (totals['profit'] as num?)?.toDouble() ?? 0,
      petrolSold: (totals['petrolSold'] as num?)?.toDouble() ?? 0,
      dieselSold: (totals['dieselSold'] as num?)?.toDouble() ?? 0,
      twoTSold: (totals['twoTSold'] as num?)?.toDouble() ?? 0,
      flaggedCount: (totals['flaggedCount'] as num?)?.toInt() ?? 0,
      entriesCompleted:
          (totals['entriesCompleted'] as num?)?.toInt() ??
          (totals['shiftsCompleted'] as num?)?.toInt() ??
          0,
      pumpPerformance:
          (json['pumpPerformance'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    PumpPerformanceModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      attendantPerformance:
          (json['attendantPerformance'] as List<dynamic>? ?? const [])
              .map(
                (item) => AttendantPerformanceModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      trend:
          (json['trend'] as List<dynamic>? ?? const [])
              .map(
                (item) => DashboardTrendPointModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      recentEntries:
          (json['recentEntries'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    ShiftEntryModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      fuelTypes:
          (json['fuelTypes'] as List<dynamic>? ?? const [])
              .map(
                (item) => FuelTypeModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      prices:
          (json['prices'] as List<dynamic>? ?? const [])
              .map(
                (item) => FuelPriceModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}

class ShiftDistributionModel {
  const ShiftDistributionModel({
    required this.shift,
    required this.revenue,
    required this.petrolSold,
    required this.dieselSold,
    required this.twoTSold,
    required this.status,
  });

  final String shift;
  final double revenue;
  final double petrolSold;
  final double dieselSold;
  final double twoTSold;
  final String status;

  factory ShiftDistributionModel.fromJson(Map<String, dynamic> json) {
    return ShiftDistributionModel(
      shift: json['shift']?.toString() ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      petrolSold: (json['petrolSold'] as num?)?.toDouble() ?? 0,
      dieselSold: (json['dieselSold'] as num?)?.toDouble() ?? 0,
      twoTSold: (json['twoTSold'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
    );
  }
}

class DailySummaryModel {
  const DailySummaryModel({
    required this.date,
    required this.revenue,
    required this.paymentTotal,
    required this.profit,
    required this.petrolSold,
    required this.dieselSold,
    required this.twoTSold,
    required this.flaggedCount,
    required this.distribution,
    required this.entries,
  });

  final String date;
  final double revenue;
  final double paymentTotal;
  final double profit;
  final double petrolSold;
  final double dieselSold;
  final double twoTSold;
  final int flaggedCount;
  final List<ShiftDistributionModel> distribution;
  final List<ShiftEntryModel> entries;

  factory DailySummaryModel.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};
    return DailySummaryModel(
      date: json['date']?.toString() ?? '',
      revenue: (totals['revenue'] as num?)?.toDouble() ?? 0,
      paymentTotal: (totals['paymentTotal'] as num?)?.toDouble() ?? 0,
      profit: (totals['profit'] as num?)?.toDouble() ?? 0,
      petrolSold: (totals['petrolSold'] as num?)?.toDouble() ?? 0,
      dieselSold: (totals['dieselSold'] as num?)?.toDouble() ?? 0,
      twoTSold: (totals['twoTSold'] as num?)?.toDouble() ?? 0,
      flaggedCount: (totals['flaggedCount'] as num?)?.toInt() ?? 0,
      distribution:
          (json['distribution'] as List<dynamic>? ?? const [])
              .map(
                (item) => ShiftDistributionModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      entries:
          (json['entries'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    ShiftEntryModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}

class TrendPointModel {
  const TrendPointModel({
    required this.date,
    required this.revenue,
    required this.paymentTotal,
    required this.profit,
    required this.petrolSold,
    required this.dieselSold,
    required this.twoTSold,
    required this.entries,
    required this.shifts,
  });

  final String date;
  final double revenue;
  final double paymentTotal;
  final double profit;
  final double petrolSold;
  final double dieselSold;
  final double twoTSold;
  final int entries;
  final int shifts;

  factory TrendPointModel.fromJson(Map<String, dynamic> json) {
    return TrendPointModel(
      date: json['date']?.toString() ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      paymentTotal: (json['paymentTotal'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      petrolSold: (json['petrolSold'] as num?)?.toDouble() ?? 0,
      dieselSold: (json['dieselSold'] as num?)?.toDouble() ?? 0,
      twoTSold: (json['twoTSold'] as num?)?.toDouble() ?? 0,
      entries: (json['entries'] as num?)?.toInt() ?? 0,
      shifts: (json['shifts'] as num?)?.toInt() ?? 0,
    );
  }
}

class MonthlyReportModel {
  const MonthlyReportModel({
    required this.month,
    required this.fromDate,
    required this.toDate,
    required this.revenue,
    required this.paymentTotal,
    required this.profit,
    required this.petrolSold,
    required this.dieselSold,
    required this.twoTSold,
    required this.creditTotal,
    required this.entriesCompleted,
    required this.shiftsCompleted,
    required this.paymentBreakdown,
    required this.fuelBreakdown,
    required this.trend,
  });

  final String month;
  final String fromDate;
  final String toDate;
  final double revenue;
  final double paymentTotal;
  final double profit;
  final double petrolSold;
  final double dieselSold;
  final double twoTSold;
  final double creditTotal;
  final int entriesCompleted;
  final int shiftsCompleted;
  final Map<String, double> paymentBreakdown;
  final Map<String, double> fuelBreakdown;
  final List<TrendPointModel> trend;

  factory MonthlyReportModel.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};
    final payments =
        json['paymentBreakdown'] as Map<String, dynamic>? ?? const {};
    final breakdown =
        json['fuelBreakdown'] as Map<String, dynamic>? ?? const {};
    return MonthlyReportModel(
      month: json['month']?.toString() ?? '',
      fromDate: json['fromDate']?.toString() ?? '',
      toDate: json['toDate']?.toString() ?? '',
      revenue: (totals['revenue'] as num?)?.toDouble() ?? 0,
      paymentTotal: (totals['paymentTotal'] as num?)?.toDouble() ?? 0,
      profit: (totals['profit'] as num?)?.toDouble() ?? 0,
      petrolSold: (totals['petrolSold'] as num?)?.toDouble() ?? 0,
      dieselSold: (totals['dieselSold'] as num?)?.toDouble() ?? 0,
      twoTSold: (totals['twoTSold'] as num?)?.toDouble() ?? 0,
      creditTotal: (totals['creditTotal'] as num?)?.toDouble() ?? 0,
      entriesCompleted:
          (totals['entriesCompleted'] as num?)?.toInt() ??
          (totals['shiftsCompleted'] as num?)?.toInt() ??
          0,
      shiftsCompleted: (totals['shiftsCompleted'] as num?)?.toInt() ?? 0,
      paymentBreakdown: payments.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      fuelBreakdown: breakdown.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      trend:
          (json['trend'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    TrendPointModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}
