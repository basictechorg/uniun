//
//  ShareViewController.swift
//  ShareExtension
//
//  Inherits RSIShareViewController (vendored locally in this target — see
//  RSIShareViewController.swift / SharedMedia.swift) so shared content — text /
//  URLs / images / videos / files — is written to the App Group
//  (group.in.uniun.app, resolved by default from the bundle ids) and the host
//  app (UNIUN) is launched to consume it. Loaded via MainInterface.storyboard,
//  whose view controller is classed as `ShareViewController`. No pod import:
//  RSIShareViewController is compiled directly into this extension.
//

import UIKit

class ShareViewController: RSIShareViewController {

    // true → tapping "Post" redirects straight into UNIUN with the shared
    // content. Return false to deliver silently and stay in the share sheet.
    override func shouldAutoRedirect() -> Bool {
        return true
    }
}
