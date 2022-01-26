//
//  StripeAmount.swift
//  ProtoStripeTerminal
//
//  Created by Renaud Pradenc on 12/01/2022.
//

import Foundation

/// An amount in a given currency
struct StripeAmount {
    /// Amount in the smallest unit of the currency (i.e: in cents if the currency has them).
    let smallestUnitAmount: UInt
    
    /// ISO code of the currency (lower case)
    let currency: String
    
    /// Initialize with an amount and a currency.
    init(amount: NSDecimalNumber, currency: String) {
        self.currency = currency.lowercased() // Stripe wants lowercase codes
        
        // Stripe demands that the amount is given as an integer in the "smallest unit". e.g. in cents for Euros or Dollars. But some currencies have no cents.
        // This method converts the decimalNumberAmount to smallest units depending on the currency.
        if noDecimalCurrencyCodes.contains(self.currency) {
            self.smallestUnitAmount = amount.uintValue
        } else {
            self.smallestUnitAmount = amount.multiplying(byPowerOf10: 2).uintValue
        }
    }
    
    var amount: NSDecimalNumber {
        if noDecimalCurrencyCodes.contains(self.currency) {
            return NSDecimalNumber(value: self.smallestUnitAmount)
        } else {
            return NSDecimalNumber(value: self.smallestUnitAmount).multiplying(byPowerOf10: -2)
        }
    }
    
    /// Codes for currencies for which the smallest unit is one — i.e. which  don't have cents
    private let noDecimalCurrencyCodes  = ["bif", "clp", "djf", "gnf", "jpy", "kmf", "krw", "mga", "pyg", "rwf", "vnd", "vuv", "xaf", "xof", "xpf"]
    
    /// Initialize with an amount expressed in the smallest unit of a currency
    init(smallestUnitAmount: UInt, currency: String) {
        self.smallestUnitAmount = smallestUnitAmount
        self.currency = currency.lowercased() // Stripe wants lowercase codes
    }
}
