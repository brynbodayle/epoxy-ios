// Created by eric_horacek on 6/22/22.
// Copyright © 2022 Airbnb Inc. All rights reserved.

import SwiftUI

// MARK: - MeasuringViewRepresentable

/// A `UIViewRepresentable` that uses a `SwiftUIMeasurementContainer` wrapping its represented
/// `UIView` to report its size that fits a proposed size to SwiftUI.
///
/// Supports iOS 13-15 using the private `_overrideSizeThatFits(…)` method and iOS 16+ using the
/// `sizeThatFits(…)` method.
///
/// - SeeAlso: ``SwiftUIMeasurementContainer``
public protocol MeasuringViewRepresentable: ViewRepresentableType
  where
  RepresentableViewType == SwiftUIMeasurementContainer<Content>
{
  /// The `UIView` content that's being measured by the enclosing `SwiftUIMeasurementContainer`.
  associatedtype Content: ViewType

  /// The sizing strategy of the represented view.
  ///
  /// To configure the sizing behavior of the `View` instance, call `sizing` on this `View`, e.g.:
  /// ```
  /// myView.sizing(.intrinsicSize)
  /// ```
  var sizing: SwiftUIMeasurementContainerStrategy { get set }
}

// MARK: Extensions

extension MeasuringViewRepresentable {
  /// Returns a copy of this view with its sizing strategy updated to the given `sizing` value.
  public func sizing(_ strategy: SwiftUIMeasurementContainerStrategy) -> Self {
    var copy = self
    copy.sizing = strategy
    return copy
  }
}

// MARK: Defaults

#if os(iOS) || os(tvOS)
extension MeasuringViewRepresentable {

  #if swift(>=5.7.1) // Proxy check for being built with the iOS 15 SDK
  @available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
  public func sizeThatFits(
    _ proposal: ProposedViewSize,
    uiView: UIViewType,
    context _: Context)
    -> CGSize?
  {
    switch sizing {
    case .intrinsic:
      return uiView.systemLayoutSizeFitting(
        UIView.layoutFittingCompressedSize,
        withHorizontalFittingPriority: .fittingSizeLevel,
        verticalFittingPriority: .fittingSizeLevel)
    case .automatic, .intrinsicHeightProposedOrIntrinsicWidth, .intrinsicHeightProposedWidth, .intrinsicWidthProposedHeight:
      uiView.translatesAutoresizingMaskIntoConstraints = false
      let widthConstraint2 = uiView.widthAnchor.constraint(equalToConstant: proposal.width ?? 0)
      widthConstraint2.isActive = true
      uiView.layoutIfNeeded()

      widthConstraint2.isActive = false

      let widthConstraint = uiView.widthAnchor.constraint(lessThanOrEqualToConstant: proposal.width ?? 0)
      widthConstraint.isActive = true
      uiView.layoutIfNeeded()

      let size = uiView.systemLayoutSizeFitting(
        UIView.layoutFittingExpandedSize,
        withHorizontalFittingPriority: .fittingSizeLevel,
        verticalFittingPriority: .fittingSizeLevel)
      widthConstraint.isActive = false

      return size
    case .proposed:
      return proposal.replacingUnspecifiedDimensions()
    }
  }
  #endif
}

#elseif os(macOS)
@available(macOS 10.15, *)
extension MeasuringViewRepresentable {
  public func _overrideSizeThatFits(
    _ size: inout CGSize,
    in proposedSize: _ProposedSize,
    nsView: NSViewType)
  {
    nsView.strategy = sizing
    let children = Mirror(reflecting: proposedSize).children
    nsView.proposedSize = .init(
      width: (
        children.first { $0.label == "width" }?
          .value as? CGFloat ?? ViewType.noIntrinsicMetric).constraintSafeValue,
      height: (
        children.first { $0.label == "height" }?
          .value as? CGFloat ?? ViewType.noIntrinsicMetric).constraintSafeValue)
    size = nsView.measuredFittingSize
  }

  // Proxy check for being built with the macOS 13 SDK.
  #if swift(>=5.7.1)
  @available(macOS 13.0, *)
  public func sizeThatFits(
    _ proposal: ProposedViewSize,
    nsView: NSViewType,
    context _: Context)
    -> CGSize?
  {
    nsView.strategy = sizing
    nsView.proposedSize = proposal.viewTypeValue
    return nsView.measuredFittingSize
  }
  #endif
}
#endif

#if swift(>=5.7.1) // Proxy check for being built with the iOS 15 SDK
@available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
extension ProposedViewSize {
  /// Creates a size suitable for the current platform's view building framework by capping infinite values to a significantly large value and
  /// replacing `nil`s with `UIView.noIntrinsicMetric`
  var viewTypeValue: CGSize {
    .init(
      width: width?.constraintSafeValue ?? ViewType.noIntrinsicMetric,
      height: height?.constraintSafeValue ?? ViewType.noIntrinsicMetric)
  }
}

#endif

extension CGFloat {
  static var maxConstraintValue: CGFloat {
    // On iOS 15 and below, configuring an auto layout constraint with the constant
    // `.greatestFiniteMagnitude` exceeds an internal limit and logs an exception to console. To
    // avoid, we use a significantly large value.
    1_000_000
  }

  /// Returns a value suitable for configuring auto layout constraints
  var constraintSafeValue: CGFloat {
    isInfinite ? .maxConstraintValue : self
  }

}
