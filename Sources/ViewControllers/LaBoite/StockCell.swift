//
//  StockCell.swift
//  OpenFoodFacts
//
//  Created by Pascal Bourguignon on 30/04/2019.
//  Copyright © 2019 Andrés Pizá Bückmann. All rights reserved.
//

import UIKit

class StockCell: UITableViewCell {

    @IBOutlet weak var productName: UILabel!
    @IBOutlet weak var stockValue: UILabel!
    @IBOutlet weak var stockProgress: UIProgressView!
    @IBOutlet weak var reorderThresholdValue: UILabel!
    @IBOutlet weak var reorderThresholdSlider: UISlider!
}
