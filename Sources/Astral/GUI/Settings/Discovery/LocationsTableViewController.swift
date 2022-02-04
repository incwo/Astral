//
//  LocationsTableViewController.swift
//  Astral
//
//  Created by Renaud Pradenc on 05/01/2022.
//

import UIKit
import StripeTerminal

class LocationsTableViewController: UITableViewController {
    
    var onLocationPicked: ((Location)->())?
    private var locations: [Location] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
    }
    
    private var isLoading: Bool = false {
        didSet {
            activityIndicator.isHidden = !isLoading
        }
    }
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let style: UIActivityIndicatorView.Style
        if #available(iOS 13, *) {
            style = .medium
        } else {
            style = .gray
        }
        let indicator = UIActivityIndicatorView(style: style)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        isLoading = true
        // By default, only the first 10 locations are returned. This is sufficient for our needs.
        Terminal.shared.listLocations(parameters: nil) { [weak self] locations, hasMore, error in
            guard let self = self else { return }
            self.locations = locations ?? []
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.isLoading = false
                if let error = error {
                    self.presentAlert(for: error)
                }
                self.tableView.reloadData()
            }
        }
    }
    
    private func presentAlert(for error: Error) {
        let alert = UIAlertController(title: "Error while getting Locations", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

// MARK: UITableViewDataSource

extension LocationsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locations.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "location", for: indexPath) as! LocationCell
        cell.location = locations[indexPath.row]
        return cell
    }
}

// MARK: UITableViewDelegate

extension LocationsTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onLocationPicked?(locations[indexPath.row])
    }
}
