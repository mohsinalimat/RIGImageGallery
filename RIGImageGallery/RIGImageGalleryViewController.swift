//
//  RIGImageGalleryViewController.swift
//  RIGPhotoViewer
//
//  Created by Michael Skiba on 2/8/16.
//  Copyright © 2016 Raizlabs. All rights reserved.
//

import UIKit

public class RIGImageGalleryViewController: UIPageViewController {

    public typealias GalleryPositionUpdateHandler = (gallery: RIGImageGalleryViewController, position: Int, total: Int) -> ()
    public typealias ActionButtonPressedHandler = (gallery: RIGImageGalleryViewController, item: RIGImageGalleryItem) -> ()
    public typealias GalleryEventHandler = RIGImageGalleryViewController -> ()
    public typealias IndexUpdateHandler = Int -> ()

    /// An optional closure to execute if the action button is tapped
    public var actionButtonHandler: ActionButtonPressedHandler?

    /// An optional closure to allow cutom trait collection change handling
    public var traitCollectionChangeHandler: GalleryEventHandler? {
        didSet {
            traitCollectionChangeHandler?(self)
        }
    }

    /// An optional closure to execute when the active index is updated
    public var indexUpdateHandler: IndexUpdateHandler?

    /// An optional closure to handle dismissing the gallery, if this is nil the view will call `dismissViewControllerAnimated(true, completion: nil)`, if this is non-nil, the view controller will not dismiss itself
    public var dismissHandler: GalleryEventHandler?

    /// An optional closure to handle updating the count text
    public var countUpdateHandler: GalleryPositionUpdateHandler? {
        didSet {
            updateCountText()
        }
    }

    /// The array of images to display. The view controller will automatically handle updates
    public var images: [RIGImageGalleryItem] = [] {
        didSet {
            handleImagesUpdate(oldValue: oldValue)
        }
    }

    /// The bar button item to use for the left side of the screen, `didSet` adds the correct target and action to ensure that `dismissHandler` is called when the button is pressed
    public var doneButton: UIBarButtonItem? = UIBarButtonItem(barButtonSystemItem: .Done, target: nil, action: nil) {
        didSet {
            configureDoneButton()
        }
    }

    /// The bar button item to use for the right side of the screen, `didSet` adds the correct target and action to ensure that `actionButtonHandler` is called
    public var actionButton: UIBarButtonItem? {
        didSet {
            configureActionButton()
        }
    }

    /// The index of the image currently bieng displayed
    public private(set) var currentImage: Int = 0 {
        didSet {
            indexUpdateHandler?(currentImage)
            updateCountText()
        }
    }

    private var navigationBarsHidden = false
    private var zoomRecognizer = UITapGestureRecognizer()
    private var toggleBarRecognizer = UITapGestureRecognizer()
    private var currentImageViewController: RIGSingleImageViewController? {
        return viewControllers?.first as? RIGSingleImageViewController
    }
    private var showDoneButton = true

    /**
     Changes the current image bieng displayed

     - parameter currentImage: The index of the image in `images` to display
     - parameter animated:     A flag that determines if this should be an animated or non-animated transition
     */
    public func setCurrentImage(currentImage: Int, animated: Bool) {
        guard currentImage >= 0 && currentImage < images.count else {
            self.currentImage = 0
            setViewControllers([UIViewController()], direction: .Forward, animated: animated, completion: nil)
            return
        }
        let newView = RIGSingleImageViewController(viewerItem: images[currentImage])
        let direction: UIPageViewControllerNavigationDirection
        if self.currentImage < currentImage {
            direction = .Forward
        }
        else {
            direction = .Reverse
        }
        self.currentImage = currentImage
        setViewControllers([newView], direction: direction, animated: animated, completion: nil)
    }

    /// The label used to display the current position in the array
    public let countLabel: UILabel = {
        let counter = UILabel()
        counter.textColor = .whiteColor()
        counter.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        return counter
    }()

    /**
     A convenience initializer to return a configured empty RIGImageGalleryViewController
     */
    public convenience init() {
        self.init(images: [])
    }

    /**
     A convenience initializer to return a configured RIGImageGalleryViewController with an array of images

     - parameter images: The images to use in the gallery
     */
    public convenience init(images: [RIGImageGalleryItem]) {
        self.init(transitionStyle: .Scroll, navigationOrientation: .Horizontal, options: [UIPageViewControllerOptionInterPageSpacingKey: 20])
        self.images = images
    }


