//
//  BaseList.swift
//  StockMeMiniDemo
//
//  Created by Pascal Bourguignon on 10/06/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import Foundation

class BaseList {

    enum Key: String {
        case stock = "fr.sbde.laboite.StockMeMiniDemo.stock"
    }
    let defaults=UserDefaults.init()
    var elements: [Stock]=[]

    func encode() -> [[String: Any]] {
        var encoded = [[String: Any]]()
        for stock in elements {
            encoded.append(stock.encode())
        }
        return encoded
    }

    func save() {
        let encoded = encode()
        print("saving bases = \(encoded)")
        defaults.set(encoded, forKey: Key.stock.rawValue)
    }

    func load() -> Bool {
        let encoded = defaults.value(forKey: Key.stock.rawValue)
        print("loaded bases = \(String(describing: encoded))")
        if encoded == nil {
            return false
        }
        var newBases = [Stock]()
        if let encoded = encoded as? [[String: Any]]? {
            for encodedStock in encoded! {
                newBases.append(Stock(fromDictionary: encodedStock))
            }
        }
        elements = newBases
        return true
    }

}

