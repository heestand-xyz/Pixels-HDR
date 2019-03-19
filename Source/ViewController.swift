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
            return pow(fraction, 5.0) * 0.75
        })
    }
    struct FreezeExposure {
        let exposure: CGFloat
        let freeze: FreezePIX
    }
    var freezeExposures: [FreezeExposure] = []
    
    var combo = false
    var comboLevels: LevelsPIX?
    var comboView: UIView?
    var captureButton: UIButton!
    
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
            freeze.view.frame = CGRect(x: x, y: 30.0, width: width, height: height)
            view.addSubview(freeze.view)
            let freezeExposure = FreezeExposure(exposure: exposure, freeze: freeze)
            freezeExposures.append(freezeExposure)
        }
        
        expose(at: 0.1)
        
        captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture HDR Exposure Stack", for: .normal)
        captureButton.addTarget(self, action: #selector(captureHDR), for: .touchUpInside)
        view.addSubview(captureButton)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let u = touches.first!.location(in: view).x / view.bounds.width
        let v = touches.first!.location(in: view).y / view.bounds.height
        if combo {
            comboLevels?.brightness = LiveFloat((1.0 - v) * 4)
            comboLevels?.gamma = LiveFloat(u * 2)
        } else {
            camera.focus = u
            expose(at: pow(1.0 - v, 5.0) * 0.75)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        comboView?.removeFromSuperview()
//        for freezeExposure in freezeExposures {
//            freezeExposure.freeze.freeze = false
//        }
    }
    
    @objc func captureHDR() {
        guard !combo else { save(pix: comboLevels!); return }
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
        combo = true
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
        let allFinal = allBlend * LiveFloat(1.0 / CGFloat(freezeExposures.count)) * 0.1
        comboLevels = LevelsPIX()
        comboLevels!.inPix = allFinal
        comboLevels!.view.frame = view.bounds
        comboLevels!.view.liveTouch(active: false)
        view.insertSubview(comboLevels!.view, at: view.subviews.count - 2)
        comboView = comboLevels!.view
        captureButton.setTitle("Save HDR Exposure Stack", for: .normal)
    }
    
    func save(pix: PIX) {
        guard let image = pix.renderedImage else { return }
        let activityViewController = UIActivityViewController(activityItems: [image] , applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view
        present(activityViewController, animated: true, completion: nil)
    }
    
    func wait(for seconds: Double, done: @escaping () -> ()) {
        RunLoop.current.add(Timer(timeInterval: seconds, repeats: false, block: { _ in
            done()
        }), forMode: .common)
    }

}

