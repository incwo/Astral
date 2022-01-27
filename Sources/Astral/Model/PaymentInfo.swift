//
//  PaymentInfo.swift
//  Astral
//
//  Created by Renaud Pradenc on 12/01/2022.
//

import Foundation

public struct CardDetails {
    public let brand: String
    public let last4: String
}

public struct PaymentInfo {
    /// Stripe identifier of the Payment Intent
    public let id: String
    
    public let date: Date
    
    public struct Charge {
        /// Stripe identifier of the Charge
        public let id: String
        public let amount: Amount
        public let cardDetails: CardDetails?
    }
    public let charges: [Charge]
}
