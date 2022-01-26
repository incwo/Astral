//
//  StralResources.swift
//  ProtoStripeTerminal
//
//  Created by Renaud Pradenc on 25/01/2022.
//

import Foundation

struct StralResources {
    
    static var bundle: Bundle = Bundle(for: StralManager.classForCoder())
}

/// Returns a localized string from the key, or the key if no translation is found.
func locz(_ key: String) -> String {
    NSLocalizedString(key, tableName: "Stral", bundle: StralResources.bundle, value: key, comment: "")
}
