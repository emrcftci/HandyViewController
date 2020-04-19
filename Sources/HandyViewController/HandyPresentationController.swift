//
//  HandyPresentationController.swift
//  HandyViewController
//
//  Created by Rasid Ramazanov on 19.04.2020.
//  Copyright © 2020 Mobven. All rights reserved.
//

import UIKit

final class HandyPresentationController: UIPresentationController {
    
    private let maxBackgroundOpacity: CGFloat = 0.5
    private var contentHeight: CGFloat!
    private var isSwipableAnimating: Bool = false
    
    private lazy var backgroundDimView: UIView! = {
        guard let container = containerView else { return nil }
        
        let view = UIView(frame: container.bounds)
        view.backgroundColor = UIColor.black.withAlphaComponent(maxBackgroundOpacity)
        view.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(didTapBackgroundDim(_:)))
        )
        
        return view
    }()
    
    private weak var topConstraint: NSLayoutConstraint?
    
    override init(presentedViewController: UIViewController,
                  presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController,
                   presenting: presentingViewController)
        
        presentedViewController.view.addGestureRecognizer(
            UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        )
        
        presentedViewController.view.translatesAutoresizingMaskIntoConstraints = false
        presentedViewController.view.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width).isActive = true
        presentedViewController.view.layer.cornerRadius = 10
        
        contentHeight = presentedViewController.view.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        ).height
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func updateTopDistance() {
        guard let container = containerView else { return }
        
        if topConstraint != nil {
            if topConstraint?.constant != topDistance {
                topConstraint?.constant = topDistance
                UIView.animate(withDuration: 0.3) {
                    container.layoutIfNeeded()
                }
            }
        } else {
            topConstraint = presentedViewController.view.topAnchor.constraint(
                equalTo: topAnchor, constant: topDistance
            )
            topConstraint?.isActive = true
        }
    }
    
    private var safeAreaBottomInset: CGFloat {
        if #available(iOS 11.0, *) {
            return presentingViewController.view.safeAreaInsets.bottom
        } else {
            return 0
        }
    }
    
    private var topAnchor: NSLayoutYAxisAnchor {
        if #available(iOS 11.0, *) {
            return containerView!.safeAreaLayoutGuide.topAnchor
        } else {
            return containerView!.topAnchor
        }
    }
    
    private var topDistance: CGFloat {
        let distance = UIScreen.main.bounds.height - contentHeight - safeAreaBottomInset
        if distance < 0 {
            return 0
        }
        return distance
    }
    
    // MARK: - Gestures
    @objc func didPan(_ panGesture: UIPanGestureRecognizer) {
        guard let view = panGesture.view, let contentView = view.superview,
            let presented = presentedView, let container = containerView else { return }
        let translation = panGesture.translation(in: contentView)
        
        if panGesture.state == .changed {
            guard translation.y > 0 else { return }
            animatePanChange(translationY: translation.y, contentView: presented, view: container)
        } else if panGesture.state == .ended {
            let velocity = panGesture.velocity(in: contentView)
            animatePanEnd(velocityCheck: velocity.y >= 1500, contentView: presented, view: container)
        }
    }
    
    private func animatePanChange(translationY: CGFloat, contentView: UIView, view: UIView) {
        contentView.frame.origin.y = view.frame.height - contentView.frame.height + translationY * 0.7 // speed
        let yVal = (UIScreen.main.bounds.height - contentView.frame.origin.y) / contentView.frame.height
        backgroundDimView.backgroundColor = UIColor(
            white: 0, alpha: yVal - maxBackgroundOpacity
        )
    }
    
    private func animatePanEnd(velocityCheck: Bool, contentView: UIView, view: UIView) {
        if velocityCheck {
            dismiss(contentView: contentView)
        } else if (UIScreen.main.bounds.height - contentView.frame.origin.y) < contentView.frame.height / 2 {
            dismiss(contentView: contentView)
        } else {
            isSwipableAnimating = true
            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.8,
                options: .curveEaseInOut, animations: { [ weak self ] in
                    guard let self = self else { return }
                    contentView.frame.origin = CGPoint(
                        x: 0, y: self.topDistance + self.safeAreaBottomInset
                    )
                    self.backgroundDimView.backgroundColor = UIColor(
                        white: 0, alpha: self.maxBackgroundOpacity
                    )
                    self.setSwipableAnimatingWithDelay()
                    
            })
        }
    }
    
    private func dismiss(contentView: UIView) {
        isSwipableAnimating = true
        UIView.animate(withDuration: 0.2, animations: {
            self.backgroundDimView.alpha = 0
            contentView.frame.origin = CGPoint(
                x: contentView.frame.origin.x,
                y: UIScreen.main.bounds.height
            )
        }, completion: { [ weak self ] (isCompleted) in
            if isCompleted {
                self?.presentedViewController.dismiss(animated: false, completion: nil)
            } else {
                self?.setSwipableAnimatingWithDelay()
            }
        })
    }
    
    private func setSwipableAnimatingWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { [ weak self] in
            self?.isSwipableAnimating = false
        })
    }
    
    @objc func didTapBackgroundDim(_ recognizer: UITapGestureRecognizer) {
        presentedViewController.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - UIPresentationController
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let container = containerView else { return .zero }
        
        updateTopDistance()
        
        return CGRect(x: 0, y: 0, width: container.bounds.width, height: UIScreen.main.bounds.height)
    }
    
    override func presentationTransitionWillBegin() {
        guard let container = containerView,
            let coordinator = presentingViewController.transitionCoordinator else { return }
        
        backgroundDimView.alpha = 0
        container.addSubview(backgroundDimView)
        backgroundDimView.addSubview(presentedViewController.view)
        
        coordinator.animate(alongsideTransition: { [ weak self ] _ in
            self?.backgroundDimView.alpha = 1
            }, completion: nil)
    }
    
    override func dismissalTransitionWillBegin() {
        guard let coordinator = presentingViewController.transitionCoordinator else { return }
        
        coordinator.animate(alongsideTransition: { [ weak self ] _ -> Void in
            self?.backgroundDimView.alpha = 0
            }, completion: nil)
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed {
            backgroundDimView.removeFromSuperview()
        }
    }
    
}

extension HandyPresentationController: HandyScrollViewDelegate {
    
    func handyScrollViewDidSetContentSize(_ scrollView: UIScrollView) {
        scrollView.layoutIfNeeded()
        let scrollViewContentHeight = scrollView.contentSize.height
        var scrollViewHeightConstant = scrollViewContentHeight
        if UIScreen.main.bounds.height - scrollViewContentHeight - contentHeight - safeAreaBottomInset < 0 {
            scrollViewHeightConstant = UIScreen.main.bounds.height - contentHeight - safeAreaBottomInset
        }
        scrollView.heightAnchor.constraint(equalToConstant: scrollViewHeightConstant).isActive = true
        contentHeight += scrollViewContentHeight
        updateTopDistance()
    }
    
    func handyScrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let presented = presentedView, let container = containerView else { return }
        let offset = scrollView.contentOffset
        guard !isSwipableAnimating && offset.y < 0 else { return }
        animatePanChange(translationY: -offset.y, contentView: presented, view: container)
    }
    
    func handyScrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint) {
        guard let presented = presentedView, let container = containerView else { return }
        guard scrollView.contentOffset.y < 0 else { return }
        if scrollView.contentOffset.y < -130 {
            dismiss(contentView: presented)
        } else {
            animatePanEnd(velocityCheck: velocity.y < -1.6, contentView: presented, view: container)
        }
    }
    
}
