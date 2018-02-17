//
//  FilterManager.swift
//  CamStamp
//
//  Created by Þorvaldur Rúnarsson on 17/02/2018.
//  Copyright © 2018 Thorvaldur. All rights reserved.
//

import Foundation
import CoreImage
import RxSwift

final class FilterManager {
    static let watermark = CIImage(image: #imageLiteral(resourceName: "watermark"))!

    let input: Observable<UIImage>
    
    let watermarkScale: Observable<Float>
    
    let output = BehaviorSubject<UIImage?>(value: nil)
    
    let disposeBag = DisposeBag()

    init(inputImage: Observable<UIImage?>,
         watermarkScale: Observable<Float>) {

        self.input = inputImage
            .filter { $0 != nil }
            .map { $0! }
        
        self.watermarkScale = watermarkScale
        
        input.map { $0.normalized() }
            .flatMap { [weak self] image -> Observable<(UIImage, Float)> in
                let scale = self?.watermarkScale ?? .just(0.2)
                return Observable.combineLatest(Observable.just(image), scale)
            }
            .throttle(0.2, scheduler: MainScheduler.instance)
            .map { args in
                let (image, wScale) = args
                
                let watermarkScale = CGFloat(wScale)
                
                let ciImage = CIImage(image: image)
                
                let filter = CIFilter(name: "CISourceOverCompositing")!
                filter.setValue(self.watermark(for: image, watermarkScale: watermarkScale),
                                forKey: kCIInputImageKey)
                filter.setValue(ciImage,
                                forKey: kCIInputBackgroundImageKey)
                return filter.outputImage!
            }
            .map { UIImage(ciImage: $0) }
            .subscribe(output)
            .disposed(by: disposeBag)
    }
    
    static func margin(for size: CGSize) -> CGFloat {
        return size.width * 0.015
    }
    
    func watermark(for image: UIImage, watermarkScale: CGFloat) -> CIImage {
        let margin = FilterManager.margin(for: image.size)

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        let watermarkSize = CGSize(width: (image.size.width - margin * 2) * watermarkScale,
                                   height: (image.size.width - margin * 2) * watermarkScale)
        
        let rect = CGRect(x: image.size.width - watermarkSize.width - margin,
                          y: image.size.height - watermarkSize.height - margin,
                          width: watermarkSize.width, height: watermarkSize.height)
        #imageLiteral(resourceName: "watermark").draw(in: rect)

        guard let output = UIGraphicsGetImageFromCurrentImageContext() else {
            fatalError("Failed to produce watermark")
        }

        return CIImage(image: output)!
    }
}

extension UIImage {
    func normalized() -> UIImage {
        guard self.imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(self.size, true, self.scale)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext();
        guard let normalized = normalizedImage else { return self }
        return normalized
    }
}
