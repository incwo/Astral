//
//  UpdateViewModel.swift
//  Astral
//
//  Created by Renaud Pradenc on 05/01/2022.
//

import Foundation
import StripeTerminal

class UpdateViewModel {
    
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
        let prefix = "Terminal.updateTimeEstimate."
        switch self {
        case .estimateLessThan1Minute:
            return locz(prefix+"estimateLessThan1Minute")
        case .estimate1To2Minutes:
            return locz(prefix+"estimate1To2Minutes")
        case .estimate2To5Minutes:
            return locz(prefix+"estimate2To5Minutes")
        case .estimate5To15Minutes:
            return locz(prefix+"estimate5To15Minutes")
        default:
            return "Unknown"
        }
    }
    
    var displayedString: String {
        return String(format: locz("Terminal.updateTimeEstimate.estimatedTime"), localizedString)
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
