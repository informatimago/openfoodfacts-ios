//
//  RootViewController.swift
//  OpenFoodFacts
//
//  Created by Andrés Pizá Bückmann on 02/01/2018.
//  Copyright © 2018 Andrés Pizá Bückmann. All rights reserved.
//

import UIKit

class RootViewController: UIViewController {
    private var tabBarVC: UITabBarController
    private var tabBarNotificationController: TabBarNotificationController

    var deepLink: DeepLinkType? {
        didSet {
            handleDeepLink()
        }
    }

    let dataManager = DataManager()

    init() {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let tabBarVC = storyboard.instantiateInitialViewController() as? UITabBarController else { fatalError("Initial VC is required") }
        self.tabBarVC = tabBarVC
        self.tabBarNotificationController = TabBarNotificationController(tabBarController: tabBarVC)

        super.init(nibName: nil, bundle: nil)

        // Inject dependencies
        let productApi = ProductService()
        let persistenceManager = PersistenceManager()

        let taxonomiesApi = TaxonomiesService()
        taxonomiesApi.persistenceManager = persistenceManager
        taxonomiesApi.refreshTaxonomiesFromServerIfNeeded()

        dataManager.productApi = productApi
        dataManager.taxonomiesApi = taxonomiesApi
        dataManager.persistenceManager = persistenceManager

        setupViewControllers(tabBarVC, dataManager)

        transition(to: tabBarVC) { _ in
            let count = self.dataManager.getItemsPendingUpload().count
            NotificationCenter.default.post(name: .pendingUploadBadgeChange, object: nil, userInfo: [NotificationUserInfoKey.pendingUploadItemCount: count])
            //to check for scanner state
            if UserDefaults.standard.bool(forKey: UserDefaultsConstants.scanningOnLaunch) == true {
                self.showScan()
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Inject dependencies into tab view controllers
    ///
    /// - Parameters:
    ///   - productApi: API Client
    ///   - dataManager: Local store client
    private func setupViewControllers(_ tab: UITabBarController, _ dataManager: DataManager) {
        for (index, child) in tab.viewControllers?.enumerated() ?? [].enumerated() {
            if var top = child as? DataManagerClient {
                top.dataManager = dataManager
            }

            if let nav = child as? UINavigationController {
                if var top = nav.viewControllers.first as? DataManagerClient {
                    top.dataManager = dataManager
                }
            }

            if child is SettingsTableViewController, let item = tab.tabBar.items?[index] {
                let items = dataManager.getItemsPendingUpload()
                item.badgeValue = items.isEmpty ? nil : "\(items.count)"
            }
        }
    }

    func showMenu() {
        print("showMenu")
        for child in tabBarVC.viewControllers ?? [] {
            if child as? NOrderMenuController != nil {
                tabBarVC.selectedIndex = tabBarVC.viewControllers?.firstIndex(of: child) ?? 0
                print("selected tab \(tabBarVC.selectedIndex)")
                break
            }
        }
    }

    func showStock() {
        print("showStock")
        for child in tabBarVC.viewControllers ?? [] {
            if child as? StockSelectionViewController != nil {
                tabBarVC.selectedIndex = tabBarVC.viewControllers?.firstIndex(of: child) ?? 0
                print("selected tab \(tabBarVC.selectedIndex)")
                break
            }
        }
    }

    func showSearch() {
        print("showSearch")
        for child in tabBarVC.viewControllers ?? [] {
            if child as? SearchViewController != nil {
                tabBarVC.selectedIndex = tabBarVC.viewControllers?.firstIndex(of: child) ?? 0
                print("selected tab \(tabBarVC.selectedIndex)")
                break
            }
        }
    }

    func showScan() {
        print("showScan")
        tabBarVC.selectedIndex = 3
        print("selected tab \(tabBarVC.selectedIndex)")
//        for child in tabBarVC.viewControllers ?? [] {
//            if "Scanner" == child.title {
//                tabBarVC.selectedIndex = tabBarVC.viewControllers?.firstIndex(of: child) ?? 0
//                print("selected tab \(tabBarVC.selectedIndex)")
//                break
//            }
//        }
    }

    private func handleDeepLink() {
        guard let deepLink = self.deepLink else { return }

        switch deepLink {
        case .scan:
            showScan()
        }

        // Reset
        self.deepLink = nil
    }

    class func rootViewController () -> RootViewController? {
        let rvc = UIApplication.shared.keyWindow!.rootViewController
        let myrvc = rvc as? RootViewController
        return myrvc
    }

}
