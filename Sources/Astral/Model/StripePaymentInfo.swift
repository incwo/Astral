//
//  StripePaymentInfo.swift
//  ProtoStripeTerminal
//
//  Created by Renaud Pradenc on 12/01/2022.
//

import Foundation

public struct StripeCardDetails {
    public let brand: String
    public let last4: String
}

public struct StripePaymentInfo {
    /// Stripe identifier of the Payment Intent
    public let id: String
    
    public let date: Date
    
    public struct Charge {
        /// Stripe identifier of the Charge
        public let id: String
        public let amount: StripeAmount
        public let cardDetails: StripeCardDetails?
    }
    public let charges: [Charge]
}
