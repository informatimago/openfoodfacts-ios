//
//  NOrderMenuController.swift
//  StockMeMiniDemo
//
//  Created by Pascal Bourguignon on 05/06/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import UIKit

class NOrderMenuController: UIViewController {

    override func viewDidLoad() {
    }

    @IBAction func stock() {
        print("move to stock")
        performSegue(withIdentifier: "stockSegue", sender: self)
    }

    @IBAction func addBase() {
        print("move to addBase")
        performSegue(withIdentifier: "addBase", sender: self)
    }

    @IBAction func receipes() {
        print("move to receipes")
        let receipesUrl = currentProvider!.urlToReceipes()!
        UIApplication.shared.open(receipesUrl, options: [:], completionHandler: {_ in })
    }

    @IBAction func shopping() {
        print("move to shopping")
        let shopUrl = currentProvider!.urlToShop()!
        UIApplication.shared.open(shopUrl, options: [:], completionHandler: {_ in })
    }

    var scannerVC: UIViewController?

    func viewControllers() -> [UIViewController] {
        if let scannerVC = storyboard?.instantiateViewController(withIdentifier: "scannerViewController") {
            self.scannerVC = scannerVC
            return [scannerVC]
        } else {
            return []
        }
    }

}
