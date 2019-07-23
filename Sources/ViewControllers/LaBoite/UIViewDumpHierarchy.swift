//
//  UIViewDumpHierarchy.swift
//  StockMeMicroDemo
//
//  Created by Pascal Bourguignon on 17/07/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import Foundation
import UIKit

extension UIView {

    enum Direction {
        case parent
        case view
        case children
    }

    func dumpHierarchy(including directions: [Direction]) {
        print("(")
        if directions.contains(Direction.parent) {
            if let parent = superview {
                print(":parent")
                parent.dumpHierarchy(including: [.parent, .view])
            }
        }
        if directions.contains(Direction.view) {
            dump(self)
        }
        if directions.contains(Direction.children) {
            print(":children (")
            for child in subviews {
                child.dumpHierarchy(including: [.view, .children])
            }
            print(")")
        }
        print(")")
    }

}
