import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserSettings {
  const UserSettings({
    this.notificationsEnabled = true,
    this.reminderDays = 1,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.calendarRows = 2,
  });

  final bool notificationsEnabled;
  final int reminderDays;
  final int reminderHour;
  final int reminderMinute;
  final int calendarRows;

  UserSettings copyWith({bool? notificationsEnabled, int? reminderDays,
    int? reminderHour, int? reminderMinute, int? calendarRows}) => UserSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderDays: reminderDays ?? this.reminderDays,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      calendarRows: calendarRows ?? this.calendarRows,
    );
}

final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, UserSettings>(SettingsViewModel.new);

class SettingsViewModel extends Notifier<UserSettings> {
  @override
  UserSettings build() => const UserSettings();

  void setNotifications(bool enabled) =>
      state = state.copyWith(notificationsEnabled: enabled);
  void setReminderDays(int days) => state = state.copyWith(reminderDays: days);
  void setTime(int hour, int minute) =>
      state = state.copyWith(reminderHour: hour, reminderMinute: minute);
  void setCalendarRows(int rows) => state = state.copyWith(calendarRows: rows);
}
