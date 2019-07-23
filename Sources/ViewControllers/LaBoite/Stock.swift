//
//  Stock.swift
//  LaBoite
//
//  Created by Pascal Bourguignon on 30/04/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import Foundation
import Network
import UserNotifications

protocol StockObserver {
    func changed(stock: Stock)
    func notifyReorder(stock: Stock)
}

class Stock {

    var observer: StockObserver?

    var controllerIPAddress: String?
    var controllerPort = UInt16(0)
    var tare: Float = 0.0
    // --
    var productName: String
    var productImageUrl: String?
    var stock: Float = 0.0
    var reorderThreshold: Float = 0.0
    var order: Float = 0.0
    var maxStock: Float = 1.0
    var notified = false

    func encode() -> [String: Any] {
        return [
            "controller.IPAddress": controllerIPAddress ?? "",
            "controller.port": controllerPort,
            "product.name": productName,
            "product.imageUrl": productImageUrl ?? "",
            "stock.tare": tare,
            "stock.mass": stock,
            "stock.reorderThreshold": reorderThreshold,
            "stock.nextOrder": order,
            "stock.maximum": maxStock
        ]
    }

    static func orempty(_ string: String?) -> String? {
        if let string = string {
            if string == "" {
                return nil
            } else {
                return string
            }
        } else {
            return string
        }
    }

    init(fromDictionary dict: [String: Any]) {
        self.controllerIPAddress = Stock.orempty(dict["controller.IPAddress"] as? String)
        self.controllerPort = dict["controller.port"] as? UInt16 ?? 0
        self.productName = dict["product.name"] as? String ?? "Unknown"
        self.productImageUrl = Stock.orempty(dict["product.imageUrl"] as? String)
        self.tare = dict["stock.tare"] as? Float ?? 0.0
        self.stock = dict["stock.mass"] as? Float ?? 1.0
        self.maxStock = dict["stock.maximum"] as? Float ?? 1.0
        self.reorderThreshold = dict["stock.reorderThreshold"] as? Float ?? 0.1
        self.order = dict["stock.nextOrder"] as? Float ?? 0.1
    }

    init(controllerIPAddress: String, controllerPort: UInt16, maxStock: Float = 0.0, reorderThreshold: Float = 0.0) {
        self.controllerIPAddress = controllerIPAddress
        self.controllerPort = controllerPort
        self.productName = "Unknown"
        self.stock = 0.0
        self.maxStock = maxStock
        self.reorderThreshold = reorderThreshold
    }

    init(productName: String, stock: Float = 0.0, reorderThreshold: Float = 0.0) {
        self.productName = productName
        self.stock = stock
        self.maxStock = stock
        self.reorderThreshold = reorderThreshold
    }

    func setProduct(_ product: Product) {
        productName = product.name ?? "Unknown"
        productImageUrl = product.frontImageSmallUrl ?? product.imageSmallUrl ??  product.frontImageUrl ?? product.imageUrl
        changed()
    }

    func changed() {
        notified = false
        if let observer = observer {
            DispatchQueue.main.async {
                observer.changed(stock: self)
            }
        }
    }

    func updateMaxStock() {
        if maxStock < stock {
            maxStock = ceil(stock)
        }
        changed()
   }

    func stock(set newValue: Float) {
        if (stock != newValue) {
            stock = newValue
            updateMaxStock()
        }
    }

    func stock(increment: Float) {
        stock += increment
        updateMaxStock()
    }

    func stock(decrement: Float) {
        stock -= decrement
        updateMaxStock()
    }

    func checkReorder() {
        if stock <= reorderThreshold {
            reorder()
        }
    }

    func reorder() {
        if !notified {
            print("Reorder \(productName)\n")
            if let observer = observer {
                DispatchQueue.main.async {
                    observer.notifyReorder(stock: self)
                    self.notified = true
                }
            }
        }
    }

    func receiveGrossWeight(_ weight: Float) {
       stock(set: weight)
//       if (tare <= weight) {
//            stock(set: weight - tare)
//        } else {
//            stock(set: 0.0)
//        }
        checkReorder()
    }

    // Polling Controller

    let crlf=Data.init()
    let datetimeFormatter=ISO8601DateFormatter.init()
    let defaults=UserDefaults.init()
    var controller: OpaquePointer?
    var setTareNow = false

    func setTare() {
        self.setTareNow = true // actually within StockViewController.pollPeriod
        print("\(productName) will set the tare soon? \(self.setTareNow)")
   }

