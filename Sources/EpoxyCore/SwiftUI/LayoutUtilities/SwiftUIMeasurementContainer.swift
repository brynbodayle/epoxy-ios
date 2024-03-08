// Created by Bryn Bodayle on 1/24/22.
// Copyright © 2022 Airbnb Inc. All rights reserved.

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import SwiftUI

// MARK: - SwiftUIMeasurementContainer

/// A view that has an `intrinsicContentSize` of the `uiView`'s `systemLayoutSizeFitting(…)` and
/// supports double layout pass sizing and content size category changes.
///
/// This container view uses an injected proposed width to measure the view and return its ideal
/// height through the `SwiftUISizingContext` binding.
///
/// - SeeAlso: ``MeasuringViewRepresentable``
public final class SwiftUIMeasurementContainer<Content: ViewType>: ViewType {

  // MARK: Lifecycle

  public init(content: Content, strategy: SwiftUIMeasurementContainerStrategy) {
    self.content = content
    super.init(frame: .zero)

    addSubview(content)
    setUpConstraints()
  }

  @available(*, unavailable)
  public required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Public

  /// The `UIView` content that's being measured by this container.
  public var content: Content {
    didSet {
      guard content !== oldValue else { return }
      oldValue.removeFromSuperview()
      addSubview(content)
      setUpConstraints()
    }
  }

  private var allConstraints = [NSLayoutConstraint]()

  private func setUpConstraints() {
    content.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.deactivate(allConstraints)
    allConstraints = [
      content.leadingAnchor.constraint(equalTo: leadingAnchor),
      content.topAnchor.constraint(equalTo: topAnchor),
      content.trailingAnchor.constraint(equalTo: trailingAnchor),
      content.bottomAnchor.constraint(equalTo: bottomAnchor),
    ]
    NSLayoutConstraint.activate(allConstraints)
  }
}

// MARK: - SwiftUIMeasurementContainerStrategy

/// The measurement strategy of a `SwiftUIMeasurementContainer`.
public enum SwiftUIMeasurementContainerStrategy {
  /// The container makes a best effort to correctly choose the measurement strategy of the view.
  ///
  /// The best effort is based on a number of heuristics:
  /// - The `uiView` will be given its intrinsic width and/or height when measurement in that
  ///   dimension produces a positive value, while zero/negative values will result in that
  ///   dimension receiving the available space proposed by the parent.
  /// - If the view contains `UILabel` subviews that require a double layout pass as determined by supporting multiple lines of text
  ///   the view will default to `intrinsicHeightProposedOrIntrinsicWidth` to allow the labels to wrap.
  ///
  /// If you would like to opt out of automatic sizing for performance or to override the default
  /// behavior, choose another strategy.
  case automatic

  /// The `uiView` is sized to fill the area proposed by its parent.
  ///
  /// Typically used for views that should expand greedily in both axes, e.g. a background view.
  case proposed

  /// The `uiView`'s receives either its intrinsic width or the proposed width, whichever is smaller. The view receives its intrinsic height
  /// based on the chosen width.
  ///
  /// Typically used for views that have a height that's a function of their width, e.g. a row with
  /// text that can wrap to multiple lines.
  case intrinsicHeightProposedOrIntrinsicWidth

  /// The `uiView` is sized with its intrinsic height and expands horizontally to fill the width
  /// proposed by its parent.
  ///
  /// Typically used for views that have a height that's a function of their parent's width.
  case intrinsicHeightProposedWidth

  /// The `uiView` is sized with its intrinsic width and expands vertically to fill the height
  /// proposed by its parent.
  ///
  /// Typically used for views that are free to grow vertically but have a fixed width, e.g. a view
  /// in a horizontal carousel.
  case intrinsicWidthProposedHeight

  /// The `uiView` is sized to its intrinsic width and height.
  ///
  /// Typically used for components with a specific intrinsic size in both axes, e.g. controls or
  /// inputs.
  case intrinsic
}

// MARK: - ResolvedSwiftUIMeasurementContainerStrategy

