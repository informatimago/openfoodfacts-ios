//
//  ViewController.swift
//  WeightMe
//
//  Created by Pascal Bourguignon on 09/04/2019.
//  Copyright © 2019 SBDE. All rights reserved.
//

import UIKit
import Network

class ScaleViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var connectionState: UILabel!
    @IBOutlet weak var controllerIPAddress: UITextField!
    @IBOutlet weak var weight: UITextField!
    @IBOutlet weak var tare: UITextField!
    @IBOutlet weak var continuousWeighting: UISwitch!
    @IBOutlet weak var startButton: UIButton!

    let defaultControllerIPAddress="boxsim.laboite.sbde.fr"
    var grossWeight: Float = 0.0
    var tareValue: Float = 0.0

    var crlf = Data.init()
    var datetimeFormatter = ISO8601DateFormatter.init()
    let defaults = UserDefaults.init()
    let controllerPort = UInt16(SERVER_PORT)
    var controller: OpaquePointer?
    enum State { case disconnected, connected, idle, weighing }
    var state = State.disconnected
    var queue = DispatchQueue.global(qos: .userInitiated)
    var continuous = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        datetimeFormatter=ISO8601DateFormatter.init()
        datetimeFormatter.formatOptions=[.withYear, .withMonth, .withDay, .withTime, .withTimeZone]
        controllerIPAddress.text=defaults.string(forKey: "controllerIPAddress") ?? defaultControllerIPAddress
        tareValue=0.0
        grossWeight=0.0
        updateWeightDisplay()
        updateConnectionState()
        continuousWeighting.setOn(false, animated: false)
        crlf=Data.init(capacity: 2)
        crlf.append(contentsOf: [13, 10])
        controllerIPAddress.delegate = self
    }

    func textFieldShouldReturn(_ sender: UITextField) -> Bool {
        sender.resignFirstResponder()
        return false
    }

    func labelForMessage(kind: UInt32) -> String {
        switch kind {
        case 0: return "VERSION"
        case 1: return "TARE-SET"
        case 2: return "CALIBRATION"
        case 3: return "SCALES-START"
        case 4: return "SCALES-QUERY"
        case 5: return "SCALES-STOP"
        case 6: return "SCALES-MEASURE"
        default: return "UNKNOWN"
        }
    }

    func sendMessage(_ message: UnsafeMutablePointer<controller_ua_message>,
                     _ newState: State) {
        let allright = fr_sbde_protocol_client_send_message(controller, message)
        print("Send Message \(labelForMessage(kind: (message.pointee.kind).rawValue)) -> \(allright)")
        free(message)
        if allright {
            state=newState
            updateConnectionState()
            switch message.pointee.kind {
            // Those messages don't have answers:
            case controller_ua_message_tare_set:
                break
            case controller_ua_message_calibration:
                break
            default:
                receiveMessage()
            }
        } else {
            if let controller=controller {
                if let error=fr_sbde_protocol_client_error(controller) {
                    print("Send Message Error \(String.init(cString: error))")
                }
            }
            stop()
        }
    }

    func receiveMessage() {
        let message=fr_sbde_protocol_client_receive_message(controller)
        if let message = message {
            print("Received Message \(labelForMessage(kind: message.pointee.kind.rawValue))")
            switch message.pointee.kind {
            case controller_ua_message_version:
                print("controller_ua_message_version")
                if !(message.pointee.message.version.version_number == 1) {
                    print("Bad version \(message.pointee.message.version.version_number)")
                }
                state=State.idle
            case controller_ua_message_scales_measure:
                print("controller_ua_message_scales_measure")
                receiveGrossWeight(message.pointee.message.scales_measure.mass)
            default:
                print("Bad Message Kind \(message.pointee.kind)")
            }
       } else {
            print("no message")
            if let controller=controller {
                if let error=fr_sbde_protocol_client_error(controller) {
                    print("Receive Message Error \(String.init(cString: error))")
                }
            }
        }
        free(message)
    }

    func sendVersion(_ version: Int) {
        print("sendVersion \(version) state=", state)
        if state==State.connected {
            let timestamp: datetime_t = datetime_now()
            let message=controller_ua_version_new(version, timestamp)
            if let message = message {
                sendMessage(message, State.idle)
            }
        }
    }

    func sendSetTare(slot: Int) {
        print("sendSetTare \(slot) state=", state)
        if (state == State.idle) || (state == State.weighing) || (state == State.connected) {
            let message = controller_ua_tare_set_new(slot)
            if let message = message {
                sendMessage(message, state)
            }
        }
    }

    func sendCalibration(slot: Int, mass: Float) {
        print("sendCalibration \(slot) \(mass) state=", state)
        if (state == State.idle) || (state == State.connected) {
            let message = controller_ua_calibration_new(slot, mass)
            if let message = message {
                sendMessage(message, state)
            }
        }
    }

    func sendScalesStart(slot: Int) {
        print("sendScalesStart \(slot) state=", state)
        if state == State.idle {
            let timestamp: datetime_t = datetime_now()
            let message = controller_ua_scales_start_new(timestamp, slot)
            if let message = message {
                sendMessage(message, State.weighing)
            }
        }
    }

    func sendScalesQuery(slot: Int) {
        print("sendScalesQuery \(slot) state=", state)
        if state == State.weighing {
            let timestamp: datetime_t = datetime_now()
            let message = controller_ua_scales_query_new(timestamp, slot)
            if let message = message {
                sendMessage(message, State.weighing)
            }
        }
    }

    func sendScalesStop(slot: Int) {
        print("sendScalesStop \(slot) state=", state)
        if state==State.weighing {
            let timestamp: datetime_t = datetime_now()
            let message = controller_ua_scales_stop_new(timestamp, slot)
            if let message = message {
                sendMessage(message, State.idle)
            }
        }
    }

    @IBAction func startStop(_ sender: Any) {
        if controller == nil {
            disableStartButton()
            start()
        } else {
            stop()
        }
    }

    func enableStopButton() {
        DispatchQueue.main.async {
            self.startButton.setTitle("Arrêter", for: UIControl.State.normal)
            self.startButton.isEnabled=true
        }
    }

    func enableStartButton() {
        DispatchQueue.main.async {
            self.startButton.setTitle("Démarrer", for: UIControl.State.normal)
            self.startButton.isEnabled=true
        }
    }

    func disableStartButton() {
        DispatchQueue.main.async {
            self.startButton.setTitle("Connexion en cours", for: UIControl.State.normal)
            self.startButton.isEnabled=false
        }
    }

    func start() {
        let host=controllerIPAddress.text!.trimmingCharacters(in: CharacterSet.init(charactersIn: " "))
        defaults.set(host, forKey: "controllerIPAddress")
        queue.async {
            self.controller = fr_sbde_protocol_client_connect(host, self.controllerPort)
            if let error = fr_sbde_protocol_client_error(self.controller) {
                print("Connection Error \(String.init(cString: error))")
                self.stop()
                return
            }
            self.state = State.connected
            self.sendVersion(1)
            self.updateConnectionState()
            self.enableStopButton()
        }
    }

    func stop() {
        if !(state==State.disconnected) {
            queue.async {
                if self.state == State.weighing {
                    self.sendScalesStop(slot: 1)
                }
                fr_sbde_protocol_client_disconnect(self.controller)
                self.controller=nil
            }
            state=State.disconnected
            self.updateConnectionState()
            self.enableStartButton()
        }
    }

    func tick() {
    }

    @IBAction func fixTare(_ sender: Any) {
        queue.async {
            self.sendSetTare(slot: 1)
        }
        tareValue=grossWeight
        updateWeightDisplay()
    }

    func isDigit(_ character: Character) -> Bool {
        return (character == "0") || (character == "1") || (character == "2") || (character == "3") || (character == "4") || (character == "5") || (character == "6") || (character == "7") || (character == "8") || (character == "9")
    }

    func substring(_ string: String, _ start: Int, _ end: Int) -> String {
        let start = string.index(string.startIndex, offsetBy: start)
        let end = string.index(string.startIndex, offsetBy: end)
        let range = start..<end
        return String(string[range])
    }

    func keepNumber(_ text: String) -> String {
        let string = Array(text)
        let count = text.count
        var start = 0
        var end = count - 1
        while (start < end) && (!isDigit(string[start])) {
            start += 1
        }
        while (start < end) && (!isDigit(string[end])) {
            end -= 1
        }
        return substring(text, start, end + 1)

    }

    @IBAction func calibrate(_ sender: Any) {
        let number = keepNumber(self.weight.text!)
        if let mass = Float(number) {
            self.weight.text = number
            queue.async {
                self.sendCalibration(slot: 1, mass: mass)
            }
        }
    }

    @IBAction func weight(_ sender: Any) {
        if state==State.idle {
            queue.async {
                self.sendScalesStart(slot: 1)
            }
        }else if state == State.weighing {
            queue.async {
                self.sendScalesQuery(slot: 1)
            }
        }
        if self.continuous {
            queue.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(200)) {
                self.weight(sender)
            }
        }
    }

    @IBAction func toggleContinuousWeighting(_ sender: Any) {
        if continuous {
            continuous=false
        }else{
            continuous=true
            self.weight(self)
        }
    }

    func formatWeight(_ weight:Float)->String{
        return String.init(format:"%.3f kg",weight)
    }

    func receiveGrossWeight(_ weight:Float) {
        grossWeight=weight;
        updateWeightDisplay()
    }

    func updateWeightDisplay() {
        DispatchQueue.main.async {
            self.tare.text=self.formatWeight(self.tareValue)
            self.weight.text=self.formatWeight(self.grossWeight-self.tareValue)
        }
    }

    func updateConnectionState() {
        DispatchQueue.main.async {
            self.connectionState.text="\(self.state)"
        }
    }

    @IBAction func back() {
        RootViewController.rootViewController()!.showMenu()
        performSegue(withIdentifier: "tabs", sender: self)
        // self.dismiss(animated: true)
    }

}
