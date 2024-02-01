//
//  PictureInPictureController
//

import AVKit
@available(tvOS 14.0, *)
public class MoonPictureInPictureController: AVPictureInPictureController {
    private static var pipController: MoonPictureInPictureController?
    private var originalViewController: UIViewController?
    private weak var view: MoonPlayerLayer?
    private weak var viewController: UIViewController?
    private weak var presentingViewController: UIViewController?
    #if canImport(UIKit)
    private weak var navigationController: UINavigationController?
    #endif

    func stop(restoreUserInterface: Bool) {
        stopPictureInPicture()
        delegate = nil
        guard MoonOptions.isPipPopViewController else {
            return
        }
        MoonPictureInPictureController.pipController = nil
        if restoreUserInterface {
            #if canImport(UIKit)
            if let viewController, let originalViewController {
                if let nav = viewController as? UINavigationController,
                   nav.viewControllers.isEmpty || (nav.viewControllers.count == 1 && nav.viewControllers[0] != originalViewController)
                {
                    nav.viewControllers = [originalViewController]
                }
                if let navigationController {
                    var viewControllers = navigationController.viewControllers
                    if viewControllers.count > 1, let last = viewControllers.last, type(of: last) == type(of: viewController) {
                        viewControllers[viewControllers.count - 1] = viewController
                        navigationController.viewControllers = viewControllers
                    }
                    if viewControllers.firstIndex(of: viewController) == nil {
                        navigationController.pushViewController(viewController, animated: true)
                    }
                } else {
                    presentingViewController?.present(originalViewController, animated: true)
                }
            }
            #endif
            view?.player.isMuted = false
            view?.play()
        }

        originalViewController = nil
    }

    func start(view: MoonPlayerLayer) {
        startPictureInPicture()
        delegate = view
        guard MoonOptions.isPipPopViewController else {
            return
        }
        self.view = view
        #if canImport(UIKit)
        if let viewController = view.viewController {
            originalViewController = viewController
            if let navigationController = viewController.navigationController, navigationController.viewControllers.count == 1 {
                self.viewController = navigationController
            } else {
                self.viewController = viewController
            }
            navigationController = self.viewController?.navigationController
            if let pre = MoonPictureInPictureController.pipController {
                view.player.isMuted = true
                pre.view?.isPipActive = false
            } else {
                if let navigationController {
                    navigationController.popViewController(animated: true)
                    #if os(iOS)
                    if navigationController.tabBarController != nil, navigationController.viewControllers.count == 1 {
                        DispatchQueue.main.async { [weak self] in
                            self?.navigationController?.setToolbarHidden(false, animated: true)
                        }
                    }
                    #endif
                } else {
                    presentingViewController = originalViewController?.presentingViewController
                    originalViewController?.dismiss(animated: true)
                }
            }
        }
        #endif
        MoonPictureInPictureController.pipController = self
    }

    static func mute() {
        pipController?.view?.player.isMuted = true
    }
}
