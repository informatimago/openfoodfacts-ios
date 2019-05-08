//
//  StockViewController.swift
//  LaBoite
//
//  Created by Pascal Bourguignon on 30/04/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import Foundation
import UIKit

class StockViewController: UITableViewController {

    var products: [Stock]=[]

    override func viewDidLoad() {
        addDemoCells()
    }

    func addDemoCells() {
        products.append(Stock(productName: "Riz Long Grain", stock: 5.000, reorderThreshold: 0.300))
        products.append(Stock(productName: "Cassonade", stock: 1.000, reorderThreshold: 0.100))
        products.append(Stock(productName: "Huile d'Olive Vierge Extra", stock: 1.000, reorderThreshold: 0.100))
        products[0].stock(decrement: 0.550)
        products[1].stock(decrement: 0.735)
        products[2].stock(decrement: 0.524)

        tableView.beginUpdates()
        tableView.insertRows(at: [IndexPath(indexes: [0, 1, 2])], with: .automatic)
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
                    cell.reorderThresholdValue.text = String(format: "%.3f kg", cell.reorderThresholdSlider.value)
                }
            }
        }
    }

    // UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "stockCell", for: indexPath)
        if let cell = cell as? StockCell {
            let product = products[indexPath.item]
            cell.productName.text=product.productName
            cell.stockValue.text=String(format: "%.3f kg", product.stock)
            cell.stockProgress.setProgress(product.stock/product.maxStock, animated: false)
            cell.reorderThresholdSlider.maximumValue = product.maxStock
            cell.reorderThresholdSlider.setValue(product.reorderThreshold, animated: false)
            cell.reorderThresholdValue.text = String(format: "%.3f kg", cell.reorderThresholdSlider.value)
        }
        return cell
    }
}
