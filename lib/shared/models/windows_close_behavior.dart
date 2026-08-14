enum WindowsCloseBehavior { ask, minimizeToTray, exit }

extension WindowsCloseBehaviorDetails on WindowsCloseBehavior {
  String get displayName => switch (this) {
    WindowsCloseBehavior.ask => 'Ask every time',
    WindowsCloseBehavior.minimizeToTray => 'Minimize to system tray',
    WindowsCloseBehavior.exit => 'Exit MBNDL',
  };

  String get description => switch (this) {
    WindowsCloseBehavior.ask =>
      'Show the close dialog and let me choose each time.',
    WindowsCloseBehavior.minimizeToTray =>
      'Keep downloads running and hide MBNDL in the tray.',
    WindowsCloseBehavior.exit =>
      'Close the application completely when the window is closed.',
  };
}
