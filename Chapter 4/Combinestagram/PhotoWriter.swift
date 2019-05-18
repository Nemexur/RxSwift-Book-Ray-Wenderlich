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

import Foundation
import UIKit
import RxSwift

/*
To wrap up, you’ll create your own custom Observable and turn a plain function into a reactive class
Здесь мы пробуем обернуть некоторую функцию под Rx, чтобы она стала рекативной
*/

class PhotoWriter: NSObject {
    typealias Callback = (NSError?) -> Void
    private let callback: Callback
    
    private init(callBack: @escaping Callback) {
        self.callback = callBack
    }
    
    /*
    The new method features all the parameters UIImageWriteToSavedPhotosAlbum(_, _, _, _) provides to its callback
    */
    @objc func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
        callback(error)
    }

    /*
    Its job is to provide the implementation of calling subscribe on the observable. In other words, it defines all the events that will be emitted to subscribers
    AnyObserver is a generic type that facilitates(облегчает) adding values onto an observable sequence, which will then be emitted to subscribers
    Фактически это при вызове create мы создаём свой собственный обзервер, который необходимо правильно настроить, чтобы не было ликов
    */
    static func save(_ image: UIImage) -> Observable<Void> {
        // Возвращам информацию о состоянии сохранения прошла ли она успешно или нет, который будет вызван сразу после загрузки, то есть после UIImageWriteToSavedPhotosAlbum (будет вызван этот же callback с ошибкой в didFinishSavingWithError)
      return Observable.create({ observer in
        let writer = PhotoWriter(callBack: { error in
          if let error = error {
            observer.onError(error)
          } else {
            observer.onCompleted()
          }
        })

        UIImageWriteToSavedPhotosAlbum(image,
                                       writer,
                                       #selector(PhotoWriter.image(_:didFinishSavingWithError:contextInfo:)),
                                       nil)
        return Disposables.create()
      })
    }
}

