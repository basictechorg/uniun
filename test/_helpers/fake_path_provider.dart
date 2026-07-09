import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Deterministic [PathProviderPlatform] test double.
///
/// Points `getApplicationDocumentsDirectory()` / `getApplicationSupportDirectory()`
/// at caller-chosen temp dirs. Install in `setUp` via
/// `PathProviderPlatform.instance = FakePathProviderPlatform(docs: ..., support: ...)`.
class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  FakePathProviderPlatform({required this.docs, required this.support});

  final String docs;
  final String support;

  @override
  Future<String?> getApplicationDocumentsPath() async => docs;

  @override
  Future<String?> getApplicationSupportPath() async => support;

  @override
  Future<String?> getTemporaryPath() async => support;
}
