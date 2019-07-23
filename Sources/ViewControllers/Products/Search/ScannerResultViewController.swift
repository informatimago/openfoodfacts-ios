//
//  ScannerResultViewController.swift
//  OpenFoodFacts
//
//  Created by Philippe Auriach on 24/01/2019.
//  Copyright © 2019 Andrés Pizá Bückmann. All rights reserved.
//

import UIKit

enum ScannerResultStatusEnum {
    case waitingForScan
    case loading(barcode: String)
    case hasSummary(product: Product)
    case hasProduct(product: Product, dataManager: DataManagerProtocol)
    case manualBarcode
}

class ScannerResultViewController: UIViewController {

    var status: ScannerResultStatusEnum = .waitingForScan {
        didSet {
            updateSummaryDisplay()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let product = product {
            fillIn(product: product)
        }
    }

    fileprivate func updateSummaryDisplay() {

        switch status {
        case .waitingForScan:
            break
        case .loading( _ /*barcode*/):
            break
        case .hasSummary(let product):
            updateSummaryVisibility(forProduct: product)
        case .hasProduct(let product, _ /*let dataManager*/):
            updateSummaryVisibility(forProduct: product)
        case .manualBarcode:
            break
        }
    }

    fileprivate func updateSummaryVisibility(forProduct product: Product) {
        fillIn(product: product)
    }

    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var brandsLabel: UILabel!
    @IBOutlet weak var quantityLabel: UILabel!
    @IBOutlet weak var nutriScoreView: NutriScoreView!
    @IBOutlet weak var novaGroupView: NovaGroupView!
    @IBOutlet weak var environmentImpactImageView: UIImageView!
    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var associationCancelButton: UIButton!
    @IBOutlet weak var associationSetButton: UIButton!

    var product: Product?

    func fillIn(product: Product) {
        self.product = product
        titleLabel.text = product.name

        if let imageUrl = product.frontImageSmallUrl ?? product.imageSmallUrl ??  product.frontImageUrl ?? product.imageUrl, let url = URL(string: imageUrl) {
            productImageView.kf.indicatorType = .activity
            productImageView.kf.setImage(with: url)
            productImageView.isHidden = false
        } else {
            productImageView.isHidden = true
        }

        brandsLabel.text = nil
        if let brands = product.brands, !brands.isEmpty {
            brandsLabel.text = brands.joined(separator: ", ")
        }
        quantityLabel.text = nil
        if let quantity = product.quantity, !quantity.isEmpty {
            quantityLabel.text = quantity
        }

        if let nutriscoreValue = product.nutriscore, let score = NutriScoreView.Score(rawValue: nutriscoreValue) {
            nutriScoreView.currentScore = score
            nutriScoreView.isHidden = false
        } else {
            nutriScoreView.isHidden = true
        }

        if let novaGroupValue = product.novaGroup,
            let novaGroup = NovaGroupView.NovaGroup(rawValue: novaGroupValue) {
            novaGroupView.novaGroup = novaGroup
            novaGroupView.isHidden = false
        } else {
            novaGroupView.isHidden = true
        }

        if let co2Impact = product.environmentImpactLevelTags?.first {
            environmentImpactImageView.image = co2Impact.image
            environmentImpactImageView.isHidden = false
        } else {
            environmentImpactImageView.isHidden = true
        }

        associationCancelButton.isUserInteractionEnabled = true
        associationSetButton.isUserInteractionEnabled = true
    }

    func popViewController() {
        self.dismiss(animated: false)
        // RootViewController.rootViewController()!.showStock()
        // self.parentContainerViewController()?.performSegue(withIdentifier: "tabs", sender: self)
    }

    var selection: ScannerSelectionProtocol?

    @IBAction func back() {
        associationCancel(self)
    }

    @IBAction func associationSet(_ sender: Any?) {
        print("association SET \(String(describing: StockViewController.searchObserver()))")
        if let searchObserver = StockViewController.searchObserver() {
            popViewController()
            searchObserver.searchFound(product: product!)
            selection?.associate()
        }
    }

    @IBAction func associationCancel(_ sender: Any?) {
        print("association CANCEL \(String(describing: StockViewController.searchObserver()))")
        if let searchObserver = StockViewController.searchObserver() {
            popViewController()
            searchObserver.cancelSearch()
            selection?.cancel()
        }
    }

}
