//
//  StripeUpdatingCell.swift
//  ProtoStripeTerminal
//
//  Created by Renaud Pradenc on 05/01/2022.
//

import UIKit

class StripeUpdatingCell: UITableViewCell {
    /// The progress of updating, in the 0..1 range.
    var progress: Float? {
        didSet {
            percentLabel.text = percentString(from: progress)
            progressView.progress = progress ?? 0.0
        }
    }
    
    private func percentString(from progress: Float?) -> String {
        guard let progress = progress else {
            return "-- %"
        }
        
        return "\(Int(progress*100.0)) %"
    }

    @IBOutlet private weak var percentLabel: UILabel!
    @IBOutlet private weak var progressView: UIProgressView!
}
