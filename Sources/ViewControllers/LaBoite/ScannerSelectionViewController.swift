//
//  ScannerSelectionViewController.swift
//  StockMeMicroDemo
//
//  Created by Pascal Bourguignon on 16/07/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import Foundation
import UIKit

protocol ScannerSelectionProtocol {
    var product: Product? { get set }
    func cancel()
    func associate()
}

class ScannerSelectionViewController: UIViewController, DataManagerClient, ScannerSelectionProtocol {
    var dataManager: DataManagerProtocol!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {

    }

    func popViewController() {
        self.dismiss(animated: false)
        // RootViewController.rootViewController()!.showStock()
        // self.parentContainerViewController()?.performSegue(withIdentifier: "tabs", sender: self)
    }

    fileprivate var selectedProduct: Product?
    var product: Product? {
        get {
            return selectedProduct
        }
        set {
            selectedProduct = newValue
            performSegue(withIdentifier: "result", sender: self)
        }
    }

    func cancel() {
        back()
    }

    func associate() {
        back()
    }

    @IBAction func back() {
        popViewController()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "scanner", let destinationVC = segue.destination as? ScannerViewController {
            print("segue scanner")
            destinationVC.selection = self
        } else
        if segue.identifier == "result", let destinationVC = segue.destination as? ScannerResultViewController {
            print("segue result")
            destinationVC.selection = self
            destinationVC.product = product
        }
    }

}
