//
//  Resources.swift
//  Astral
//
//  Created by Renaud Pradenc on 25/01/2022.
//

import Foundation
import UIKit

struct Resources {
    
}

/// Returns a localized string from the key, or the key if no translation is found.
func locz(_ key: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: .module, value: key, comment: "")
}

extension UIColor {
    static let astralAccent = UIColor(named: "astral.accent", in: .module, compatibleWith: nil)
    static let astralLabel = UIColor(named: "astral.label", in: .module, compatibleWith: nil)
    static let astralLabelSecondary = UIColor(named: "astral.label.secondary", in: .module, compatibleWith: nil)
}