    public override init(transitionStyle style: UIPageViewControllerTransitionStyle, navigationOrientation: UIPageViewControllerNavigationOrientation, options: [String : AnyObject]?) {
        super.init(transitionStyle: style, navigationOrientation: navigationOrientation, options: options)
        dataSource = self
        delegate = self
        automaticallyAdjustsScrollViewInsets = false
        handleImagesUpdate(oldValue: [])
        configureDoneButton()
        configureActionButton()
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        configureDoneButton()
        zoomRecognizer.addTarget(self, action: #selector(toggleZoom(_:)))
        zoomRecognizer.numberOfTapsRequired = 2
        zoomRecognizer.delegate = self
        toggleBarRecognizer.addTarget(self, action: #selector(toggleBarVisiblity(_:)))
        toggleBarRecognizer.delegate = self
        view.addGestureRecognizer(zoomRecognizer)
        view.addGestureRecognizer(toggleBarRecognizer)
        view.backgroundColor = UIColor.blackColor()
        countLabel.sizeToFit()

        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil),
            UIBarButtonItem(customView: countLabel),
            UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil),
        ]
    }

    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        updateBarStatus(animated: false)
        if currentImage < images.count {
            let photoPage =  RIGSingleImageViewController(viewerItem: images[currentImage])
            setViewControllers([photoPage], direction: .Forward, animated: false, completion: nil)
        }
    }

    public override func prefersStatusBarHidden() -> Bool {
        return navigationBarsHidden
    }

    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        currentImageViewController?.scrollView.baseInsets = scrollViewInset
    }

    public override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        traitCollectionChangeHandler?(self)
    }

}

extension RIGImageGalleryViewController: UIGestureRecognizerDelegate {

    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailByGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == zoomRecognizer {
            return otherGestureRecognizer == toggleBarRecognizer
        }
        return false
    }

    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOfGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == toggleBarRecognizer {
            return otherGestureRecognizer == zoomRecognizer
        }
        return false
    }

}

// MARK: - Actions

extension RIGImageGalleryViewController {

    func toggleBarVisiblity(recognizer: UITapGestureRecognizer) {
        navigationBarsHidden = !navigationBarsHidden
        updateBarStatus(animated: true)
    }

    func toggleZoom(recognizer: UITapGestureRecognizer) {
        currentImageViewController?.scrollView.toggleZoom()
    }

    func dismissPhotoView(sender: UIBarButtonItem) {
        if dismissHandler != nil {
            dismissHandler?(self)
        }
        else {
            dismissViewControllerAnimated(true, completion: nil)
        }
    }

    func performAction(sender: UIBarButtonItem) {
        if let item = currentImageViewController?.viewerItem {
            actionButtonHandler?(gallery: self, item: item)
        }
    }

}

extension RIGImageGalleryViewController: UIPageViewControllerDataSource {

    public func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {

        guard let index = indexOf(viewController: viewController)?.successor()
            where index < images.count else {
            return nil
        }
        let zoomView = RIGSingleImageViewController(viewerItem: images[index])
        return zoomView
    }

    public func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
        guard let index = indexOf(viewController: viewController)?.predecessor()
            where index >= 0 else {
                return nil
        }
        let zoomView = RIGSingleImageViewController(viewerItem: images[index])
        return zoomView
    }

}

extension RIGImageGalleryViewController: UIPageViewControllerDelegate {

    public func pageViewController(pageViewController: UIPageViewController, willTransitionToViewControllers pendingViewControllers: [UIViewController]) {
        for viewControl in pendingViewControllers {
            if let imageControl = viewControl as? RIGSingleImageViewController {
                imageControl.scrollView.baseInsets = scrollViewInset
            }
        }
    }

    public func pageViewController(pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if let index = viewControllers?.first.flatMap({ indexOf(viewController: $0) }) {
            currentImage = index
        }
    }
}

// MARK: - Private

private extension RIGImageGalleryViewController {

    func indexOf(viewController viewController: UIViewController, imagesArray: [RIGImageGalleryItem]? = nil) -> Int? {
        guard let item = (viewController as? RIGSingleImageViewController)?.viewerItem else {
            return nil
        }
        return (imagesArray ?? images).indexOf(item)
    }

    func configureDoneButton() {
        doneButton?.target = self
        doneButton?.action = #selector(dismissPhotoView(_:))
        navigationItem.leftBarButtonItem = doneButton
    }

    func configureActionButton() {
        actionButton?.target = self
        actionButton?.action = #selector(performAction(_:))
        navigationItem.rightBarButtonItem = actionButton
    }

    func updateBarStatus(animated animated: Bool) {
        navigationController?.setToolbarHidden(navigationBarsHidden, animated: animated)
        navigationController?.setNavigationBarHidden(navigationBarsHidden, animated: animated)
        setNeedsStatusBarAppearanceUpdate()
        UIView.animateWithDuration(0.15) {
            self.currentImageViewController?.scrollView.baseInsets = self.scrollViewInset
        }
    }

    func handleImagesUpdate(oldValue oldValue: [RIGImageGalleryItem]) {
        for viewController in childViewControllers {
            if let index = indexOf(viewController: viewController, imagesArray: oldValue),
                childView = viewController as? RIGSingleImageViewController where index < images.count {
                childView.viewerItem = images[index]
                childView.scrollView.baseInsets = scrollViewInset
            }
        }
        updateCountText()
    }

    private var scrollViewInset: UIEdgeInsets {
        loadViewIfNeeded()
        return UIEdgeInsets(top: topLayoutGuide.length, left: 0, bottom: bottomLayoutGuide.length, right: 0)
    }

    private func updateCountText() {
        if countUpdateHandler != nil {
            countUpdateHandler?(gallery: self, position: currentImage, total: images.count)
        }
        else {
            countLabel.text = nil
        }
        countLabel.sizeToFit()
    }

}
