//
//  BoxedLabel.swift
//  StockMeMiniDemo
//
//  Created by Pascal Bourguignon on 05/06/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import Foundation
import UIKit

class BoxedLabel: UILabel {
    var color = UIColor.black

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let context = UIGraphicsGetCurrentContext()!
        context.saveGState()
        defer { context.restoreGState() }

        let path = UIBezierPath(roundedRect: self.bounds,
                                byRoundingCorners: [.topLeft, .topRight, .bottomLeft, .bottomRight],
                                cornerRadii: CGSize(width: 4, height: 4))
        context.setLineWidth(3.0)
        context.addPath(path.cgPath)
        context.closePath()
        context.setStrokeColor(color.cgColor)
        context.strokePath()
    }

}
