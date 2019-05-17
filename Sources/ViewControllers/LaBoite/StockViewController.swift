//
//  StockViewController.swift
//  LaBoite
//
//  Created by Pascal Bourguignon on 30/04/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications

protocol SearchObserver {
    func cancelSearch()
    func searchFound(product: Product)
}

class StockViewController: UITableViewController, SearchObserver {
    let defaults=UserDefaults.init()
    let pollPeriod = 3.0 // seconds
    let defaultControllerIPAddress="boxsim.laboite.sbde.fr"
    let controllerPort=UInt16(SERVER_PORT)
    var timer: Timer?

    var products: [Stock]=[]

    override func viewDidLoad() {
        StockViewController.instance = self
        hideKeyboardWhenTappedAround()
        if !loadConfiguration() {
            addDemoCells()
        }
        startPollingControllers()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge],
                                                                completionHandler: {granted, error in
                                                                    if granted {
                                                                        print("UserNotification allowed.")
                                                                    } else {
                                                                        print("UserNotification refused \(String(describing: error)).")
                                                                    }
        })
        UNUserNotificationCenter.current().delegate = UIApplication.shared.delegate as? UNUserNotificationCenterDelegate
    }

    func encode() -> [[String: Any]] {
        var encoded = [[String: Any]]()
        for stock in products {
            encoded.append(stock.encode())
        }
        return encoded
    }

    enum Key: String {
        case stock = "fr.sbde.laboite.StockMeMiniDemo.stock"
    }

    func saveConfiguration() {
        let configuration = encode()
        print("saving configuration = \(configuration)")
        defaults.set(configuration, forKey: StockViewController.Key.stock.rawValue)
    }

    func loadConfiguration() -> Bool {
        let encoded = defaults.value(forKey: StockViewController.Key.stock.rawValue)
        print("loaded configuration = \(String(describing: encoded))")
        if encoded == nil {
            return false
        }
        var stocks = [Stock]()
        if let encoded = encoded as? [[String: Any]]? {
            for encodedStock in encoded! {
                stocks.append(Stock(fromDictionary: encodedStock))
            }
        }
        products = stocks
        initializeTableView()
        return true
    }

    func initializeTableView() {
        tableView.beginUpdates()
        tableView.insertSections(IndexSet(arrayLiteral: 0, 1), with: .automatic)
        // The ControllerConfigurationCell
        tableView.insertRows(at: [IndexPath(item: 0, section: 1)], with: .automatic)
        tableView.endUpdates()
        // The StockCells
        tableView.reloadData()
    }

    func addDemoCells() {
        products.append(Stock(productName: "Riz Long Grain", stock: 5.000, reorderThreshold: 0.300))
        products.append(Stock(productName: "Cassonade", stock: 1.000, reorderThreshold: 0.100))
        products.append(Stock(productName: "Huile d'Olive Vierge Extra", stock: 1.000, reorderThreshold: 0.100))
        products[0].stock(decrement: 0.550)
        products[1].stock(decrement: 0.735)
        products[2].stock(decrement: 0.524)

        initializeTableView()
    }

    func tableViewCellForView(_ view: UIView) -> UITableViewCell? {
        if let tableViewCell = view as? UITableViewCell {
            return tableViewCell
        } else {
            return tableViewCellForView(view.superview!)
        }
    }

    func stockCellContaining(view: UIView) -> StockCell? {
        if let tableViewCell = tableViewCellForView(view) {
            if let cell = tableViewCell as? StockCell {
                return cell
            }
        }
        return nil
    }

    @IBAction func updateReorderThreshold(_ sender: UISlider) {
        if let cell = stockCellContaining(view: sender) {
            if cell.reorderThresholdSlider == sender {
                cell.product.reorderThreshold = cell.reorderThresholdSlider.value
                cell.product.changed()
                saveConfiguration()
            }
        }
    }

    @IBAction func connectToNewController(_ sender: UIButton) {
        if let tableViewCell = tableViewCellForView(sender) {
            if let cell = tableViewCell as? ControllerConfigurationCell {
                // TODO try to connect to the controller and add the cell only if ok
                products.append(Stock(controllerIPAddress: cell.controllerIPAddress.text!,
                                      controllerPort: UInt16(cell.controllerPort.text!) ?? controllerPort))
                tableView.beginUpdates()
                tableView.insertRows(at: [IndexPath(item: products.count-1, section: 0)], with: .automatic)
                tableView.endUpdates()
                timer!.fire()
                saveConfiguration()
            }
        }
    }


    var associatingCell: StockCell?

    @IBAction func associateProduct(_ sender: UIButton) {
        if let cell = stockCellContaining(view: sender) {
            associatingCell = cell
            segueToScanner()
        }
    }

    // UITableViewDataSource

    override func numberOfSections(in: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:  return products.count
        case 1:  return 1
        default: return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "newControllerCell", for: indexPath)
            if let cell = cell as? ControllerConfigurationCell {
                cell.controllerIPAddress!.text = defaultControllerIPAddress
            }
            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "stockCell", for: indexPath)
            if let cell = cell as? StockCell {
                let product = products[indexPath.item]
                cell.product = product
                cell.changed(stock: product)
            }
            return cell
        }
    }

    // Stock Polling

    func startPollingControllers() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(floatLiteral: pollPeriod),
                                     repeats: true,
                                     block: { (_: Timer) -> Void in
                                        print("Calling pollControllers")
                                        self.pollControllers() })
        print("Created scheduled Timer \(timer!.timeInterval)")
    }

    func pollControllers() {
        for stock in products {
            stock.pollController()
        }
    }

    // Search product by name

    static var instance: StockViewController?
    static var searchingController: StockViewController?

    class func searchObserver() -> SearchObserver? {
        return searchingController
    }

    func segueToScanner() {
        // RootViewController.rootViewController()?.showScan()
        StockViewController.searchingController = self
        performSegue(withIdentifier: "scanProductSegue", sender: self)
    }

    func searchFound(product: Product) {
        print("\(String(describing: product.name))")
        associatingCell?.product.setProduct(product)
        associatingCell = nil
        StockViewController.searchingController = nil
        saveConfiguration()
    }

    func cancelSearch() {
        associatingCell = nil
        StockViewController.searchingController = nil
    }

}