    func pollController() {
        print("pollController \(String(describing: controllerIPAddress)) \(controllerPort)")
        if controllerIPAddress == nil {
            checkReorder()
            return
        }
        if connectToController() {
            /* Initialize Protocol */
            sendVersion(1)
            print("\(productName) connected; tare? \(self.setTareNow)")
            if self.setTareNow {
                self.setTareNow = false
                sendSetTare(slot: 1)
                /* TODO: sleep a little */
            }
            /* Query Weight */
            sendScalesStart(slot: 1)
            sendScalesQuery(slot: 1)
            sendScalesStop(slot: 1)
            disconnectFromController()
        }
    }

    func connectToController() -> Bool {
        let host = controllerIPAddress!.trimmingCharacters(in: CharacterSet.init(charactersIn: " "))
        defaults.set(host, forKey: "fr.sbde.laboite.controllerIPAddress")
        controller = fr_sbde_protocol_client_connect(host, controllerPort)
        if let error = fr_sbde_protocol_client_error(controller) {
            print("Connection Error \(String.init(cString: error))")
            return false
        }
        return true
    }

    func disconnectFromController() {
        if controller != nil {
            fr_sbde_protocol_client_disconnect(controller)
            controller=nil
        }
    }

    func sendMessage(_ message: UnsafeMutablePointer<controller_ua_message>) {
        sendMessage(message, true)
    }

    func sendMessage(_ message: UnsafeMutablePointer<controller_ua_message>, _ expectResponse: Bool) {
        if controller == nil {
            print("sendMessage: Not connected to \(String(describing: controllerIPAddress))")
            return
        }
        let okay = fr_sbde_protocol_client_send_message(controller, message)
        print("Send Message \(message.pointee.kind) -> \(okay)")
        free(message)
        if okay {
            if expectResponse {
                receiveMessage()
            }
        } else {
            if let controller = controller {
                if let error = fr_sbde_protocol_client_error(controller) {
                    print("Send Message Error \(String.init(cString: error))")
                }
            }
            disconnectFromController()
        }
    }

    func receiveMessage() {
        if controller == nil {
            print("receiveMessage: Not connected to \(String(describing: controllerIPAddress))")
            return
        }
        let message = fr_sbde_protocol_client_receive_message(controller)
        print("Received Message \(String(describing: message?.pointee.kind))")
        if let message = message {
            switch message.pointee.kind {
            case controller_ua_message_version:
                if !(message.pointee.message.version.version_number == 1) {
                    print("Bad version \(message.pointee.message.version.version_number)")
                }
            case controller_ua_message_scales_measure:
                receiveGrossWeight(message.pointee.message.scales_measure.mass)
            default:
                print("Bad Message Kind \(message.pointee.kind)")
            }
        } else {
            if let controller = controller {
                if let error = fr_sbde_protocol_client_error(controller) {
                    print("Receive Message Error \(String.init(cString: error))")
                }
            }
        }
        free(message)
    }

    func sendVersion(_ version: Int) {
        if controller == nil {
            print("sendVersion: Not connected to \(String(describing: controllerIPAddress))")
            return
        }
        print("sendVersion \(version)")
        let timestamp: datetime_t = datetime_now()
        let message = controller_ua_version_new(version, timestamp)
        if let message = message {
            sendMessage(message)
        }
    }

    func sendSetTare(slot: Int) {
        if controller == nil {
            print("sendSetTare: Not connected to \(String(describing: controllerIPAddress))")
            return
        }
        print("sendSetTare \(slot)")
        let message = controller_ua_tare_set_new(slot)
        if let message = message {
            sendMessage(message, false)
        }
    }

    func sendScalesStart(slot: Int) {
        if controller == nil {
            print("sendScalesStart: Not connected to \(String(describing: controllerIPAddress))")
            return
        }
        print("sendScalesStart \(slot)")
        let timestamp: datetime_t = datetime_now()
        let message = controller_ua_scales_start_new(timestamp, slot)
        if let message = message {
            sendMessage(message)
        }
    }

    func sendScalesQuery(slot: Int) {
        if controller == nil {
            print("sendScalesQuery: Not connected to \(String(describing: controllerIPAddress))")
            return
        }
        print("sendScalesQuery \(slot)")
        let timestamp: datetime_t = datetime_now()
        let message = controller_ua_scales_query_new(timestamp, slot)
        if let message = message {
            sendMessage(message)
        }
    }

    func sendScalesStop(slot: Int) {
        if controller == nil {
            print("sendScalesStop: Not connected to \(String(describing: controllerIPAddress))")
            return
        }
        print("sendScalesStop \(slot)")
        let timestamp: datetime_t = datetime_now()
        let message = controller_ua_scales_stop_new(timestamp, slot)
        if let message = message {
            sendMessage(message)
        }
    }

}
