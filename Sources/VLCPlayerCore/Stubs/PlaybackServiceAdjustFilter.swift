/*****************************************************************************
 * PlaybackServiceAdjustFilter.swift
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2022 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Maxime Chapelet <umxprime # videolabs.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

import Foundation
import VLCKit

@objc(VLCPlaybackServiceAdjustFilter)
public final class PlaybackServiceAdjustFilter: NSObject {
    @objc let mediaPlayerAdjustFilter: VLCFilter
    public let contrast: Parameter
    public let brightness: Parameter
    public let hue: Parameter
    public let saturation: Parameter
    public let gamma: Parameter

    @available(*, unavailable)
    private override init() {
        fatalError("\(#function) has not been implemented")
    }

    @objc(initWithMediaPlayerAdjustFilter:)
    init(_ mediaPlayerAdjustFilter: VLCAdjustFilter) {
        self.mediaPlayerAdjustFilter = mediaPlayerAdjustFilter
        contrast = Parameter(mediaPlayerAdjustFilter.contrast)
        brightness = Parameter(mediaPlayerAdjustFilter.brightness)
        hue = Parameter(mediaPlayerAdjustFilter.hue)
        saturation = Parameter(mediaPlayerAdjustFilter.saturation)
        gamma = Parameter(mediaPlayerAdjustFilter.gamma)
    }

    public var isEnabled: Bool {
        get {
            mediaPlayerAdjustFilter.isEnabled
        }
        set {
            mediaPlayerAdjustFilter.isEnabled = newValue
        }
    }

    public func resetParametersIfNeeded() -> Bool {
        return mediaPlayerAdjustFilter.resetParametersIfNeeded()
    }
}

extension PlaybackServiceAdjustFilter {
    public class Parameter {
        private weak var parameter: VLCFilterParameterProtocol!

        private func floatValue(_ value: Any) -> Float {
            switch value {
            case let value as NSNumber :
                return value.floatValue
            case let value as NSString :
                return value.floatValue
            default:
                fatalError()
            }
        }

        public var value: Float {
            get {
                floatValue(parameter.value)
            }
            set {
                parameter.value = NSNumber(value: newValue)
            }
        }

        public var minValue: Float {
            floatValue(parameter.minValue)
        }

        public var maxValue: Float {
            floatValue(parameter.maxValue)
        }

        public init(_ parameter: VLCFilterParameterProtocol) {
            self.parameter = parameter
        }
    }
}
