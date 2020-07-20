//
//  UIViewController+Panel.swift
//  Aiolos
//
//  Created by Matthias Tretter on 04/08/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import UIKit


@objc
public extension UIViewController {

    var aiolosPanel: Panel? {
        var panel = self.parent
        while panel != nil && (panel is Panel) == false {
            panel = panel?.parent
        }

        return panel as? Panel
    }
}
