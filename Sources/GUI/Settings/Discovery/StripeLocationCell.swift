//
//  StripeLocationCell.swift
//  ProtoStripeTerminal
//
//  Created by Renaud Pradenc on 05/01/2022.
//

import UIKit
import StripeTerminal

/// A cell to show the name and the address of a Stripe Location
class StripeLocationCell: UITableViewCell {
    
    var location: Location? {
        didSet {
            nameLabel.text = location?.displayName
            line1Label.text = location?.address?.line1
            line2Label.text = location?.address?.line2
            cityLabel.text = location?.address?.city
            stateLabel.text = location?.address?.state
            countryLabel.text = location?.address?.country
        }
    }

    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var line1Label: UILabel!
    @IBOutlet private weak var line2Label: UILabel!
    @IBOutlet private weak var cityLabel: UILabel!
    @IBOutlet private weak var stateLabel: UILabel!
    @IBOutlet private weak var countryLabel: UILabel!
}
