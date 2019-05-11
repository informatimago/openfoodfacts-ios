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

class StockViewController: UITableViewController {

    let defaultControllerIPAddress="boxsim.laboite.sbde.fr"
    let controllerPort=UInt16(SERVER_PORT)
    var timer: Timer?

    var products: [Stock]=[]

    override func viewDidLoad() {
        hideKeyboardWhenTappedAround()
        addDemoCells()
        startPollingControllers()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge],
                                                                completionHandler: {granted, error in
                                                                    if granted {
                                                                        print("UserNotification allowed.")
                                                                    } else {
                                                                        print("UserNotification refused.")
                                                                    }
        })
        UNUserNotificationCenter.current().delegate = UIApplication.shared.delegate as? UNUserNotificationCenterDelegate
    }

    func addDemoCells() {
        products.append(Stock(productName: "Riz Long Grain", stock: 5.000, reorderThreshold: 0.300))
        products.append(Stock(productName: "Cassonade", stock: 1.000, reorderThreshold: 0.100))
        products.append(Stock(productName: "Huile d'Olive Vierge Extra", stock: 1.000, reorderThreshold: 0.100))
        products[0].stock(decrement: 0.550)
        products[1].stock(decrement: 0.735)
        products[2].stock(decrement: 0.524)

        tableView.beginUpdates()
        tableView.insertSections(IndexSet(arrayLiteral: 0, 1), with: .automatic)
        // The ControllerConfigurationCell
        tableView.insertRows(at: [IndexPath(item:0 , section: 1)], with: .automatic)
        // The StockCells
        tableView.insertRows(at: [IndexPath(item: 0, section: 0)], with: .automatic)
        tableView.insertRows(at: [IndexPath(item: 1, section: 0)], with: .automatic)
        tableView.insertRows(at: [IndexPath(item: 2, section: 0)], with: .automatic)
        tableView.endUpdates()
    }

    func tableViewCellForView(_ view: UIView) -> UITableViewCell? {
        if let tableViewCell = view as? UITableViewCell {
            return tableViewCell
        } else {
            return tableViewCellForView(view.superview!)
        }
    }

    @IBAction func updateReorderThreshold(_ sender: UISlider) {
        if let tableViewCell = tableViewCellForView(sender) {
            if let cell = tableViewCell as? StockCell {
                if cell.reorderThresholdSlider == sender {
                    cell.product.reorderThreshold = cell.reorderThresholdSlider.value
                    cell.product.changed()
                }
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
            }
        }
    }

    @IBAction func scanProductCodeBar(_ sender: UIButton) {
        print("TODO: SCAN PRODUCT CODE BAR")
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
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(floatLiteral: 33.0),
                                     repeats: true,
                                     block: { (_: Timer) -> Void in
                                        print("Calling pollControllers")
                                        self.pollControllers() })
        print("Created scheduled Timer \(timer!.timeInterval)")
    }

    func pollControllers() {
        print("pollControllers")
        for stock in products {
            stock.pollController()
        }
    }

}
