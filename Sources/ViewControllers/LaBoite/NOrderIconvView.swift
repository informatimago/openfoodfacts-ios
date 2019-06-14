//
//  NOrderIconvView.swift
//  StockMeMiniDemo
//
//  Created by Pascal Bourguignon on 14/06/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import UIKit
class NOrderIconView: UIView {

    override func layoutSubviews() {
        var yyy: CGFloat = 0
        var xxx: CGFloat = 0
        var nnn = 0
        if bounds.width < bounds.height {
            // vertical
            for view in subviews {
                switch nnn {
                case 0:
                    xxx = 0
                default:
                    xxx = bounds.width - view.frame.width
                }
                view.frame = CGRect(x: xxx, y: yyy, width: view.frame.width, height: view.frame.height)
                if nnn == 1 {
                    yyy += view.frame.height
                }
                nnn = (nnn + 1) % 2
            }
        } else {
            // horizontal
            for view in subviews {
                switch nnn {
                case 0:
                    xxx = 0
                case 1:
                    xxx = (bounds.width - 3 * view.frame.width) / 2 + view.frame.width
                default:
                    xxx = bounds.width - view.frame.width
                }
                view.frame = CGRect(x: xxx, y: yyy, width: view.frame.width, height: view.frame.height)
                if nnn == 2 {
                    yyy += view.frame.height
                }
                nnn = (nnn + 1) % 3
            }
        }
    }

}
