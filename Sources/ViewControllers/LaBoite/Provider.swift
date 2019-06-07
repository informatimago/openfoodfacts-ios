//
//  Provider.swift
//  StockMeMiniDemo
//
//  Created by Pascal Bourguignon on 07/06/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import Foundation
import UIKit

protocol Provider {

    func urlToShop() -> URL?
    func urlToOrder( productNamed productName: String) -> URL?
    func urlToReceipes() -> URL?
}

var currentProvider: Provider?

