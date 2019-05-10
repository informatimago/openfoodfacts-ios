//
//  UIProgress+Thickness.swift
//  StockMeMiniDemo
//
//  Created by Pascal Bourguignon on 10/05/2019.
//  Copyright © 2019 Andrés Pizá Bückmann. All rights reserved.
//

import UIKit

extension UIProgressView {

    @IBInspectable var barHeight: CGFloat {
        get {
            return transform.d * 2.0
        }
        set {
            // 2.0 Refers to the default height of 2
            let heightScale = newValue / 2.0
            let originalCenter = center
            transform = CGAffineTransform(scaleX: 1.0, y: heightScale)
            center = originalCenter
        }
    }
}
