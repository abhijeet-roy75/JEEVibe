// Conditional export for OfflineProvider
// Exports the real implementation on mobile, stub on web

export 'offline_provider_stub.dart'
    if (dart.library.io) 'offline_provider.dart';
