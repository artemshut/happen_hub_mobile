import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';

class UserController extends StateNotifier<User?> {
  UserController() : super(null);

  void setUser(User user) => state = user;

  void clearUser() => state = null;
}

final userProvider =
    StateNotifierProvider<UserController, User?>((ref) => UserController());
