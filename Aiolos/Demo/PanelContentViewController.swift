//
//  PanelContentViewController.swift
//  AiolosDemo
//
//  Created by Matthias Tretter on 12/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation
import UIKit


final class PanelContentViewController: UITableViewController {

    private let color: UIColor

    init(color: UIColor) {
        self.color = color
        super.init(style: .plain)
        self.title = "Content"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = self.color
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(handleAddPress))
    }
}

// MARK: UITableViewDataSource

extension PanelContentViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 100
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = "Cell \(indexPath.row)"
        cell.contentView.backgroundColor = .clear
        cell.backgroundView?.backgroundColor = .clear
        cell.backgroundColor = .clear
        return cell
    }
}

// MARK: - Private

private extension PanelContentViewController {

    @objc
    func handleAddPress(_ sender: UIBarButtonItem) {
        print("Add…")
    }
}
