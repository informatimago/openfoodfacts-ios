//
//  StockCell.swift
//  OpenFoodFacts
//
//  Created by Pascal Bourguignon on 30/04/2019.
//  Copyright © 2019 Andrés Pizá Bückmann. All rights reserved.
//

import UIKit
import UserNotifications
import Kingfisher

class StockCell: UITableViewCell, StockObserver {

    @IBOutlet weak var productName: UILabel!
    @IBOutlet weak var stockValue: UILabel!
    @IBOutlet weak var stockProgress: UIProgressView?
    @IBOutlet weak var reorderThresholdValue: UILabel!
    @IBOutlet weak var reorderThresholdManual: UITextField!
    @IBOutlet weak var reorderThresholdSlider: UISlider?
    @IBOutlet weak var productImage: UIButton!

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
        productName.text = stock.productName
        if let imageUrlString = stock.productImageUrl {
            if let url = URL(string: imageUrlString) {
                print("productImage.imageView = \(String(describing: productImage.imageView))")
                print("productImageUrl = \(String(describing: stock.productImageUrl))")
                KingfisherManager.shared.retrieveImage(with: url) { result in
                    switch result {
                    case .success(let value):
                        print("Kingfisher Task done for: \(value.source.url?.absoluteString ?? "")")
                        self.productImage.setImage(value.image, for: UIControl.State.normal)
                    case .failure(let error):
                        print("Kingfisher Job failed: \(error.localizedDescription)")
                    }
                }
            }
        }
        stockValue.text = String(format: "%.0f g", product.stock*1000)
        stockProgress?.barHeight = 8.0
        stockProgress?.setProgress(product.stock/product.maxStock, animated: false)
        reorderThresholdSlider?.maximumValue = product.maxStock
        reorderThresholdSlider?.setValue(product.reorderThreshold, animated: false)
        reorderThresholdValue.text = String(format: "%.0f g", product.reorderThreshold*1000)
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
        stockProgress?.progressTintColor = color
        if let stockValue = stockValue as? BoxedLabel {
            stockValue.color = color
            stockValue.setNeedsDisplay()
        }
    }

    class func registerNotifications() {
        // Define the custom actions.
        let acceptAction = UNNotificationAction(identifier: "REORDER_NOW_ACTION",
                                                title: "Reorder Now",
                                                options: UNNotificationActionOptions(rawValue: 0))
        let declineAction = UNNotificationAction(identifier: "REORDER_DECLINE_ACTION",
                                                 title: "Later",
                                                 options: UNNotificationActionOptions(rawValue: 0))
        // Define the notification type
        let reorderCategory =
            UNNotificationCategory(identifier: "REORDER_CATEGORY",
                                   actions: [acceptAction, declineAction],
                                   intentIdentifiers: [],
                                   hiddenPreviewsBodyPlaceholder: "",
                                   options: .customDismissAction)
        // Register the notification type.
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.setNotificationCategories([reorderCategory])
    }

    func notifyReorder(stock: Stock) {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = "REORDER_CATEGORY"
        content.title = "Reorder \(stock.productName)"
        content.subtitle = "We're almost out of \(stock.productName)"
        content.body = "There remains only \(stock.stock) kg of \(stock.productName); it would be a good time to reorder some."
        content.userInfo = ["PRODUCT_NAME": stock.productName]
        content.badge = 1
        let imageName = "tetra-pak" // TODO: use product image
        if let imageURL = Bundle.main.url(forResource: imageName, withExtension: "png") {
            let attachment = try? UNNotificationAttachment(identifier: imageName, url: imageURL, options: .none)
            content.attachments = [attachment!]
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "reorder \(stock.productName)",
            content: content,
            trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

}
