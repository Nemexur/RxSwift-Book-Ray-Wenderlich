import RxSwift
import UIKit

/*
Когда мы получаем .error or .completed, то мы обязательно потом вызывается dispose, то есть мы удаляем стрим (он больше ничего не даст)
*/
extension UIViewController {
    func showAlert(title: String, description: String?) -> Observable<Void> {
        return Observable.create({ [weak self] observer in
            let alert = UIAlertController(title: title, message: description, preferredStyle: .alert)
            let closeAction = UIAlertAction(title: "Close", style: .default, handler: { _ in
                observer.onCompleted()
            })
            alert.addAction(closeAction)
            self?.present(alert, animated: true, completion: nil)
            return Disposables.create {
                // Этот код будет выполнен после вызова функции dispose (run upon - начинаться после)
                alert.dismiss(animated: true, completion: nil)
            }
        })
    }
}
