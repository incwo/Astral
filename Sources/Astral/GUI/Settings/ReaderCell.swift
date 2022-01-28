//
//  ReaderCell.swift
//  Astral
//
//  Created by Renaud Pradenc on 22/12/2021.
//

import UIKit

/// A Table View Cell to show the identity of a Stripe Reader
class ReaderCell: UITableViewCell {
    var model: String? {
        didSet {
            modelLabel.text = model
        }
    }
    
    var serialNumber: String? {
        didSet {
            serialNumberLabel.text = serialNumber
        }
    }
    
    /// Battery level 0..1
    var batteryLevel: Float? {
        didSet {
            if let batteryLevel = batteryLevel {
                batteryLevelLabel.text = "\(Int(batteryLevel*100.0))%"
            } else {
                batteryLevelLabel.text = "--"
            }
        }
    }

    @IBOutlet private weak var modelLabel: UILabel!
    @IBOutlet private weak var serialNumberLabel: UILabel!
    @IBOutlet private weak var batteryLevelLabel: UILabel!
}
