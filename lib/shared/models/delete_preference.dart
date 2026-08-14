enum DeletePreference {
  ask, // Always ask user
  listOnly, // Only remove from list
  fileOnly, // Only delete file
  both, // Delete both
}

extension DeletePreferenceExtension on DeletePreference {
  String get displayName {
    switch (this) {
      case DeletePreference.ask:
        return 'Always ask';
      case DeletePreference.listOnly:
        return 'Remove from list only';
      case DeletePreference.fileOnly:
        return 'Delete file only';
      case DeletePreference.both:
        return 'Delete both';
    }
  }

  String get description {
    switch (this) {
      case DeletePreference.ask:
        return 'Ask every time what to delete';
      case DeletePreference.listOnly:
        return 'Only remove from download history';
      case DeletePreference.fileOnly:
        return 'Only delete the downloaded file';
      case DeletePreference.both:
        return 'Remove from list and delete file';
    }
  }
}
