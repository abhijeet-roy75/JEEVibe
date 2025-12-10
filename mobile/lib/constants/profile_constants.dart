class ProfileConstants {
  static const List<String> genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  static const List<String> currentClasses = [
    'Class 11',
    'Class 12',
    'Dropper (12th Pass)',
  ];

  static const List<String> targetExams = [
    'JEE Main',
    'JEE Main + Advanced',
    'JEE Advanced',
    'BITSAT',
    'WBJEE',
    'MHT CET',
    'KCET',
    'Other',
  ];

  static List<String> getTargetYears() {
    final currentYear = DateTime.now().year;
    return [
      currentYear.toString(),
      (currentYear + 1).toString(),
      (currentYear + 2).toString(),
      (currentYear + 3).toString(),
    ];
  }

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

  static const List<String> coachingInstitutes = [
    'No Coaching',
    'FIITJEE',
    'Allen',
    'Resonance',
    'Aakash',
    'Physics Wallah',
    'Unacademy',
    'Vedantu',
    'Sri Chaitanya',
    'Narayana',
    'Vibrant Academy',
    'Other',
  ];

  static const List<String> studyModes = [
    'Self-study only',
    'Coaching only',
    'Coaching + Self-study',
    'Online classes only',
    'Hybrid (Online + Offline)',
  ];

  static const List<String> languages = [
    'English',
    'Hindi',
    'Bilingual (English + Hindi)',
  ];

  static const List<String> subjects = [
    'Physics',
    'Chemistry',
    'Mathematics',
  ];
}
