/*
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import Photos
import RxSwift

class PhotosViewController: UICollectionViewController {

  // MARK: public properties

  let bag = DisposeBag()
  
  var selectedPhotos: Observable<UIImage> {
    return selectedPhotosSubject.asObservable()
  }

  // MARK: private properties

  private lazy var photos = PhotosViewController.loadPhotos()
  private lazy var imageManager = PHCachingImageManager()

  fileprivate let selectedPhotosSubject = PublishSubject<UIImage>()

  private lazy var thumbnailSize: CGSize = {
    let cellSize = (self.collectionViewLayout as! UICollectionViewFlowLayout).itemSize
    return CGSize(width: cellSize.width * UIScreen.main.scale,
                  height: cellSize.height * UIScreen.main.scale)
  }()

  static func loadPhotos() -> PHFetchResult<PHAsset> {
    let allPhotosOptions = PHFetchOptions()
    allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    return PHAsset.fetchAssets(with: allPhotosOptions)
  }

  // MARK: View Controller

  override func viewDidLoad() {
    super.viewDidLoad()

    let authorized = PHPhotoLibrary.authorized.share()

    authorized
        // Мы дожидаемся возвращения true и если таковой есть то берём его через take
        /*
        First you use skipWhile(_:) to ignore all false elements. In case the user doesn’t grant access, your subscription’s onNext code will never get executed
        */
        .skipWhile({ $0 == false })
        /*
        Secondly, you chain another operator: take(1). Whenever a true comes through the filter, you take that one element and ignore everything else after it
        Хотя это не очень уже обязательный параметр, но для лучше понимания кода так будет лучше
        */
        .take(1)
        .subscribe(onNext: { [weak self] _ in
            self?.photos = PhotosViewController.loadPhotos()
            /*
            Нужно потому, что requestAuthorization делает onNext необязательно на главном потоке
            */
            DispatchQueue.main.async {
                self?.collectionView?.reloadData()
            }
        })
        .disposed(by: bag)

    authorized
        /*
        Выдаст один false, если было передано false, false
        */
        .distinctUntilChanged()
        // skip(1)
        /*
        Берём первый элемент с конца
        */
        .takeLast(1)
        .filter({ $0 == false })
        .subscribe(onNext: { [weak self] _ in
            guard let errorMessage = self?.errorMessage else { return }
            DispatchQueue.main.async(execute: errorMessage)
        })
        .disposed(by: bag)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    /*
    Your observable sequence of photos actually completes its purpose when the photo controller leaves the navigation stack
    */
    selectedPhotosSubject.onCompleted()
  }

  // MARK: - Actions -

  private func errorMessage() {
    showAlert(title: "No Access to Camera Roll",
              description: "You can grant access to Combinestogram from the Settings app")
        /*
        Если алерт провисел 5 секнуд и кнопка "Закрыть" не была нажата, то он автоматически сам disposed (будет вызван onDisposed)
        При нажатии на "Закрыт" будет вызван onCompleted в соответсвии с кодом showAlert
        */
        .debug("No Access Alert", trimOutput: false)
        .take(5.0, scheduler: MainScheduler.instance)
        .subscribe(onDisposed: { [weak self] in
            self?.dismiss(animated: true, completion: nil)
            _ = self?.navigationController?.popViewController(animated: true)
        })
        .disposed(by: bag)
  }

  // MARK: UICollectionView

  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return photos.count
  }

  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

    let asset = photos.object(at: indexPath.item)
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PhotoCell

    cell.representedAssetIdentifier = asset.localIdentifier
    imageManager.requestImage(for: asset,
                              targetSize: thumbnailSize,
                              contentMode: .aspectFill,
                              options: nil,
                              resultHandler: { image, _ in
      if cell.representedAssetIdentifier == asset.localIdentifier {
        cell.imageView.image = image
      }
    })

    return cell
  }

  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let asset = photos.object(at: indexPath.item)

    if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
      cell.flash()
    }

    imageManager.requestImage(for: asset,
                              targetSize: view.frame.size,
                              contentMode: .aspectFill,
                              options: nil,
                              resultHandler: { [weak self] image, info in
                                guard let image = image, let info = info else { return }
                                /*
                                In the event you received the full-size image, you call onNext(_) on your subject and provide it with the full photo
                                То есть проверяем тот случай, что нам пришло именно полноразмерная картинка
                                */
                                if let isThumbnail = info[PHImageResultIsDegradedKey as NSString] as? Bool, !isThumbnail {
                                  self?.selectedPhotosSubject.onNext(image)
                                }
    })
  }
}
