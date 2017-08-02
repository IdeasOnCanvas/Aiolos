//
//  PanelContentViewController.swift
//  AiolosDemo
//
//  Created by Matthias Tretter on 12/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation
import UIKit


final class PanelContentViewController: UIViewController {

    private let color: UIColor

    init(color: UIColor) {
        self.color = color
        super.init(nibName: nil, bundle: nil)
        self.title = "Content"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = self.color
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(handleAddPress))
    }
}

// MARK: - Private

private extension PanelContentViewController {

    @objc
    func handleAddPress(_ sender: UIBarButtonItem) {
        print("Add…")
    }
}