/// The resolved measurement strategy of a `SwiftUIMeasurementContainer`, matching the cases of the
/// `SwiftUIMeasurementContainerStrategy` without the automatic case.
private enum ResolvedSwiftUIMeasurementContainerStrategy {
  case proposed, intrinsicHeightProposedWidth, intrinsicWidthProposedHeight,
       intrinsicHeightProposedOrIntrinsicWidth, intrinsic(CGSize)
}

// MARK: - UILayoutPriority

extension LayoutPriorityType {
  /// An "almost required" constraint, useful for creating near-required constraints that don't
  /// error when unable to be satisfied.
  @nonobjc
  fileprivate static var almostRequired: LayoutPriorityType { .init(rawValue: required.rawValue - 1) }
}

// MARK: - UIView

extension ViewType {
  /// The `systemLayoutSizeFitting(…)` of this view with a compressed size and fitting priorities.
  @nonobjc
  fileprivate func systemLayoutFittingIntrinsicSize() -> CGSize {
    #if os(macOS)
    intrinsicContentSize
    #else
    systemLayoutSizeFitting(
      UIView.layoutFittingCompressedSize,
      withHorizontalFittingPriority: .fittingSizeLevel,
      verticalFittingPriority: .fittingSizeLevel)
    #endif
  }

  /// The `systemLayoutSizeFitting(…)` of this view with a compressed height with a fitting size
  /// priority and with the given fixed width and fitting priority.
  @nonobjc
  fileprivate func systemLayoutFittingIntrinsicHeightFixedWidth(
    _ width: CGFloat,
    priority: LayoutPriorityType = .almostRequired)
    -> CGSize
  {
    #if os(macOS)
    return CGSize(width: width, height: intrinsicContentSize.height)
    #else
    let targetSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)

    return systemLayoutSizeFitting(
      targetSize,
      withHorizontalFittingPriority: priority,
      verticalFittingPriority: .fittingSizeLevel)
    #endif
  }

  /// The `systemLayoutSizeFitting(…)` of this view with a compressed width with a fitting size
  /// priority and with the given fixed height and fitting priority.
  @nonobjc
  fileprivate func systemLayoutFittingIntrinsicWidthFixedHeight(
    _ height: CGFloat,
    priority: LayoutPriorityType = .almostRequired)
    -> CGSize
  {
    #if os(macOS)
    return CGSize(width: intrinsicContentSize.width, height: height)
    #else
    let targetSize = CGSize(width: UIView.layoutFittingCompressedSize.width, height: height)

    return systemLayoutSizeFitting(
      targetSize,
      withHorizontalFittingPriority: .fittingSizeLevel,
      verticalFittingPriority: priority)
    #endif
  }

  /// Whether this view or any of its subviews has a subview that has a double layout pass `UILabel` as determined by being
  /// configured to show multiple lines of text. This view should get a `intrinsicHeightProposedOrIntrinsicWidth` sizing
  /// strategy so that it wraps correctly.
  @nonobjc
  fileprivate func containsDoubleLayoutPassSubviews() -> Bool {
    #if os(macOS)
    return false
    #else
    var contains = false
    if let label = self as? UILabel, label.numberOfLines != 1 {
      contains = true
    }
    for subview in subviews {
      contains = contains || subview.containsDoubleLayoutPassSubviews()
    }
    return contains
    #endif
  }
}

// MARK: - CGSize

extension CGSize {
  /// A `CGSize` with `noIntrinsicMetric` for both its width and height.
  fileprivate static var noIntrinsicMetric: CGSize {
    .init(width: ViewType.noIntrinsicMetric, height: ViewType.noIntrinsicMetric)
  }

  /// Returns a `CGSize` with its width and/or height replaced with the corresponding field of the
  /// provided `fallback` size if they are `UIView.noIntrinsicMetric`.
  fileprivate func replacingNoIntrinsicMetric(with fallback: CGSize) -> CGSize {
    .init(
      width: width == ViewType.noIntrinsicMetric ? fallback.width : width,
      height: height == ViewType.noIntrinsicMetric ? fallback.height : height)
  }
}
