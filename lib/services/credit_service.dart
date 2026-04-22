import 'dart:convert';

import '../models/domain_models.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'sales_service.dart';

class CreditService {
  CreditService() : _apiClient = ApiClient(AuthService());

  final ApiClient _apiClient;
  final SalesService _salesService = SalesService();

  Future<CreditLedgerSummaryModel> fetchSummary({
    bool forceRefresh = false,
  }) async {
    final response = await _apiClient.get(
      '/credits/summary',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = _apiClient.decodeObject(response);
      return CreditLedgerSummaryModel.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      );
    }
    throw Exception(
      _apiClient.errorMessage(
        response,
        fallback: 'Failed to load credit summary.',
      ),
    );
  }

  Future<(CreditLedgerSummaryModel, List<CreditCustomerSummaryModel>)>
  fetchCustomers({
    String query = '',
    String status = 'all',
    String? fromDate,
    String? toDate,
    bool forceRefresh = false,
  }) async {
    final params = <String, String>{
      if (query.trim().isNotEmpty) 'query': query.trim(),
      if (status.trim().isNotEmpty) 'status': status.trim(),
      if (fromDate != null && fromDate.isNotEmpty) 'from': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'to': toDate,
    };
    final suffix = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final response = await _apiClient.get(
      '/credits/customers$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = _apiClient.decodeObject(response);
      return (
        CreditLedgerSummaryModel.fromJson(
          json['summary'] as Map<String, dynamic>? ?? const {},
        ),
        (json['customers'] as List<dynamic>? ?? const [])
            .map(
              (item) => CreditCustomerSummaryModel.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
      );
    }
    if (_isMissingRoute(response.body, '/credits/customers')) {
      return _buildLegacyCustomers(
        query: query,
        status: status,
        fromDate: fromDate,
        toDate: toDate,
      );
    }
    throw Exception(
      _apiClient.errorMessage(
        response,
        fallback: 'Failed to load credit customers.',
      ),
    );
  }

  Future<CreditCustomerDetailModel> fetchCustomerDetail(
    String customerId, {
    String? fromDate,
    String? toDate,
    String type = 'all',
    bool forceRefresh = false,
  }) async {
    final params = <String, String>{
      if (fromDate != null && fromDate.isNotEmpty) 'from': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'to': toDate,
      if (type.isNotEmpty && type != 'all') 'type': type,
    };
    final suffix = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final response = await _apiClient.get(
      '/credits/customers/$customerId$suffix',
      useCache: true,
      forceRefresh: forceRefresh,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return CreditCustomerDetailModel.fromJson(
        _apiClient.decodeObject(response),
      );
    }
    if (_isMissingRoute(response.body, '/credits/customers')) {
      return _buildLegacyCustomerDetail(
        customerId,
        fromDate: fromDate,
        toDate: toDate,
        type: type,
      );
    }
    throw Exception(
      _apiClient.errorMessage(
        response,
        fallback: 'Failed to load credit detail.',
      ),
    );
  }

  Future<CreditTransactionModel> recordCollection({
    required String name,
    required double amount,
    required String date,
    required String paymentMode,
    String customerId = '',
    String note = '',
  }) async {
    final response = await _apiClient.post(
      '/credits/collections',
      body: jsonEncode({
        'customerId': customerId,
        'name': name,
        'amount': amount,
        'date': date,
        'paymentMode': paymentMode,
        'note': note,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (_isMissingRoute(response.body, '/credits/collections')) {
        throw Exception(
          'This server does not support standalone collection recording yet. Update the backend before using this action.',
        );
      }
      throw Exception(
        _apiClient.errorMessage(
          response,
          fallback: 'Failed to record collection.',
        ),
      );
    }
    final json = _apiClient.decodeObject(response);
    return CreditTransactionModel.fromJson(
      json['transaction'] as Map<String, dynamic>? ?? const {},
    );
  }

  bool _isMissingRoute(String body, String route) {
    return body.toLowerCase().contains('cannot get ${route.toLowerCase()}') ||
        body.toLowerCase().contains('cannot post ${route.toLowerCase()}');
  }

  Future<(CreditLedgerSummaryModel, List<CreditCustomerSummaryModel>)>
  _buildLegacyCustomers({
    required String query,
    required String status,
    String? fromDate,
    String? toDate,
  }) async {
    final transactions = await _legacyTransactions();
    final grouped = <String, List<CreditTransactionModel>>{};
    for (final transaction in transactions) {
      grouped.putIfAbsent(transaction.customerId, () => []).add(transaction);
    }

    final customers =
        grouped.entries
            .map(
              (entry) => _legacySummaryFromTransactions(
                entry.value,
                fromDate: fromDate,
                toDate: toDate,
              ),
            )
            .where((item) {
              if (query.trim().isNotEmpty &&
                  !item.customer.name.toLowerCase().contains(
                    query.trim().toLowerCase(),
                  )) {
                return false;
              }
              if (status != 'all' && item.status != status) {
                return false;
              }
              if (!_matchesRange(item.lastActivityDate, fromDate, toDate)) {
                return false;
              }
              return true;
            })
            .toList()
          ..sort((a, b) {
            final balanceCompare = b.currentBalance.compareTo(a.currentBalance);
            if (balanceCompare != 0) {
              return balanceCompare;
            }
            return b.lastActivityDate.compareTo(a.lastActivityDate);
          });

    return (
      CreditLedgerSummaryModel(
        openCustomerCount: customers
            .where((item) => item.status == 'open')
            .length,
        openBalanceTotal: customers
            .where((item) => item.status == 'open')
            .fold<double>(0, (sum, item) => sum + item.currentBalance),
        collectedInRangeTotal: customers.fold<double>(
          0,
          (sum, item) => sum + item.collectedInRange,
        ),
      ),
      customers,
    );
  }

  Future<CreditCustomerDetailModel> _buildLegacyCustomerDetail(
    String customerId, {
    String? fromDate,
    String? toDate,
    String type = 'all',
  }) async {
    final transactions =
        (await _legacyTransactions())
            .where((item) => item.customerId == customerId)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (transactions.isEmpty) {
      return CreditCustomerDetailModel(
        customer: CreditCustomerModel(
          id: customerId,
          stationId: '',
          name: 'Unknown customer',
          normalizedName: '',
          createdAt: '',
          updatedAt: '',
          lastUsedAt: '',
        ),
        currentBalance: 0,
        status: 'closed',
        totalIssued: 0,
        totalCollected: 0,
        issuedInRange: 0,
        collectedInRange: 0,
        openedAt: '',
        lastClosedAt: '',
        lastActivityDate: '',
        transactions: const [],
      );
    }

    final summary = _legacySummaryFromTransactions(
      transactions,
      fromDate: fromDate,
      toDate: toDate,
    );
    final filteredTransactions = transactions.where((item) {
      if (!_matchesRange(item.date, fromDate, toDate)) {
        return false;
      }
      if (type != 'all' && item.type != type) {
        return false;
      }
      return true;
    }).toList();

    return CreditCustomerDetailModel(
      customer: summary.customer,
      currentBalance: summary.currentBalance,
      status: summary.status,
      totalIssued: summary.totalIssued,
      totalCollected: summary.totalCollected,
      issuedInRange: summary.issuedInRange,
      collectedInRange: summary.collectedInRange,
      openedAt: summary.openedAt,
      lastClosedAt: summary.lastClosedAt,
      lastActivityDate: summary.lastActivityDate,
      transactions: filteredTransactions,
    );
  }

  Future<List<CreditTransactionModel>> _legacyTransactions() async {
    final entries = await _salesService.fetchEntries();
    final transactions = <CreditTransactionModel>[];

    for (final entry in entries) {
      for (final credit in entry.creditEntries) {
        final customerId = _legacyCustomerId(credit.customerId, credit.name);
        if (credit.name.trim().isEmpty || credit.amount <= 0) {
          continue;
        }
        transactions.add(
          CreditTransactionModel(
            id: '${entry.id}:issue:$customerId:${transactions.length}',
            stationId: entry.stationId,
            customerId: customerId,
            customerNameSnapshot: credit.name.trim(),
            type: 'issue',
            amount: credit.amount,
            date: entry.date,
            paymentMode: '',
            entryId: entry.id,
            createdBy: entry.submittedByName,
            createdAt: entry.submittedAt,
            note: '',
            runningBalance: 0,
          ),
        );
      }
      for (final collection in entry.creditCollections) {
        final customerId = _legacyCustomerId(
          collection.customerId,
          collection.name,
        );
        if (collection.name.trim().isEmpty || collection.amount <= 0) {
          continue;
        }
        transactions.add(
          CreditTransactionModel(
            id: '${entry.id}:collection:$customerId:${transactions.length}',
            stationId: entry.stationId,
            customerId: customerId,
            customerNameSnapshot: collection.name.trim(),
            type: 'collection',
            amount: collection.amount,
            date: collection.date.isEmpty ? entry.date : collection.date,
            paymentMode: collection.paymentMode,
            entryId: entry.id,
            createdBy: entry.submittedByName,
            createdAt: entry.submittedAt,
            note: collection.note,
            runningBalance: 0,
          ),
        );
      }
    }

    final grouped = <String, List<CreditTransactionModel>>{};
    for (final item in transactions) {
      grouped.putIfAbsent(item.customerId, () => []).add(item);
    }

    final resolved = <CreditTransactionModel>[];
    for (final group in grouped.values) {
      group.sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
      var balance = 0.0;
      for (final item in group) {
        balance += item.type == 'issue' ? item.amount : -item.amount;
        resolved.add(
          CreditTransactionModel(
            id: item.id,
            stationId: item.stationId,
            customerId: item.customerId,
            customerNameSnapshot: item.customerNameSnapshot,
            type: item.type,
            amount: item.amount,
            date: item.date,
            paymentMode: item.paymentMode,
            entryId: item.entryId,
            createdBy: item.createdBy,
            createdAt: item.createdAt,
            note: item.note,
            runningBalance: balance,
          ),
        );
      }
    }

    return resolved;
  }

  CreditCustomerSummaryModel _legacySummaryFromTransactions(
    List<CreditTransactionModel> transactions, {
    String? fromDate,
    String? toDate,
  }) {
    final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
    final first = sorted.first;
    final double currentBalance = sorted.last.runningBalance;
    final totalIssued = sorted
        .where((item) => item.type == 'issue')
        .fold<double>(0, (sum, item) => sum + item.amount);
    final totalCollected = sorted
        .where((item) => item.type == 'collection')
        .fold<double>(0, (sum, item) => sum + item.amount);
    final issuedInRange = sorted
        .where(
          (item) =>
              item.type == 'issue' &&
              _matchesRange(item.date, fromDate, toDate),
        )
        .fold<double>(0, (sum, item) => sum + item.amount);
    final collectedInRange = sorted
        .where(
          (item) =>
              item.type == 'collection' &&
              _matchesRange(item.date, fromDate, toDate),
        )
        .fold<double>(0, (sum, item) => sum + item.amount);

    String lastClosedAt = '';
    for (final item in sorted) {
      if (item.runningBalance <= 0) {
        lastClosedAt = item.date;
      }
    }

    return CreditCustomerSummaryModel(
      customer: CreditCustomerModel(
        id: first.customerId,
        stationId: first.stationId,
        name: first.customerNameSnapshot,
        normalizedName: _normalizeName(first.customerNameSnapshot),
        createdAt: first.createdAt,
        updatedAt: sorted.last.createdAt,
        lastUsedAt: sorted.last.createdAt,
      ),
      currentBalance: currentBalance,
      status: currentBalance > 0 ? 'open' : 'closed',
      totalIssued: totalIssued,
      totalCollected: totalCollected,
      issuedInRange: issuedInRange,
      collectedInRange: collectedInRange,
      openedAt: sorted
          .firstWhere(
            (item) => item.type == 'issue',
            orElse: () => sorted.first,
          )
          .date,
      lastClosedAt: lastClosedAt,
      lastActivityDate: sorted.last.date,
    );
  }

  bool _matchesRange(String date, String? fromDate, String? toDate) {
    if (date.isEmpty) {
      return fromDate == null && toDate == null;
    }
    if (fromDate != null &&
        fromDate.isNotEmpty &&
        date.compareTo(fromDate) < 0) {
      return false;
    }
    if (toDate != null && toDate.isNotEmpty && date.compareTo(toDate) > 0) {
      return false;
    }
    return true;
  }

  String _legacyCustomerId(String customerId, String name) {
    final direct = customerId.trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    return 'legacy:${_normalizeName(name)}';
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
