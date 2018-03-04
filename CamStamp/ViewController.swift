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
import NVActivityIndicatorView
import Lorikeet

class ViewController: UIViewController, UINavigationControllerDelegate {

    @IBOutlet weak var container: UIView!
    @IBOutlet weak var galleryButton: UIButton!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    
    let previewView = UIImageView(image: #imageLiteral(resourceName: "watermark"))
    
    var indicator: NVActivityIndicatorView!
    
    let viewModel = ViewModel()
    
    let presentMediaTypePicker = PublishSubject<UIImagePickerControllerSourceType>()
    
    var disposeBag = DisposeBag()

    let scaleValueKey = "scaleValueKey"

    override func viewDidLoad() {
        super.viewDidLoad()
        
        previewView.contentMode = .scaleAspectFit
        imageView.addSubview(previewView)
        
        let lastValue = UserDefaults.standard.float(forKey: scaleValueKey)
        let initialSliderValue = lastValue == 0 ? 0.2 : lastValue
        slider.setValue(initialSliderValue, animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updatePreview(with: initialSliderValue)
        }
        
        setupRx()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupColors()
    }
    
    func resetupRx() {
        disposeBag = DisposeBag()
        setupRx()
    }
    
    func setupRx() {
        setupRxForImagePicking()
        setupRxForViewModel()

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

        let image = imageView.image
        resetupRx()
        viewModel.imageSubject.onNext(image)
    }
    
    func setupRxForViewModel() {
        viewModel.presentAlert
            .subscribe(onNext: showAlert)
            .disposed(by: disposeBag)
        
        viewModel.imageSubject
            .filter { $0 != nil }
            .subscribeOn(MainScheduler.instance)
            .subscribe(onNext: { [unowned self] image in
                UIView.transition(with: self.imageView,
                                  duration: 0.3,
                                  options: .transitionCrossDissolve,
                                  animations: {
                                    self.imageView.image = image
                                    let newScale = (try? self.viewModel.watermarkScale.value()) ?? 0.2
                                    self.updatePreview(with: newScale)
                                  }, completion: nil)
            })
            .disposed(by: disposeBag)

        viewModel.taskManager.isWorking
            .subscribeOn(MainScheduler.instance)
            .subscribe(onNext: setIndicatorState)
            .disposed(by: disposeBag)
        
        viewModel.taskManager.isWorking.skip(1)
            .debounce(0.2, scheduler: MainScheduler.instance)
            .bind(to: saveButton.rx.isHidden)
            .disposed(by: disposeBag)
        
        saveButton.rx.tap.map { _ in true }
            .bind(to: saveButton.rx.isHidden)
            .disposed(by: disposeBag)
    }
    
    func setupRxForImagePicking() {
        galleryButton.rx.tap
            .map(imagePicker)
            .subscribe(onNext: { [unowned self] actionSheet in
                self.present(actionSheet, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
        
        
        presentMediaTypePicker
            .map(cameraPicker)
            .subscribe(onNext: { [unowned self] in
                self.present($0, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
    }
    
    func setupColors() {
        container.backgroundColor = .darkGray
        saveButton.backgroundColor = .darkGray
        let base = UIColor(hue: CGFloat(arc4random_uniform(360))/360.0,
                           saturation: 0.5,
                           brightness: 0.75,
                           alpha: 1)
        imageView.backgroundColor = base

        let fg = base.lkt.complimentaryColor

        galleryButton.tintColor = fg
        slider.tintColor = fg
        saveButton.setTitleColor(fg, for: .normal)
        
    }
}
