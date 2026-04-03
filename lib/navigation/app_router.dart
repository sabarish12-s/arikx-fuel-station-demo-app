import 'package:flutter/widgets.dart';

import '../models/auth_models.dart';
import '../screens/login_screen.dart';
import '../screens/management_shell.dart';
import '../screens/pending_approval_screen.dart';
import '../screens/sales_shell.dart';

Widget screenForUser(AuthUser? user) {
  if (user == null) {
    return const LoginScreen();
  }
  if (user.status == 'pending' || user.status == 'rejected') {
    return PendingApprovalScreen(user: user);
  }
  if (user.role == 'admin' || user.role == 'superadmin') {
    return ManagementShell(user: user);
  }
  return SalesShell(user: user);
}
