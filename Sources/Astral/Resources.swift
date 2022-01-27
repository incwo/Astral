//
//  Resources.swift
//  Astral
//
//  Created by Renaud Pradenc on 25/01/2022.
//

import Foundation

struct Resources {
    
}

/// Returns a localized string from the key, or the key if no translation is found.
func locz(_ key: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: .module, value: key, comment: "")
}
