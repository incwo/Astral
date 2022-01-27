//
//  StripeUpdateViewModel.swift
//  ProtoStripeTerminal
//
//  Created by Renaud Pradenc on 05/01/2022.
//

import Foundation
import StripeTerminal

class StripeUpdateViewModel {
    
    init(onInstallUpdate: @escaping ()->()) {
        self.onInstallUpdate = onInstallUpdate
    }
    
    let onInstallUpdate: ()->()
    
    // MARK: Reader and Update
    
    /// Update of the progress between 0 and 1.
    var progress: Float = 0.0
    
    // MARK: Content
    
    enum Content {
        case empty
        case noUpdateAvailable (Reader)
        case updateAvailable (Reader)
        case updating (Reader)
    }
    var content: Content = .empty
    
    enum Row {
        case currentVersion (String)
        case updateVersion (String)
        case upToDate
        case update
        case updating (Float)
    }
    
    struct Section {
        internal init(rows: [Row], footer: String? = nil) {
            self.rows = rows
            self.footer = footer
        }
        
        let rows: [Row]
        let footer: String?
    }
    
    var sections: [Section] {
        switch content {
        case .empty:
            return []
            
        case .noUpdateAvailable (let reader):
            return [
                Section(rows: [
                    .currentVersion(reader.currentVersion),
                    .upToDate
                ]),
            ]
        case .updateAvailable (let reader):
            return [
                Section(rows: [
                    .currentVersion(reader.currentVersion),
                    .updateVersion(reader.updateVersion),
                ], footer: reader.estimatedUpdateTime),
                Section(rows: [
                    .update
                ]),
            ]
                        
        case .updating (let reader):
            return [
                Section(rows: [
                    .currentVersion(reader.currentVersion),
                    .updateVersion(reader.updateVersion),
                ], footer: reader.estimatedUpdateTime),
                Section(rows: [
                    .updating (progress)
                ]),
            ]
        }
    }
    
}

private extension UpdateTimeEstimate {
    var localizedString: String {
        switch self {
        case .estimateLessThan1Minute:
            return "less than 1 minute"
        case .estimate1To2Minutes:
            return "1 to 2 minutes"
        case .estimate2To5Minutes:
            return "2 to 5 minutes"
        case .estimate5To15Minutes:
            return "5 to 15 minutes"
        default:
            return "Unknown"
        }
    }
    
    var displayedString: String {
        "Estimated updating time: \(self.localizedString)"
    }
}

private extension Reader {
    var currentVersion: String {
        self.deviceSoftwareVersion ?? "???"
    }
    
    var updateVersion: String {
        self.availableUpdate?.deviceSoftwareVersion ?? "???"
    }
    
    var estimatedUpdateTime: String? {
        self.availableUpdate?.estimatedUpdateTime.displayedString
    }
}
