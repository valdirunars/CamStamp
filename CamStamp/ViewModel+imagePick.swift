//
//  ViewModel+imagePick.swift
//  CamStamp
//
//  Created by Þorvaldur Rúnarsson on 18/02/2018.
//  Copyright © 2018 Thorvaldur. All rights reserved.
//

import UIKit

extension ViewModel: UIImagePickerControllerDelegate  {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        var pickedImage: UIImage?
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            pickedImage = image
        }
        
        guard let image = pickedImage else { return }
        
        print(image.imageOrientation.rawValue)
        
        assets.onNext([])
        imageSubject.onNext(image)
        
        picker.dismiss(animated: true, completion: nil)
        
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
