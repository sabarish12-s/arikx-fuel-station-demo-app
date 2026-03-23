import 'package:flutter/widgets.dart';

import '../models/auth_models.dart';
import '../screens/login_screen.dart';
import '../screens/pending_approval_screen.dart';
import '../screens/sales_dashboard_screen.dart';
import '../screens/superadmin_requests_screen.dart';

Widget screenForUser(AuthUser? user) {
  if (user == null) {
    return const LoginScreen();
  }
  if (user.status == 'pending') {
    return const PendingApprovalScreen();
  }
  if (user.role == 'superadmin') {
    return const SuperAdminRequestsScreen();
  }
  return const SalesDashboardScreen();
}
