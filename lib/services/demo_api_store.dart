import 'dart:convert';

import 'package:http/http.dart' as http;

class DemoApiStore {
  DemoApiStore._() {
    _seed();
  }

  static final DemoApiStore instance = DemoApiStore._();

  static const String _stationId = 'station-demo-01';
  static const String _adminId = 'demo-superadmin';
  static final DateTime _anchorDate = DateTime(2026, 4, 25);

  late Map<String, dynamic> _station;
  late List<Map<String, dynamic>> _fuelTypes;
  late List<Map<String, dynamic>> _prices;
  late List<Map<String, dynamic>> _salesmen;
  final List<Map<String, dynamic>> _entries = [];
  final List<Map<String, dynamic>> _dailyFuelRecords = [];
  final List<Map<String, dynamic>> _deliveries = [];
  final List<Map<String, dynamic>> _stockSnapshots = [];
  final List<Map<String, dynamic>> _openingReadingLogs = [];
  final List<Map<String, dynamic>> _priceRequests = [];
  final List<Map<String, dynamic>> _managedUsers = [];
  final List<Map<String, dynamic>> _accessRequests = [];

  Future<http.Response> request(
    String method,
    String path, {
    Object? body,
  }) async {
    final uri = Uri.parse('https://demo.local$path');
    final segments = uri.pathSegments;
    try {
      if (segments.isEmpty) {
        return _notFound(method, uri.path);
      }
      switch (segments.first) {
        case 'auth':
          return _auth(method, segments);
        case 'sales':
          return _sales(method, uri, segments, body);
        case 'management':
          return _management(method, uri, segments, body);
        case 'inventory':
          return _inventory(method, uri, segments, body);
        case 'credits':
          return _credits(method, uri, segments, body);
        case 'admin':
          return _admin(method, segments);
        case 'users':
          return _users(method, segments, body);
      }
      return _notFound(method, uri.path);
    } catch (error) {
      return _json({
        'message': 'Demo data could not handle this request.',
        'error': error.toString(),
        'path': uri.path,
      }, status: 500);
    }
  }

  http.Response _auth(String method, List<String> segments) {
    if (method == 'GET' && segments.length == 2 && segments[1] == 'me') {
      return _json({'user': _demoUser()});
    }
    return _json({'user': _demoUser(), 'token': 'demo-local-token'});
  }

  http.Response _sales(
    String method,
    Uri uri,
    List<String> segments,
    Object? body,
  ) {
    if (method == 'GET' && segments.length == 2 && segments[1] == 'dashboard') {
      return _json(
        _salesDashboard(uri.queryParameters['date'] ?? _dateKey(_anchorDate)),
      );
    }
    if (method == 'GET' &&
        segments.length == 3 &&
        segments[1] == 'summary' &&
        segments[2] == 'daily') {
      return _json(
        _dailySummary(uri.queryParameters['date'] ?? _dateKey(_anchorDate)),
      );
    }
    if (segments.length >= 2 && segments[1] == 'entries') {
      if (method == 'GET' && segments.length == 2) {
        return _json({'entries': _filterEntries(uri)});
      }
      if (method == 'GET' && segments.length == 3) {
        return _json({'entry': _entryById(segments[2])});
      }
      if (method == 'POST' &&
          segments.length == 3 &&
          segments[2] == 'preview') {
        return _json({'entry': _entryFromBody(body, status: 'preview')});
      }
      if (method == 'POST' && segments.length == 3 && segments[2] == 'draft') {
        final entry = _entryFromBody(body, status: 'draft');
        _upsertEntry(entry);
        return _json({'entry': entry});
      }
      if (method == 'POST' && segments.length == 2) {
        final entry = _entryFromBody(body, status: 'approved');
        _upsertEntry(entry);
        return _json({'entry': entry});
      }
      if (method == 'PATCH' && segments.length == 3) {
        final current = _entryById(segments[2]);
        final entry = _entryFromBody(
          body,
          status: current['status']?.toString() ?? 'approved',
          id: segments[2],
        );
        _upsertEntry(entry);
        return _json({'entry': entry});
      }
    }
    return _notFound(method, uri.path);
  }

  http.Response _management(
    String method,
    Uri uri,
    List<String> segments,
    Object? body,
  ) {
    if (method == 'GET' && segments.length == 2 && segments[1] == 'dashboard') {
      return _json(_managementDashboard(uri));
    }
    if (segments.length >= 2 && segments[1] == 'entries') {
      if (method == 'GET' && segments.length == 2) {
        return _json({'entries': _filterEntries(uri)});
      }
      if (method == 'GET' && segments.length == 3) {
        return _json({'entry': _entryById(segments[2])});
      }
      if (method == 'POST' &&
          segments.length == 4 &&
          segments[3] == 'approve') {
        final entry = _entryById(segments[2]);
        entry['status'] = 'approved';
        entry['approvedAt'] = _timestamp(entry['date']?.toString() ?? '');
        entry['reviewedBy'] = _adminId;
        _upsertEntry(entry);
        return _json({'entry': entry});
      }
      if (method == 'PATCH' && segments.length == 3) {
        final current = _entryById(segments[2]);
        final entry = _entryFromBody(
          body,
          status: current['status']?.toString() ?? 'approved',
          id: segments[2],
          date: current['date']?.toString(),
        );
        _upsertEntry(entry);
        return _json({'entry': entry});
      }
      if (method == 'PATCH' && segments.length == 4 && segments[3] == 'date') {
        final entry = _entryById(segments[2]);
        entry['date'] = _bodyMap(body)['date']?.toString() ?? entry['date'];
        _upsertEntry(entry);
        return _json({'entry': entry});
      }
      if (method == 'DELETE' && segments.length == 3) {
        _entries.removeWhere((entry) => entry['id']?.toString() == segments[2]);
        return _json({'ok': true});
      }
    }
    if (method == 'GET' &&
        segments.length == 3 &&
        segments[1] == 'reports' &&
        segments[2] == 'monthly') {
      return _json(_monthlyReport(uri));
    }
    return _notFound(method, uri.path);
  }

