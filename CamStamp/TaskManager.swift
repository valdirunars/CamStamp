//
//  TaskManager.swift
//  CamStamp
//
//  Created by Þorvaldur Rúnarsson on 19/02/2018.
//  Copyright © 2018 Thorvaldur. All rights reserved.
//

import Photos
import RxSwift
import UIKit

enum InputTask {
    case fetchImage(PHAsset)
    case saveImage(UIImage)
    case requestAuthorization(UIImage)
}

enum OutputTask {
    case fetchImage(UIImage)
    case saveImage(Bool)
    case requestAuthorization(Bool, UIImage)
}

final class TaskManager {
    
    let input = PublishSubject<InputTask>()
    let output = PublishSubject<OutputTask>()
    
    let isWorking = BehaviorSubject(value: false)
    
    private let disposeBag = DisposeBag()

    init() {
        
        input.do(onNext: { [unowned self] _ in self.isWorking.onNext(true) })
            .subscribe(onNext: start)
            .disposed(by: disposeBag)

        output.subscribe(onNext: { [unowned self] _ in self.isWorking.onNext(false) })
            .disposed(by: disposeBag)
    }
    
    func start(_ task: InputTask) {
        switch task {
        case .fetchImage(let asset):
            
            let size = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
            let manager = PHImageManager.default()
            let option = PHImageRequestOptions()
            option.isNetworkAccessAllowed = true
            option.isSynchronous = false
            option.deliveryMode = .highQualityFormat
            manager.requestImage(for: asset,
                                 targetSize: size,
                                 contentMode: .aspectFit,
                                 options: option,
                                 resultHandler: { (result, info) -> Void in
                self.output.onNext(.fetchImage(result!))
            })
        case .saveImage(let image):
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
                    }) { [unowned self] success, error in
                        self.output.onNext(.saveImage(success))
                    }
                }
            }
        case .requestAuthorization(let img):
            PHPhotoLibrary.requestAuthorization({ [unowned self] status in
                self.output.onNext(.requestAuthorization(status == .authorized, img))
            })
        }
    }
}
