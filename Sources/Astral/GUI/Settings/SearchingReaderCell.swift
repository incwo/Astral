//
//  SearchingReaderCell.swift
//  
//
//  Created by Renaud Pradenc on 11/02/2022.
//

import UIKit

class SearchingReaderCell: UITableViewCell {
    
    typealias OnCancel = ()->()
    var onCancel: OnCancel?

    @IBAction private func cancel(_ sender: Any) {
        onCancel?()
    }
}
