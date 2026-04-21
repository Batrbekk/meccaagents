import 'package:flutter_riverpod/flutter_riverpod.dart';

// Shared Riverpod container so non-widget code (Dio interceptors, background
// callbacks, etc.) can read and invalidate providers.
final appContainer = ProviderContainer();
