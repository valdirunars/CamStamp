//
//  ViewModel.swift
//  CamStamp
//
//  Created by Þorvaldur Rúnarsson on 17/02/2018.
//  Copyright © 2018 Thorvaldur. All rights reserved.
//

import Foundation
import RxSwift
import Photos

final class ViewModel: NSObject, UINavigationControllerDelegate {
    let imageSubject = BehaviorSubject<UIImage?>(value: nil)
    let watermarkScale = BehaviorSubject<Float>(value: 0.2)
    let savePressed = PublishSubject<Void>()
    
    let presentAlert = PublishSubject<String>()

    let disposeBag = DisposeBag()
    
    lazy var filterManager = FilterManager(inputImage: self.imageSubject,
                                           watermarkScale: watermarkScale)
    
    override init() {
        super.init()

        savePressed.withLatestFrom(filterManager.output.filter { $0 != nil }.map { $0! })
            .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribeOn(MainScheduler.instance)
            .subscribe(onNext: { [unowned self] _ in
                if PHPhotoLibrary.authorizationStatus() != .authorized {
                    PHPhotoLibrary.requestAuthorization({ status in
                        if status == .authorized {
                            self.savePhoto()
                        } else {
                            self.presentAlert.onNext("Failed to save photo")
                        }
                    })
                } else {
                    self.savePhoto()
                }
            })
            .disposed(by: disposeBag)
    }
    
    func savePhoto() {
        DispatchQueue.global(qos: .background).async {

            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let url = URL(fileURLWithPath: "\(documentsPath)/tempFile.jpg")

            DispatchQueue.main.async {
                let image = (try! self.filterManager.output.value())!

                UIGraphicsBeginImageContext(image.size)
                
                image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
                
                let convertibleImage = UIGraphicsGetImageFromCurrentImageContext()!
                
                UIGraphicsEndImageContext()
                
                let data = UIImagePNGRepresentation(convertibleImage)!
                try! data.write(to: url, options: .atomic)

                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }) { success, error in
                    self.presentAlert.onNext(success ? "SUCCESS"
                                                     : "FAILED: \(error?.localizedDescription ?? "")")
                }
            }
        }
    }
}

extension ViewModel {
    var saveHidden: Observable<Bool> {
        return imageSubject.map { $0 == nil }
    }
}

extension ViewModel: UIImagePickerControllerDelegate  {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        var pickedImage: UIImage?
        if let editedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            pickedImage = editedImage
        } else if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            pickedImage = image
        }
        
        guard let image = pickedImage else { return }

        print(image.imageOrientation.rawValue)
        
        imageSubject.onNext(image)
        
        picker.dismiss(animated: true, completion: nil)
        
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
