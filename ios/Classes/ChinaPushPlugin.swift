import Flutter
import UIKit

import UserNotifications

public class ChinaPushPlugin: NSObject,  FlutterPlugin,UNUserNotificationCenterDelegate {
   var channel: FlutterMethodChannel?
      var result:FlutterResult?
      var resumingFromBackground = false
      var regId:String?

      let manufacturer = "APPLE"

      init(channel: FlutterMethodChannel) {
          self.channel = channel
          super.init()
      }

      public static func register(with registrar: FlutterPluginRegistrar) {
          let channel = FlutterMethodChannel(name: "china_push", binaryMessenger: registrar.messenger())
          let instance = ChinaPushPlugin(channel: channel)
          registrar.addApplicationDelegate(instance)
          registrar.addMethodCallDelegate(instance, channel: channel)
      }

      public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
          switch call.method {
          case "getPlatformVersion":
              result("iOS " + UIDevice.current.systemVersion)
          case "initPush":
              initPush(result:result)
          case "getRegId":
              result(regId)
          case "getManufacturer":
              result(manufacturer)
          case "enableLog":
              if let isEnabled = call.arguments as? Bool {
                  Logger.isEnabled = isEnabled
              }
          default:
              result(FlutterMethodNotImplemented)
          }
      }

      private func initPush(result: @escaping FlutterResult) {
          self.result = result
          let notificationCenter = UNUserNotificationCenter.current()
          notificationCenter.delegate = self

          notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
              if let error = error {
                  DispatchQueue.main.async {
                      Logger.log("requestAuthorization failed: \(error.localizedDescription)")
                      result(FlutterError(code: "10086", message: error.localizedDescription, details: nil))
                      self.result = nil
                  }
                  return
              }

              Logger.log("requestAuthorization granted: \(granted)")
              DispatchQueue.main.async {
                  UIApplication.shared.registerForRemoteNotifications()
              }
          }
      }

      public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {

          UNUserNotificationCenter.current().delegate = self
          return true
      }

      public func applicationDidEnterBackground(_ application: UIApplication) {
          resumingFromBackground = true
      }

      public func applicationDidBecomeActive(_ application: UIApplication) {
          resumingFromBackground = false
          UIApplication.shared.applicationIconBadgeNumber = -1;
      }

      public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

          let deviceTokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
          self.regId = deviceTokenString
          Logger.log("onResister Success")
          result?(["regId":regId,"manufacturer":"APPLE"])
          result = nil
      }

      public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
          Logger.log("onRegister Failed: \(error.localizedDescription)")
          result?(FlutterError(code: "10087", message: error.localizedDescription, details: nil))
          result = nil
      }


      public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
          let userInfo = FlutterApnsSerialization.remoteMessageUserInfoToDict(userInfo)

          onMessage(userInfo: userInfo)
          completionHandler(.noData)
          return true
      }

      public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
          let userInfo = notification.request.content.userInfo

          guard userInfo["aps"] != nil else {
              return
          }

          completionHandler([.alert, .sound])
      }

      public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
          var userInfo = response.notification.request.content.userInfo
          guard userInfo["aps"] != nil else {
              return
          }

          userInfo["actionIdentifier"] = response.actionIdentifier
          let serializedUserInfo = FlutterApnsSerialization.remoteMessageUserInfoToDict(userInfo)

          onMessage(userInfo: serializedUserInfo)
          completionHandler()
      }


      private func onMessage(userInfo: [String: Any]) {
          Logger.log("onMessage")
          if let data = ((userInfo["aps"] as? [String: Any])?["attributes"] as? [String: Any])?["data"] as? String {
              channel?.invokeMethod("onNotificationClick", arguments: data)
              return
          }
          var payload = userInfo
          payload.removeValue(forKey: "aps")
          channel?.invokeMethod("onNotificationClick", arguments: payload)
      }

  }
  extension UNNotificationCategoryOptions {
      static let stringToValue: [String: UNNotificationCategoryOptions] = {
          var r: [String: UNNotificationCategoryOptions] = [:]
          r["UNNotificationCategoryOptions.customDismissAction"] = .customDismissAction
          r["UNNotificationCategoryOptions.allowInCarPlay"] = .allowInCarPlay
          if #available(iOS 11.0, *) {
              r["UNNotificationCategoryOptions.hiddenPreviewsShowTitle"] = .hiddenPreviewsShowTitle
          }
          if #available(iOS 11.0, *) {
              r["UNNotificationCategoryOptions.hiddenPreviewsShowSubtitle"] = .hiddenPreviewsShowSubtitle
          }
          if #available(iOS 13.0, *) {
              r["UNNotificationCategoryOptions.allowAnnouncement"] = .allowAnnouncement
          }
          return r
      }()
}
