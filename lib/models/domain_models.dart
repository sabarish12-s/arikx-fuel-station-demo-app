class PumpReadings {
  const PumpReadings({
    required this.petrol,
    required this.diesel,
  });

  final double petrol;
  final double diesel;

  factory PumpReadings.fromJson(Map<String, dynamic> json) {
    return PumpReadings(
      petrol: (json['petrol'] as num?)?.toDouble() ?? 0,
      diesel: (json['diesel'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'petrol': petrol,
      'diesel': diesel,
    };
  }
}

class FuelTotals {
  const FuelTotals({
    required this.petrol,
    required this.diesel,
  });

  final double petrol;
  final double diesel;

  factory FuelTotals.fromJson(Map<String, dynamic> json) {
    return FuelTotals(
      petrol: (json['petrol'] as num?)?.toDouble() ?? 0,
      diesel: (json['diesel'] as num?)?.toDouble() ?? 0,
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
  });

  final String id;
  final String name;
  final String shortName;
  final String description;
  final String color;
  final String icon;
  final bool active;

  factory FuelTypeModel.fromJson(Map<String, dynamic> json) {
    return FuelTypeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      shortName: json['shortName']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      color: json['color']?.toString() ?? '#1E5CBA',
      icon: json['icon']?.toString() ?? 'local_gas_station',
      active: json['active'] as bool? ?? true,
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
  });

  final String fuelTypeId;
  final double costPrice;
  final double sellingPrice;
  final String updatedAt;
  final String updatedBy;

  factory FuelPriceModel.fromJson(Map<String, dynamic> json) {
    return FuelPriceModel(
      fuelTypeId: json['fuelTypeId']?.toString() ?? '',
      costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0,
      updatedAt: json['updatedAt']?.toString() ?? '',
      updatedBy: json['updatedBy']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fuelTypeId': fuelTypeId,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
    };
  }
}

class StationPumpModel {
  const StationPumpModel({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  factory StationPumpModel.fromJson(Map<String, dynamic> json) {
    return StationPumpModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
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
  });

  final String id;
  final String name;
  final String code;
  final String city;
  final List<String> shifts;
  final List<StationPumpModel> pumps;
  final Map<String, PumpReadings> baseReadings;

  factory StationConfigModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> baseReadingsJson =
        json['baseReadings'] as Map<String, dynamic>? ?? const {};
    return StationConfigModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      shifts:
          (json['shifts'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
      pumps:
          (json['pumps'] as List<dynamic>? ?? const [])
              .map(
                (item) => StationPumpModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      baseReadings: baseReadingsJson.map(
        (key, value) => MapEntry(
          key,
          PumpReadings.fromJson(value as Map<String, dynamic>),
        ),
      ),
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
    required this.reviewedBy,
    required this.approvedAt,
    required this.submittedAt,
    required this.updatedAt,
    required this.openingReadings,
    required this.closingReadings,
    required this.soldByPump,
    required this.totals,
    required this.revenue,
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
  final String reviewedBy;
  final String approvedAt;
  final String submittedAt;
  final String updatedAt;
  final Map<String, PumpReadings> openingReadings;
  final Map<String, PumpReadings> closingReadings;
  final Map<String, PumpReadings> soldByPump;
  final EntryTotals totals;
  final double revenue;
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
      reviewedBy: json['reviewedBy']?.toString() ?? '',
      approvedAt: json['approvedAt']?.toString() ?? '',
      submittedAt: json['submittedAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
      openingReadings: parseReadings('openingReadings'),
      closingReadings: parseReadings('closingReadings'),
      soldByPump: parseReadings('soldByPump'),
      totals: EntryTotals.fromJson(
        json['totals'] as Map<String, dynamic>? ?? const {},
      ),
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SalesDashboardModel {
  const SalesDashboardModel({
    required this.station,
    required this.date,
    required this.nextShift,
    required this.nextOpeningReadings,
    required this.revenue,
    required this.profit,
    required this.petrolSold,
    required this.dieselSold,
    required this.shiftsCompleted,
    required this.todaysEntries,
  });

  final StationConfigModel station;
  final String date;
  final String nextShift;
  final Map<String, PumpReadings> nextOpeningReadings;
  final double revenue;
  final double profit;
  final double petrolSold;
  final double dieselSold;
  final int shiftsCompleted;
  final List<ShiftEntryModel> todaysEntries;

  factory SalesDashboardModel.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};
    final readings =
        json['nextOpeningReadings'] as Map<String, dynamic>? ?? const {};
    return SalesDashboardModel(
      station: StationConfigModel.fromJson(
        json['station'] as Map<String, dynamic>? ?? const {},
      ),
      date: json['date']?.toString() ?? '',
      nextShift: json['nextShift']?.toString() ?? '',
      nextOpeningReadings: readings.map(
        (key, value) => MapEntry(
          key,
          PumpReadings.fromJson(value as Map<String, dynamic>),
        ),
      ),
      revenue: (totals['revenue'] as num?)?.toDouble() ?? 0,
      profit: (totals['profit'] as num?)?.toDouble() ?? 0,
      petrolSold: (totals['petrolSold'] as num?)?.toDouble() ?? 0,
      dieselSold: (totals['dieselSold'] as num?)?.toDouble() ?? 0,
      shiftsCompleted: (totals['shiftsCompleted'] as num?)?.toInt() ?? 0,
      todaysEntries:
          (json['todaysEntries'] as List<dynamic>? ?? const [])
              .map(
                (item) => ShiftEntryModel.fromJson(item as Map<String, dynamic>),
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
    required this.profit,
    required this.petrolSold,
    required this.dieselSold,
    required this.flaggedCount,
    required this.shiftsCompleted,
    required this.recentEntries,
    required this.fuelTypes,
    required this.prices,
  });

  final StationConfigModel station;
  final String today;
  final int pendingRequests;
  final double revenue;
  final double profit;
  final double petrolSold;
  final double dieselSold;
  final int flaggedCount;
  final int shiftsCompleted;
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
      profit: (totals['profit'] as num?)?.toDouble() ?? 0,
      petrolSold: (totals['petrolSold'] as num?)?.toDouble() ?? 0,
      dieselSold: (totals['dieselSold'] as num?)?.toDouble() ?? 0,
      flaggedCount: (totals['flaggedCount'] as num?)?.toInt() ?? 0,
      shiftsCompleted: (totals['shiftsCompleted'] as num?)?.toInt() ?? 0,
      recentEntries:
          (json['recentEntries'] as List<dynamic>? ?? const [])
              .map(
                (item) => ShiftEntryModel.fromJson(item as Map<String, dynamic>),
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
    required this.status,
  });

  final String shift;
  final double revenue;
  final double petrolSold;
  final double dieselSold;
  final String status;

  factory ShiftDistributionModel.fromJson(Map<String, dynamic> json) {
    return ShiftDistributionModel(
      shift: json['shift']?.toString() ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      petrolSold: (json['petrolSold'] as num?)?.toDouble() ?? 0,
      dieselSold: (json['dieselSold'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
    );
  }
}

class DailySummaryModel {
  const DailySummaryModel({
    required this.date,
    required this.revenue,
    required this.profit,
    required this.petrolSold,
    required this.dieselSold,
    required this.flaggedCount,
    required this.distribution,
    required this.entries,
  });

  final String date;
  final double revenue;
  final double profit;
  final double petrolSold;
  final double dieselSold;
  final int flaggedCount;
  final List<ShiftDistributionModel> distribution;
  final List<ShiftEntryModel> entries;

  factory DailySummaryModel.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};
    return DailySummaryModel(
      date: json['date']?.toString() ?? '',
      revenue: (totals['revenue'] as num?)?.toDouble() ?? 0,
      profit: (totals['profit'] as num?)?.toDouble() ?? 0,
      petrolSold: (totals['petrolSold'] as num?)?.toDouble() ?? 0,
      dieselSold: (totals['dieselSold'] as num?)?.toDouble() ?? 0,
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
                (item) => ShiftEntryModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}

class TrendPointModel {
  const TrendPointModel({
    required this.date,
    required this.revenue,
    required this.profit,
    required this.petrolSold,
    required this.dieselSold,
    required this.shifts,
  });

  final String date;
  final double revenue;
  final double profit;
  final double petrolSold;
  final double dieselSold;
  final int shifts;

  factory TrendPointModel.fromJson(Map<String, dynamic> json) {
    return TrendPointModel(
      date: json['date']?.toString() ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      petrolSold: (json['petrolSold'] as num?)?.toDouble() ?? 0,
      dieselSold: (json['dieselSold'] as num?)?.toDouble() ?? 0,
      shifts: (json['shifts'] as num?)?.toInt() ?? 0,
    );
  }
}

class MonthlyReportModel {
  const MonthlyReportModel({
    required this.month,
    required this.revenue,
    required this.profit,
    required this.petrolSold,
    required this.dieselSold,
    required this.shiftsCompleted,
    required this.fuelBreakdown,
    required this.trend,
  });

  final String month;
  final double revenue;
  final double profit;
  final double petrolSold;
  final double dieselSold;
  final int shiftsCompleted;
  final Map<String, double> fuelBreakdown;
  final List<TrendPointModel> trend;

  factory MonthlyReportModel.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};
    final breakdown =
        json['fuelBreakdown'] as Map<String, dynamic>? ?? const {};
    return MonthlyReportModel(
      month: json['month']?.toString() ?? '',
      revenue: (totals['revenue'] as num?)?.toDouble() ?? 0,
      profit: (totals['profit'] as num?)?.toDouble() ?? 0,
      petrolSold: (totals['petrolSold'] as num?)?.toDouble() ?? 0,
      dieselSold: (totals['dieselSold'] as num?)?.toDouble() ?? 0,
      shiftsCompleted: (totals['shiftsCompleted'] as num?)?.toInt() ?? 0,
      fuelBreakdown: breakdown.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      trend:
          (json['trend'] as List<dynamic>? ?? const [])
              .map(
                (item) => TrendPointModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}
