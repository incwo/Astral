//
//  ReaderIdentityCell.swift
//  Astral
//
//  Created by Renaud Pradenc on 23/12/2021.
//

import UIKit

class ReaderIdentityCell: UITableViewCell {

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

    @IBOutlet private weak var modelLabel: UILabel!
    @IBOutlet private weak var serialNumberLabel: UILabel!
}
