//
//  ViewController.swift
//  Pixels HDR
//
//  Created by Hexagons on 2019-03-18.
//  Copyright © 2019 Hexagons. All rights reserved.
//

import UIKit
import Pixels

class ViewController: UIViewController {

    var camera: CameraPIX!
    var final: PIX!
    
    var exposures: [CGFloat] {
        let count = 5
        return (0..<count).map({ i -> CGFloat in
            let fraction = CGFloat(i) / CGFloat(count - 1)
            return pow(fraction, 3.0) * 0.7 + 0.01
        })
    }
    struct FreezeExposure {
        let exposure: CGFloat
        let freeze: FreezePIX
    }
    var freezeExposures: [FreezeExposure] = []
    
    var combo = false
    var comboLevels: LevelsPIX!
    
    var button: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Pixels.main.bits = ._16
        
        camera = CameraPIX()
        camera.camRes = ._1080p
        camera.manualExposure = true
        camera.manualFocus = true

        final = camera
        final.view.frame = view.bounds
        final.view.liveTouch(active: false)
        view.addSubview(final.view)
        
        let bgColor = ColorPIX(res: ._1080p)
        bgColor.color = .black
        
        var allBlend: PIX & PIXOut = bgColor
        for (i, exposure) in exposures.enumerated() {
            
            let freeze = FreezePIX()
            freeze.inPix = camera
            
            let blend = BlendPIX()
            blend.mode = .add
            blend.inPixA = allBlend
            blend.inPixB = freeze * LiveFloat(0.5 + (1.0 - exposure))
            allBlend = blend
            
            let count = CGFloat(exposures.count)
            let w = view.bounds.width / count
            let h = (view.bounds.width / count) / (16 / 9)
            let x = (view.bounds.width / count) * CGFloat(i)
            let y = CGFloat(30.0)
            freeze.view.frame = CGRect(x: x, y: y, width: w, height: h)
            freeze.view.alpha = 0.0
            view.addSubview(freeze.view)
            
            let freezeExposure = FreezeExposure(exposure: exposure, freeze: freeze)
            freezeExposures.append(freezeExposure)
            
        }
        
        let allFinal = allBlend * LiveFloat(1.0 / CGFloat(freezeExposures.count))
        comboLevels = LevelsPIX()
        comboLevels.inPix = allFinal
        comboLevels.view.frame = view.bounds
        comboLevels.view.liveTouch(active: false)
        comboLevels.view.backgroundColor = .black
        comboLevels.brightness = 0.5
        comboLevels.gamma = 0.5
        view.addSubview(comboLevels!.view)
        comboLevels!.view.isHidden = true
        
        expose(at: 0.1)
        
        button = UIButton(type: .system)
        button.setTitle("Capture HDR Exposure Stack", for: .normal)
        button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        view.addSubview(button)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let u = touches.first!.location(in: view).x / view.bounds.width
        let v = touches.first!.location(in: view).y / view.bounds.height
        if combo {
            comboLevels?.brightness = LiveFloat(1.0 - v)
            comboLevels?.gamma = LiveFloat(u)
        } else {
            camera.focus = u
            expose(at: pow(1.0 - v, 3.0) * 0.7 + 0.01)
        }
    }
    
    @objc func buttonAction() {
        guard !combo else {
            for freezeExposure in freezeExposures {
                freezeExposure.freeze.freeze = false
                freezeExposure.freeze.view.alpha = 0.0
            }
            button.setTitle("Capture HDR Exposure Stack", for: .normal)
            comboLevels!.view.isHidden = true
            combo = false
            return
        }
        var index = 0
        func cap() {
            guard index < exposures.count else {
                expose(at: 0.1)
                wait(for: 0.5) {
                    self.combine()
                }
                return
            }
            self.capture(exposure: exposures[index]) {
                index += 1
                cap()
            }
        }
        cap()
        button.isEnabled = false
        button.setTitle("Capture in progress...", for: .normal)
    }
    
    func capture(exposure: CGFloat, done: @escaping () -> ()) {
        expose(at: exposure)
        wait(for: Double(exposure * camera.maxExposure + 0.5)) {
            for freezeExposure in self.freezeExposures {
                if freezeExposure.exposure == exposure {
                    freezeExposure.freeze.freeze = true
                    freezeExposure.freeze.view.alpha = 1.0
                }
            }
            self.wait(for: 0.25, done: {
                done()
            })
        }
    }
    
    func expose(at exposure: CGFloat) {
        camera.exposure = camera.minExposure + exposure * (camera.maxExposure - camera.minExposure)
        camera.iso = camera.minISO + exposure * (camera.maxISO - camera.minISO)
    }
    
    func combine() {
        combo = true
        comboLevels!.view.isHidden = false
        button.setTitle("Reset HDR Exposure Stack", for: .normal)
        button.isEnabled = true
    }
    
//    func save() {
//        guard let image = comboLevels.renderedImage else {
//            let alert = UIAlertController(title: "Texture Not Found", message: nil, preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
//            present(alert, animated: true, completion: nil)
//            return
//        }
//        let activityViewController = UIActivityViewController(activityItems: [image] , applicationActivities: nil)
//        activityViewController.popoverPresentationController?.sourceView = self.view
//        present(activityViewController, animated: true, completion: nil)
//    }
    
    func wait(for seconds: Double, done: @escaping () -> ()) {
        RunLoop.current.add(Timer(timeInterval: seconds, repeats: false, block: { _ in
            done()
        }), forMode: .common)
    }

}

