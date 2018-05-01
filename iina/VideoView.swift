 //
//  VideoView.swift
//  iina
//
//  Created by lhc on 8/7/16.
//  Copyright © 2016 lhc. All rights reserved.
//

import Cocoa


class VideoView: NSView {

  weak var player: PlayerCore!

  lazy var videoLayer: ViewLayer = {
    let layer = ViewLayer()
    layer.videoView = self
    return layer
  }()

  var videoSize: NSSize?

  var isUninited = false
  var uninitLock = NSLock()

  var link: CVDisplayLink?

  // MARK: - Attributes

  override var mouseDownCanMoveWindow: Bool {
    return true
  }

  override var isOpaque: Bool {
    return true
  }

  // MARK: - Init

  override init(frame: CGRect) {

    super.init(frame: frame)

    // set up layer
    layer = videoLayer
    videoLayer.contentsScale = NSScreen.main!.backingScaleFactor
    wantsLayer = true

    // other settings
    autoresizingMask = [.width, .height]
    wantsBestResolutionOpenGLSurface = true
  
    // dragging init
    registerForDraggedTypes([.nsFilenames, .nsURL, .string])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func uninit() {
    uninitLock.lock()
    
    guard !isUninited else {
      uninitLock.unlock()
      return
    }
    
    player.mpv.mpvUninitRendering()
    isUninited = true
    uninitLock.unlock()
  }

  deinit {
    uninit()
  }

  override func draw(_ dirtyRect: NSRect) {
    // do nothing
  }
  
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    return true
  }

  // MARK: Drag and drop
  
  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    return player.acceptFromPasteboard(sender)
  }
  
  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    return player.openFromPasteboard(sender)
  }

  // MARK: Display link

  func startDisplayLink() {
    guard let window = window else { return }
    let displayId = UInt32(window.screen!.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! Int)
    CVDisplayLinkCreateWithActiveCGDisplays(&link)
    guard let link = link else {
      Utility.fatal("Cannot Create display link!")
    }
    CVDisplayLinkSetCurrentCGDisplay(link, displayId)
    CVDisplayLinkSetOutputCallback(link, displayLinkCallback, mutableRawPointerOf(obj: player.mpv))
    CVDisplayLinkStart(link)
  }

  func stopDisplaylink() {
    guard let link = link, CVDisplayLinkIsRunning(link) else { return }
    CVDisplayLinkStop(link)
  }

  func updateDisplaylink() {
    guard let window = window, let link = link else { return }
    let displayId = UInt32(window.screen!.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! Int)
    CVDisplayLinkSetCurrentCGDisplay(link, displayId)
  }
  
}

fileprivate func displayLinkCallback(
  _ displayLink: CVDisplayLink, _ inNow: UnsafePointer<CVTimeStamp>,
  _ inOutputTime: UnsafePointer<CVTimeStamp>,
  _ flagsIn: CVOptionFlags,
  _ flagsOut: UnsafeMutablePointer<CVOptionFlags>,
  _ context: UnsafeMutableRawPointer?) -> CVReturn {
  let mpv = unsafeBitCast(context, to: MPVController.self)
  mpv.mpvReportSwap()
  return kCVReturnSuccess
}

