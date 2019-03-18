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
        let count = 12
        return (0..<count).map({ i -> CGFloat in
            let fraction = CGFloat(i) / CGFloat(count - 1)
            return pow(fraction, 3.0) * 0.75
        })
    }
    struct FreezeExposure {
        let exposure: CGFloat
        let freeze: FreezePIX
    }
    var freezeExposures: [FreezeExposure] = []
    
    var comboView: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Pixels.main.bits = ._16
        
        camera = CameraPIX()
        camera.manualExposure = true
        camera.manualFocus = true

        final = camera
        final.view.frame = view.bounds
        final.view.liveTouch(active: false)
        view.addSubview(final.view)
        
        for (i, exposure) in exposures.enumerated() {
            let freeze = FreezePIX()
            freeze.inPix = camera
            let count = CGFloat(exposures.count)
            let x = (view.bounds.width / count) * CGFloat(i)
            let width = view.bounds.width / count
            let height = (view.bounds.width / count) / (16 / 9)
            freeze.view.frame = CGRect(x: x, y: 0.0, width: width, height: height)
            view.addSubview(freeze.view)
            let freezeExposure = FreezeExposure(exposure: exposure, freeze: freeze)
            freezeExposures.append(freezeExposure)
        }
        
        expose(at: 0.1)
        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let u = touches.first!.location(in: view).x / view.bounds.width
        camera.focus = u
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        comboView?.removeFromSuperview()
//        for freezeExposure in freezeExposures {
//            freezeExposure.freeze.freeze = false
//        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
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
    }
    
    func capture(exposure: CGFloat, done: @escaping () -> ()) {
        expose(at: exposure)
        wait(for: Double(exposure * camera.maxExposure + 0.5)) {
            for freezeExposure in self.freezeExposures {
                if freezeExposure.exposure == exposure {
                    freezeExposure.freeze.freeze = true
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
        let bgColor = ColorPIX(res: .fullscreen)
        bgColor.color = .black
        var allBlend: PIX & PIXOut = bgColor
        for freezeExposure in freezeExposures {
            let blend = BlendPIX()
            blend.mode = .add
            blend.inPixA = allBlend
            blend.inPixB = freezeExposure.freeze * LiveFloat(0.5 + 1.0 - freezeExposure.exposure)
            allBlend = blend
        }
        let allFinal = allBlend * LiveFloat(1.0 / CGFloat(freezeExposures.count)) * 0.15
        allFinal.view.frame = view.bounds
        allFinal.view.liveTouch(active: false)
        view.addSubview(allFinal.view)
        comboView = allFinal.view
    }
    
    func wait(for seconds: Double, done: @escaping () -> ()) {
        RunLoop.current.add(Timer(timeInterval: seconds, repeats: false, block: { _ in
            done()
        }), forMode: .common)
    }

}

