
public enum TimerStyle : Int {
    
    case `default` //DisplayLink
    case displayLink
    case timer
    case none
}

public class Tween: NSObject {
    
    fileprivate var tweenOperations = [TweenableOperation]()
    fileprivate var pausedTimeStamp : TimeInterval?
    fileprivate var displayLink : CADisplayLink?
    fileprivate var timer: Timer?
    fileprivate var busy = false
    
    public var timerStyle: TimerStyle = .default {
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
    
    public var timerInterval: TimeInterval = 1/60 {
        didSet {
            stop()
            start()
        }
    }
    
    deinit {
        stop()
    }
    
    public static let shared = Tween(.default)
    
    public class func shared(_ timerStyle: TimerStyle = .default, frameInterval: Int? = nil, timerInterval: TimeInterval? = nil) -> Tween {
        return Tween(timerStyle, frameInterval: frameInterval, timerInterval: timerInterval)
    }
    
    public init( _ timerStyle: TimerStyle = .default, frameInterval: Int? = nil, timerInterval: TimeInterval? = nil) {
        
        super.init()
        self.timerStyle = timerStyle
        self.frameInterval = frameInterval ?? self.frameInterval
        self.timerInterval = timerInterval ?? self.timerInterval
    }
    
    public func addTweenOperation<T>(_ operation: OperationTween<T>) {
        
        guard let tweenableOperation = TweenableMapper.map(operation),
            operation.period.duration > 0 else {
                print("please set a duration")
                return
        }
        
        self.tweenOperations.append(tweenableOperation)
        start()
    }
    
    public func removeTweenOperation<T>(_ operation: OperationTween<T>) -> Bool {
        
        guard let index = self.tweenOperations.index(where: {
            switch $0 {
            case let .double(op):   return op == operation as? OperationTween<Double>
            case let .float(op):    return op == operation as? OperationTween<Float>
            case let .cgfloat(op):  return op == operation as? OperationTween<CGFloat>
            case let .cgsize(op):   return op == operation as? OperationTween<CGSize>
            case let .cgpoint(op):  return op == operation as? OperationTween<CGPoint>
            case let .cgrect(op):   return op == operation as? OperationTween<CGRect>
            case let .uicolor(op):  return op == operation as? OperationTween<UIColor>
            }
        })
            else { return false }
        
        self.tweenOperations.remove(at: index)
        return true
    }
    
    public func removeTweenOperationByName(_ name: String) -> Bool {
        
        let copy = self.tweenOperations
        
        for tweenableOperation in copy {
            
            switch tweenableOperation {
            case let .double(operation) where operation.name == name:   return removeTweenOperation(operation)
            case let .float(operation) where operation.name == name:    return removeTweenOperation(operation)
            case let .cgfloat(operation) where operation.name == name:  return removeTweenOperation(operation)
            case let .cgsize(operation) where operation.name == name:   return removeTweenOperation(operation)
            case let .cgpoint(operation) where operation.name == name:  return removeTweenOperation(operation)
            case let .cgrect(operation) where operation.name == name:   return removeTweenOperation(operation)
            case let .uicolor(operation) where operation.name == name:  return removeTweenOperation(operation)
            default:
                break
            }
        }
        return false
    }
    
    public func removeAllOperations() {
        self.tweenOperations.removeAll()
    }
    
    public func hasOperations() -> Bool {
        return self.tweenOperations.count > 0
    }
    
    fileprivate func progressOperation<T>(_ timeStamp: TimeInterval, operation: OperationTween<T>) -> Bool {
        
        let period = operation.period
        
        guard let startTimeStamp = period.startTimeStamp else {
            period.set(startTimeStamp: timeStamp)
            return operation.expired
        }
        
        guard period.hasStarted(timeStamp), !operation.expired
            else { return operation.expired }
        
        if !period.hasEnded(timeStamp) {
            
            period.progress = T.evaluate(start: period.start,
                                         end: period.end,
                                         time: timeStamp - startTimeStamp - period.delay,
                                         duration: period.duration,
                                         timingFunction: operation.timingMode.timingFunction())
        } else {
            
            period.progress = period.end
            operation.expired = true
        }
        
        period.updatedTimeStamp = timeStamp
        
        guard let updateBlock = operation.updateBlock
            else { return operation.expired }
        
        guard let dispatchQueue = operation.dispatchQueue else {
            updateBlock(period)
            return operation.expired
        }
        
        dispatchQueue.async { () -> Void in
            updateBlock(period)
        }
        return operation.expired
    }
    
    fileprivate func expiry<T>(_ operation: OperationTween<T>) {
        
        guard let completeBlock = operation.completeBlock
            else { return }
        
        guard let dispatchQueue = operation.dispatchQueue else {
            completeBlock()
            return
        }
        
        dispatchQueue.async { () -> Void in
            completeBlock()
        }
    }
    
    public func update(_ timeStamp: TimeInterval) {
        
        guard hasOperations() else {
            stop()
            return
        }
        
        func remove<T>(_ operation: OperationTween<T>) {
            if removeTweenOperation(operation) {
                expiry(operation)
            }
        }
        
        let copy = self.tweenOperations
        
        func progress<T>(timeStamp: TimeInterval, operation: OperationTween<T>) {
            if progressOperation(timeStamp, operation: operation) {
                remove(operation)
            }
        }
        
        copy.forEach {
            
            switch $0 {
            case let .double(operation):    progress(timeStamp: timeStamp, operation: operation)
            case let .float(operation):     progress(timeStamp: timeStamp, operation: operation)
            case let .cgfloat(operation):   progress(timeStamp: timeStamp, operation: operation)
            case let .cgsize(operation):    progress(timeStamp: timeStamp, operation: operation)
            case let .cgpoint(operation):   progress(timeStamp: timeStamp, operation: operation)
            case let .cgrect(operation):    progress(timeStamp: timeStamp, operation: operation)
            case let .uicolor(operation):   progress(timeStamp: timeStamp, operation: operation)
            }
        }
    }
    
    @objc func handleDisplayLink(_ sender: CADisplayLink) {
        handleTick(sender.timestamp)
    }
    
    @objc func handleTimer(_ sender: Timer) {
        handleTick(CACurrentMediaTime())
    }
    
    fileprivate func handleTick(_ timeStamp: TimeInterval) {
        
        guard !self.busy
            else { return }
        
        self.busy = true
        update(timeStamp)
        self.busy = false
    }
    
    fileprivate func start() {
        
        guard hasOperations() && !self.paused
            else { return }
        
        if self.displayLink == nil && (self.timerStyle == .default || self.timerStyle == .displayLink) {
            
            self.displayLink = UIScreen.main.displayLink(withTarget: self, selector: #selector(Tween.handleDisplayLink(_:)))
            self.displayLink!.frameInterval = self.frameInterval
            self.displayLink!.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
            
        } else if timer == nil && timerStyle == .timer {
            
            self.timer = Timer.scheduledTimer(timeInterval: self.timerInterval, target: self, selector: #selector(Tween.handleTimer(_:)), userInfo: nil, repeats: true)
            self.timer!.fire()
        }
    }
    
    fileprivate func stop() {
        
        if self.displayLink != nil {
            
            self.displayLink!.isPaused = true
            self.displayLink!.remove(from: RunLoop.main, forMode: RunLoopMode.commonModes)
            self.displayLink = nil
        }
        
        if self.timer != nil {
            
            self.timer!.invalidate()
            self.timer = nil
        }
    }
    
    fileprivate func pause() {
        
        if self.paused && (self.timer != nil || self.displayLink != nil) {
            
            self.pausedTimeStamp = CACurrentMediaTime()
            stop()
            return
        }
        
        guard self.timer == nil && self.displayLink == nil
            else { return }
        
        guard let pausedTimeStamp = self.pausedTimeStamp else {
            
            self.pausedTimeStamp = nil
            start()
            return
        }
        
        let diff = CACurrentMediaTime() - pausedTimeStamp
        
        func pause<T>(_ operation: OperationTween<T>, time: TimeInterval) {
            if let startTimeStamp = operation.period.startTimeStamp {
                operation.period.set(startTimeStamp: startTimeStamp + time)
            }
        }
        
        self.tweenOperations.forEach {
            
            switch $0 {
            case let .double(operation):    pause(operation, time: diff)
            case let .float(operation):     pause(operation, time: diff)
            case let .cgfloat(operation):   pause(operation, time: diff)
            case let .cgsize(operation):    pause(operation, time: diff)
            case let .cgpoint(operation):   pause(operation, time: diff)
            case let .cgrect(operation):    pause(operation, time: diff)
            case let .uicolor(operation):   pause(operation, time: diff)
            }
        }
    }
    
    //Convience functions
    
    public func value<T: Tweenable>(start: T, end: T, duration: TimeInterval = 1) -> OperationTween<T> {
        
        let period = Period(start: start, end: end, duration: duration, delay: 0)
        let operation = OperationTween(period: period)
        addTweenOperation(operation)
        return operation
    }
}

