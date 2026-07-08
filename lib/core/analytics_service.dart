import 'package:flutter/foundation.dart';

/// Lightweight analytics facade — swap for Firebase/Amplitude post-launch.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  void logEvent(String name, {Map<String, Object?> params = const {}}) {
    debugPrint('[Analytics] $name ${params.isEmpty ? '' : params}');
  }

  void trackScheduleCreateStart({int? dayCount}) {
    logEvent('schedule_create_start', params: {
      if (dayCount != null) 'day_count': dayCount,
    });
  }

  void trackScheduleCreateEnd({required bool success, int? dayCount, String? error}) {
    logEvent('schedule_create_end', params: {
      'success': success,
      if (dayCount != null) 'day_count': dayCount,
      if (error != null) 'error': error,
    });
  }

  void trackPublishSuccess({required int dayCount}) {
    logEvent('publish_success', params: {'day_count': dayCount});
  }

  void trackPublishFail({String? error}) {
    logEvent('publish_fail', params: {
      if (error != null) 'error': error,
    });
  }

  void trackStaffOpen() {
    logEvent('staff_open');
  }
}
