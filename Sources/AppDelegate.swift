//
//  AppDelegate.swift
//  OpenFoodFacts
//
//  Created by Andrés Pizá Bückmann on 06/04/2017.
//  Copyright © 2017 Andrés Pizá Bückmann. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics
import XCGLogger
import RealmSwift
import UserNotifications

let log = XCGLogger(identifier: "advancedLogger", includeDefaultDestinations: false)

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        configureRealm()

        if ProcessInfo().environment["UITesting"] == nil {
            configureLog()
            Fabric.with([Crashlytics.self])
        } else {
            UIApplication.shared.keyWindow?.layer.speed = 100
        }

        ShortcutParser.shared.registerShortcuts()
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = RootViewController()
        window?.makeKeyAndVisible()

        fr_sbde_protocol_client_initialize()
        StockCell.registerNotifications()

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        DeepLinkManager.shared.checkDeepLink()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        StockViewController.instance?.saveConfiguration()
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(DeepLinkManager.shared.handleShortcut(item: shortcutItem))
    }

    fileprivate func configureLog() {
        let systemDestination = AppleSystemLogDestination(identifier: "advancedLogger.systemDestination")
        systemDestination.outputLevel = .debug
        systemDestination.showLogIdentifier = false
        systemDestination.showFunctionName = true
        systemDestination.showThreadName = true
        systemDestination.showLevel = true
        systemDestination.showFileName = true
        systemDestination.showLineNumber = true
        systemDestination.showDate = true
        log.add(destination: systemDestination)
        log.logAppDetails()
    }

    private func configureRealm() {
        let config = Realm.Configuration(
            schemaVersion: 21
        )

        Realm.Configuration.defaultConfiguration = config
    }

    // UserNotification action handling:

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler:
        @escaping () -> Void) {

        // Get the meeting ID from the original notification.
        let userInfo = response.notification.request.content.userInfo
        let productName = userInfo["PRODUCT_NAME"] as? String ?? ""

        // Perform the task associated with the action.
        switch response.actionIdentifier {
        case "REORDER_NOW_ACTION", "com.apple.UNNotificationDefaultActionIdentifier":
            print("Reorder now \(productName)")
            if let escapedProductName = productName.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) {
                UIApplication.shared.open(URL(string: "https://www.carrefour.fr/s?q=\(escapedProductName)")!,
                                          options: [:],
                                          completionHandler: {_ in })
            }
        case "REORDER_DECLINE_ACTION":
            print("Will reorder \(productName) later.")
        default:
            print("Default response actionIdentifier \(response.actionIdentifier)")
        }

        // Always call the completion handler when done.
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }

}

// swiftlint:disable force_cast
extension AppDelegate {
    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    var rootViewController: RootViewController {
        return window!.rootViewController as! RootViewController
    }
}
