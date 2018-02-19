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
    
    let assets = BehaviorSubject<[PHAsset]>(value: [])
    
    let presentAlert = PublishSubject<String>()
    
    let disposeBag = DisposeBag()
    
    let filterManager = FilterManager()
    let taskManager = TaskManager()

    override init() {
        super.init()
            
        assets
            .filter { $0.isEmpty == false }
            .throttle(0.1, scheduler: MainScheduler.instance)
            .map {
                let asset = $0.first!
                return InputTask.fetchImage(asset)
            }
            .subscribe(taskManager.input)
            .disposed(by: disposeBag)
        
        let image = imageSubject
            .filter { i in i != nil }
            .map { i in i! }
        
        savePressed
            .map { _ in true }
            .withLatestFrom(image)
            .withLatestFrom(watermarkScale.map(CGFloat.init)) { i, s in (i, s) }
            .map(filterManager.output)
            .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribeOn(MainScheduler.instance)
            .map { image -> InputTask in
                PHPhotoLibrary.authorizationStatus() != .authorized ? .requestAuthorization(image)
                    : .saveImage(image)
            }
            .subscribe(taskManager.input)
            .disposed(by: disposeBag)
        
        taskManager.output
            .subscribe(onNext: { [unowned self] output in
                switch output {
                case .fetchImage(let img):
                    self.imageSubject.onNext(img)
                case .saveImage(let success):
                    self.presentAlert.onNext(success ? "Successfully saved image"
                        : "Failed to save image")
                    var assets = try! self.assets.value()
                    if assets.count >= 2 {
                        assets.remove(at: 0)
                        self.assets.onNext(assets)
                    }
                case .requestAuthorization(let success, let img):
                    if success {
                        self.taskManager.input.onNext(.saveImage(img))
                    } else {
                        self.presentAlert.onNext("Could not save image")
                    }
                }
            })
            .disposed(by: disposeBag)
    }
}
