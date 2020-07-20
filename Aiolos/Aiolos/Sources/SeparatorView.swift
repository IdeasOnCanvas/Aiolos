//
//  SeparatorView.swift
//  Aiolos
//
//  Created by Matthias Tretter on 09/08/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit


/// Internal class that is used for the separator between the resize handle and panel content
final class SeparatorView: UIView {

    // MARK: - Lifecycle

    init(configuration: Panel.Configuration) {
        super.init(frame: .zero)

        self.configure(with: configuration)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - SeparatorView

    func configure(with configuration: Panel.Configuration) {
        self.backgroundColor = configuration.appearance.separatorColor
    }
}
