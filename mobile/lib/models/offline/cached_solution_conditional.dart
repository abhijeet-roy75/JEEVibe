// Conditional export for offline models
// Exports stub on web, real implementation on mobile

export 'cached_solution_stub.dart'
    if (dart.library.io) 'cached_solution.dart';
