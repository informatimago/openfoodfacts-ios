//
//  Stock.swift
//  LaBoite
//
//  Created by Pascal Bourguignon on 30/04/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import Foundation
import Network

class Stock {

    var controllerIPAddress: String?
    var controllerPort = UInt16(0)
    // --
    var productName: String
    var stock: Float = 0.0
    var reorderThreshold: Float = 0.0
    var maxStock: Float = 1.0

    init(controllerIPAddress: String, controllerPort: UInt16, maxStock: Float = 0.0, reorderThreshold: Float = 0.0) {
        self.controllerIPAddress = controllerIPAddress
        self.controllerPort = controllerPort
        self.productName = "Unknown"
        self.stock = 0.0
        self.maxStock = maxStock
        self.reorderThreshold = reorderThreshold
    }

    init(productName: String,stock: Float=0.0, reorderThreshold: Float=0.0) {
        self.productName = productName
        self.stock = stock
        self.maxStock = stock
        self.reorderThreshold = reorderThreshold
    }

    func stock(increment: Float) {
        stock += increment
        if maxStock < stock {
            maxStock = stock
        }
    }

    func stock(decrement: Float) {
        self.stock-=decrement
        if maxStock<stock {
            maxStock=stock
        }
    }

    func checkReorder() {
        if stock<reorderThreshold {
            reorder()
        }
    }

    func reorder() {
        print("Reorder \(productName)\n")
    }

}
