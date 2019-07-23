//
//  RootViewController.swift
//  OpenFoodFacts
//
//  Created by Andrés Pizá Bückmann on 02/01/2018.
//  Copyright © 2018 Andrés Pizá Bückmann. All rights reserved.
//

import UIKit

class RootViewController: UIViewController {
    private var norderMenuVC: NOrderMenuController

    var deepLink: DeepLinkType? {
        didSet {
            handleDeepLink()
        }
    }

    let dataManager = DataManager()

    init() {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let norderMenuVC = storyboard.instantiateInitialViewController() as? NOrderMenuController else { fatalError("Initial VC is required") }
        self.norderMenuVC = norderMenuVC

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

        setupViewControllers(norderMenuVC, dataManager)
        showMenu()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Inject dependencies into tab view controllers
    ///
    /// - Parameters:
    ///   - productApi: API Client
    ///   - dataManager: Local store client
    private func setupViewControllers(_ vc: NOrderMenuController, _ dataManager: DataManager) {
        for (_, child) in vc.viewControllers().enumerated() {
            if var top = child as? DataManagerClient {
                top.dataManager = dataManager
            }

            if let nav = child as? UINavigationController {
                if var top = nav.viewControllers.first as? DataManagerClient {
                    top.dataManager = dataManager
                }
            }
        }
    }

    func showMenu() {
        print("showMenu")
        transition(to: norderMenuVC) { _ in
        }
    }

    func showStock() {
        print("showStock")
        norderMenuVC.stock()
    }

    private func handleDeepLink() {
        guard let deepLink = self.deepLink else { return }

//        switch deepLink {
//        case .scan:
//            showScan()
//        }

        // Reset
        self.deepLink = nil
    }

    class func rootViewController () -> RootViewController? {
        let rvc = UIApplication.shared.keyWindow!.rootViewController
        let myrvc = rvc as? RootViewController
        return myrvc
    }

}
