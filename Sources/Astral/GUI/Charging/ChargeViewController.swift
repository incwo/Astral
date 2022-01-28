//
//  ChargeViewController.swift
//  Astral
//
//  Created by Renaud Pradenc on 25/01/2022.
//

import UIKit

class ChargeViewController: UIViewController {

    var operationTitle: String? {
        didSet {
            self.title = operationTitle
        }
    }
    
    var amount: String? {
        didSet {
            if isViewLoaded {
                amountLabel.text = amount
            }
        }
    }
    
    var status: String? {
        didSet {
            if isViewLoaded {
                statusLabel.text = status
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        amountLabel.text = amount
        statusLabel.text = status
    }
    

    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var statusLabel: UILabel!
}
