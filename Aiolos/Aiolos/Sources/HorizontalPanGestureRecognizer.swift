//
//  Copyright (c) 2019 IdeasOnCanvas GmbH. All rights reserved.
//

import UIKit

/// UIPanGestureRecognizer that's being used for moving the panel horizontally
public final class HorizontalPanGestureRecognizer: UIPanGestureRecognizer {

    // MARK: - Properties

    public var detectsPointerScrolling: Bool = false {
        didSet {
            guard #available(iOS 13.4, *), NSClassFromString("UIPointerInteraction") != nil else { return }

            self.allowedScrollTypesMask = self.detectsPointerScrolling ? .continuous : []
        }
    }
}
