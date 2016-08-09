//
//  MKTween.swift
//  MKTween
//
//  Created by Kevin Malkic on 25/01/2016.
//  Copyright © 2016 Malkic Kevin. All rights reserved.
//

import Foundation

public enum MKTweenTimerStyle : Int {
	
	case Default //DisplayLink
	case DisplayLink
	case Timer
	case None
}

public class MKTween: NSObject {
	
	private var tweenOperations = [MKTweenOperation]()
	private var expiredTweenOperations = [MKTweenOperation]()
	private var pausedTimeStamp : NSTimeInterval?
	private var displayLink : CADisplayLink?
	private var timer: NSTimer?
	private var busy = false
	
	public var timerStyle: MKTweenTimerStyle = .Default {
		
		didSet {
			
			stop()
			start()
		}
	}
	
	/* When true the object is prevented from firing. Initial state is
	* false. */
	
	public var paused: Bool = false {
		
		didSet {
			
			pause()
		}
	}
	
	/* Defines how many display frames must pass between each time the
	* display link fires. Default value is one, which means the display
	* link will fire for every display frame. Setting the interval to two
	* will cause the display link to fire every other display frame, and
	* so on. The behavior when using values less than one is undefined. */
	
	public var frameInterval: Int = 1 {
		
		didSet {
			
			stop()
			start()
		}
	}
	
	public var timerInterval: NSTimeInterval = 1/60 {
		
		didSet {
			
			stop()
			start()
		}
	}
	
	deinit {
		
		stop()
	}
	
	public class var shared: MKTween {
		
		return MKTween.shared(.Default)
	}
	
	public class func shared(timerStyle: MKTweenTimerStyle = .Default, frameInterval: Int? = nil, timerInterval: NSTimeInterval? = nil) -> MKTween {
		
		struct Static {
			
			static var instance: MKTween!
			static var token: dispatch_once_t = 0
		}
		
		dispatch_once(&Static.token) {
			
			Static.instance = MKTween(timerStyle, frameInterval: frameInterval, timerInterval: timerInterval)
		}
		
		return Static.instance!
	}
	
	public init( _ timerStyle: MKTweenTimerStyle = .Default, frameInterval: Int? = nil, timerInterval: NSTimeInterval? = nil) {
		
		super.init()
		
		self.timerStyle = timerStyle
		self.frameInterval = frameInterval ?? self.frameInterval
		self.timerInterval = timerInterval ?? self.timerInterval
	}
	
	public func addTweenOperation(operation: MKTweenOperation) {
		
		if operation.period.duration > 0 {
			
			tweenOperations.append(operation)
			
			start()
		}
	}
	
	public func removeTweenOperation(operation: MKTweenOperation) {
		
		tweenOperations.removeOperation(operation)
	}
	
	public func removeTweenOperationByName(name: String) {
		
		let copy = tweenOperations
		
		for operation in copy {
			
			if operation.name == name {
				
				tweenOperations.removeOperation(operation)
			}
		}
	}
	
	public func removeAllOperations() {
		
		let copy = tweenOperations
		
		for operation in copy {
			
			removeTweenOperation(operation)
		}
	}
	
	public func hasOperations() -> Bool {
		
		return tweenOperations.count > 0
	}
	
	public func hasOperation(name: String) -> Bool {
		
		for operation in tweenOperations {
			
			if operation.name == name {
				
				return true
			}
		}
		
		return false
	}
	
	public func update(timeStamp: NSTimeInterval) {
		
		if tweenOperations.count == 0 {
			
			stop()
			
			return
		}
		
		let copy = tweenOperations
		
		for operation in copy {
			
			let period = operation.period
			
			if let startTimeStamp = period.startTimeStamp {
				
				let timeToStart = startTimeStamp + period.delay
				
				if timeStamp >= timeToStart {
					
					let timeToEnd = startTimeStamp + period.delay + period.duration
					
					if timeStamp <= timeToEnd {
						
						period.progress = operation.timingFunction(time: timeStamp - startTimeStamp - period.delay, begin: period.startValue, difference: period.endValue - period.startValue, duration: period.duration)
						
					} else {
						
						period.progress = period.endValue
						expiredTweenOperations.append(operation)
						removeTweenOperation(operation)
					}
					
					period.updatedTimeStamp = timeStamp
					
					if let updateBlock = operation.updateBlock {
						
						if let dispatchQueue = operation.dispatchQueue {
							
							dispatch_async(dispatchQueue, { () -> Void in
								
								updateBlock(period: period)
							})
							
						} else {
							
							updateBlock(period: period)
						}
					}
				}
				
			} else {
				
				period.startTimeStamp = timeStamp
			}
		}
		
		let expiredCopy = expiredTweenOperations
		
		for operation in expiredCopy {
			
			if let completeBlock = operation.completeBlock {
				
				if let dispatchQueue = operation.dispatchQueue {
					
					dispatch_async(dispatchQueue, { () -> Void in
						
						completeBlock()
					})
					
				} else {
					
					completeBlock()
				}
			}
			
			expiredTweenOperations.removeOperation(operation)
		}
	}
	
	func handleDisplayLink(sender: CADisplayLink) {
		
		handleTick(sender.timestamp)
	}
	
	func handleTimer(sender: NSTimer) {
		
		handleTick(CACurrentMediaTime())
	}
	
	private func handleTick(timeStamp: NSTimeInterval) {
		
		if busy {
			
			return
		}
		
		busy = true
		
		update(timeStamp)
		
		busy = false
	}
	
	private func start() {
		
		if tweenOperations.count == 0 || paused {
			
			return
		}
		
		if displayLink == nil && (timerStyle == .Default || timerStyle == .DisplayLink) {
			
			displayLink = UIScreen.mainScreen().displayLinkWithTarget(self, selector: "handleDisplayLink:")
			displayLink!.frameInterval = frameInterval
			displayLink!.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
			
		} else if timer == nil && timerStyle == .Timer {
			
			timer = NSTimer.scheduledTimerWithTimeInterval(timerInterval, target: self, selector: "handleTimer:", userInfo: nil, repeats: true)
			timer!.fire()
		}
	}
	
	private func stop() {
		
		if displayLink != nil {
			
			displayLink!.paused = true
			displayLink!.removeFromRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
			displayLink = nil
		}
		
		if timer != nil {
			
			timer!.invalidate()
			timer = nil
		}
	}
	
	private func pause() {
		
		if paused && (timer != nil || displayLink != nil) {
			
			pausedTimeStamp = CACurrentMediaTime()
			
			stop()
			
		} else if timer == nil && displayLink == nil {
			
			if let pausedTimeStamp = pausedTimeStamp {
				
				let diff = CACurrentMediaTime() - pausedTimeStamp
				
				let operationsStarted = tweenOperations.filter({ (operation) -> Bool in
					
					return operation.period.startTimeStamp != nil
				})
				
				for operation in operationsStarted {
					
					operation.period.startTimeStamp! += diff
				}
			}
			
			pausedTimeStamp = nil
			
			start()
		}
	}
}