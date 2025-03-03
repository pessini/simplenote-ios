import Foundation
import UIKit
import SafariServices
import SwiftUI

// MARK: - SPOnboardingViewController
//
class SPOnboardingViewController: UIViewController, SPAuthenticationInterface {

    /// Message: Container View
    ///
    @IBOutlet var messageView: UIView!

    /// Message: Text Label
    ///
    @IBOutlet var messageLabel: UILabel!

    /// Top Image
    ///
    @IBOutlet var simplenoteImageView: UIImageView!

    /// Top Label
    ///
    @IBOutlet var simplenoteLabel: UILabel!

    /// Header
    ///
    @IBOutlet var headerLabel: UILabel!

    /// SignUp Button
    ///
    @IBOutlet var signUpButton: SPSquaredButton!

    /// Login Button
    ///
    @IBOutlet var loginButton: UIButton!

    /// Indicates if Extended Debugging has been enabled
    ///
    private var debugEnabled = false

    /// Simperium's Authenticator Instance
    ///
    var authenticator: SPAuthenticator?

    // MARK: - Overriden Properties

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var shouldAutorotate: Bool {
        return false
    }

    // MARK: - Overridden Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationItem()
        setupNavigationController()
        setupMessageView()
        setupImageView()
        setupLabels()
        setupActionButtons()
        startListeningToNotifications()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ensureNavigationBarIsHidden()
    }
}

// MARK: - Private
//
private extension SPOnboardingViewController {

    func setupNavigationItem() {
        navigationItem.backBarButtonItem = UIBarButtonItem(title: String(), style: .plain, target: nil, action: nil)
    }

    func setupNavigationController() {
        navigationController?.navigationBar.applyLightStyle()
        navigationController?.overrideUserInterfaceStyle = .light
    }

    func setupMessageView() {
        messageView.backgroundColor = .simplenoteRed50Color
        messageView.layer.cornerRadius = signUpButton.cornerRadius
    }

    func setupActionButtons() {
        signUpButton.setTitle(OnboardingStrings.signupText, for: .normal)
        signUpButton.setTitleColor(.white, for: .normal)
        signUpButton.backgroundColor = .simplenoteBlue50Color

        loginButton.setTitle(OnboardingStrings.loginText, for: .normal)
        loginButton.setTitleColor(.simplenoteBlue50Color, for: .normal)
    }

    func setupImageView() {
        simplenoteImageView.tintColor = .simplenoteBlue50Color
    }

    func setupLabels() {
        simplenoteLabel.text = OnboardingStrings.brandText
        simplenoteLabel.textColor = UIColor.simplenoteGray100Color
        simplenoteLabel.adjustsFontSizeToFitWidth = true
        simplenoteLabel.font = .preferredFont(for: .largeTitle, weight: .semibold)

        headerLabel.text = OnboardingStrings.headerText
        headerLabel.textColor = UIColor.simplenoteGray50Color
        headerLabel.adjustsFontSizeToFitWidth = true
        headerLabel.font = .preferredFont(forTextStyle: .title3)
    }

    func displayDebugMessage(enabled: Bool) {
        let text = enabled ? OnboardingStrings.debugEnabled : OnboardingStrings.debugDisabled
        let backgroundColor = enabled ? UIColor.simplenoteRed50Color : .simplenoteGray50Color

        display(message: text, backgroundColor: backgroundColor)
    }

    func display(message: String, backgroundColor: UIColor) {
        messageLabel.text = message
        messageView.isHidden = false
        messageView.alpha = UIKitConstants.alpha0_0
        messageView.backgroundColor = backgroundColor

        UIView.animate(withDuration: UIKitConstants.animationShortDuration) {
            self.messageView.alpha = UIKitConstants.alpha1_0
        }

        UIView.animate(withDuration: UIKitConstants.animationLongDuration, delay: UIKitConstants.animationDelayLong, options: [], animations: {
            self.messageView.alpha = UIKitConstants.alpha0_0
        }, completion: nil)
    }
}

// MARK: - Actions
//
private extension SPOnboardingViewController {

