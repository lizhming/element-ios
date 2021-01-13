// File created from simpleScreenTemplate
// $ createSimpleScreen.sh Dialpad Dialpad
/*
 Copyright 2020 New Vector Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import UIKit
import libPhoneNumber_iOS

@objc protocol DialpadViewControllerDelegate: class {
    func dialpadViewControllerDidTapCall(_ viewController: DialpadViewController, withPhoneNumber phoneNumber: String)
    func dialpadViewControllerDidTapClose(_ viewController: DialpadViewController)
}

@objcMembers
class DialpadViewController: UIViewController {
    
    // MARK: Outlets
    
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var phoneNumberTextField: UITextField! {
        didSet {
            phoneNumberTextField.text = nil
            //  avoid showing keyboard on text field
            phoneNumberTextField.inputView = UIView()
            phoneNumberTextField.inputAccessoryView = UIView()
        }
    }
    @IBOutlet private weak var lineView: UIView!
    @IBOutlet private weak var digitsStackView: UIStackView!
    @IBOutlet private weak var backspaceButton: DialpadActionButton! {
        didSet {
            backspaceButton.type = .backspace
        }
    }
    @IBOutlet private weak var callButton: DialpadActionButton! {
        didSet {
            callButton.type = .call
        }
    }
    
    // MARK: Private
    
    private enum Constants {
        static let sizeOniPad: CGSize = CGSize(width: 375, height: 667)
    }
    
    private var wasCursorAtTheEnd: Bool = true
    
    /// Phone number as formatted
    private var phoneNumber: String = "" {
        willSet {
            wasCursorAtTheEnd = isCursorAtTheEnd()
        } didSet {
            phoneNumberTextField.text = phoneNumber
            if wasCursorAtTheEnd {
                moveCursorToTheEnd()
            }
        }
    }
    /// Phone number as non-formatted
    private var rawPhoneNumber: String {
        return phoneNumber.vc_removingAllWhitespaces()
    }
    private var theme: Theme!
    
    // MARK: Public
    
    weak var delegate: DialpadViewControllerDelegate?
    
    // MARK: - Setup
    
    class func instantiate() -> DialpadViewController {
        let viewController = StoryboardScene.DialpadViewController.initialScene.instantiate()
        viewController.theme = ThemeService.shared().theme
        return viewController
    }
    
    // MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        titleLabel.text = VectorL10n.dialpadTitle
        self.registerThemeServiceDidChangeThemeNotification()
        self.update(theme: self.theme)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.theme.statusBarStyle
    }
    
    // MARK: - Private
    
    private func isCursorAtTheEnd() -> Bool {
        guard let selectedRange = phoneNumberTextField.selectedTextRange else {
            return true
        }
        
        if !selectedRange.isEmpty {
            return false
        }
        
        let cursorEndPos = phoneNumberTextField.offset(from: phoneNumberTextField.beginningOfDocument, to: selectedRange.end)
        
        return cursorEndPos == phoneNumber.count
    }
    
    private func moveCursorToTheEnd() {
        guard let cursorPos = phoneNumberTextField.position(from: phoneNumberTextField.beginningOfDocument,
                                                            offset: phoneNumber.count) else { return }
        
        phoneNumberTextField.selectedTextRange = phoneNumberTextField.textRange(from: cursorPos,
                                                                                to: cursorPos)
    }
    
    private func reformatPhoneNumber() {
        guard let phoneNumberUtil = NBPhoneNumberUtil.sharedInstance() else {
            //  no formatter
            return
        }
        
        do {
            //  try formatting the number
            if phoneNumber.hasPrefix("00") {
                let range = phoneNumber.startIndex..<phoneNumber.index(phoneNumber.startIndex, offsetBy: 2)
                phoneNumber.replaceSubrange(range, with: "+")
            }
            let nbPhoneNumber = try phoneNumberUtil.parse(rawPhoneNumber, defaultRegion: nil)
            phoneNumber = try phoneNumberUtil.format(nbPhoneNumber, numberFormat: .INTERNATIONAL)
        } catch {
            //  continue without formatting
        }
    }
    
    private func update(theme: Theme) {
        self.theme = theme
        
        self.view.backgroundColor = theme.backgroundColor
        
        if let navigationBar = self.navigationController?.navigationBar {
            theme.applyStyle(onNavigationBar: navigationBar)
        }
        
        titleLabel.textColor = theme.noticeSecondaryColor
        phoneNumberTextField.textColor = theme.textPrimaryColor
        lineView.backgroundColor = theme.lineBreakColor
        closeButton.setBackgroundImage(Asset.Images.closeButton.image.vc_tintedImage(usingColor: theme.tabBarUnselectedItemTintColor), for: .normal)
        
        updateThemesOfAllButtons(in: digitsStackView, with: theme)
    }
    
    private func updateThemesOfAllButtons(in view: UIView, with theme: Theme) {
        if let button = view as? DialpadButton {
            button.update(theme: theme)
        } else {
            for subview in view.subviews {
                updateThemesOfAllButtons(in: subview, with: theme)
            }
        }
    }
    
    private func registerThemeServiceDidChangeThemeNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: .themeServiceDidChangeTheme, object: nil)
    }

    // MARK: - Actions
    
    @objc private func themeDidChange() {
        self.update(theme: ThemeService.shared().theme)
    }
    
    @IBAction private func closeButtonAction(_ sender: UIButton) {
        delegate?.dialpadViewControllerDidTapClose(self)
    }
    
    @IBAction private func digitButtonAction(_ sender: DialpadButton) {
        let digit = sender.title(for: .normal) ?? ""
        
        if let selectedRange = phoneNumberTextField.selectedTextRange {
            if isCursorAtTheEnd() {
                phoneNumber += digit
                reformatPhoneNumber()
                return
            }
            let cursorStartPos = phoneNumberTextField.offset(from: phoneNumberTextField.beginningOfDocument, to: selectedRange.start)
            let cursorEndPos = phoneNumberTextField.offset(from: phoneNumberTextField.beginningOfDocument, to: selectedRange.end)
            
            phoneNumber.replaceSubrange((phoneNumber.index(phoneNumber.startIndex, offsetBy: cursorStartPos))..<(phoneNumber.index(phoneNumber.startIndex, offsetBy: cursorEndPos)), with: digit)
            
            guard let cursorPos = phoneNumberTextField.position(from: phoneNumberTextField.beginningOfDocument,
                                                                offset: cursorEndPos + digit.count) else { return }
            
            reformatPhoneNumber()
            
            phoneNumberTextField.selectedTextRange = phoneNumberTextField.textRange(from: cursorPos,
                                                                                    to: cursorPos)
        } else {
            phoneNumber += digit
            reformatPhoneNumber()
        }
    }
    
    @IBAction private func backspaceButtonAction(_ sender: DialpadActionButton) {
        if phoneNumber.isEmpty {
            return
        }
        
        if let selectedRange = phoneNumberTextField.selectedTextRange {
            let cursorStartPos = phoneNumberTextField.offset(from: phoneNumberTextField.beginningOfDocument, to: selectedRange.start)
            let cursorEndPos = phoneNumberTextField.offset(from: phoneNumberTextField.beginningOfDocument, to: selectedRange.end)
            
            let rangePos: UITextPosition!
            
            if selectedRange.isEmpty {
                //  just caret, remove one char from the cursor position
                if cursorStartPos == 0 {
                    //  already at the beginning of the text, no more text to remove here
                    return
                }
                phoneNumber.replaceSubrange((phoneNumber.index(phoneNumber.startIndex, offsetBy: cursorStartPos-1))..<(phoneNumber.index(phoneNumber.startIndex, offsetBy: cursorEndPos)), with: "")
                
                rangePos = phoneNumberTextField.position(from: phoneNumberTextField.beginningOfDocument,
                                                         offset: cursorStartPos-1)
            } else {
                //  really some text selected, remove selected range of text
                
                phoneNumber.replaceSubrange((phoneNumber.index(phoneNumber.startIndex, offsetBy: cursorStartPos))..<(phoneNumber.index(phoneNumber.startIndex, offsetBy: cursorEndPos)), with: "")
                
                rangePos = phoneNumberTextField.position(from: phoneNumberTextField.beginningOfDocument,
                                                         offset: cursorStartPos)
            }
            
            reformatPhoneNumber()
            
            guard let cursorPos = rangePos else { return }
            phoneNumberTextField.selectedTextRange = phoneNumberTextField.textRange(from: cursorPos,
                                                                                    to: cursorPos)
        } else {
            phoneNumber.removeLast()
            reformatPhoneNumber()
        }
    }
    
    @IBAction private func callButtonAction(_ sender: DialpadActionButton) {
        delegate?.dialpadViewControllerDidTapCall(self, withPhoneNumber: rawPhoneNumber)
    }
    
}

//  MARK: - CustomSizedPresentable

extension DialpadViewController: CustomSizedPresentable {
    
    func customSize(withParentContainerSize containerSize: CGSize) -> CGSize {
        return Constants.sizeOniPad
    }
    
}