//
//  ViewController.swift
//  CamStamp
//
//  Created by Þorvaldur Rúnarsson on 17/02/2018.
//  Copyright © 2018 Thorvaldur. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

extension Comparable {
    func withMinimum(_ min: Self) -> Self {
        return max(min, self)
    }
    
    func withMaximum(_ max: Self) -> Self {
        return min(max, self)
    }
}

class ViewController: UIViewController, UINavigationControllerDelegate {

    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    
    let previewView = UIImageView(image: #imageLiteral(resourceName: "watermark"))
    
    let viewModel = ViewModel()
    
    let disposeBag = DisposeBag()

    let scaleValueKey = "scaleValueKey"

    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.addSubview(previewView)
        
        let lastValue = UserDefaults.standard.float(forKey: scaleValueKey)
        let initialSliderValue = lastValue == 0 ? 0.2 : lastValue
        slider.setValue(initialSliderValue, animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updatePreview(with: initialSliderValue)
        }
        
        viewModel.presentAlert
            .map { title in
                let alert = UIAlertController.init(title: title, message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                return alert
            }
            .subscribe(onNext: { [unowned self] in self.present($0, animated: true, completion: nil) })
            .disposed(by: disposeBag)

        viewModel.imageSubject
            .bind(to: imageView.rx.image)
            .disposed(by: disposeBag)
        
        viewModel.saveHidden
            .bind(to: saveButton.rx.isHidden)
            .disposed(by: disposeBag)
        
        cameraButton.rx.tap
            .subscribe(onNext:  { [unowned self] in
                guard let mediaTypes = UIImagePickerController.availableMediaTypes(for: .camera),
                    UIImagePickerController.isSourceTypeAvailable(.camera) else {
                        self.showAlert()
                        return
                }
                
                let controller = UIImagePickerController()
                controller.sourceType = .camera
                controller.allowsEditing = false
                
                controller.mediaTypes = mediaTypes
                
                controller.delegate = self.viewModel
                self.present(controller, animated: true)
            })
            .disposed(by: disposeBag)
        
        slider.rx.value
            .do(onNext: { [unowned self] in
                self.updatePreview(with: $0)
                UserDefaults.standard.set($0, forKey: self.scaleValueKey)
            })
            .bind(to: viewModel.watermarkScale)
            .disposed(by: disposeBag)
        
        saveButton.rx.tap
            .bind(to: viewModel.savePressed)
            .disposed(by: disposeBag)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func showAlert() {
        let alert = UIAlertController(title: "Cannot Get Camera", message: "Media type \"Camera\" not available", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func updatePreview(with scale: Float) {
        let newScale = CGFloat(scale)

        let fullSize = imageView.frame.size
        let margin = FilterManager.margin(for: fullSize)
        
        let previewWidth = (fullSize.width - (margin * 2)) * newScale
        let previewHeight = (fullSize.height - (margin * 2)) * newScale
        let x = fullSize.width - previewWidth - margin
        let y = fullSize.height - previewHeight - margin

        let frame = CGRect(x: x,
                           y: y,
                           width: previewWidth,
                           height: previewHeight)
        
        self.previewView.frame = frame
    }
}
