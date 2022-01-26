//
//  StripePaymentInfo.swift
//  ProtoStripeTerminal
//
//  Created by Renaud Pradenc on 12/01/2022.
//

import Foundation

struct StripeCardDetails {
    let brand: String
    let last4: String
}

struct StripePaymentInfo {
    /// Stripe identifier of the Payment Intent
    let id: String
    
    let date: Date
    
    struct Charge {
        /// Stripe identifier of the Charge
        let id: String
        let amount: StripeAmount
        let cardDetails: StripeCardDetails?
    }
    let charges: [Charge]
}
