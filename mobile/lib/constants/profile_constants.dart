class ProfileConstants {
  // Simplified onboarding constants

  /// Exam types for simplified onboarding (Screen 2)
  static const List<String> examTypes = [
    'JEE Main',
    'JEE Main + Advanced',
  ];

  /// Current class options for onboarding (Screen 1)
  static const List<String> currentClassOptions = [
    '11',
    '12',
    'Other',
  ];

  /// Target years (dynamically generated)
  static List<String> getTargetYears() {
    final currentYear = DateTime.now().year;
    return [
      currentYear.toString(),
      (currentYear + 1).toString(),
      (currentYear + 2).toString(),
      (currentYear + 3).toString(),
    ];
  }

  /// Indian states and UTs
  static const List<String> states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand',
    'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur',
    'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
    'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
    'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Andaman and Nicobar Islands', 'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu', 'Delhi',
    'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry',
  ];

  /// Study setup options (multi-select)
  static const List<String> studySetupOptions = [
    'Self-study',
    'Online coaching',
    'Offline coaching',
    'School only',
  ];

  /// Popular engineering branches for dream branch selection
  static const List<String> dreamBranches = [
    'Computer Science',
    'Electronics',
    'Mechanical',
    'Civil',
    'Electrical',
    'Chemical',
    'Aerospace',
    'Biotechnology',
    'Not sure yet',
  ];

  /// Subjects (for internal use)
  static const List<String> subjects = [
    'Physics',
    'Chemistry',
    'Mathematics',
  ];
}
