//
//  BaseViewController.swift
//  StockMeMiniDemo
//
//  Created by Pascal Bourguignon on 07/06/2019.
//  Copyright © 2019 SBDE SAS àcv. All rights reserved.
//

import Foundation
import UIKit

class BaseViewController: UIViewController {

    @IBAction func back() {
        // RootViewController.rootViewController()!.showMenu()
        // performSegue(withIdentifier: "tabs", sender: self)
        self.dismiss(animated: true)
    }

    @IBOutlet weak var controllerIPAddress: UITextField!
    @IBOutlet weak var controllerPort: UITextField!

    @IBAction func addNewBase(_ sender: UIButton) {
        BaseList.instance().addNewBase(controllerIPAddress.text!,
                                       UInt16(controllerPort.text!) ?? BaseList.defaultControllerPort)
    }

}
