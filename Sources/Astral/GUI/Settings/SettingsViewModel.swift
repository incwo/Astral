//
//  SettingsViewModel.swift
//  Astral
//
//  Created by Renaud Pradenc on 22/12/2021.
//

import Foundation
import StripeTerminal

class SettingsViewModel {
    init(onSetupNewReader: @escaping ()->(), onShowUpdate: @escaping ()->(), onDisconnect: @escaping ()->()) {
        self.onSetupNewReader = onSetupNewReader
        self.onShowUpdate = onShowUpdate
        self.onDisconnect = onDisconnect
    }
    
    let onSetupNewReader: ()->()
    let onShowUpdate: ()->()
    let onDisconnect: ()->()
    
    // MARK: Content
    
    enum Content {
        case noReaderConnected
        case searchingReader
        case connecting
        case connected (Reader)
    }
    var content: Content = .noReaderConnected
    
    struct Section {
        internal init(title: String? = nil, rows: [Row]) {
            self.title = title
            self.rows = rows
        }
        
        let title: String?
        let rows: [Row]
    }
    
    enum Row {
        case setupReader
        case searchingReader
        case connecting
        case readerDescription (Reader)
        case softwareUpdate
        case disconnect
    }
    
    var sections: [Section] {
        switch content {
        case .noReaderConnected:
            return [
                Section(title: "Reader", rows: [.setupReader])
            ]
            
        case .searchingReader:
            return [
                Section(title: "Reader", rows: [.searchingReader])
            ]
            
        case .connecting:
            return [
                Section(title: "Reader", rows: [.connecting])
            ]
            
        case .connected(let reader):
            return [
                Section(title: "Reader", rows: [.readerDescription(reader)]),
                makeUpdateSection(reader: reader),
                Section(rows: [.disconnect])
            ].compactMap({ $0 })
        }
    }
    
    private func makeUpdateSection(reader: Reader) -> Section? {
        guard let _ = reader.availableUpdate  else {
            return nil
        }
        
        return Section(rows: [.softwareUpdate])
    }
}
