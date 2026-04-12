import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agentteam/features/auth/data/auth_repository.dart';
import 'package:agentteam/features/auth/domain/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final repo = ref.read(authRepositoryProvider);
    return repo.getCurrentUser();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      return repo.login(email, password);
    });
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncData(null);
  }
}
