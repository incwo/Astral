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
    
    var onCancel: (()->())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel(_:)))
        
        amountLabel.text = amount
        statusLabel.text = status
    }
    
    @objc private func cancel(_ sender: UIBarButtonItem) {
        onCancel?()
    }
    

    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var statusLabel: UILabel!
}
