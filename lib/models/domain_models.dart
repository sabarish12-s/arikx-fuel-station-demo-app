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
  const CreditEntryModel({required this.name, required this.amount});

  final String name;
  final double amount;

  factory CreditEntryModel.fromJson(Map<String, dynamic> json) {
    return CreditEntryModel(
      name: json['name']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'amount': amount};
  }
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
    this.mismatchReason = '',
  });

  final String date;
  final Map<String, PumpReadings> closingReadings;
  final Map<String, String> pumpAttendants;
  final Map<String, bool> pumpTesting;
  final Map<String, PumpPaymentBreakdownModel> pumpPayments;
  final Map<String, double> pumpCollections;
  final PaymentBreakdownModel paymentBreakdown;
  final List<CreditEntryModel> creditEntries;
  final String mismatchReason;

  DailyEntryDraft copyWith({
    String? date,
    Map<String, PumpReadings>? closingReadings,
    Map<String, String>? pumpAttendants,
    Map<String, bool>? pumpTesting,
    Map<String, PumpPaymentBreakdownModel>? pumpPayments,
    Map<String, double>? pumpCollections,
    PaymentBreakdownModel? paymentBreakdown,
    List<CreditEntryModel>? creditEntries,
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
      mismatchReason: mismatchReason ?? this.mismatchReason,
    );
  }
}

class PumpEntryDraft {
  const PumpEntryDraft({
    required this.attendant,
    required this.closingReadings,
    required this.testingEnabled,
    required this.payments,
  });

  final String attendant;
  final PumpReadings? closingReadings;
  final bool testingEnabled;
  final PumpPaymentBreakdownModel payments;
}

class PaymentEntryDraft {
  const PaymentEntryDraft({
    required this.paymentBreakdown,
    required this.creditEntries,
  });

  final PaymentBreakdownModel paymentBreakdown;
  final List<CreditEntryModel> creditEntries;
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
    if (periods.isEmpty) {
      return null;
    }
    final openEnded =
        periods.where((period) => period.effectiveTo.isEmpty).toList();
    if (openEnded.isNotEmpty) {
      return openEnded.last;
    }
    return periods.last;
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
  });

  final String effectiveFrom;
  final String effectiveTo;
  final double costPrice;
  final double sellingPrice;
  final String updatedAt;
  final String updatedBy;

  factory FuelPricePeriodModel.fromJson(Map<String, dynamic> json) {
    return FuelPricePeriodModel(
      effectiveFrom: json['effectiveFrom']?.toString() ?? '',
      effectiveTo: json['effectiveTo']?.toString() ?? '',
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0,
      updatedAt: json['updatedAt']?.toString() ?? '',
      updatedBy: json['updatedBy']?.toString() ?? '',
    );
  }

  FuelPricePeriodModel copyWith({
    String? effectiveFrom,
    String? effectiveTo,
    double? costPrice,
    double? sellingPrice,
    String? updatedAt,
    String? updatedBy,
  }) {
    return FuelPricePeriodModel(
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
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
  });

  final String id;
  final String name;
  final String code;
  final String city;
  final List<String> shifts;
  final List<StationPumpModel> pumps;
  final Map<String, PumpReadings> baseReadings;
  final Map<String, PumpReadings> meterLimits;

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
    };
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
    required this.totals,
    required this.revenue,
    required this.computedRevenue,
    required this.paymentTotal,
    required this.mismatchAmount,
    required this.mismatchReason,
    required this.profit,
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
  final Map<String, bool> pumpTesting;
  final Map<String, PumpPaymentBreakdownModel> pumpPayments;
  final Map<String, double> pumpCollections;
  final PaymentBreakdownModel paymentBreakdown;
  final List<CreditEntryModel> creditEntries;
  final EntryTotals totals;
  final double revenue;
  final double computedRevenue;
  final double paymentTotal;
  final double mismatchAmount;
  final String mismatchReason;
  final double profit;

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
          .map((key, value) => MapEntry(key, value == true)),
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
      totals: EntryTotals.fromJson(
        json['totals'] as Map<String, dynamic>? ?? const {},
      ),
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      computedRevenue: (json['computedRevenue'] as num?)?.toDouble() ?? 0,
      paymentTotal: (json['paymentTotal'] as num?)?.toDouble() ?? 0,
      mismatchAmount: (json['mismatchAmount'] as num?)?.toDouble() ?? 0,
      mismatchReason: json['mismatchReason']?.toString() ?? '',
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SalesDashboardModel {
  const SalesDashboardModel({
    required this.station,
    required this.date,
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
  });

  final StationConfigModel station;
  final String date;
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

  factory SalesDashboardModel.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};
    final readings =
        json['openingReadings'] as Map<String, dynamic>? ?? const {};
    return SalesDashboardModel(
      station: StationConfigModel.fromJson(
        json['station'] as Map<String, dynamic>? ?? const {},
      ),
      date: json['date']?.toString() ?? '',
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
    );
  }
}

class ManagementDashboardModel {
  const ManagementDashboardModel({
    required this.station,
    required this.today,
    required this.pendingRequests,
    required this.revenue,
    required this.paymentTotal,
    required this.profit,
    required this.petrolSold,
    required this.dieselSold,
    required this.twoTSold,
    required this.flaggedCount,
    required this.entriesCompleted,
    required this.recentEntries,
    required this.fuelTypes,
    required this.prices,
  });

  final StationConfigModel station;
  final String today;
  final int pendingRequests;
  final double revenue;
  final double paymentTotal;
  final double profit;
  final double petrolSold;
  final double dieselSold;
  final double twoTSold;
  final int flaggedCount;
  final int entriesCompleted;
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
      pendingRequests: (json['pendingRequests'] as num?)?.toInt() ?? 0,
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
    required this.entriesCompleted,
    required this.shiftsCompleted,
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
  final int entriesCompleted;
  final int shiftsCompleted;
  final Map<String, double> fuelBreakdown;
  final List<TrendPointModel> trend;

  factory MonthlyReportModel.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};
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
      entriesCompleted:
          (totals['entriesCompleted'] as num?)?.toInt() ??
          (totals['shiftsCompleted'] as num?)?.toInt() ??
          0,
      shiftsCompleted: (totals['shiftsCompleted'] as num?)?.toInt() ?? 0,
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
