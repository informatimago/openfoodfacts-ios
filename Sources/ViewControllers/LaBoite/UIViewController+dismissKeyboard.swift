//
//  UIViewController+dismissKeyboard.swift
//  StockMeMiniDemo
//
//  Created by Pascal Bourguignon on 11/05/2019.
//  Copyright © 2019 SBDE SAS ÀCV. All rights reserved.
//

import UIKit

extension UIViewController {

    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
