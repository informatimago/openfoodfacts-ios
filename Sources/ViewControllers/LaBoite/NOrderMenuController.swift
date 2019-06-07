//
//  NOrderMenuController.swift
//  StockMeMiniDemo
//
//  Created by Pascal Bourguignon on 05/06/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import Foundation
import UIKit

class NOrderMenuController: UIViewController {

    override func viewDidLoad() {
    }

    @IBAction func stock() {
        print("move to stock")
        // RootViewController.rootViewController()!.showStock()
        performSegue(withIdentifier: "stockSegue", sender: self)
    }

    @IBAction func scale() {
        print("move to scale")
    }

    @IBAction func receipes() {
        print("move to receipes")
    }

    @IBAction func nutrition() {
        print("move to nutrition")
    }

    @IBAction func shopping() {
        print("move to shopping")
    }

    @IBAction func addApp() {
        print("move to addApp")
    }

}