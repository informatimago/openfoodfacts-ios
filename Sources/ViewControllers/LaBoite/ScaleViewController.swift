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
    var grossWeight:Float=0.0
    var tareValue:Float=0.0

    var crlf=Data.init()
    var datetimeFormatter=ISO8601DateFormatter.init()
    let defaults=UserDefaults.init()
    let controllerPort=UInt16(SERVER_PORT)
    var controller:OpaquePointer?=nil
    enum State { case disconnected,connected,idle,weighing }
    var state=State.disconnected
    var queue=DispatchQueue.global(qos:.userInitiated)
    var continuous=false

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        datetimeFormatter=ISO8601DateFormatter.init()
        datetimeFormatter.formatOptions=[.withYear,.withMonth,.withDay,.withTime,.withTimeZone]
        controllerIPAddress.text=defaults.string(forKey:"controllerIPAddress") ?? defaultControllerIPAddress
        tareValue=0.0
        grossWeight=0.0
        updateWeightDisplay()
        updateConnectionState()
        continuousWeighting.setOn(false, animated:false)
        crlf=Data.init(capacity:2)
        crlf.append(contentsOf:[13,10])
        controllerIPAddress.delegate = self;
    }

    func textFieldShouldReturn(_ sender: UITextField)->Bool {
        sender.resignFirstResponder()
        return false
    }

    func sendMessage(_ message: UnsafeMutablePointer<controller_ua_message>,
                     _ newState:State){
        let ok=fr_sbde_protocol_client_send_message(controller, message)
        print("Send Message \(message.pointee.kind) -> \(ok)")
        free(message)
        if ok {
            state=newState
        } else {
            if let controller=controller {
                if let error=fr_sbde_protocol_client_error(controller) {
                    print("Send Message Error \(String.init(cString: error))")
                }
            }
            stop()
        }
        updateConnectionState()
        receiveMessage()
    }

    func receiveMessage() {
        let message=fr_sbde_protocol_client_receive_message(controller)
        print("Received Message \(String(describing: message?.pointee.kind))")
        if let message=message {
            switch(message.pointee.kind) {
            case controller_ua_message_version:
                if (!(message.pointee.message.version.version==1)) {
                    print("Bad version \(message.pointee.message.version.version)")
                }
                state=State.idle
            case controller_ua_message_scales_measure:
                receiveGrossWeight(message.pointee.message.scales_measure.mass)
            default:
                print("Bad Message Kind \(message.pointee.kind)")
            }
        } else {
            if let controller=controller {
                if let error=fr_sbde_protocol_client_error(controller) {
                    print("Receive Message Error \(String.init(cString: error))")
                }
            }
        }
        free(message)
    }

    func sendVersion(_ version: Int){
        print("sendVersion \(version) state=", state)
        if state==State.connected {
            let timestamp:datetime_t=datetime_now()
            let message=controller_ua_version_new(version,timestamp)
            if let message=message {
                sendMessage(message,State.idle)
            }
        }
    }

    func sendScalesStart(slot:Int){
        print("sendScalesStart \(slot) state=",state)
        if state==State.idle {
            let timestamp:datetime_t=datetime_now()
            let message=controller_ua_scales_start_new(timestamp,slot)
            if let message=message {
                sendMessage(message,State.weighing)
            }
        }
    }

    func sendScalesQuery(slot:Int){
        print("sendScalesQuery \(slot) state=",state)
        if state==State.weighing {
            let timestamp:datetime_t=datetime_now()
            let message=controller_ua_scales_query_new(timestamp,slot)
            if let message=message {
                sendMessage(message,State.weighing)
            }
        }
    }

    func sendScalesStop(slot:Int){
        print("sendScalesStop \(slot) state=",state)
        if state==State.weighing {
            let timestamp:datetime_t=datetime_now()
            let message=controller_ua_scales_stop_new(timestamp,slot)
            if let message=message {
                sendMessage(message,State.idle)
            }
        }
    }

    @IBAction func startStop(_ sender: Any) {
        if controller==nil {
            disableStartButton()
            start()
        }else{
            stop()
        }
    }

    func enableStopButton(){
        DispatchQueue.main.async {
            self.startButton.setTitle("Arrêter", for: UIControl.State.normal)
            self.startButton.isEnabled=true
        }
    }

    func enableStartButton(){
        DispatchQueue.main.async {
            self.startButton.setTitle("Démarrer", for: UIControl.State.normal)
            self.startButton.isEnabled=true
        }
    }

    func disableStartButton(){
        DispatchQueue.main.async {
            self.startButton.setTitle("Connexion en cours", for: UIControl.State.normal)
            self.startButton.isEnabled=false
        }
    }


    func start(){
        let host=controllerIPAddress.text!.trimmingCharacters(in: CharacterSet.init(charactersIn:" "))
        defaults.set(host,forKey:"controllerIPAddress")
        queue.async {
            self.controller=fr_sbde_protocol_client_connect(host,self.controllerPort);
            if let error=fr_sbde_protocol_client_error(self.controller) {
                print("Connection Error \(String.init(cString:error))")
                self.stop()
                return
            }
            self.state=State.connected;
            self.sendVersion(1)
            self.updateConnectionState()
            self.enableStopButton()
            self.receiveMessage()
        }
    }

    func stop(){
        if !(state==State.disconnected) {
            queue.async {
                if self.state==State.weighing {
                    self.sendScalesStop(slot:1)
                }
                fr_sbde_protocol_client_disconnect(self.controller);
                self.controller=nil
            }
            state=State.disconnected
            self.updateConnectionState()
            self.enableStartButton()
        }
    }

    func tick(){
    }

    @IBAction func fixTare(_ sender: Any) {
        tareValue=grossWeight
        updateWeightDisplay()
    }

    @IBAction func weight(_ sender: Any) {
        if state==State.idle {
            queue.async {
                self.sendScalesStart(slot:1)
            }
        }else if state==State.weighing {
            queue.async {
                self.sendScalesQuery(slot:1)
            }
        }
        if self.continuous {
            queue.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(200)){
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

    func receiveGrossWeight(_ weight:Float){
        grossWeight=weight;
        updateWeightDisplay()
    }

    func updateWeightDisplay(){
        DispatchQueue.main.async {
            self.tare.text=self.formatWeight(self.tareValue)
            self.weight.text=self.formatWeight(self.grossWeight-self.tareValue)
        }
    }

    func updateConnectionState(){
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