    @IBAction
    func signupWasPressed() {
        presentAuthenticationInterface(mode: .signup)
    }

    @IBAction
    func loginWasPressed() {
        presentAuthenticationInterface(mode: .requestLoginCode)
    }

    @IBAction
    func unlockDebugMode() {
        debugEnabled.toggle()
        displayDebugMessage(enabled: debugEnabled)
    }

    func ensureNavigationBarIsHidden() {
        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    func presentAuthenticationInterface(mode: AuthenticationMode) {
        guard let simperiumAuthenticator = authenticator else {
            fatalError("Missing Simperium Authenticator Instance")
        }

        let controller = SPAuthHandler(simperiumService: simperiumAuthenticator)
        let viewController = SPAuthViewController(controller: controller, mode: mode)
        viewController.debugEnabled = debugEnabled
        navigationController?.pushViewController(viewController, animated: true)
    }
}

// MARK: - Actions
//
private extension SPOnboardingViewController {

    func startListeningToNotifications() {
        let name = NSNotification.Name(rawValue: kSignInErrorNotificationName)
        
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleSignInError), name: name, object: nil)
        nc.addObserver(self, selector: #selector(handleMagicLinkAuthDidFail), name: .magicLinkAuthDidFail, object: nil)
    }

    @objc func handleSignInError(note: Notification) {
        let message = note.userInfo?[NSLocalizedDescriptionKey] as? String ?? SignInError.genericErrorText
        let alertController = UIAlertController(title: SignInError.title, message: message, preferredStyle: .alert)

        alertController.addDefaultActionWithTitle(SignInError.acceptButtonText)

        /// SFSafariViewController _might_ be onscreen
        presentedViewController?.dismiss(animated: true, completion: nil)
        present(alertController, animated: true, completion: nil)
    }
    
    @objc func handleMagicLinkAuthDidFail() {
        DispatchQueue.main.async {
            self.presentMagicLinkInvalidView()
        }
    }
}


// MARK: - Magic Link Helpers
//
private extension SPOnboardingViewController {

    /// Presents the Invalid Magic Link UI
    ///
    private func presentMagicLinkInvalidView() {
        var rootView = MagicLinkInvalidView()
        rootView.onPressRequestNewLink = { [weak self] in
            self?.presentAuthenticationInterfaceIfNeeded(mode: .requestLoginCode)
        }

        let hostingController = UIHostingController(rootView: rootView)
        hostingController.modalPresentationStyle = .formSheet
        hostingController.sheetPresentationController?.detents = [.medium()]

        let presenter = navigationController?.visibleViewController ?? self
        presenter.present(hostingController, animated: true)
    }
    
    /// Dismisses all of the presented ViewControllers, and pushes the Authentication UI with the specified mode.
    /// - Note: Whenever the required AuthUI is already onscreen, we'll do nothing
    ///
    func presentAuthenticationInterfaceIfNeeded(mode: AuthenticationMode) {
        navigationController?.popToRootViewController(animated: true)
        presentAuthenticationInterface(mode: mode)
    }
}


// MARK: - Private Types
//
private struct OnboardingStrings {
    static let debugDisabled = NSLocalizedString("Debug Disabled", comment: "Indicates that Extended Debugging has been disabled")
    static let debugEnabled = NSLocalizedString("🐞 Debug Enabled 🐞", comment: "Indicates that Extended Debugging has been enabled")
    static let brandText = NSLocalizedString("Simplenote", comment: "Our mighty brand!")
    static let signupText = NSLocalizedString("Sign Up", comment: "Signup Action")
    static let loginText = NSLocalizedString("Log In", comment: "Login Action")
    static let headerText = NSLocalizedString("The simplest way to keep notes.", comment: "Onboarding Header Text")
}

private struct SignInError {
    static let title = NSLocalizedString("Couldn't Sign In", comment: "Alert dialog title displayed on sign in error")
    static let genericErrorText = NSLocalizedString("An error was encountered while signing in.", comment: "Sign in error message")
    static let acceptButtonText = NSLocalizedString("OK", comment: "Dismisses an AlertController")
}