  http.Response _inventory(
    String method,
    Uri uri,
    List<String> segments,
    Object? body,
  ) {
    if (segments.length >= 2 && segments[1] == 'fuel-types') {
      if (method == 'GET') return _json({'fuelTypes': _fuelTypes});
      if (method == 'POST') {
        final item = _bodyMap(body);
        _fuelTypes.add(item);
        return _json({'fuelType': item}, status: 201);
      }
      if (method == 'PATCH' && segments.length == 3) {
        final item = {..._fuelTypeById(segments[2]), ..._bodyMap(body)};
        _replaceById(_fuelTypes, item);
        return _json({'fuelType': item});
      }
      if (method == 'DELETE' && segments.length == 3) {
        _fuelTypes.removeWhere((item) => item['id'] == segments[2]);
        return _json({'ok': true});
      }
    }
    if (segments.length >= 2 && segments[1] == 'day-setup') {
      if (method == 'GET' && segments.length == 3 && segments[2] == 'state') {
        return _json(_daySetupState());
      }
      if (method == 'GET') return _json({'setups': _daySetups(uri)});
      if (method == 'PUT') {
        final setup = _setupFromBody(body);
        return _json({'setup': setup});
      }
      if (method == 'DELETE') return _json({'ok': true});
    }
    if (segments.length >= 2 && segments[1] == 'prices') {
      if (method == 'GET') return _json({'prices': _prices});
      if (method == 'PUT') {
        _prices = (_bodyMap(body)['prices'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        return _json({'prices': _prices});
      }
      if (method == 'DELETE') return _json({'ok': true});
    }
    if (segments.length >= 2 && segments[1] == 'price-update-requests') {
      if (method == 'GET') {
        return _json({'requests': _filterPriceRequests(uri)});
      }
      if (method == 'POST' && segments.length == 2) {
        final request = _priceRequestFromBody(body);
        _priceRequests.add(request);
        return _json({'request': request}, status: 201);
      }
      if (method == 'POST' && segments.length == 4) {
        final request = _priceRequestById(segments[2]);
        request['status'] = segments[3] == 'approve' ? 'approved' : 'rejected';
        request['reviewedAt'] = _timestamp(_dateKey(_anchorDate));
        request['reviewedBy'] = _adminId;
        request['reviewedByName'] = 'Demo Admin';
        request['reviewNote'] = _bodyMap(body)['note']?.toString() ?? '';
        return _json({'request': request});
      }
    }
    if (segments.length == 2 && segments[1] == 'station-config') {
      if (method == 'GET') return _json({'station': _station});
      if (method == 'PUT') {
        _station = _mergeStation(_bodyMap(body));
        return _json({'station': _station});
      }
    }
    if (method == 'GET' && segments.length == 2 && segments[1] == 'dashboard') {
      return _json(_inventoryDashboard());
    }
    if (segments.length >= 2 && segments[1] == 'daily-fuel') {
      if (method == 'GET' && segments.length == 3 && segments[2] == 'current') {
        final date = uri.queryParameters['date'] ?? _dateKey(_anchorDate);
        return _json({'record': _dailyFuelRecord(date)});
      }
      if (method == 'GET') {
        return _json({'records': _filterRecords(uri, _dailyFuelRecords)});
      }
      if (method == 'PUT') {
        final record = _dailyFuelRecordFromBody(body);
        _replaceById(_dailyFuelRecords, record);
        return _json({'record': record});
      }
    }
    if (segments.length >= 2 && segments[1] == 'deliveries') {
      if (method == 'GET') {
        return _json({'deliveries': _filterRecords(uri, _deliveries)});
      }
      if (method == 'POST') {
        final delivery = _deliveryFromBody(body);
        _deliveries.add(delivery);
        _refreshStationStock();
        return _json({'delivery': delivery}, status: 201);
      }
    }
    if (segments.length >= 2 && segments[1] == 'stock-snapshots') {
      if (method == 'GET') {
        return _json({'snapshots': _filterRecords(uri, _stockSnapshots)});
      }
      if (method == 'POST') {
        final snapshot = _stockSnapshotFromBody(body);
        _stockSnapshots.add(snapshot);
        return _json({'snapshot': snapshot}, status: 201);
      }
      if (method == 'DELETE') return _json({'ok': true});
    }
    if (segments.length >= 2 && segments[1] == 'opening-readings') {
      if (method == 'GET') {
        return _json({'logs': _filterRecords(uri, _openingReadingLogs)});
      }
      if (method == 'POST') {
        final log = _openingLogFromBody(body);
        _openingReadingLogs.add(log);
        return _json({'log': log}, status: 201);
      }
      if (method == 'DELETE') return _json({'ok': true});
    }
    return _notFound(method, uri.path);
  }

  http.Response _credits(
    String method,
    Uri uri,
    List<String> segments,
    Object? body,
  ) {
    if (method == 'GET' && segments.length == 2 && segments[1] == 'summary') {
      return _json({'summary': _creditSummary(_creditCustomers(uri))});
    }
    if (segments.length >= 2 && segments[1] == 'customers') {
      if (method == 'GET' && segments.length == 2) {
        final customers = _creditCustomers(uri);
        return _json({
          'summary': _creditSummary(customers),
          'customers': customers,
        });
      }
      if (method == 'GET' && segments.length == 3) {
        return _json(_creditCustomerDetail(segments[2], uri));
      }
    }
    if (method == 'POST' &&
        segments.length == 2 &&
        segments[1] == 'collections') {
      final data = _bodyMap(body);
      final transaction = {
        'id':
            'collection-${_entries.length}-${DateTime.now().millisecondsSinceEpoch}',
        'stationId': _stationId,
        'customerId': data['customerId']?.toString().isNotEmpty == true
            ? data['customerId'].toString()
            : _customerId(data['name']?.toString() ?? 'Demo Customer'),
        'customerNameSnapshot': data['name']?.toString() ?? 'Demo Customer',
        'type': 'collection',
        'amount': _double(data['amount']),
        'date': data['date']?.toString() ?? _dateKey(_anchorDate),
        'paymentMode': data['paymentMode']?.toString() ?? 'upi',
        'entryId': '',
        'createdBy': _adminId,
        'createdAt': _timestamp(
          data['date']?.toString() ?? _dateKey(_anchorDate),
        ),
        'note': data['note']?.toString() ?? '',
        'runningBalance': 0,
      };
      return _json({'transaction': transaction}, status: 201);
    }
    return _notFound(method, uri.path);
  }

  http.Response _admin(String method, List<String> segments) {
    if (method == 'GET' && segments.length == 2 && segments[1] == 'requests') {
      return _json({'requests': _accessRequests});
    }
    if (method == 'POST') {
      return _json({'ok': true});
    }
    return _notFound(method, '/${segments.join('/')}');
  }

  http.Response _users(String method, List<String> segments, Object? body) {
    if (method == 'GET' &&
        segments.length == 2 &&
        segments[1] == 'management') {
      return _json(_userManagementOverview());
    }
    if (method == 'GET' && segments.length == 2 && segments[1] == 'requests') {
      return _json({'requests': _accessRequests});
    }
    if (method == 'POST' && segments.length == 2 && segments[1] == 'staff') {
      final data = _bodyMap(body);
      _managedUsers.add({
        'id': 'staff-${_managedUsers.length + 1}',
        'name': data['name']?.toString() ?? '',
        'email': data['email']?.toString() ?? '',
        'role': data['role']?.toString() ?? 'sales',
        'requestedRole': data['role']?.toString() ?? 'sales',
        'status': 'approved',
        'stationId': _stationId,
        'createdAt': _timestamp(_dateKey(_anchorDate)),
        'requestCreatedAt': '',
        'reviewedAt': _timestamp(_dateKey(_anchorDate)),
        'rejectionReason': '',
      });
      return _json({'ok': true}, status: 201);
    }
    if (method == 'PATCH' && segments.length == 3 && segments[1] == 'staff') {
      final data = _bodyMap(body);
      for (final user in _managedUsers) {
        if (user['id'] == segments[2]) {
          user['role'] = data['role']?.toString() ?? user['role'];
        }
      }
      return _json({'ok': true});
    }
    if (method == 'DELETE' && segments.length == 3 && segments[1] == 'staff') {
      _managedUsers.removeWhere((user) => user['id'] == segments[2]);
      return _json({'ok': true});
    }
    if (method == 'POST') {
      return _json({'ok': true});
    }
    return _notFound(method, '/${segments.join('/')}');
  }

  void _seed() {
    _fuelTypes = [
      _fuelType('petrol', 'Petrol', 'MS', '#1E5CBA', 'local_gas_station'),
      _fuelType('diesel', 'Diesel', 'HSD', '#0F9D58', 'local_shipping'),
      _fuelType('two_t_oil', '2T Oil', '2T', '#F59E0B', 'oil_barrel'),
    ];
    _prices = [
      _price('petrol', 96.25, 105.50),
      _price('diesel', 85.80, 93.20),
      _price('two_t_oil', 360.0, 420.0),
    ];
    _salesmen = [
      _salesman('sales-001', 'Arjun Kumar', 'S001'),
      _salesman('sales-002', 'Bala Murugan', 'S002'),
      _salesman('sales-003', 'Charan Patel', 'S003'),
      _salesman('sales-004', 'Deepak Singh', 'S004'),
      _salesman('sales-005', 'Esha Nair', 'S005'),
      _salesman('sales-006', 'Farhan Ali', 'S006'),
      _salesman('sales-007', 'Gowri Ramesh', 'S007'),
    ];

    final opening = {
      'pump1': _readings(12500, 4200, 140),
      'pump2': _readings(11900, 4500, 132),
      'pump3': _readings(7100, 9600, 118),
      'pump4': _readings(6800, 10100, 121),
    };

    _station = {
      'id': _stationId,
      'name': 'Arikx fuel station',
      'code': 'FSD-001',
      'city': 'Demo City',
      'shifts': ['Daily'],
      'pumps': [
        {'id': 'pump1', 'label': 'Pump 1'},
        {'id': 'pump2', 'label': 'Pump 2'},
        {'id': 'pump3', 'label': 'Pump 3'},
        {'id': 'pump4', 'label': 'Pump 4'},
      ],
      'baseReadings': _copyReadingsMap(opening),
      'inventoryPlanning': {
        'openingStock': {
          'petrol': 125000.0,
          'diesel': 120000.0,
          'two_t_oil': 2200.0,
        },
        'currentStock': {
          'petrol': 125000.0,
          'diesel': 120000.0,
          'two_t_oil': 2200.0,
        },
        'deliveryLeadDays': 3,
        'alertBeforeDays': 2,
        'updatedAt': _timestamp(
          _dateKey(_anchorDate.subtract(const Duration(days: 20))),
        ),
      },
      'salesmen': _salesmen,
      'flagThreshold': 0.015,
    };

    _seedEntries(opening);
    _seedInventoryHistory();
    _seedUsers();
    _refreshStationStock();
  }

  void _seedEntries(Map<String, Map<String, double>> startingReadings) {
    final pumpReadings = _copyReadingsMap(startingReadings);
    final dates = List<String>.generate(
      20,
      (index) => _dateKey(_anchorDate.subtract(Duration(days: 19 - index))),
    );
    for (var dayIndex = 0; dayIndex < dates.length; dayIndex++) {
      final date = dates[dayIndex];
      final petrolDay = 3000.0 + ((dayIndex % 5) - 2) * 60.0;
      final dieselDay = 3000.0 + ((dayIndex % 7) - 3) * 45.0;
      final twoTDay = 24.0 + (dayIndex % 4) * 2.0;
      for (var shiftIndex = 0; shiftIndex < 1; shiftIndex++) {
        final shiftWeights = [1.0];
        final pumpPetrolWeights = [0.34, 0.31, 0.19, 0.16];
        final pumpDieselWeights = [0.15, 0.18, 0.34, 0.33];
        final pumpTwoTWeights = [0.35, 0.25, 0.20, 0.20];
        final soldByPump = <String, Map<String, double>>{};
        final openingReadings = _copyReadingsMap(pumpReadings);
        final closingReadings = <String, Map<String, double>>{};
        final pumpSalesmen = <String, Map<String, dynamic>>{};
        final pumpAttendants = <String, String>{};
        final pumpTesting = <String, Map<String, dynamic>>{};
        final pumpPayments = <String, Map<String, double>>{};
        final pumpCollections = <String, double>{};

        for (var pumpIndex = 0; pumpIndex < 4; pumpIndex++) {
          final pumpId = 'pump${pumpIndex + 1}';
          final petrol = _round(
            petrolDay * shiftWeights[shiftIndex] * pumpPetrolWeights[pumpIndex],
          );
          final diesel = _round(
            dieselDay * shiftWeights[shiftIndex] * pumpDieselWeights[pumpIndex],
          );
          final twoT = _round(
            twoTDay * shiftWeights[shiftIndex] * pumpTwoTWeights[pumpIndex],
          );
          soldByPump[pumpId] = _readings(petrol, diesel, twoT);
          pumpReadings[pumpId] = _addReadings(
            pumpReadings[pumpId]!,
            soldByPump[pumpId]!,
          );
          closingReadings[pumpId] = _copyReading(pumpReadings[pumpId]!);

          final salesman =
              _salesmen[(dayIndex + shiftIndex + pumpIndex) % _salesmen.length];
          pumpSalesmen[pumpId] = {
            'salesmanId': salesman['id'],
            'salesmanName': salesman['name'],
            'salesmanCode': salesman['code'],
          };
          pumpAttendants[pumpId] = salesman['name']?.toString() ?? '';
          pumpTesting[pumpId] = {
            'petrol': 2.5,
            'diesel': 2.0,
            'addToInventory': true,
          };
        }

        final totals = _fuelTotals(soldByPump.values);
        final revenue = _revenueFor(totals);
        final credit = _round(revenue * (0.055 + (shiftIndex * 0.004)));
        final cash = _round(revenue * 0.38);
        final upi = _round(revenue * 0.45);
        final check = _round(revenue - cash - upi - credit);
        final paymentBreakdown = {'cash': cash, 'check': check, 'upi': upi};
        final paymentTotal = _round(cash + check + upi + credit);

        for (var pumpIndex = 0; pumpIndex < 4; pumpIndex++) {
          final pumpId = 'pump${pumpIndex + 1}';
          final pumpRevenue = _revenueFor(soldByPump[pumpId]!);
          pumpPayments[pumpId] = {
            'cash': _round(pumpRevenue * 0.38),
            'check': _round(pumpRevenue * 0.12),
            'upi': _round(pumpRevenue * 0.45),
            'credit': _round(pumpRevenue * 0.05),
          };
          pumpCollections[pumpId] = pumpPayments[pumpId]!.values.fold<double>(
            0,
            (sum, value) => sum + value,
          );
        }

        final creditEntries = shiftIndex == dayIndex % 3
            ? [
                {
                  'pumpId': 'pump${(dayIndex % 4) + 1}',
                  'customerId': _customerId('Metro Logistics'),
                  'name': 'Metro Logistics',
                  'amount': _round(credit * 0.65),
                },
                {
                  'pumpId': 'pump${((dayIndex + 2) % 4) + 1}',
                  'customerId': _customerId('Sri Ganesh Transport'),
                  'name': 'Sri Ganesh Transport',
                  'amount': _round(credit * 0.35),
                },
              ]
            : <Map<String, dynamic>>[];
        final creditCollections = shiftIndex == (dayIndex + 1) % 3
            ? [
                {
                  'customerId': _customerId('Metro Logistics'),
                  'name': 'Metro Logistics',
                  'amount': _round(credit * 0.45),
                  'date': date,
                  'paymentMode': 'upi',
                  'note': 'Demo collection',
                },
              ]
            : <Map<String, dynamic>>[];

        final flagged = dayIndex % 8 == 0;
        final entry = {
          'id': 'entry-$date',
          'stationId': _stationId,
          'date': date,
          'shift': 'Daily',
          'status': 'approved',
          'flagged': flagged,
          'varianceNote': flagged
              ? 'Demo variance check: cash verified by manager.'
              : '',
          'submittedBy':
              _salesmen[(dayIndex + shiftIndex) % _salesmen.length]['id'],
          'submittedByName':
              _salesmen[(dayIndex + shiftIndex) % _salesmen.length]['name'],
          'reviewedBy': _adminId,
          'approvedAt': _timestamp(date, hour: 23, minute: shiftIndex + 10),
          'submittedAt': _timestamp(date, hour: 12 + shiftIndex * 4),
          'updatedAt': _timestamp(date, hour: 13 + shiftIndex * 4),
          'openingReadings': openingReadings,
          'closingReadings': closingReadings,
          'soldByPump': soldByPump,
          'pumpSalesmen': pumpSalesmen,
          'pumpAttendants': pumpAttendants,
          'pumpTesting': pumpTesting,
          'pumpPayments': pumpPayments,
          'pumpCollections': pumpCollections,
          'paymentBreakdown': paymentBreakdown,
          'creditEntries': creditEntries,
          'creditCollections': creditCollections,
          'totals': {
            'opening': _fuelTotals(openingReadings.values),
            'closing': _fuelTotals(closingReadings.values),
            'sold': totals,
          },
          'inventoryTotals': totals,
          'revenue': revenue,
          'computedRevenue': revenue,
          'paymentTotal': paymentTotal,
          'salesSettlementTotal': _round(cash + check + upi),
          'creditCollectionTotal': _round(
            creditCollections.fold<double>(
              0,
              (sum, item) => sum + _double(item['amount']),
            ),
          ),
          'mismatchAmount': flagged ? 120.0 : 0.0,
          'mismatchReason': flagged ? 'Demo manager note for showcase.' : '',
          'profit': _profitFor(totals),
          'priceSnapshot': _priceSnapshot(),
        };
        _entries.add(entry);
      }
      _dailyFuelRecords.add(_dailyFuelRecordForDate(date, dayIndex));
    }
  }

  void _seedInventoryHistory() {
    final dates = List<String>.generate(
      20,
      (index) => _dateKey(_anchorDate.subtract(Duration(days: 19 - index))),
    );
    for (var i = 0; i < dates.length; i += 5) {
      _deliveries.add({
        'id': 'delivery-${dates[i]}',
        'stationId': _stationId,
        'fuelTypeId': 'petrol',
        'date': dates[i],
        'quantity': 18000.0,
        'quantities': {
          'petrol': 18000.0,
          'diesel': 17000.0,
          'two_t_oil': 350.0,
        },
        'note': 'Scheduled demo replenishment',
        'purchasedByName': 'Demo Admin',
        'createdBy': _adminId,
        'createdAt': _timestamp(dates[i], hour: 8),
      });
    }
    _stockSnapshots.add({
      'id': 'stock-opening',
      'stationId': _stationId,
      'effectiveDate': dates.first,
      'stock': {'petrol': 125000.0, 'diesel': 120000.0, 'two_t_oil': 2200.0},
      'note': 'Static demo opening stock',
      'createdAt': _timestamp(dates.first),
      'createdBy': _adminId,
      'createdByName': 'Demo Admin',
    });
    _openingReadingLogs.add({
      'id': 'opening-${dates.first}',
      'stationId': _stationId,
      'effectiveDate': dates.first,
      'readings': _station['baseReadings'],
      'note': 'Demo opening pump readings',
      'createdAt': _timestamp(dates.first),
      'createdBy': _adminId,
      'createdByName': 'Demo Admin',
    });
    _priceRequests.add({
      'id': 'price-req-demo-01',
      'stationId': _stationId,
      'effectiveDate': _dateKey(_anchorDate.add(const Duration(days: 1))),
      'currentPrices': _priceSnapshot(),
      'requestedPrices': {
        'petrol': {'costPrice': 97.0, 'sellingPrice': 106.0},
        'diesel': {'costPrice': 86.2, 'sellingPrice': 93.8},
      },
      'note': 'Demo pending price update',
      'status': 'pending',
      'requestedAt': _timestamp(_dateKey(_anchorDate), hour: 10),
      'requestedBy': 'sales-003',
      'requestedByName': 'Charan Patel',
    });
  }

  void _seedUsers() {
    _managedUsers.addAll([
      {
        'id': _adminId,
        'name': 'Demo Admin',
        'email': 'demo.admin@fuelstation.local',
        'role': 'superadmin',
        'requestedRole': 'superadmin',
        'status': 'approved',
        'stationId': _stationId,
        'createdAt': _timestamp('2026-04-01'),
        'requestCreatedAt': '',
        'reviewedAt': _timestamp('2026-04-01'),
        'rejectionReason': '',
      },
      for (final salesman in _salesmen)
        {
          'id': salesman['id'],
          'name': salesman['name'],
          'email':
              '${salesman['code'].toString().toLowerCase()}@fuelstation.local',
          'role': 'sales',
          'requestedRole': 'sales',
          'status': 'approved',
          'stationId': _stationId,
          'createdAt': _timestamp('2026-04-02'),
          'requestCreatedAt': '',
          'reviewedAt': _timestamp('2026-04-02'),
          'rejectionReason': '',
        },
    ]);
    _accessRequests.add({
      'id': 'access-demo-01',
      'userId': 'pending-demo-01',
      'stationId': _stationId,
      'name': 'Naveen Demo',
      'email': 'naveen.demo@example.com',
      'roleRequested': 'sales',
      'status': 'pending',
      'createdAt': _timestamp(_dateKey(_anchorDate), hour: 9),
    });
  }

  Map<String, dynamic> _salesDashboard(String date) {
    final dayEntries = _entriesForRange(date, date);
    final totals = _entryTotals(dayEntries);
    return {
      'station': _station,
      'date': date,
      'setupExists': true,
      'allowedEntryDate': _dateKey(_anchorDate),
      'activeSetupDate': date,
      'entryLockedReason': '',
      'openingReadings': dayEntries.isEmpty
          ? _station['baseReadings']
          : dayEntries.first['openingReadings'],
      'selectedEntry': dayEntries.isEmpty ? null : dayEntries.last,
      'entryExists': dayEntries.isNotEmpty,
      'totals': totals,
      'todaysEntries': dayEntries,
      'dailyFuelRecord': _dailyFuelRecord(date),
      'dailyFuelRecordComplete': true,
      'priceSnapshot': _priceSnapshot(),
    };
  }

  Map<String, dynamic> _dailySummary(String date) {
    final dayEntries = _entriesForRange(date, date);
    final totals = _entryTotals(dayEntries);
    return {
      'date': date,
      'totals': totals,
      'distribution': dayEntries
          .map(
            (entry) => {
              'shift': entry['shift'],
              'revenue': entry['revenue'],
              'petrolSold': _sold(entry, 'petrol'),
              'dieselSold': _sold(entry, 'diesel'),
              'twoTSold': _sold(entry, 'twoT'),
              'status': entry['status'],
            },
          )
          .toList(),
      'entries': dayEntries,
    };
  }

  Map<String, dynamic> _managementDashboard(Uri uri) {
    final range = _rangeFromQuery(uri);
    final entries = _entriesForRange(range['fromDate']!, range['toDate']!);
    final totals = _entryTotals(entries);
    return {
      'station': _station,
      'today': _dateKey(_anchorDate),
      'range': range,
      'setupExists': true,
      'allowedEntryDate': _dateKey(_anchorDate),
      'activeSetupDate': _dateKey(_anchorDate),
      'entryLockedReason': '',
      'pendingRequests': _accessRequests.length,
      'varianceCount': entries
          .where((entry) => entry['flagged'] == true)
          .length,
      'totals': totals,
      'pumpPerformance': _pumpPerformance(entries),
      'attendantPerformance': _attendantPerformance(entries),
      'trend': _dashboardTrend(range['fromDate']!, range['toDate']!),
      'recentEntries': entries.reversed.take(8).toList(),
      'dailyFuelRecord': _dailyFuelRecord(_dateKey(_anchorDate)),
      'dailyFuelRecordComplete': true,
      'fuelTypes': _fuelTypes,
      'prices': _prices,
    };
  }

  Map<String, dynamic> _monthlyReport(Uri uri) {
    final range = _rangeFromQuery(uri);
    final entries = _entriesForRange(range['fromDate']!, range['toDate']!);
    final totals = _entryTotals(entries);
    return {
      'month':
          (uri.queryParameters['month'] ??
          _dateKey(_anchorDate).substring(0, 7)),
      'fromDate': range['fromDate'],
      'toDate': range['toDate'],
      'totals': totals,
      'paymentBreakdown': _paymentBreakdown(entries),
      'fuelBreakdown': {
        'petrol': totals['petrolSold'],
        'diesel': totals['dieselSold'],
        'twoT': totals['twoTSold'],
      },
      'trend': _monthlyTrend(range['fromDate']!, range['toDate']!),
    };
  }

  Map<String, dynamic> _inventoryDashboard() {
    final planning = _station['inventoryPlanning'] as Map<String, dynamic>;
    final current = planning['currentStock'] as Map<String, dynamic>;
    return {
      'station': _station,
      'inventoryPlanning': planning,
      'forecast': [
        _forecast('petrol', 'Petrol', _double(current['petrol']), 3000.0),
        _forecast('diesel', 'Diesel', _double(current['diesel']), 3000.0),
        _forecast('two_t_oil', '2T Oil', _double(current['two_t_oil']), 26.0),
      ],
      'deliveries': _deliveries.reversed.take(6).toList(),
      'activeStockSnapshot': _stockSnapshots.last,
    };
  }

  Map<String, dynamic> _daySetupState() {
    return {
      'setupExists': true,
      'allowedEntryDate': _dateKey(_anchorDate),
      'nextAllowedSetupDate': _dateKey(
        _anchorDate.add(const Duration(days: 1)),
      ),
      'activeSetupDate': _dateKey(_anchorDate),
      'entryLockedReason': '',
      'setups': _daySetups(Uri.parse('https://demo.local/inventory/day-setup')),
    };
  }

  List<Map<String, dynamic>> _daySetups(Uri uri) {
    final dates = _dailyFuelRecords
        .map((record) => record['date'].toString())
        .toList();
    return dates
        .map(
          (date) => {
            'id': 'setup-$date',
            'stationId': _stationId,
            'effectiveDate': date,
            'openingReadings': _entriesForRange(date, date).isEmpty
                ? _station['baseReadings']
                : _entriesForRange(date, date).first['openingReadings'],
            'startingStock': _dailyFuelRecord(date)['openingStock'],
            'fuelPrices': _priceSnapshot(),
            'note': 'Static demo day setup',
            'createdAt': _timestamp(date),
            'createdBy': _adminId,
            'createdByName': 'Demo Admin',
            'lockedAt': _timestamp(date, hour: 23),
            'lockedBy': _adminId,
            'lockedByName': 'Demo Admin',
          },
        )
        .where((setup) => _matchesRange(setup['effectiveDate'].toString(), uri))
        .toList();
  }

  List<Map<String, dynamic>> _filterEntries(Uri uri) {
    String? from = uri.queryParameters['from'];
    String? to = uri.queryParameters['to'];
    final month = uri.queryParameters['month'];
    if (month != null && month.isNotEmpty) {
      from = '$month-01';
      to = _monthEnd(month);
    }
    from ??= _dateKey(_anchorDate.subtract(const Duration(days: 30)));
    to ??= _dateKey(_anchorDate);
    return _entriesForRange(from, to);
  }

  List<Map<String, dynamic>> _entriesForRange(String fromDate, String toDate) {
    return _entries.where((entry) {
      final date = entry['date']?.toString() ?? '';
      return date.compareTo(fromDate) >= 0 && date.compareTo(toDate) <= 0;
    }).toList()..sort((left, right) {
      final dateCompare = left['date'].toString().compareTo(
        right['date'].toString(),
      );
      if (dateCompare != 0) return dateCompare;
      return left['submittedAt'].toString().compareTo(
        right['submittedAt'].toString(),
      );
    });
  }

  Map<String, dynamic> _entryById(String id) {
    return _entries.firstWhere(
      (entry) => entry['id']?.toString() == id,
      orElse: () => _entries.isEmpty ? <String, dynamic>{} : _entries.last,
    );
  }

  Map<String, dynamic> _entryFromBody(
    Object? body, {
    required String status,
    String? id,
    String? date,
  }) {
    final data = _bodyMap(body);
    final entryDate = date ?? data['date']?.toString() ?? _dateKey(_anchorDate);
    final existingEntries = _entriesForRange(entryDate, entryDate);
    final fallbackClosing = existingEntries.isEmpty
        ? _station['baseReadings'] as Map<String, dynamic>
        : existingEntries.last['closingReadings'] as Map<String, dynamic>;
    final submittedClosing = _readingsMapFrom(data['closingReadings']);
    final closing = submittedClosing == null
        ? fallbackClosing
        : submittedClosing.map(
            (key, value) => MapEntry(key, <String, dynamic>{...value}),
          );
    final opening = _openingForDate(entryDate, closing);
    final soldByPump = <String, Map<String, double>>{};
    for (final pumpId in closing.keys) {
      final close = _doubleMap(
        closing[pumpId] as Map<String, dynamic>? ?? const {},
      );
      final open = _doubleMap(
        opening[pumpId] as Map<String, dynamic>? ?? const {},
      );
      soldByPump[pumpId] = {
        'petrol': _round((close['petrol'] ?? 0) - (open['petrol'] ?? 0)),
        'diesel': _round((close['diesel'] ?? 0) - (open['diesel'] ?? 0)),
        'twoT': _round((close['twoT'] ?? 0) - (open['twoT'] ?? 0)),
      };
    }
    final totals = _fuelTotals(soldByPump.values);
    final revenue = _revenueFor(totals);
    final paymentBreakdown = _bodyMap(data['paymentBreakdown']);
    final cash = _double(paymentBreakdown['cash']);
    final check = _double(paymentBreakdown['check']);
    final upi = _double(paymentBreakdown['upi']);
    return {
      'id':
          id ??
          'entry-$entryDate-custom-${DateTime.now().millisecondsSinceEpoch}',
      'stationId': _stationId,
      'date': entryDate,
      'shift': data['shift']?.toString() ?? 'Daily',
      'status': status,
      'flagged': false,
      'varianceNote': '',
      'submittedBy': _adminId,
      'submittedByName': 'Demo Admin',
      'reviewedBy': status == 'approved' ? _adminId : '',
      'approvedAt': status == 'approved' ? _timestamp(entryDate) : '',
      'submittedAt': _timestamp(entryDate),
      'updatedAt': _timestamp(entryDate),
      'openingReadings': opening,
      'closingReadings': closing,
      'soldByPump': soldByPump,
      'pumpSalesmen': _bodyMap(data['pumpSalesmen']),
      'pumpAttendants': _bodyMap(data['pumpAttendants']),
      'pumpTesting': _bodyMap(data['pumpTesting']),
      'pumpPayments': _bodyMap(data['pumpPayments']),
      'pumpCollections': _bodyMap(data['pumpCollections']),
      'paymentBreakdown': {'cash': cash, 'check': check, 'upi': upi},
      'creditEntries': data['creditEntries'] as List<dynamic>? ?? const [],
      'creditCollections':
          data['creditCollections'] as List<dynamic>? ?? const [],
      'totals': {
        'opening': _fuelTotals(opening.values),
        'closing': _fuelTotals(closing.values),
        'sold': totals,
      },
      'inventoryTotals': totals,
      'revenue': revenue,
      'computedRevenue': revenue,
      'paymentTotal': cash + check + upi,
      'salesSettlementTotal': cash + check + upi,
      'creditCollectionTotal': 0.0,
      'mismatchAmount': 0.0,
      'mismatchReason': data['mismatchReason']?.toString() ?? '',
      'profit': _profitFor(totals),
      'priceSnapshot': _priceSnapshot(),
    };
  }

  Map<String, dynamic> _openingForDate(
    String date,
    Map<String, dynamic> fallback,
  ) {
    final previous =
        _entries
            .where((entry) => entry['date'].toString().compareTo(date) < 0)
            .toList()
          ..sort(
            (left, right) => left['submittedAt'].toString().compareTo(
              right['submittedAt'].toString(),
            ),
          );
    if (previous.isEmpty) return fallback;
    return previous.last['closingReadings'] as Map<String, dynamic>;
  }

  void _upsertEntry(Map<String, dynamic> entry) {
    final entryDate = entry['date']?.toString() ?? '';
    _entries.removeWhere(
      (item) => item['id'] == entry['id'] || item['date'] == entryDate,
    );
    _entries.add(entry);
    _refreshStationStock();
  }

  Map<String, dynamic> _entryTotals(List<Map<String, dynamic>> entries) {
    final sold = {'petrol': 0.0, 'diesel': 0.0, 'twoT': 0.0};
    var revenue = 0.0;
    var paymentTotal = 0.0;
    var profit = 0.0;
    var creditTotal = 0.0;
    for (final entry in entries) {
      sold['petrol'] = sold['petrol']! + _sold(entry, 'petrol');
      sold['diesel'] = sold['diesel']! + _sold(entry, 'diesel');
      sold['twoT'] = sold['twoT']! + _sold(entry, 'twoT');
      revenue += _double(entry['revenue']);
      paymentTotal += _double(entry['paymentTotal']);
      profit += _double(entry['profit']);
      for (final credit
          in entry['creditEntries'] as List<dynamic>? ?? const []) {
        creditTotal += _double((credit as Map<String, dynamic>)['amount']);
      }
    }
    return {
      'revenue': _round(revenue),
      'paymentTotal': _round(paymentTotal),
      'profit': _round(profit),
      'petrolSold': _round(sold['petrol']!),
      'dieselSold': _round(sold['diesel']!),
      'twoTSold': _round(sold['twoT']!),
      'creditTotal': _round(creditTotal),
      'flaggedCount': entries.where((entry) => entry['flagged'] == true).length,
      'entriesCompleted': entries
          .where((entry) => entry['status'] != 'draft')
          .length,
      'shiftsCompleted': entries
          .where((entry) => entry['status'] != 'draft')
          .length,
    };
  }

  List<Map<String, dynamic>> _pumpPerformance(
    List<Map<String, dynamic>> entries,
  ) {
    return ['pump1', 'pump2', 'pump3', 'pump4'].map((pumpId) {
      final liters = {'petrol': 0.0, 'diesel': 0.0, 'twoT': 0.0};
      var collected = 0.0;
      final attendants = <String>{};
      for (final entry in entries) {
        final soldByPump =
            entry['soldByPump'] as Map<String, dynamic>? ?? const {};
        final sold = _doubleMap(
          soldByPump[pumpId] as Map<String, dynamic>? ?? const {},
        );
        liters['petrol'] = liters['petrol']! + (sold['petrol'] ?? 0);
        liters['diesel'] = liters['diesel']! + (sold['diesel'] ?? 0);
        liters['twoT'] = liters['twoT']! + (sold['twoT'] ?? 0);
        final collections =
            entry['pumpCollections'] as Map<String, dynamic>? ?? const {};
        collected += _double(collections[pumpId]);
        final names =
            entry['pumpAttendants'] as Map<String, dynamic>? ?? const {};
        if ((names[pumpId]?.toString() ?? '').isNotEmpty) {
          attendants.add(names[pumpId].toString());
        }
      }
      final computed = _revenueFor(liters);
      return {
        'pumpId': pumpId,
        'pumpLabel': 'Pump ${pumpId.substring(4)}',
        'liters': _roundReadings(liters),
        'totalLiters': _round(
          liters.values.fold<double>(0, (sum, value) => sum + value),
        ),
        'collectedAmount': _round(collected),
        'computedSalesValue': computed,
        'variance': _round(collected - computed),
        'attendantsSeen': attendants.toList(),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _attendantPerformance(
    List<Map<String, dynamic>> entries,
  ) {
    return _salesmen.map((salesman) {
      final name = salesman['name'].toString();
      final liters = {'petrol': 0.0, 'diesel': 0.0, 'twoT': 0.0};
      final days = <String>{};
      final pumps = <String>{};
      var collected = 0.0;
      for (final entry in entries) {
        final attendants =
            entry['pumpAttendants'] as Map<String, dynamic>? ?? const {};
        final soldByPump =
            entry['soldByPump'] as Map<String, dynamic>? ?? const {};
        final collections =
            entry['pumpCollections'] as Map<String, dynamic>? ?? const {};
        for (final pumpId in attendants.keys) {
          if (attendants[pumpId]?.toString() != name) continue;
          final sold = _doubleMap(
            soldByPump[pumpId] as Map<String, dynamic>? ?? const {},
          );
          liters['petrol'] = liters['petrol']! + (sold['petrol'] ?? 0);
          liters['diesel'] = liters['diesel']! + (sold['diesel'] ?? 0);
          liters['twoT'] = liters['twoT']! + (sold['twoT'] ?? 0);
          collected += _double(collections[pumpId]);
          days.add(entry['date'].toString());
          pumps.add(pumpId);
        }
      }
      final computed = _revenueFor(liters);
      return {
        'attendantName': name,
        'liters': _roundReadings(liters),
        'totalLiters': _round(
          liters.values.fold<double>(0, (sum, value) => sum + value),
        ),
        'collectedAmount': _round(collected),
        'computedSalesValue': computed,
        'variance': _round(collected - computed),
        'activeDays': days.length,
        'pumpsWorked': pumps.toList(),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _dashboardTrend(String fromDate, String toDate) {
    return _datesBetween(fromDate, toDate).map((date) {
      final entries = _entriesForRange(date, date);
      final totals = _entryTotals(entries);
      return {
        'date': date,
        'totalLiters': _round(
          _double(totals['petrolSold']) +
              _double(totals['dieselSold']) +
              _double(totals['twoTSold']),
        ),
        'petrolSold': totals['petrolSold'],
        'dieselSold': totals['dieselSold'],
        'collectedAmount': totals['paymentTotal'],
        'computedSalesValue': totals['revenue'],
        'approvedEntries': totals['entriesCompleted'],
      };
    }).toList();
  }

  List<Map<String, dynamic>> _monthlyTrend(String fromDate, String toDate) {
    return _datesBetween(fromDate, toDate)
        .map((date) {
          final entries = _entriesForRange(date, date);
          final totals = _entryTotals(entries);
          return {
            'date': date,
            'revenue': totals['revenue'],
            'paymentTotal': totals['paymentTotal'],
            'profit': totals['profit'],
            'petrolSold': totals['petrolSold'],
            'dieselSold': totals['dieselSold'],
            'twoTSold': totals['twoTSold'],
            'entries': totals['entriesCompleted'],
            'shifts': totals['shiftsCompleted'],
          };
        })
        .where((point) => _double(point['entries']) > 0)
        .toList();
  }

  Map<String, double> _paymentBreakdown(List<Map<String, dynamic>> entries) {
    final totals = {'cash': 0.0, 'check': 0.0, 'upi': 0.0};
    for (final entry in entries) {
      final payments =
          entry['paymentBreakdown'] as Map<String, dynamic>? ?? const {};
      for (final key in totals.keys) {
        totals[key] = totals[key]! + _double(payments[key]);
      }
    }
    return totals.map((key, value) => MapEntry(key, _round(value)));
  }

  List<Map<String, dynamic>> _creditCustomers(Uri uri) {
    final transactions = _creditTransactions(uri);
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final transaction in transactions) {
      grouped
          .putIfAbsent(transaction['customerId'].toString(), () => [])
          .add(transaction);
    }
    final customers = <Map<String, dynamic>>[];
    for (final items in grouped.values) {
      var balance = 0.0;
      var issued = 0.0;
      var collected = 0.0;
      for (final item in items) {
        if (item['type'] == 'issue') {
          balance += _double(item['amount']);
          issued += _double(item['amount']);
        } else {
          balance -= _double(item['amount']);
          collected += _double(item['amount']);
        }
        item['runningBalance'] = _round(balance);
      }
      final first = items.first;
      final last = items.last;
      customers.add({
        'customer': {
          'id': first['customerId'],
          'stationId': _stationId,
          'name': first['customerNameSnapshot'],
          'normalizedName': first['customerNameSnapshot']
              .toString()
              .toLowerCase(),
          'createdAt': first['createdAt'],
          'updatedAt': last['createdAt'],
          'lastUsedAt': last['createdAt'],
        },
        'currentBalance': _round(balance),
        'status': balance > 0 ? 'open' : 'closed',
        'totalIssued': _round(issued),
        'totalCollected': _round(collected),
        'issuedInRange': _round(issued),
        'collectedInRange': _round(collected),
        'openedAt': first['date'],
        'lastClosedAt': balance <= 0 ? last['date'] : '',
        'lastActivityDate': last['date'],
      });
    }
    customers.sort(
      (a, b) =>
          _double(b['currentBalance']).compareTo(_double(a['currentBalance'])),
    );
    return customers;
  }

  Map<String, dynamic> _creditSummary(List<Map<String, dynamic>> customers) {
    final open = customers.where((item) => item['status'] == 'open').toList();
    return {
      'openCustomerCount': open.length,
      'openBalanceTotal': _round(
        open.fold<double>(
          0,
          (sum, item) => sum + _double(item['currentBalance']),
        ),
      ),
      'collectedInRangeTotal': _round(
        customers.fold<double>(
          0,
          (sum, item) => sum + _double(item['collectedInRange']),
        ),
      ),
    };
  }

  Map<String, dynamic> _creditCustomerDetail(String customerId, Uri uri) {
    final transactions = _creditTransactions(
      uri,
    ).where((item) => item['customerId'] == customerId).toList();
    if (transactions.isEmpty) {
      return {
        'customer': {
          'id': customerId,
          'stationId': _stationId,
          'name': 'Demo Customer',
        },
        'currentBalance': 0,
        'status': 'closed',
        'totalIssued': 0,
        'totalCollected': 0,
        'issuedInRange': 0,
        'collectedInRange': 0,
        'openedAt': '',
        'lastClosedAt': '',
        'lastActivityDate': '',
        'transactions': [],
      };
    }
    final summary = _creditCustomers(uri).firstWhere(
      (item) => (item['customer'] as Map<String, dynamic>)['id'] == customerId,
      orElse: () => <String, dynamic>{},
    );
    return {...summary, 'transactions': transactions};
  }

  List<Map<String, dynamic>> _creditTransactions(Uri uri) {
    final transactions = <Map<String, dynamic>>[];
    for (final entry in _filterEntries(uri)) {
      for (final credit
          in entry['creditEntries'] as List<dynamic>? ?? const []) {
        final item = credit as Map<String, dynamic>;
        transactions.add({
          'id': '${entry['id']}:issue:${transactions.length}',
          'stationId': _stationId,
          'customerId': item['customerId'],
          'customerNameSnapshot': item['name'],
          'type': 'issue',
          'amount': item['amount'],
          'date': entry['date'],
          'paymentMode': '',
          'entryId': entry['id'],
          'createdBy': entry['submittedByName'],
          'createdAt': entry['submittedAt'],
          'note': '',
          'runningBalance': 0,
        });
      }
      for (final collection
          in entry['creditCollections'] as List<dynamic>? ?? const []) {
        final item = collection as Map<String, dynamic>;
        transactions.add({
          'id': '${entry['id']}:collection:${transactions.length}',
          'stationId': _stationId,
          'customerId': item['customerId'],
          'customerNameSnapshot': item['name'],
          'type': 'collection',
          'amount': item['amount'],
          'date': item['date'] ?? entry['date'],
          'paymentMode': item['paymentMode'],
          'entryId': entry['id'],
          'createdBy': entry['submittedByName'],
          'createdAt': entry['submittedAt'],
          'note': item['note'] ?? '',
          'runningBalance': 0,
        });
      }
    }
    transactions.sort(
      (a, b) => a['date'].toString().compareTo(b['date'].toString()),
    );
    return transactions;
  }

  Map<String, dynamic> _userManagementOverview() {
    final approved = _managedUsers
        .where((user) => user['status'] == 'approved')
        .toList();
    return {
      'summary': {
        'totalUsers': _managedUsers.length,
        'approvedUsers': approved.length,
        'pendingRequests': _accessRequests.length,
        'adminCount': approved.where((user) => user['role'] == 'admin').length,
        'salesCount': approved.where((user) => user['role'] == 'sales').length,
        'superAdminCount': approved
            .where((user) => user['role'] == 'superadmin')
            .length,
      },
      'permissions': {'canManageSuperAdmins': true},
      'users': _managedUsers,
      'requests': _accessRequests,
    };
  }

  Map<String, dynamic> _rangeFromQuery(Uri uri) {
    final month = uri.queryParameters['month'];
    final from = uri.queryParameters['from'];
    final to = uri.queryParameters['to'];
    if (from != null && from.isNotEmpty && to != null && to.isNotEmpty) {
      return {
        'label': '$from to $to',
        'preset': 'custom',
        'fromDate': from,
        'toDate': to,
      };
    }
    if (month != null && month.isNotEmpty) {
      return {
        'label': month,
        'preset': 'month',
        'fromDate': '$month-01',
        'toDate': _monthEnd(month),
      };
    }
    final currentMonth = _dateKey(_anchorDate).substring(0, 7);
    return {
      'label': currentMonth,
      'preset': 'month',
      'fromDate': '$currentMonth-01',
      'toDate': _monthEnd(currentMonth),
    };
  }

  void _refreshStationStock() {
    final opening = {
      'petrol': 125000.0,
      'diesel': 120000.0,
      'two_t_oil': 2200.0,
    };
    for (final delivery in _deliveries) {
      final quantities =
          delivery['quantities'] as Map<String, dynamic>? ?? const {};
      opening['petrol'] = opening['petrol']! + _double(quantities['petrol']);
      opening['diesel'] = opening['diesel']! + _double(quantities['diesel']);
      opening['two_t_oil'] =
          opening['two_t_oil']! + _double(quantities['two_t_oil']);
    }
    for (final entry in _entries) {
      opening['petrol'] = opening['petrol']! - _sold(entry, 'petrol');
      opening['diesel'] = opening['diesel']! - _sold(entry, 'diesel');
      opening['two_t_oil'] = opening['two_t_oil']! - _sold(entry, 'twoT');
    }
    final planning = _station['inventoryPlanning'] as Map<String, dynamic>;
    planning['currentStock'] = opening.map(
      (key, value) => MapEntry(key, _round(value)),
    );
  }

  Map<String, dynamic> _setupFromBody(Object? body) {
    final data = _bodyMap(body);
    final date = data['effectiveDate']?.toString() ?? _dateKey(_anchorDate);
    return {
      'id': 'setup-$date',
      'stationId': _stationId,
      'effectiveDate': date,
      'openingReadings': _bodyMap(data['openingReadings']),
      'startingStock': _bodyMap(data['startingStock']),
      'fuelPrices': _bodyMap(data['fuelPrices']),
      'note': data['note']?.toString() ?? '',
      'createdAt': _timestamp(date),
      'createdBy': _adminId,
      'createdByName': 'Demo Admin',
    };
  }

  Map<String, dynamic> _priceRequestFromBody(Object? body) {
    final data = _bodyMap(body);
    return {
      'id': 'price-req-${_priceRequests.length + 1}',
      'stationId': _stationId,
      'effectiveDate':
          data['effectiveDate']?.toString() ?? _dateKey(_anchorDate),
      'currentPrices': _priceSnapshot(),
      'requestedPrices': _bodyMap(data['fuelPrices']),
      'note': data['note']?.toString() ?? '',
      'status': 'pending',
      'requestedAt': _timestamp(_dateKey(_anchorDate)),
      'requestedBy': _adminId,
      'requestedByName': 'Demo Admin',
    };
  }

  Map<String, dynamic> _dailyFuelRecordFromBody(Object? body) {
    final data = _bodyMap(body);
    final date = data['date']?.toString() ?? _dateKey(_anchorDate);
    return {
      ..._dailyFuelRecord(date),
      'density': _bodyMap(data['density']),
      'updatedAt': _timestamp(date),
      'updatedBy': _adminId,
      'updatedByName': 'Demo Admin',
      'exists': true,
      'complete': true,
    };
  }

  Map<String, dynamic> _deliveryFromBody(Object? body) {
    final data = _bodyMap(body);
    final date = data['date']?.toString() ?? _dateKey(_anchorDate);
    final quantities = _bodyMap(data['quantities']);
    return {
      'id': 'delivery-$date-${_deliveries.length + 1}',
      'stationId': _stationId,
      'fuelTypeId': 'petrol',
      'date': date,
      'quantity': _double(quantities['petrol']),
      'quantities': quantities,
      'note': data['note']?.toString() ?? '',
      'purchasedByName': 'Demo Admin',
      'createdBy': _adminId,
      'createdAt': _timestamp(date),
    };
  }

  Map<String, dynamic> _stockSnapshotFromBody(Object? body) {
    final data = _bodyMap(body);
    final date = data['effectiveDate']?.toString() ?? _dateKey(_anchorDate);
    return {
      'id': 'stock-$date-${_stockSnapshots.length + 1}',
      'stationId': _stationId,
      'effectiveDate': date,
      'stock': _bodyMap(data['stock']),
      'note': data['note']?.toString() ?? '',
      'createdAt': _timestamp(date),
      'createdBy': _adminId,
      'createdByName': 'Demo Admin',
    };
  }

  Map<String, dynamic> _openingLogFromBody(Object? body) {
    final data = _bodyMap(body);
    final date = data['effectiveDate']?.toString() ?? _dateKey(_anchorDate);
    return {
      'id': 'opening-$date-${_openingReadingLogs.length + 1}',
      'stationId': _stationId,
      'effectiveDate': date,
      'readings': _bodyMap(data['readings']),
      'note': data['note']?.toString() ?? '',
      'createdAt': _timestamp(date),
      'createdBy': _adminId,
      'createdByName': 'Demo Admin',
    };
  }

  List<Map<String, dynamic>> _filterPriceRequests(Uri uri) {
    final status = uri.queryParameters['status']?.trim() ?? '';
    if (status.isEmpty) return _priceRequests;
    return _priceRequests.where((item) => item['status'] == status).toList();
  }

  List<Map<String, dynamic>> _filterRecords(
    Uri uri,
    List<Map<String, dynamic>> records,
  ) {
    return records.where((item) {
      final date = (item['date'] ?? item['effectiveDate'] ?? '').toString();
      return _matchesRange(date, uri);
    }).toList();
  }

  bool _matchesRange(String date, Uri uri) {
    final from = uri.queryParameters['from'];
    final to = uri.queryParameters['to'];
    if (from != null && from.isNotEmpty && date.compareTo(from) < 0) {
      return false;
    }
    if (to != null && to.isNotEmpty && date.compareTo(to) > 0) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> _mergeStation(Map<String, dynamic> patch) {
    final next = {..._station};
    for (final entry in patch.entries) {
      next[entry.key] = entry.value;
    }
    next['id'] = _stationId;
    return next;
  }

  Map<String, dynamic> _dailyFuelRecord(String date) {
    return _dailyFuelRecords.firstWhere(
      (record) => record['date'] == date,
      orElse: () => _dailyFuelRecordForDate(date, 0),
    );
  }

  Map<String, dynamic> _dailyFuelRecordForDate(String date, int index) {
    return {
      'id': 'fuel-$date',
      'stationId': _stationId,
      'date': date,
      'openingStock': {
        'petrol': _round(125000.0 - index * 3000.0),
        'diesel': _round(120000.0 - index * 3000.0),
      },
      'density': {'petrol': 748.0 + (index % 3), 'diesel': 832.0 + (index % 4)},
      'price': {'petrol': 105.50, 'diesel': 93.20},
      'sourceClosingDate': _dateKey(
        DateTime.parse(date).subtract(const Duration(days: 1)),
      ),
      'createdBy': _adminId,
      'createdByName': 'Demo Admin',
      'updatedBy': _adminId,
      'updatedByName': 'Demo Admin',
      'createdAt': _timestamp(date),
      'updatedAt': _timestamp(date),
      'exists': true,
      'complete': true,
    };
  }

  Map<String, dynamic> _demoUser() {
    return {
      'id': _adminId,
      'name': 'Demo Admin',
      'email': 'demo.admin@fuelstation.local',
      'role': 'superadmin',
      'status': 'approved',
      'stationId': _stationId,
    };
  }

  Map<String, dynamic> _fuelType(
    String id,
    String name,
    String shortName,
    String color,
    String icon,
  ) {
    return {
      'id': id,
      'name': name,
      'shortName': shortName,
      'description': '$name demo fuel type',
      'color': color,
      'icon': icon,
      'active': true,
      'createdAt': _timestamp('2026-04-01'),
    };
  }

  Map<String, dynamic> _price(
    String fuelTypeId,
    double costPrice,
    double sellingPrice,
  ) {
    final period = {
      'effectiveFrom': '2026-04-01',
      'effectiveTo': '',
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'updatedAt': _timestamp('2026-04-01'),
      'updatedBy': _adminId,
    };
    return {
      'fuelTypeId': fuelTypeId,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'effectiveFrom': period['effectiveFrom'],
      'effectiveTo': '',
      'updatedAt': period['updatedAt'],
      'updatedBy': _adminId,
      'periods': [period],
    };
  }

  Map<String, dynamic> _salesman(String id, String name, String code) {
    return {
      'id': id,
      'name': name,
      'code': code,
      'active': true,
      'createdAt': _timestamp('2026-04-01'),
      'updatedAt': _timestamp('2026-04-01'),
    };
  }

  Map<String, dynamic> _forecast(
    String fuelTypeId,
    String label,
    double stock,
    double averageDailySales,
  ) {
    final days = averageDailySales <= 0 ? null : stock / averageDailySales;
    final runout = days == null
        ? ''
        : _dateKey(_anchorDate.add(Duration(days: days.floor())));
    return {
      'fuelTypeId': fuelTypeId,
      'label': label,
      'currentStock': _round(stock),
      'averageDailySales': averageDailySales,
      'daysRemaining': days == null ? null : _round(days),
      'projectedRunoutDate': runout,
      'recommendedOrderDate': runout.isEmpty
          ? ''
          : _dateKey(DateTime.parse(runout).subtract(const Duration(days: 5))),
      'shouldAlert': days != null && days < 7,
      'alertMessage': days != null && days < 7
          ? '$label stock is within the demo reorder window.'
          : '',
    };
  }

  Map<String, Map<String, double>>? _readingsMapFrom(dynamic value) {
    if (value is! Map) return null;
    return value.map(
      (key, item) => MapEntry(
        key.toString(),
        _doubleMap(item as Map<String, dynamic>? ?? const {}),
      ),
    );
  }

  Map<String, double> _readings(double petrol, double diesel, double twoT) {
    return {
      'petrol': _round(petrol),
      'diesel': _round(diesel),
      'twoT': _round(twoT),
    };
  }

  Map<String, double> _addReadings(
    Map<String, double> left,
    Map<String, double> right,
  ) {
    return {
      'petrol': _round((left['petrol'] ?? 0) + (right['petrol'] ?? 0)),
      'diesel': _round((left['diesel'] ?? 0) + (right['diesel'] ?? 0)),
      'twoT': _round((left['twoT'] ?? 0) + (right['twoT'] ?? 0)),
    };
  }

  Map<String, double> _copyReading(Map<String, double> source) {
    return {
      'petrol': source['petrol'] ?? 0,
      'diesel': source['diesel'] ?? 0,
      'twoT': source['twoT'] ?? 0,
    };
  }

  Map<String, Map<String, double>> _copyReadingsMap(
    Map<String, Map<String, double>> source,
  ) {
    return source.map((key, value) => MapEntry(key, _copyReading(value)));
  }

  Map<String, double> _roundReadings(Map<String, double> source) {
    return source.map((key, value) => MapEntry(key, _round(value)));
  }

  Map<String, double> _fuelTotals(Iterable<dynamic> readings) {
    final totals = {'petrol': 0.0, 'diesel': 0.0, 'twoT': 0.0};
    for (final raw in readings) {
      if (raw is! Map) {
        continue;
      }
      final item = _doubleMap(raw);
      totals['petrol'] = totals['petrol']! + (item['petrol'] ?? 0);
      totals['diesel'] = totals['diesel']! + (item['diesel'] ?? 0);
      totals['twoT'] = totals['twoT']! + (item['twoT'] ?? 0);
    }
    return totals.map((key, value) => MapEntry(key, _round(value)));
  }

  Map<String, double> _doubleMap(Map<dynamic, dynamic> source) {
    return source.map((key, value) => MapEntry(key.toString(), _double(value)));
  }

  Map<String, dynamic> _priceSnapshot() {
    return {
      for (final price in _prices)
        price['fuelTypeId'].toString(): {
          'sellingPrice': _double(price['sellingPrice']),
          'costPrice': _double(price['costPrice']),
        },
    };
  }

  double _sold(Map<String, dynamic> entry, String key) {
    final totals =
        entry['inventoryTotals'] as Map<String, dynamic>? ?? const {};
    return _double(totals[key]);
  }

  double _revenueFor(Map<String, double> sold) {
    return _round(
      (sold['petrol'] ?? 0) * 105.50 +
          (sold['diesel'] ?? 0) * 93.20 +
          (sold['twoT'] ?? 0) * 420.0,
    );
  }

  double _profitFor(Map<String, double> sold) {
    return _round(
      (sold['petrol'] ?? 0) * (105.50 - 96.25) +
          (sold['diesel'] ?? 0) * (93.20 - 85.80) +
          (sold['twoT'] ?? 0) * (420.0 - 360.0),
    );
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  double _round(double value) => double.parse(value.toStringAsFixed(2));

  Map<String, dynamic> _bodyMap(Object? body) {
    if (body == null) {
      return <String, dynamic>{};
    }
    if (body is Map<String, dynamic>) {
      return body;
    }
    if (body is Map) {
      return body.map((key, value) => MapEntry(key.toString(), value));
    }
    if (body is String && body.trim().isNotEmpty) {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    }
    return <String, dynamic>{};
  }

  List<String> _datesBetween(String fromDate, String toDate) {
    final from = DateTime.tryParse(fromDate) ?? _anchorDate;
    final to = DateTime.tryParse(toDate) ?? from;
    final days = to.difference(from).inDays;
    if (days < 0) return const [];
    return List<String>.generate(
      days + 1,
      (index) => _dateKey(from.add(Duration(days: index))),
    );
  }

  String _monthEnd(String month) {
    final parts = month.split('-');
    final year = int.tryParse(parts.first) ?? _anchorDate.year;
    final monthNumber = parts.length > 1
        ? int.tryParse(parts[1]) ?? _anchorDate.month
        : _anchorDate.month;
    return _dateKey(DateTime(year, monthNumber + 1, 0));
  }

  String _timestamp(String date, {int hour = 9, int minute = 0}) {
    final parsed = DateTime.tryParse(date) ?? _anchorDate;
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      hour,
      minute,
    ).toIso8601String();
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _customerId(String name) {
    return 'cust-${name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')}';
  }

  Map<String, dynamic> _fuelTypeById(String id) {
    return _fuelTypes.firstWhere(
      (item) => item['id'] == id,
      orElse: () => <String, dynamic>{},
    );
  }

  Map<String, dynamic> _priceRequestById(String id) {
    return _priceRequests.firstWhere(
      (item) => item['id'] == id,
      orElse: () => <String, dynamic>{},
    );
  }

  void _replaceById(
    List<Map<String, dynamic>> list,
    Map<String, dynamic> item,
  ) {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return;
    list.removeWhere((element) => element['id']?.toString() == id);
    list.add(item);
  }

  http.Response _json(Object? body, {int status = 200}) {
    return http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }

  http.Response _notFound(String method, String path) {
    return _json({
      'message': 'Demo route not found.',
      'method': method,
      'path': path,
    }, status: 404);
  }
}
