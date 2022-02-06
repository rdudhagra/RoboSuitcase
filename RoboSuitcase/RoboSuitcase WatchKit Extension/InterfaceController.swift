//
//  InterfaceController.swift
//  RoboSuitcase WatchKit Extension
//
//  Created by Ravi Dudhagra on 2/5/22.
//

import WatchKit
import Foundation
import CoreMotion

let url = "http://robosuitcase.wifi.local.cmu.edu/motor?"


class InterfaceController: WKInterfaceController, WKExtendedRuntimeSessionDelegate, WKCrownDelegate {
    @IBOutlet weak var current_motor_power_slider: WKInterfaceGroup!
    @IBOutlet weak var target_motor_power_slider: WKInterfaceGroup!
    @IBOutlet weak var angle_slider_left: WKInterfaceGroup!
    @IBOutlet weak var angle_slider_right: WKInterfaceGroup!
    @IBOutlet weak var start_stop_btn: WKInterfaceButton!
    
    var enabled = false
    
    var session : WKExtendedRuntimeSession?
    
    var timer : Timer?
    var startDate : Date?
    
    let motionManager = CMMotionManager()
    let queue = OperationQueue()
    var initAngle = 0.0
    var currentAngle = 0.0
    
    var targetMotorPower = 0.0
    var currentMotorPower = 0.0 // Separate these two variables into target and current so we can clamp acceleration easily
    
    var urlSession = URLSession(configuration: URLSessionConfiguration.default)
    
    
    
    
    /* INTERFACECONTROLLER LIFECYCLE */
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Digital crown setup
        self.crownSequencer.delegate = self
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        // Tilt detection setup
        motionManager.deviceMotionUpdateInterval = 0.01
        motionManager.showsDeviceMovementDisplay = true
        motionManager.startDeviceMotionUpdates(to: self.queue, withHandler: read_tilt)
        
        // Stay awake using an extended runtime session
        session = WKExtendedRuntimeSession()
        session!.delegate = self
        session!.start()
        
        // Autorotate screen instead of turning off
        WKExtension.shared().isAutorotating = true
        
        // Focus crown
        self.crownSequencer.focus()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        
        motionManager.stopDeviceMotionUpdates()
        
        WKExtension.shared().isAutorotating = false
    }
    
    
    
    
    /* EXTENDED RUNTIME SESSION LIFECYCLE */
    
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {}
    
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Starting extended runtime session")
        // Set up timer to fire every second
        timer = Timer(fire: Date(), interval: 0.2, repeats: true) {timer in
            self.timerFired()
        }
        timer!.tolerance = 0.02 // For visual updates, 0.2 is close enough
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        
        WKExtension.shared().isAutorotating = false
    }
    
    
    
    
    /* TILT DETECTION FUNCTIONS */
    
    func read_tilt(data: CMDeviceMotion?, err: Error?) {
        if motionManager.isDeviceMotionActive {
            var angle = (data?.attitude.pitch)
            if (angle != nil) {
                if initAngle == 0 {
                    initAngle = angle!
                }
                angle! -= initAngle
                currentAngle = currentAngle * 0.9 + angle! * 0.1
            } else {
                print("Data was nil for some reason")
                return
            }
        } else {
            motionManager.startDeviceMotionUpdates()
        }
    }
    
    
    
    
    /* DIGITAL CROWN READ FUNCTIONS */
    
    func crownDidRotate(_ crownSequencer: WKCrownSequencer?, rotationalDelta: Double) {
        if enabled {
            targetMotorPower = min(255,max(0,targetMotorPower + rotationalDelta * 200))
        } else {
            targetMotorPower = 0
        }
    }
    
    
    
    
    /* TIMER CALLBACK FUNCTION */
    
    func timerFired() {
        sendToSuitcase(angle: Int(min(120, max(0, currentAngle * 200 + 60))), speed: targetMotorPower)
    }
    
    
    
    
    /* NETWORKING FUNCTIONS */
    
    func sendToSuitcase(angle: Int, speed: Double) {
        let delta = min(10, abs(speed - currentMotorPower) / 4)
        currentMotorPower += max(-delta, min(delta, speed - currentMotorPower))
        current_motor_power_slider.setRelativeHeight(currentMotorPower / 255.0, withAdjustment: 0)
        target_motor_power_slider.setRelativeHeight(speed / 255.0, withAdjustment: 0)
        
        Task {
            do {
                _ = try await urlSession.bytes(from: URL.init(string: url + "angle=" + String(angle) + "&speed=" + String(currentMotorPower))!)
            } catch {
                
            }
        }
        if angle <= 60 {
            angle_slider_left.setRelativeWidth(CGFloat(60 - angle) / 60.0, withAdjustment: 0)
            angle_slider_right.setRelativeWidth(0, withAdjustment: 0)
        } else {
            angle_slider_left.setRelativeWidth(0, withAdjustment: 0)
            angle_slider_right.setRelativeWidth(CGFloat(angle - 60) / 60.0, withAdjustment: 0)
        }
    }
    
    
    
    /* BUTTON PRESS HANDLERS */
    @IBAction func reset_tilt() {
        initAngle = 0 // Forces the read_tilt() function to reset the value on the next call
    }
    
    @IBAction func start_stop_control() {
        enabled = !enabled
        start_stop_btn.setBackgroundColor(enabled ? .init(red: 151.0/255.0, green: 28.0/255.0, blue: 28.0/255.0, alpha: 1) : .init(red: 0, green: 143/255.0, blue: 0, alpha: 1    ))
        start_stop_btn.setTitle(enabled ? "Stop" : "Start")
        
        if !enabled {
            targetMotorPower = 0
        }
    }
}
