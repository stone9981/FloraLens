import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    registerNativeChannel()
  }

  private func registerNativeChannel() {
    // Scene 模式下窗口由 SceneDelegate 持有，self.window 一定有值；在 super.scene
    // 之后 FlutterViewController 通常已被设为 window.rootViewController。若尚未就绪，
    // 则短暂延迟重试，确保通道一定注册成功。
    guard let vc = self.window?.rootViewController as? FlutterViewController else {
      print("[native] rootViewController not ready yet, retry in 0.5s")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.registerNativeChannel()
      }
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.floralens/native",
      binaryMessenger: vc.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "openAppSettings" {
        print("[native] openAppSettings invoked")
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          print("[native] openAppSettings FAILED: URL unavailable")
          result(FlutterError(code: "UNAVAILABLE", message: "Settings URL unavailable", details: nil))
          return
        }
        print("[native] opening \(url.absoluteString)")
        UIApplication.shared.open(url, options: [:]) { opened in
          print("[native] open settings result: \(opened)")
          result(opened)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    print("[native] MethodChannel 'com.floralens/native' registered OK")
  }
}
