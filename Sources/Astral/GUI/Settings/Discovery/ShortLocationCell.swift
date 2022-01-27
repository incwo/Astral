//
//  ShortLocationCell.swift
//  Astral
//
//  Created by Renaud Pradenc on 06/01/2022.
//

import Foundation
import UIKit
import StripeTerminal

/// A cell to show a short identification of a Location
class ShortLocationCell: UITableViewCell {
    
    var location: Location? {
        didSet {
            nameLabel.text = location?.displayName
            line1Label.text = location?.address?.line1
            cityLabel.text = location?.address?.city
        }
    }

    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var line1Label: UILabel!
    @IBOutlet private weak var cityLabel: UILabel!
}
