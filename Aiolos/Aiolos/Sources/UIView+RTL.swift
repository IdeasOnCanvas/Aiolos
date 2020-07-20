//
//  UIView+RTL.swift
//  Aiolos
//
//  Created by Matthias Tretter on 25.01.19.
//  Copyright © 2019 Matthias Tretter. All rights reserved.
//

import UIKit


extension UIView {

    var isRTL: Bool {
        return self.effectiveUserInterfaceLayoutDirection == .rightToLeft
    }
}
