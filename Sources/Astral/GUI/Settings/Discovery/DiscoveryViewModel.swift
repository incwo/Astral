//
//  DiscoveryViewModel.swift
//  Astral
//
//  Created by Renaud Pradenc on 21/01/2022.
//

import Foundation
import StripeTerminal

class DiscoveryViewModel {
    
    init(onUpdateDiscovering: @escaping (Bool)->(), onUpdateSections: @escaping (IndexSet)->()) {
        self.onUpdateDiscovering = onUpdateDiscovering
        self.onUpdateSections = onUpdateSections
    }
    
    let onUpdateDiscovering: (Bool)->()
    let onUpdateSections: (IndexSet)->()
    
    /// The location for which Readers are shown
    var location: Location? {
        didSet {
            reloadSections([.location, .readers])
        }
    }
    
    /// The readers found at this location
    var readers: [Reader] = [] {
        didSet {
            reloadSections([.readers])
        }
    }
    
    private var isDiscovering: Bool = false {
        didSet {
            onUpdateDiscovering(isDiscovering)
        }
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
