import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register the Gana background-processing task BEFORE
    // application(_:didFinishLaunchingWithOptions:) returns — iOS only
    // accepts BGTaskScheduler registrations during the launch window.
    //
    // The identifier MUST match:
    //   • ios/Runner/Info.plist → BGTaskSchedulerPermittedIdentifiers
    //   • lib/features/shiv/gana/engine/gana_workmanager.dart →
    //     kGanaBackgroundTickTask
    //
    // Without this call iOS has no handler for the identifier and refuses
    // to launch the task even though Workmanager().registerOneOffTask
    // submits it. (Android works automatically; iOS demands the Swift-side
    // handler.)
    WorkmanagerPlugin.registerBGProcessingTask(
      withIdentifier: "in.uniun.app.gana.tick"
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
