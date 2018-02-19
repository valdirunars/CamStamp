//
//  ViewModel+Save.swift
//  CamStamp
//
//  Created by Þorvaldur Rúnarsson on 18/02/2018.
//  Copyright © 2018 Thorvaldur. All rights reserved.
//

import Photos
import UIKit
import RxSwift

extension ViewModel {
    func savePhoto(_ image: UIImage, completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let url = URL(fileURLWithPath: "\(documentsPath)/tempFile.jpg")
            
            DispatchQueue.main.async {
                
                UIGraphicsBeginImageContext(image.size)
                
                image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
                
                let convertibleImage = UIGraphicsGetImageFromCurrentImageContext()!
                
                UIGraphicsEndImageContext()
                
                let data = UIImagePNGRepresentation(convertibleImage)!
                try! data.write(to: url, options: .atomic)
                
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }) { [weak self] success, error in

                    completion?(success)
                    self?.presentAlert.onNext(success ? "Successfully saved photo"
                        : "Failed: \(error?.localizedDescription ?? "")")
                }
            }
        }
    }
}
