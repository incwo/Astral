//
//  DiscoveryViewModel.swift
//  Astral
//
//  Created by Renaud Pradenc on 21/01/2022.
//

import Foundation
import StripeTerminal

class DiscoveryViewModel {
    
    init(readersDiscovery: ReadersDiscovery, onUpdateDiscovering: @escaping (Bool)->(), onUpdateSections: @escaping (IndexSet)->(), onError: @escaping (Error)->()) {
        self.readersDiscovery = readersDiscovery
        self.onUpdateDiscovering = onUpdateDiscovering
        self.onUpdateSections = onUpdateSections
        self.onError = onError
    }
    
    let readersDiscovery: ReadersDiscovery
    let onUpdateDiscovering: (Bool)->()
    let onUpdateSections: (IndexSet)->()
    let onError: (Error)->()
    
    /// The location for which Readers are shown
    var location: Location? {
        didSet {
            if let _ = location {
                reloadSections([.location, .readers])
                cancelDiscovery {
                    self.startDiscovery()
                }
            } else { // The location is removed, e.g. after disconnecting a reader
                reloadSections([.location, .readers])
            }
        }
    }
    
    deinit {
        cancelDiscovery { }
    }
    
    /// The readers found at this location
    private(set) var readers: [Reader] = [] {
        didSet {
            reloadSections([.readers])
        }
    }
    
    // MARK: Discovery
    private func startDiscovery() {
        updateDiscovering()
        readers = []
        
        readersDiscovery.discoverReaders(onUpdate: { readers in
            DispatchQueue.main.async {
                self.readers = readers
            }
        }, onError: { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.readers = []
                self.updateDiscovering()
                self.onError(error)
            }
        })
    }
    
    private func cancelDiscovery(completion: @escaping ()->()) {
        readersDiscovery.cancel {
            self.updateDiscovering()
            self.readers = []
            completion()
        }
    }
    
    private func updateDiscovering() {
        onUpdateDiscovering(readersDiscovery.isDiscovering)
    }
    
    // MARK: Content
    
    enum Row {
        case pickLocation
        case location (Location)
        case noLocationPicked
        case reader (Reader)
    }
    
    struct Section {
        internal init(header: String? = nil, rows: [Row]) {
            self.header = header
            self.rows = rows
        }
        
        let header: String?
        let rows: [Row]
    }
    
    private var locationSection: Section {
        let header = locz("DiscoveryViewModel.sectionHeader.location")
        if let location = location {
            return Section(header: header, rows: [.location(location)])
        } else {
            return Section(header: header, rows: [.pickLocation])
        }
    }
    private var readersSection: Section {
        let header = locz("DiscoveryViewModel.sectionHeader.readers")
        if let _ = location {
            return Section(header: header, rows: readers.compactMap({ .reader($0) }))
        } else {
            return Section(header: header, rows: [.noLocationPicked])
        }
    }
    
    var sections: [Section] {
        [locationSection, readersSection]
    }
    
    private enum SectionIndex: Int {
        case location
        case readers
    }
    
    private func reloadSections(_ sectionIndexes: [SectionIndex]) {
        onUpdateSections(IndexSet(sectionIndexes.map(\.rawValue)))
    }
}
