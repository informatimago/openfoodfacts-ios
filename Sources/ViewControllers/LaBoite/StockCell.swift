//
//  StockCell.swift
//  OpenFoodFacts
//
//  Created by Pascal Bourguignon on 30/04/2019.
//  Copyright © 2019 Andrés Pizá Bückmann. All rights reserved.
//

import UIKit

class StockCell: UITableViewCell, StockObserver {

    @IBOutlet weak var productName: UILabel!
    @IBOutlet weak var stockValue: UILabel!
    @IBOutlet weak var stockProgress: UIProgressView!
    @IBOutlet weak var reorderThresholdValue: UILabel!
    @IBOutlet weak var reorderThresholdSlider: UISlider!

    var internalProduct: Stock!
    var product: Stock! {
        get {
            return self.internalProduct
        }
        set(newProduct) {
            internalProduct = newProduct
            internalProduct.observer = self
        }
    }

    func changed(stock: Stock) {
        productName.text=product.productName
        stockValue.text=String(format: "%.3f kg", product.stock)
        stockProgress.barHeight = 8.0
        stockProgress.setProgress(product.stock/product.maxStock, animated: false)
        reorderThresholdSlider.maximumValue = product.maxStock
        reorderThresholdSlider.setValue(product.reorderThreshold, animated: false)
        reorderThresholdValue.text = String(format: "%.3f kg", reorderThresholdSlider.value)
        updateColor()
    }

    func updateColor() {
        let current = product.stock
        let redLevel = product.reorderThreshold * 1.1
        let orangeLevel = (product.maxStock - redLevel) / 3.0 + redLevel
        var color = UIColor.green
        if current <= redLevel {
            color = UIColor.red
        } else if current <= orangeLevel {
            color = UIColor.orange
        }
        stockProgress.progressTintColor = color
    }

}
