//
//  CarrefourProvider.swift
//  StockMeMiniDemo
//
//  Created by Pascal Bourguignon on 07/06/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import Foundation
import UIKit

class CarrefourProvider: Provider {

    func urlToShop() -> URL? {
        return URL(string: "https://www.carrefour.fr/")
    }

    func urlToReceipes() -> URL? {
        return URL(string: "https://www.marmiton.org/recettes/recettes-incontournables.aspx")
    }

    func urlToOrder( productNamed productName: String) -> URL? {
        print("Reorder now \(productName)")
        if let escapedProductName = productName.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) {
            return URL(string: "https://www.carrefour.fr/s?q=\(escapedProductName)")
        } else {
            return nil
        }
    }

}
