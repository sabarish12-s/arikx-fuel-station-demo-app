const CreditCustomer = require('../models/CreditCustomer');
const CreditTransaction = require('../models/CreditTransaction');

function roundNumber(value) {
  return Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;
}

function sortTransactions(transactions = []) {
  return [...transactions].sort((a, b) => {
    const dateCompare = String(a.date || '').localeCompare(String(b.date || ''));
    if (dateCompare !== 0) {
      return dateCompare;
    }
    return String(a.createdAt || '').localeCompare(String(b.createdAt || ''));
  });
}

function filterByRange(transactions = [], {from, to} = {}) {
  return transactions.filter((transaction) => {
    const date = String(transaction.date || '');
    if (from && date < from) {
      return false;
    }
    if (to && date > to) {
      return false;
    }
    return true;
  });
}

function summarizeLedgerFromTransactions(transactions = [], {from, to} = {}) {
  const balanceByCustomer = new Map();
  let collectedInRangeTotal = 0;

  for (const transaction of transactions) {
    const customerId = String(transaction.customerId || '').trim();
    if (!customerId) {
      continue;
    }
    const amount = Number(transaction.amount || 0);
    const nextBalance =
      Number(balanceByCustomer.get(customerId) || 0) +
      (transaction.type === 'issue' ? amount : -amount);
    balanceByCustomer.set(customerId, roundNumber(nextBalance));

    const date = String(transaction.date || '');
    const inRange =
      (!from || date >= from) &&
      (!to || date <= to);
    if (inRange && transaction.type === 'collection') {
      collectedInRangeTotal += amount;
    }
  }

  const openBalances = [...balanceByCustomer.values()].filter(
    (balance) => balance > 0,
  );

  return {
    openCustomerCount: openBalances.length,
    openBalanceTotal: roundNumber(
      openBalances.reduce((sum, balance) => sum + Number(balance || 0), 0),
    ),
    collectedInRangeTotal: roundNumber(collectedInRangeTotal),
  };
}

function summarizeCustomerTransactions(customer, transactions, rangeTransactions) {
  const ordered = sortTransactions(transactions);
  let balance = 0;
  let openedAt = '';
  let lastClosedAt = '';

  for (const transaction of ordered) {
    if (transaction.type === 'issue') {
      balance += Number(transaction.amount || 0);
      if (!openedAt) {
        openedAt = transaction.date;
      }
    } else {
      balance -= Number(transaction.amount || 0);
    }
    if (balance <= 0) {
      lastClosedAt = transaction.date;
    }
  }

  const totalIssued = roundNumber(
    ordered.reduce(
      (sum, transaction) =>
        sum + (transaction.type === 'issue' ? Number(transaction.amount || 0) : 0),
      0,
    ),
  );
  const totalCollected = roundNumber(
    ordered.reduce(
      (sum, transaction) =>
        sum + (transaction.type === 'collection' ? Number(transaction.amount || 0) : 0),
      0,
    ),
  );
  const issuedInRange = roundNumber(
    rangeTransactions.reduce(
      (sum, transaction) =>
        sum + (transaction.type === 'issue' ? Number(transaction.amount || 0) : 0),
      0,
    ),
  );
  const collectedInRange = roundNumber(
    rangeTransactions.reduce(
      (sum, transaction) =>
        sum + (transaction.type === 'collection' ? Number(transaction.amount || 0) : 0),
      0,
    ),
  );

  return {
    customer: customer.toJson(),
    currentBalance: roundNumber(totalIssued - totalCollected),
    status: totalIssued - totalCollected > 0 ? 'open' : 'closed',
    totalIssued,
    totalCollected,
    issuedInRange,
    collectedInRange,
    openedAt,
    lastClosedAt,
    lastActivityDate:
      ordered.length == 0 ? '' : ordered[ordered.length - 1].date,
  };
}

async function listCreditCustomers(stationId, {query, status = 'all', from, to} = {}) {
  await CreditTransaction.ensureBackfilledForStation(stationId);
  const [customers, transactions] = await Promise.all([
    CreditCustomer.allForStation(stationId),
    CreditTransaction.allForStation(stationId),
  ]);

  const queryValue = String(query || '').trim().toLowerCase();
  const byCustomer = new Map();
  for (const transaction of transactions) {
    const bucket = byCustomer.get(transaction.customerId) || [];
    bucket.push(transaction);
    byCustomer.set(transaction.customerId, bucket);
  }

  const summaries = customers
    .map((customer) => {
      const customerTransactions = byCustomer.get(customer.id) || [];
      const rangeTransactions = filterByRange(customerTransactions, {from, to});
      return summarizeCustomerTransactions(
        customer,
        customerTransactions,
        rangeTransactions,
      );
    })
    .filter((item) => {
      if (queryValue && !item.customer.name.toLowerCase().includes(queryValue)) {
        return false;
      }
      if (status === 'open' && item.currentBalance <= 0) {
        return false;
      }
      if (status === 'closed' && item.currentBalance > 0) {
        return false;
      }
      if ((from || to) && item.issuedInRange <= 0 && item.collectedInRange <= 0) {
        return false;
      }
      return true;
    })
    .sort((a, b) => {
      const activityCompare = String(b.lastActivityDate || '').localeCompare(
        String(a.lastActivityDate || ''),
      );
      if (activityCompare !== 0) {
        return activityCompare;
      }
      return a.customer.name.localeCompare(b.customer.name);
    });

  return {
    summary: summarizeLedgerFromTransactions(transactions, {from, to}),
    customers: summaries,
  };
}

async function getCreditLedgerSummary(stationId, {from, to} = {}) {
  await CreditTransaction.ensureBackfilledForStation(stationId);
  const transactions = await CreditTransaction.allForStation(stationId);
  return summarizeLedgerFromTransactions(transactions, {from, to});
}

async function getCreditCustomerDetail(stationId, customerId, {from, to, type = 'all'} = {}) {
  await CreditTransaction.ensureBackfilledForStation(stationId);
  const [customer, transactions] = await Promise.all([
    CreditCustomer.findById(customerId),
    CreditTransaction.allForCustomer(stationId, customerId),
  ]);
  if (!customer || customer.stationId !== stationId) {
    return null;
  }

  const customerTransactions = sortTransactions(
    transactions.filter((transaction) => transaction.customerId === customerId),
  );
  const summary = summarizeCustomerTransactions(
    customer,
    customerTransactions,
    filterByRange(customerTransactions, {from, to}),
  );

  let runningBalance = 0;
  const transactionsWithBalance = customerTransactions.map((transaction) => {
    if (transaction.type === 'issue') {
      runningBalance += Number(transaction.amount || 0);
    } else {
      runningBalance -= Number(transaction.amount || 0);
    }
    return {
      ...transaction.toJson(),
      runningBalance: roundNumber(runningBalance),
    };
  });

  const filteredTransactions = transactionsWithBalance.filter((transaction) => {
    if (type !== 'all' && transaction.type !== type) {
      return false;
    }
    if (from && String(transaction.date || '') < from) {
      return false;
    }
    if (to && String(transaction.date || '') > to) {
      return false;
    }
    return true;
  });

  return {
    ...summary,
    transactions: filteredTransactions,
  };
}

module.exports = {
  getCreditCustomerDetail,
  getCreditLedgerSummary,
  listCreditCustomers,
};
