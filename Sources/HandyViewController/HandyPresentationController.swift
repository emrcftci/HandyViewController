//
//  HandyPresentationController.swift
//  HandyViewController
//
//  Created by Rasid Ramazanov on 19.04.2020.
//  Copyright © 2020 Mobven. All rights reserved.
//

import UIKit

final class HandyPresentationController: UIPresentationController {
    
    private var contentMode: ContentMode = .contentSize
    
    private let maxBackgroundOpacity: CGFloat = 0.5
    private var contentHeight: CGFloat!
    private var scrollViewHeight: CGFloat = 0
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
    private weak var scrollViewHeightConstraint: NSLayoutConstraint?
    
    required init(presentedViewController: UIViewController,
                  presenting presentingViewController: UIViewController?, contentMode: ContentMode) {
        super.init(presentedViewController: presentedViewController,
                   presenting: presentingViewController)
        self.contentMode = contentMode
        
        presentedViewController.view.addGestureRecognizer(
            UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        )
        
        presentedViewController.view.layer.cornerRadius = 10
        
        if contentMode == .fullScreen {
            contentHeight = UIScreen.main.bounds.height - 44 // TODO: calculate
        } else {
            presentedViewController.view.translatesAutoresizingMaskIntoConstraints = false
            presentedViewController.view.widthAnchor.constraint(
                equalToConstant: UIScreen.main.bounds.width
            ).isActive = true
            contentHeight = presentedViewController.view.systemLayoutSizeFitting(
                UIView.layoutFittingCompressedSize
            ).height
        }
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
    
    private var minimumTopDistance: CGFloat {
        return safeAreaTopInset
    }
    
    private var safeAreaBottomInset: CGFloat {
        if #available(iOS 11.0, *) {
            return presentingViewController.view.safeAreaInsets.bottom
        } else {
            return 0
        }
    }
    
    private var safeAreaTopInset: CGFloat {
        if #available(iOS 11.0, *) {
            return presentingViewController.view.safeAreaInsets.top
        } else {
            return 20
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
        guard contentMode == .contentSize else {
            return minimumTopDistance
        }
        let distance = UIScreen.main.bounds.height - contentHeight - scrollViewHeight + minimumTopDistance
        if distance < 0 {
            return minimumTopDistance
        }
        return distance
    }
    
    // MARK: - Gestures
    @objc func didPan(_ panGesture: UIPanGestureRecognizer) {
        guard let view = panGesture.view, let contentView = view.superview else { return }
        let translation = panGesture.translation(in: contentView)
        
        if panGesture.state == .changed {
            guard translation.y > 0 else { return }
            animatePanChange(translationY: translation.y)
        } else if panGesture.state == .ended {
            let velocity = panGesture.velocity(in: contentView)
            animatePanEnd(velocityCheck: velocity.y >= 1500)
        }
    }
    
    private func animatePanChange(translationY: CGFloat) {
        guard let presented = presentedView else { return }
        presented.frame.origin.y = topDistance - self.safeAreaBottomInset + translationY * 0.7 // speed
        let yVal = (UIScreen.main.bounds.height - presented.frame.origin.y) / presented.frame.height
        backgroundDimView.backgroundColor = UIColor(
            white: 0, alpha: yVal - maxBackgroundOpacity
        )
    }
    
    private func animatePanEnd(velocityCheck: Bool) {
        guard let presented = presentedView else { return }
        if velocityCheck {
            dismiss()
        } else if (UIScreen.main.bounds.height - presented.frame.origin.y + minimumTopDistance) <
            presented.frame.height / 2 {
            dismiss()
        } else {
            isSwipableAnimating = true
            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.8,
                options: .curveEaseInOut, animations: { [ weak self ] in
                    guard let self = self else { return }
                    guard let presented = self.presentedView else { return }
                    presented.frame.origin = CGPoint(
                        x: 0, y: self.topDistance - self.safeAreaBottomInset
                    )
                    self.backgroundDimView.backgroundColor = UIColor(
                        white: 0, alpha: self.maxBackgroundOpacity
                    )
                    self.setSwipableAnimatingWithDelay()
            })
        }
    }
    
    private func dismiss() {
        isSwipableAnimating = true
        UIView.animate(withDuration: 0.2, animations: { [ weak self ] in
            guard let self = self else { return }
            guard let presented = self.presentedView else { return }
            self.backgroundDimView.alpha = 0
            presented.frame.origin = CGPoint(
                x: presented.frame.origin.x,
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: { [ weak self] in
            self?.isSwipableAnimating = false
        })
    }
    
    @objc func didTapBackgroundDim(_ recognizer: UITapGestureRecognizer) {
        presentedViewController.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - UIPresentationController
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let container = containerView else { return .zero }
        
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
            self?.updateTopDistance()
            }, completion: { [ weak self ] _ in
                self?.animatePanEnd(velocityCheck: false)
        })
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
        scrollView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        setScrollViewHeight(scrollView)
    }
    
    func handyScrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset
        guard !isSwipableAnimating && offset.y < 0 else { return }
        animatePanChange(translationY: -offset.y)
    }
    
    func handyScrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint) {
        guard scrollView.contentOffset.y < 0 else { return }
        if scrollView.contentOffset.y < -130 {
            dismiss()
        } else {
            animatePanEnd(velocityCheck: velocity.y < -1.6)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == "contentSize" {
            if let scrollView = object as? UIScrollView {
                setScrollViewHeight(scrollView)
            }
        }
    }
    
    private func setScrollViewHeight(_ scrollView: UIScrollView) {
        let scrollViewContentHeight = scrollView.contentSize.height
        scrollViewHeight = 0
        
        if contentHeight + scrollViewContentHeight + minimumTopDistance > UIScreen.main.bounds.height {
            scrollViewHeight = UIScreen.main.bounds.height - contentHeight - minimumTopDistance
        } else {
            scrollViewHeight = scrollViewContentHeight
        }
        
        if scrollViewHeightConstraint == nil {
            scrollViewHeightConstraint = scrollView.heightAnchor.constraint(
                equalToConstant: scrollViewHeight
            )
            scrollViewHeightConstraint?.isActive = true
            updateTopDistance()
        } else {
            scrollViewHeightConstraint?.constant = scrollViewHeight
            topConstraint?.constant = topDistance
            UIView.animate(withDuration: 0.15) { [ weak self ] in
                self?.containerView?.layoutIfNeeded()
            }
            animatePanEnd(velocityCheck: false)
        }
    }
    
}
