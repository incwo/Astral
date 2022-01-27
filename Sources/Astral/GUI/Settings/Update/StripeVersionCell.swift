//
//  StripeVersionCell.swift
//  ProtoStripeTerminal
//
//  Created by Renaud Pradenc on 05/01/2022.
//

import UIKit

class StripeVersionCell: UITableViewCell {

    var version: String? {
        didSet {
            versionLabel.text = version
        }
    }

    @IBOutlet private weak var versionLabel: UILabel!
}
