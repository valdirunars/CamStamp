//
//  UIKit+extensions.swift
//  CamStamp
//
//  Created by Þorvaldur Rúnarsson on 18/02/2018.
//  Copyright © 2018 Thorvaldur. All rights reserved.
//

import UIKit
import AVFoundation
import BSImagePicker
import NVActivityIndicatorView

extension UIViewController {
    func showAlert(title: String) {
        present(alert(with: title), animated: true, completion: nil)
    }
    
    func alert(with title: String) -> UIAlertController {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        return alert
    }
}

extension ViewController {
    func imagePicker() -> UIAlertController {
        let actionSheet = UIAlertController(title: "Select Option", message: nil, preferredStyle: .actionSheet)
        let galleryAction = UIAlertAction(title: "Gallery", style: .default, handler: { [unowned self] _ in
            self.bs_presentImagePickerController(BSImagePickerViewController(), animated: true,
                                                 select: nil,
                                                 deselect: nil,
                                                 cancel: nil,
                                                 finish: { assets in
                                                    DispatchQueue.main.async {
                                                        self.viewModel.assets
                                                            .onNext(assets)
                                                    }
            },
                                                 completion: nil)
        })
        
        let cameraAction = UIAlertAction(title: "Camera", style: .default, handler: { [unowned self] _ in
            self.presentMediaTypePicker.onNext(.camera)
        })
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        actionSheet.addAction(galleryAction)
        actionSheet.addAction(cameraAction)
        actionSheet.addAction(cancel)
        return actionSheet
    }
    
    func cameraPicker(mediaType: UIImagePickerControllerSourceType) -> UIViewController {
        guard let mediaTypes = UIImagePickerController.availableMediaTypes(for: mediaType),
            UIImagePickerController.isSourceTypeAvailable(mediaType) else {
                return alert(with: "Cannot Get Camera")
        }
        
        let controller = UIImagePickerController()
        controller.sourceType = mediaType
        controller.allowsEditing = false
        
        controller.mediaTypes = mediaTypes
        
        controller.delegate = self.viewModel
        return controller
    }
    
    func setIndicatorState(_ state: Bool) {
        DispatchQueue.main.async {
            if state {
                let frame = self.imageView.frame
                let spinSize: CGFloat = 60
                let spinFrame = CGRect(x: (frame.size.width / 2.0) - (spinSize / 2.0),
                                       y: (frame.size.height / 2.0) - (spinSize / 2.0),
                                       width: spinSize,
                                       height: spinSize)
                self.indicator = NVActivityIndicatorView(frame: spinFrame,
                                                         type: .squareSpin,
                                                         color: .white)
                self.imageView.addSubview(self.indicator)
                self.indicator.startAnimating()
            } else {
                self.indicator?.stopAnimating()
                self.indicator?.removeFromSuperview()
            }
        }
    }
    
    func updatePreview(with scale: Float) {
        let newScale = CGFloat(scale)
        
        DispatchQueue.main.async { [weak self] in
            guard let strong = self else { return }
            let imageFrame = AVMakeRect(aspectRatio: strong.imageView.image?.size ?? strong.imageView.frame.size,
                                        insideRect: strong.imageView.bounds)
            
            let margin = FilterManager.margin(for: imageFrame.size)
            
            let length = min(imageFrame.size.width, imageFrame.size.height)
            
            let watermark = #imageLiteral(resourceName: "watermark")
            let previewWidth = length * newScale
            let previewHeight = previewWidth * watermark.size.height / watermark.size.width
            let x = imageFrame.minX + (imageFrame.size.width - previewWidth - margin)
            let y = imageFrame.minY + (imageFrame.size.height - previewHeight - margin)
            
            let frame = CGRect(x: x,
                               y: y,
                               width: previewWidth,
                               height: previewHeight)
            
            
            UIView.animate(withDuration: 0.0167, animations: { [weak strong] in
                strong?.previewView.frame = frame
            })
        }
        
    }
}

