//
//  ViewController.swift
//  TestCard
//
//  Created by John on 7/14/21.
//  Copyright © 2021 Abraham Shenghur. All rights reserved.
//

import UIKit
//import CardSlider

struct Movie: CardSliderItem {
    let image: UIImage
    let rating: Int?
    let title: String
    let subtitle: String?
    let description: String?
}

class ViewController: UIViewController {
    let movies = [
        Movie(image: #imageLiteral(resourceName: "trueCar"), rating: nil, title: "TrueCar", subtitle: nil, description: nil),
        Movie(image: #imageLiteral(resourceName: "carGurus"), rating: nil, title: "CarGurus", subtitle: nil, description: nil),
        Movie(image: #imageLiteral(resourceName: "carsDotCom"), rating: nil, title: "Cars.com", subtitle: nil, description: nil),
        Movie(image: #imageLiteral(resourceName: "autotrader"), rating: nil, title: "Autotrader", subtitle: nil, description: nil),
        Movie(image: #imageLiteral(resourceName: "craigslist"), rating: nil, title: "Craigslist", subtitle: nil, description: nil),
    ]
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let cardSlider = CardSliderViewController.with(dataSource: self)
        cardSlider.title = "Websites"
        cardSlider.modalPresentationStyle = .fullScreen
        present(cardSlider, animated: true, completion: nil)
    }
}

extension ViewController: CardSliderDataSource {
    func item(for index: Int) -> CardSliderItem {
        return movies[index]
    }
    
    func numberOfItems() -> Int {
        return movies.count
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                      CardSlider
////////////////////////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////
// Public - CardSliderViewController:
/////////////////////////////////////

/// Model for a card.
public protocol CardSliderItem {
    /// The image for the card.
    var image: UIImage { get }
    
    /// Rating from 0 to 5. If set to nil, rating view will not be displayed for the card.
    var rating: Int? { get }
    
    /// Will be displayed in the title view below the card.
    var title: String { get }
    
    /// Will be displayed under the main title for the card.
    var subtitle: String? { get }
    
    /// Will be displayed as scrollable text in the expanded view.
    var description: String? { get }
}

public protocol CardSliderDataSource: class {
    /// CardSliderItem for the card at given index, counting from the top.
    func item(for index: Int) -> CardSliderItem
    
    /// Total number of cards.
    func numberOfItems() -> Int
}

/// A view controller displaying a slider of cards, represented by CardSliderItems.
///
/// Needs CardSliderDataSource to show data.
import SafariServices

open class CardSliderViewController: UIViewController, UIScrollViewDelegate, SFSafariViewControllerDelegate {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var collectionView: UICollectionView!
    @IBOutlet private var headerView: UIView!
    @IBOutlet private var cardTitleContainer: UIView!
    @IBOutlet private var cardTitleView: CardTitleView!
    @IBOutlet private var ratingView: RatingView!
    @IBOutlet private var descriptionLabel: UILabel!
    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var scrollStack: UIStackView!
    @IBOutlet private var scrollPlaceholderView: UIView!
    private weak var cardSnapshot: UIView?
    private weak var cardTitleSnapshot: UIView?
    private weak var openCardCell: UICollectionViewCell?
    private var animator: UIViewPropertyAnimator?
    private let cellID = "CardCell"
    
    
    /// Instantiate CardSliderViewController.
    ///
    /// - Parameter dataSource: CardSliderDataSource
    
    public static func with(dataSource: CardSliderDataSource) -> CardSliderViewController {
        
        if let path = Bundle(for: self).path(forResource: "CardSlider", ofType: "bundle"),
            let bundle = Bundle(path: path),
            let controller = UIStoryboard(name: "Main", bundle: bundle).instantiateInitialViewController() as? CardSliderViewController {
            
            controller.dataSource = dataSource
            return controller
        }
        
        if let controller = UIStoryboard(name: "Main", bundle: Bundle(for: self)).instantiateInitialViewController() as? CardSliderViewController {
            
            controller.dataSource = dataSource
            return controller
        }
        
        fatalError("Failed to initialize CardSliderViewController")
    }
    
    public weak var dataSource: CardSliderDataSource!
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delaysContentTouches = false
    }
    
    open override var title: String? {
        didSet {
            titleLabel?.text = title
        }
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        titleLabel.text = title
        self.collectionView.collectionViewLayout.invalidateLayout()
        self.collectionView.layoutIfNeeded()
        self.prepareFirstCard()
    }
    
    private func prepareFirstCard() {
        guard let layout = collectionView.collectionViewLayout as? CardsLayout else { return }
        let item = dataSource.item(for: dataSource.numberOfItems() - layout.currentPage - 1)
        cardTitleView.set(title: CardTitle(title: item.title, subtitle: item.subtitle))
    }
    
    // MARK: - Detailed view animations
    
    /// The amount in points by which the card image will extend over the top and the sides in the expanded view.
    public var cardOversize: CGFloat = 15
    /// The amount in points by which the scroll must be pulled down for the expanded view to close.
    public var cardDismissingThreshold: CGFloat = 70
    
    private var isShowingDescription = false
    private var visibleDescriptionHeight: CGFloat {
        guard let titleSnapshot = cardTitleSnapshot else { return 0 }
        return scrollView.bounds.height - scrollPlaceholderView.bounds.height - titleSnapshot.bounds.height - scrollView.safeAreaInsets.top
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == collectionView {
            cardSnapshot?.removeFromSuperview()
            openCardCell?.isHidden = false
            return
        }
        
        guard scrollView == self.scrollView, isShowingDescription else { return }
        guard let cardSnapshot = cardSnapshot else { return }
        
        if scrollView.contentOffset.y < -cardDismissingThreshold {
            self.hideCardDescription()
        }
            
        else if scrollView.contentOffset.y < -scrollView.safeAreaInsets.top {
            guard let cell = openCardCell else { return }
            if animator == nil {
                animator = UIViewPropertyAnimator(duration: 1.0, dampingRatio: 0.7) {
                    cardSnapshot.frame = self.view.convert(cell.frame, from: cell.superview!)
                }
            }
            animator?.fractionComplete = abs((scrollView.contentOffset.y + scrollView.safeAreaInsets.top) / visibleDescriptionHeight)
        }
            
        else {
            resetCardAnimation()
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == collectionView else { return }
        guard let layout = collectionView.collectionViewLayout as? CardsLayout else { return }
        let item = dataSource.item(for: dataSource.numberOfItems() - layout.currentPage - 1)
        cardTitleView.set(title: CardTitle(title: item.title, subtitle: item.subtitle))
    }
    
    private func resetCardAnimation() {
        guard let snapshot = cardSnapshot else { return }
        animator?.stopAnimation(false)
        animator?.finishAnimation(at: .current)
        animator = nil
        let ratio = snapshot.bounds.width / snapshot.bounds.height
        let width = self.view.bounds.width + self.cardOversize * 2
        let height = width / ratio
        let offset = min(-cardOversize, -pow(scrollView.contentOffset.y - cardOversize, 0.9))
        snapshot.frame = CGRect(x: -self.cardOversize, y: -self.cardOversize + offset, width: width, height: height)
    }
    
    private func showCardDescription(for indexPath: IndexPath) {
        if indexPath.row == 0 {
            let url = URL(string: "https://inlandempire.craigslist.org/search/cta?query=Acura+cl&purveyor-input=all")
            let safariVC = SFSafariViewController(url: url!)
            safariVC.delegate = self
            
            self.present(safariVC, animated: true)
        } else if indexPath.row == 1 {
            let url = URL(string: "https://www.autotrader.com/cars-for-sale/all-cars?zip=92570&makeCodeList=ACURA&modelCodeList=ACUCL")
            let safariVC = SFSafariViewController(url: url!)
            safariVC.delegate = self
            
            self.present(safariVC, animated: true)
        } else if indexPath.row == 2 {
            let url = URL(string: "https://www.cars.com/for-sale/searchresults.action/?mdId=20773&mkId=20001&rd=20&searchSource=QUICK_FORM&stkTypId=28881&zc=92571")
            let safariVC = SFSafariViewController(url: url!)
            safariVC.delegate = self
            
            self.present(safariVC, animated: true)
        } else if indexPath.row == 3 {
            let url = URL(string: "https://www.cargurus.com/Cars/inventorylisting/viewDetailsFilterViewInventoryListing.action?zip=92501&showNegotiable=true&sortDir=DESC&sourceContext=untrackedWithinSite_false_0&distance=50000&sortType=NEWEST_CAR_YEAR&entitySelectingHelper.selectedEntity=d191")
            let safariVC = SFSafariViewController(url: url!)
            safariVC.delegate = self
            
            self.present(safariVC, animated: true)
        } else if indexPath.row == 4 {
            let url = URL(string: "https://www.truecar.com/used-cars-for-sale/listings/acura/cl/location-perris-ca/?searchRadius=5000&sort[]=year_asc")
            let safariVC = SFSafariViewController(url: url!)
            safariVC.delegate = self
            
            self.present(safariVC, animated: true)
        }
        
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        openCardCell = cell
        
        let cardTitleSnapshot = cardTitleContainer.renderSnapshot()
        self.cardTitleSnapshot = cardTitleSnapshot
        
        let cardSnapshot = cell.renderSnapshot()
        self.cardSnapshot = cardSnapshot
        
        descriptionLabel.text = dataSource.item(for: dataSource.numberOfItems() - indexPath.item - 1).description
        scrollStack.insertArrangedSubview(cardTitleSnapshot, at: 1)
        scrollView.isHidden = false
        
        let cellFrame = view.convert(cell.frame, from: cell.superview!)
        cardSnapshot.frame = cellFrame
        view.insertSubview(cardSnapshot, belowSubview: cardTitleContainer)
        scrollView.center.y += visibleDescriptionHeight
        
        UIView.animate(withDuration: 0.3, animations: {
            self.scrollView.center.y -= self.visibleDescriptionHeight
            self.resetCardAnimation()
        }) { _ in
            self.isShowingDescription = true
        }
        statusbarStyle = .lightContent
    }
    
    private func hideCardDescription() {
        guard !scrollView.isHidden, isShowingDescription else { return }
        isShowingDescription = false
        
        let scrollviewSnapshot = scrollView.snapshotView(afterScreenUpdates: false)!
        view.addSubview(scrollviewSnapshot)
        scrollviewSnapshot.frame = scrollView.frame
        let offset = visibleDescriptionHeight + scrollView.contentOffset.y + scrollView.safeAreaInsets.top
        scrollView.isHidden = true
        
        cardTitleContainer.isHidden = true
        UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.9, animations: {
            scrollviewSnapshot.center.y += offset
        }) { _ in
            scrollviewSnapshot.removeFromSuperview()
            self.scrollView.isHidden = true
            self.cardTitleContainer.isHidden = false
            self.cardTitleSnapshot?.removeFromSuperview()
        }
        
        openCardCell?.isHidden = true
        animator?.addCompletion({ _ in
            self.cardSnapshot?.removeFromSuperview()
            self.openCardCell?.isHidden = false
            self.animator = nil
        })
        animator?.startAnimation()
        statusbarStyle = .default
    }
    
    // MARK: - View Controller
    
    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    private var statusbarStyle: UIStatusBarStyle = .default {
        didSet {
            UIView.animate(withDuration: 0.3) {
                self.setNeedsStatusBarAppearanceUpdate()
            }
        }
    }
    
    override open var preferredStatusBarStyle: UIStatusBarStyle {
        return statusbarStyle
    }
}

// MARK: - Collection View

extension CardSliderViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.numberOfItems()
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: cellID, for: indexPath)
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? CardSliderCell else { return }
        let item = dataSource.item(for: dataSource.numberOfItems() - indexPath.item - 1)
        cell.imageView.image = item.image
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if CGFloat(indexPath.item) != collectionView.contentOffset.x / collectionView.bounds.width {
            collectionView.setContentOffset(CGPoint(x: collectionView.bounds.width * CGFloat(indexPath.item), y: 0), animated: true)
            return
        }
        
        showCardDescription(for: indexPath)
    }
}

// MARK: - CardsLayoutDelegate

extension CardSliderViewController: CardsLayoutDelegate {
    func transition(between currentIndex: Int, and nextIndex: Int, progress: CGFloat) {
        let currentItem = dataSource.item(for: dataSource.numberOfItems() - currentIndex - 1)
        let nextItem = dataSource.item(for: dataSource.numberOfItems() - nextIndex - 1)
        
        ratingView.rating = (progress > 0.5 ? nextItem : currentItem).rating
        let currentTitle = CardTitle(title: currentItem.title, subtitle: currentItem.subtitle)
        let nextTitle = CardTitle(title: nextItem.title, subtitle: nextItem.subtitle)
        cardTitleView.transition(between: currentTitle, secondTitle: nextTitle, progress: progress)
    }
}

private final class BundleToken {}


///////////////////////////
// Public - CardSliderCell
///////////////////////////

class CardSliderCell: UICollectionViewCell, ParallaxCardCell {
    open var cornerRadius: CGFloat = 10 { didSet { update() }}
    open var shadowOpacity: CGFloat = 0.3 { didSet { update() }}
    open var shadowColor: UIColor = .black { didSet { update() }}
    open var shadowRadius: CGFloat = 20 { didSet { update() }}
    open var shadowOffset: CGSize = CGSize(width: 0, height: 20) { didSet { update() }}
    
    /// Maximum image zoom during scrolling
    open var maxZoom: CGFloat {
        return 1.3
    }
    
    private var zoom: CGFloat = 0
    private var shadeOpacity: CGFloat = 0
    
    open var imageView = UIImageView()
    open var shadeView = UIView()
    open var highlightView = UIView()
    
    private var latestBounds: CGRect?
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        imageView.contentMode = .scaleAspectFill
        contentView.addSubview(imageView)
        shadeView.backgroundColor = .white
        contentView.addSubview(shadeView)
        highlightView.backgroundColor = .black
        highlightView.alpha = 0
        contentView.addSubview(highlightView)
    }
    
    open func setShadeOpacity(progress: CGFloat) {
        shadeOpacity = progress
        updateShade()
        updateShadow()
    }
    
    open func setZoom(progress: CGFloat) {
        zoom = progress
        updateImagePosition()
    }
    
    override open var bounds: CGRect {
        didSet {
            guard latestBounds != bounds else { return }
            latestBounds = bounds
            highlightView.frame = bounds
            update()
        }
    }
    
    private func update() {
        updateImagePosition()
        updateShade()
        updateMask()
        updateShadow()
    }
    
    open func updateShade() {
        shadeView.frame = bounds.insetBy(dx: -2, dy: -2) // to avoid edge flickering during scaling
        shadeView.alpha = 1 - shadeOpacity
    }
    
    open func updateImagePosition() {
        zoom = min(zoom, 1)
        imageView.frame = bounds.applying(CGAffineTransform(scaleX: 1 + (1 - zoom), y: 1 + (1 - zoom)))
        imageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    open func updateMask() {
        let mask = CAShapeLayer()
        let path =  UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        mask.path = path
        contentView.layer.mask = mask
    }
    
    open override var isHighlighted: Bool {
        get {
            return super.isHighlighted
        }
        set {
            super.isHighlighted = newValue
            UIView.animate(withDuration: newValue ? 0 : 0.3) {
                self.highlightView.alpha = newValue ? 0.2 : 0
            }
        }
    }
    
    open func updateShadow() {
        if layer.shadowPath == nil {
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
            layer.shadowColor = shadowColor.cgColor
            layer.shadowRadius = shadowRadius
            layer.shadowOffset = shadowOffset
            layer.masksToBounds = false
        }
        layer.shadowOpacity = Float(shadowOpacity * shadeOpacity)
    }
    
    open override func prepareForReuse() {
        super.prepareForReuse()
        setShadeOpacity(progress: 0)
    }
}


/////////////////////////
// Public - CardTitleView
/////////////////////////

struct CardTitle: Equatable {
    let title: String?
    let subtitle: String?
}

class CardTitleView: UIView {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!
    private var firstTitle: CardTitle?
    private var secondTitle: CardTitle?
    private weak var firstSnapshot: UIView?
    private weak var secondSnapshot: UIView?
    private var animator: UIViewPropertyAnimator?
    
    private func reset() {
        self.firstSnapshot?.removeFromSuperview()
        self.secondSnapshot?.removeFromSuperview()
        firstTitle = nil
        secondTitle = nil
        titleLabel.alpha = 1
        subtitleLabel.alpha = 1
    }
    
    func set(title: CardTitle) {
        reset()
        titleLabel.text = title.title
        subtitleLabel.text = title.subtitle
    }
    
    func transition(between firstTitle: CardTitle, secondTitle: CardTitle, progress: CGFloat) {
        guard firstTitle != self.firstTitle, secondTitle != self.secondTitle else {
            animator?.fractionComplete = progress
            return
        }
        
        reset()
        
        self.firstTitle = firstTitle
        self.secondTitle = secondTitle
        
        titleLabel.text = firstTitle.title ?? " " // retaining vertical space when there's no text
        subtitleLabel.text = firstTitle.subtitle ?? " "
        layoutIfNeeded()
        let firstSnapshot = renderSnapshot()
        self.firstSnapshot = firstSnapshot
        
        titleLabel.text = secondTitle.title ?? " "
        subtitleLabel.text = secondTitle.subtitle ?? " "
        layoutIfNeeded()
        let secondSnapshot = renderSnapshot()
        self.secondSnapshot = secondSnapshot
        
        addSubview(firstSnapshot)
        addSubview(secondSnapshot)
        
        firstSnapshot.center = CGPoint(x: bounds.midX, y: bounds.midY)
        secondSnapshot.center = CGPoint(x: bounds.midX, y: bounds.maxY)
        secondSnapshot.alpha = 0
        titleLabel.alpha = 0
        subtitleLabel.alpha = 0
        
        animator?.stopAnimation(true)
        animator = UIViewPropertyAnimator(duration: 1, curve: .linear, animations: { [bounds] in
            firstSnapshot.center = CGPoint(x: bounds.midX, y: bounds.minY)
            firstSnapshot.alpha = 0
            secondSnapshot.center = CGPoint(x: bounds.midX, y: bounds.midY)
            secondSnapshot.alpha = 1
        })
        animator?.fractionComplete = progress
    }
}





////////////////////////
// Private - CardLayout
////////////////////////

protocol ParallaxCardCell {
    func setShadeOpacity(progress: CGFloat)
    func setZoom(progress: CGFloat)
}

@objc protocol CardsLayoutDelegate: class {
    func transition(between currentIndex: Int, and nextIndex: Int, progress: CGFloat)
}

class CardsLayout: UICollectionViewLayout {
    @IBOutlet private weak var delegate: CardsLayoutDelegate!
    
    public var itemSize: CGSize = .zero {
        didSet { invalidateLayout() }
    }
    
    ///
    public var minScale: CGFloat = 0.8 {
        didSet { invalidateLayout() }
    }
    public var spacing: CGFloat = 35 {
        didSet { invalidateLayout() }
    }
    public var visibleItemsCount: Int = 3 {
        didSet { invalidateLayout() }
    }
    
    override open var collectionView: UICollectionView {
        return super.collectionView!
    }
    
    override open func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    var itemsCount: CGFloat {
        return CGFloat(collectionView.numberOfItems(inSection: 0))
    }
    
    var collectionBounds: CGRect {
        return collectionView.bounds
    }
    
    var contentOffset: CGPoint {
        return collectionView.contentOffset
    }
    
    var currentPage: Int {
        return max(Int(contentOffset.x) / Int(collectionBounds.width), 0)
    }
    
    override open var collectionViewContentSize: CGSize {
        return CGSize(width: collectionBounds.width * itemsCount, height: collectionBounds.height)
    }
    
    private var didInitialSetup = false
    
    open override func prepare() {
        guard !didInitialSetup else { return }
        didInitialSetup = true
        
        let width = collectionBounds.width * 0.7
        let height = width / 0.6
        itemSize = CGSize(width: width, height: height)
        
        collectionView.setContentOffset(CGPoint(x: collectionViewContentSize.width - collectionBounds.width, y: 0), animated: false)
    }
    
    override open func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let itemsCount = collectionView.numberOfItems(inSection: 0)
        guard itemsCount > 0 else { return nil }
        
        let minVisibleIndex = max(currentPage - visibleItemsCount + 1, 0)
        let offset = CGFloat(Int(contentOffset.x) % Int(collectionBounds.width))
        let offsetProgress = CGFloat(offset) / collectionBounds.width
        let maxVisibleIndex = max(min(itemsCount - 1, currentPage + 1), minVisibleIndex)
        
        let attributes: [UICollectionViewLayoutAttributes] = (minVisibleIndex...maxVisibleIndex).map {
            let indexPath = IndexPath(item: $0, section: 0)
            return layoutAttributes(for: indexPath, currentPage, offset, offsetProgress)
        }
        return attributes
    }
    
    private func layoutAttributes(for indexPath: IndexPath, _ pageIndex: Int, _ offset: CGFloat, _ offsetProgress: CGFloat) -> UICollectionViewLayoutAttributes {
        let attributes = UICollectionViewLayoutAttributes(forCellWith:indexPath)
        let visibleIndex = max(indexPath.item - pageIndex + visibleItemsCount, 0)
        
        if visibleIndex == visibleItemsCount + 1 {
            delegate?.transition(between: indexPath.item, and: max(indexPath.item - 1, 0), progress: 1 - offsetProgress)
        }
        
        attributes.size = itemSize
        let topCardMidX = contentOffset.x + collectionBounds.width - itemSize.width / 2 - spacing / 2
        attributes.center = CGPoint(x: topCardMidX - spacing * CGFloat(visibleItemsCount - visibleIndex), y: collectionBounds.midY)
        attributes.zIndex = visibleIndex
        let scale = parallaxProgress(for: visibleIndex, offsetProgress, minScale)
        attributes.transform = CGAffineTransform(scaleX: scale, y: scale)
        
        let cell = collectionView.cellForItem(at: indexPath) as? ParallaxCardCell
        cell?.setZoom(progress: scale)
        let progress = parallaxProgress(for: visibleIndex, offsetProgress)
        cell?.setShadeOpacity(progress: progress)
        
        switch visibleIndex {
        case visibleItemsCount + 1:
            attributes.center.x += collectionBounds.width - offset - spacing
            cell?.setShadeOpacity(progress: 1)
        default:
            attributes.center.x -= spacing * offsetProgress
        }
        
        return attributes
    }
    
    private func parallaxProgress(for visibleIndex: Int, _ offsetProgress: CGFloat, _ minimum: CGFloat = 0) -> CGFloat {
        let step = (1.0 - minimum) / CGFloat(visibleItemsCount)
        return 1.0 - CGFloat(visibleItemsCount - visibleIndex) * step - step * offsetProgress
    }
}



////////////////////////
// Private - Extensions
////////////////////////

extension UIView {
    func renderSnapshot() -> UIView {
        let shadowOpacity = layer.shadowOpacity
        layer.shadowOpacity = 0 // avoid capturing shadow bits in bounds
        
        let snapshot = UIImageView(image: UIGraphicsImageRenderer(bounds: bounds).image { context in
            layer.render(in: context.cgContext)
        })
        layer.shadowOpacity = shadowOpacity
        
        if let shadowPath = layer.shadowPath {
            snapshot.layer.shadowPath = shadowPath
            snapshot.layer.shadowColor = layer.shadowColor
            snapshot.layer.shadowOffset = layer.shadowOffset
            snapshot.layer.shadowRadius = layer.shadowRadius
            snapshot.layer.shadowOpacity = layer.shadowOpacity
        }
        return snapshot
    }
}


///////////////////////
// Private - RatingView
///////////////////////

class RatingView: UIStackView {
    open var rating: Int? = 0 {
        didSet {
            previousRating = oldValue
            update()
        }
    }
    
    private var previousRating: Int?
    
    open var minScale: CGFloat = 0.7 {
        didSet { update() }
    }
    
    private func update() {
        guard let stars = arrangedSubviews.filter({ $0 is UIImageView }) as? [UIImageView] else { return }
        guard let rating = rating else {
            stars.forEach { star in
                UIView.animate(withDuration: 0.3, animations: {
                    star.transform = CGAffineTransform(scaleX: self.minScale, y: self.minScale)
                    star.alpha = 0
                })
            }
            return
        }
        
        let previousRating = self.previousRating ?? 0
        stars.enumerated().forEach { [previousRating, rating] index, star in
            let shouldShow = rating > index
            let delay = 0.1 * TimeInterval(shouldShow ? index - previousRating + 1 : previousRating - index - 1)
            if star.alpha == 0 {
                star.alpha = 0.4
            }
            UIView.animate(withDuration: 0.2, delay: delay, animations: {
                star.alpha = shouldShow ? 1 : 0.4
                star.transform = shouldShow ? .identity : CGAffineTransform(scaleX: self.minScale, y: self.minScale)
            })
        }
    }
}
