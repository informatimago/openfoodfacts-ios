//
//  StockViewController.swift
//  LaBoite
//
//  Created by Pascal Bourguignon on 30/04/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications

protocol SearchObserver {
    func cancelSearch()
    func searchFound(product: Product)
}

class StockViewController: UITableViewController, SearchObserver, UIPickerViewDelegate, UIPickerViewDataSource {

    let pollPeriod = 3.0 // seconds
    var timer: Timer?

    var bases: BaseList?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
    }

    override func viewDidLoad() {
        StockViewController.instance = self
        hideKeyboardWhenTappedAround()
        bases = BaseList.instance()
        if !(bases!.load()) {
            addDemoCells()
        }
        initializeTableView()
        startPollingControllers()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge],
                                                                completionHandler: {granted, error in
                                                                    if granted {
                                                                        print("UserNotification allowed.")
                                                                    } else {
                                                                        print("UserNotification refused \(String(describing: error)).")
                                                                    }
        })
        UNUserNotificationCenter.current().delegate = UIApplication.shared.delegate as? UNUserNotificationCenterDelegate
    }

    func initializeTableView() {
        tableView.estimatedRowHeight = 100.0 // Adjust Primary table height
        tableView.rowHeight = 100.0 // UITableView.automaticDimension

        tableView.beginUpdates()
        tableView.insertSections(IndexSet(arrayLiteral: 0, 1), with: .automatic)
        // The ControllerConfigurationCell
        tableView.insertRows(at: [IndexPath(item: 0, section: 1)], with: .automatic)
        tableView.endUpdates()
        // The StockCells
        tableView.reloadData()
    }

    func addDemoCells() {
        bases!.elements.append(Stock(productName: "Riz Long Grain", stock: 5.000, reorderThreshold: 0.300))
        bases!.elements.append(Stock(productName: "Cassonade", stock: 1.000, reorderThreshold: 0.100))
        bases!.elements.append(Stock(productName: "Huile d'Olive Vierge Extra", stock: 1.000, reorderThreshold: 0.100))
        bases!.elements[0].stock(decrement: 0.550)
        bases!.elements[1].stock(decrement: 0.735)
        bases!.elements[2].stock(decrement: 0.524)
    }

    func saveConfiguration() {
        bases!.save()
    }

    func tableViewCellForView(_ view: UIView) -> UITableViewCell? {
        if let tableViewCell = view as? UITableViewCell {
            return tableViewCell
        } else {
            return tableViewCellForView(view.superview!)
        }
    }

    func stockCellContaining(view: UIView) -> StockCell? {
        if let tableViewCell = tableViewCellForView(view) {
            if let cell = tableViewCell as? StockCell {
                return cell
            }
        }
        return nil
    }

    func updateThreshold(_ value: Float, ofCell cell: StockCell) {
        cell.product.reorderThreshold = value
        cell.product.changed()
        bases!.save()
    }

    func updateOrder(_ value: Float, ofCell cell: StockCell) {
        cell.product.order = value
        cell.product.changed()
        bases!.save()
    }

    @IBAction func updateReorderThreshold(_ sender: UIView) {
        if let cell = stockCellContaining(view: sender) {
            if let slider = sender as? UISlider {
                updateThreshold(slider.value, ofCell: cell)
            }
            if let text = sender as? UITextField {
                dismissKeyboard()
                let value = Int(text.text!)
                updateThreshold(Float(value!)/1000.0, ofCell: cell)
            }
        }
    }

    @IBAction func connectToNewController(_ sender: UIButton) {
        if let tableViewCell = tableViewCellForView(sender) {
            if let cell = tableViewCell as? ControllerConfigurationCell {
                bases!.addNewBase(cell.controllerIPAddress.text!,
                                  UInt16(cell.controllerPort.text!) ?? BaseList.defaultControllerPort)
                tableView.beginUpdates()
                tableView.insertRows(at: [IndexPath(item: bases!.elements.count-1, section: 0)], with: .automatic)
                tableView.endUpdates()
                timer!.fire()
                bases!.save()
            }
        }
    }


    // StockCell

    var associatingCell: StockCell?

    @IBAction func associateProduct(_ sender: UIButton) {
        if let cell = stockCellContaining(view: sender) {
            associatingCell = cell
            segueToScanner()
        }
    }

    // MARK: UIPickerView Delegation

    func parseMassValue(_ text: String) -> Float? {
        if text.hasSuffix(" g") {
            return Float(text.prefix(text.count - 2))!/1000.0
        } else {
            let value = Float(text)
            return value
        }
    }

    var thresholdValues = [String](arrayLiteral: "25 g", "50 g", "75 g", "100 g", "200 g", "300 g", "500 g", "750 g", "1000 g")
    var orderValues = [String](arrayLiteral: "250 g", "500 g", "750 g", "1000 g", "2000 g", "5000 g")

    var currentCell: StockCell?
    var currentPicker: UIPickerView?
    var pickerValues: [String]?
    var pickerButton: UIButton?
    enum PickerField {
        case threshold
        case order
    }
    var pickerField = PickerField.threshold

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if (pickerValues != nil) {
            return pickerValues!.count
        } else {
            return 0
        }
    }

    func pickerView( _ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerValues?[row]
    }

    func pickerView( _ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let newValue = pickerValues![row]
        pickerButton!.setTitle(newValue, for: UIControl.State.normal)
        currentPicker!.isHidden = true
        let parsedValue = parseMassValue(newValue)
        switch(pickerField){
        case PickerField.threshold:
            updateThreshold(parsedValue!, ofCell: currentCell!)
        case PickerField.order:
            updateOrder(parsedValue!, ofCell: currentCell!)
        }
    }

    func initializePicker() {
        if currentPicker == nil {
            currentPicker = UIPickerView()
            currentPicker!.backgroundColor = UIColor.lightGray
            currentPicker!.delegate = self
            currentPicker!.dataSource = self
            currentPicker!.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(currentPicker!)
            currentPicker!.isHidden = true
            currentPicker!.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor).isActive = true
            currentPicker!.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
            currentPicker!.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        }
    }

    @IBAction func changeThreshold(_ sender: UIButton) {
        initializePicker()
        if let cell = stockCellContaining(view: sender) {
            currentCell = cell
            pickerValues = thresholdValues
            pickerButton = sender
            pickerField = PickerField.threshold
            currentPicker!.reloadAllComponents()
            currentPicker!.isHidden = false
        }
    }

    @IBAction func changeOrder(_ sender: UIButton) {
        initializePicker()
        if let cell = stockCellContaining(view: sender) {
            currentCell = cell
            pickerValues = orderValues
            pickerButton = sender
            pickerField = PickerField.order
            currentPicker!.reloadAllComponents()
            currentPicker!.isHidden = false
        }
    }

    // UITableViewDataSource

    override func numberOfSections(in: UITableView) -> Int {
        // return 2
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:  return bases!.elements.count
        // case 1:  return 1
        default: return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
            // case 1:
            //     let cell = tableView.dequeueReusableCell(withIdentifier: "newControllerCell", for: indexPath)
            //     if let cell = cell as? ControllerConfigurationCell {
            //         cell.controllerIPAddress!.text = BaseList.defaultControllerIPAddress
            //     }
            //     return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "stockCell", for: indexPath)
            if let cell = cell as? StockCell {
                let product = bases!.elements[indexPath.item]
                cell.product = product
                cell.changed(stock: product)
            }
            return cell
        }
    }

    @available(iOS 11.0, *)
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        switch indexPath.section {
        case 0:
            let delete = UIContextualAction(style: .destructive, title: "Delete") { (action, sourceView, completionHandler) in
                print("index path of delete: \(indexPath)")
                print("action = \(action)")
                print("sourceView = \(sourceView)")
                self.bases!.elements.remove(at: indexPath.item)
                self.bases!.save()
                tableView.reloadData()
                completionHandler(true)
            }

            let tare = UIContextualAction(style: .normal, title: "Tare") { (action, sourceView, completionHandler) in
                self.bases!.elements[indexPath.item].setTare()
                self.bases!.save()
                completionHandler(true)
            }

//            let rename = UIContextualAction(style: .normal, title: "Edit") { (action, sourceView, completionHandler) in
//                print("index path of edit: \(indexPath)")
//                completionHandler(true)
//            }
//            let swipeActionConfig = UISwipeActionsConfiguration(actions: [rename, delete])
            let swipeActionConfig = UISwipeActionsConfiguration(actions: [delete,tare])
            swipeActionConfig.performsFirstActionWithFullSwipe = false
            return swipeActionConfig
        default:
            return nil
        }
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        switch indexPath.section {
        case 0:
            return true
        default:
            return false
        }
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCell.EditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            // handle delete (by removing the data from your array and updating the tableview)
            switch indexPath.section {
            case 0:
                bases!.elements.remove(at: indexPath.item)
                bases!.save()
            default:
                break
            }
        }
    }

    // Stock Polling

    func startPollingControllers() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(floatLiteral: pollPeriod),
                                     repeats: true,
                                     block: { (_: Timer) -> Void in
                                        print("Calling pollControllers")
                                        self.pollControllers() })
        print("Created scheduled Timer \(timer!.timeInterval)")
    }

    func pollControllers() {
        for stock in bases!.elements {
            stock.pollController()
        }
    }

    // Search product by name

    static var instance: StockViewController?
    static var searchingController: StockViewController?

    class func searchObserver() -> SearchObserver? {
        return searchingController
    }

    func segueToScanner() {
        StockViewController.searchingController = self
        RootViewController.rootViewController()?.showScan()
        performSegue(withIdentifier: "tabs", sender: self)
    }

    func searchFound(product: Product) {
        print("\(String(describing: product.name))")
        associatingCell?.product.setProduct(product)
        associatingCell = nil
        StockViewController.searchingController = nil
        bases!.save()
    }

    func cancelSearch() {
        associatingCell = nil
        StockViewController.searchingController = nil
    }

}
