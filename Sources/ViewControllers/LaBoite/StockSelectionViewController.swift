//
//  StockSelectionViewController.swift
//  StockMeMiniDemo
//
//  Created by Pascal Bourguignon on 05/06/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import Foundation
import UIKit

class StockSelectionViewController: UIViewController {

    override func viewDidLoad() {
    }

    @IBAction func back() {
        self.dismiss(animated: true)
    }

    @IBAction func selectCategory(_ sender: UIButton) {
        currentCategory!.text = sender.titleLabel!.text
    }

    @IBOutlet var currentCategory: UILabel?
}
