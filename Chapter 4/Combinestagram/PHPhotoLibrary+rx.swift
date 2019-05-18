import Foundation
import Photos
import RxSwift

extension PHPhotoLibrary {
  static var authorized: Observable<Bool> {
    return Observable.create({ observer in
      DispatchQueue.main.async {
        /*
        Если пользователь до этого уже вошёл в фото, то возвращаем true
        */
        if authorizationStatus() == .authorized {
          observer.onNext(true)
          observer.onCompleted()
        } else {
            /*
            Если пользовательно до этого не вошёл в фото, то запрашиваем доступ и возвращаём в итоге результат его выбора
            */
          observer.onNext(false)
          requestAuthorization({ newStatus in
            observer.onNext(newStatus == .authorized)
            observer.onCompleted()
          })
        }
      }

      return Disposables.create()
    })
  }
}
