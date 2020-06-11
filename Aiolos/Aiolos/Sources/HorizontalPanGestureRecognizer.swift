//
//  Copyright (c) 2019 IdeasOnCanvas GmbH. All rights reserved.
//

import UIKit

/// UIPanGestureRecognizer that's being used for moving the panel horizontally
public final class HorizontalPanGestureRecognizer: UIPanGestureRecognizer {

    public override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)

        if #available(iOS 13.4, *), NSClassFromString("UIPointerInteraction") != nil {
            // Allow HorizontalPanGestureRecognizer to detect horizontal pointer scrolls to move the panel
            self.allowedScrollTypesMask = .all
        }
    }
}
