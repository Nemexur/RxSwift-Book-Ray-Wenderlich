import RxSwift

import UIKit
import RxSwift

//More importantly, an observable won’t send events until it has a subscriber. Remember that an observable is really a sequence definition; subscribing to an observable is really more like calling next() on an Iterator in the Swift standard library
//
// let sequence = 0..<3
// var iterator = sequence.makeIterator()
// while let n = iterator.next() {
// print(n)
// }
// Prints:
// 0 1 2

enum MyError: Error {
    case anError
}

example(of: "just, of, from") {
    // 1
    let one = 1
    let two = 2
    let three = 3
    // 2
    let observable: Observable<Int> = Observable<Int>.just(one)
    /*
     just is aptly named, since all it does is create an observable sequence containing just a single element
     */
    let observable2 = Observable.of(one, two, three)
    /*
     That’s because the of operator takes a variadic parameter of the type inferred by the elements passed to it
     То есть мы это такой параметр, которому можно подавать различное количество значений (в нашем случае различное количество значениц Int)
     */
    let observable3 = Observable.of([one, two, three])
    /*
     The just operator can also take an array as its single element, which may seem a little weird at first. However, it’s the array that is the single element, not its contents
     То есть наш массив будет единственным элементом
     */
    let observable4 = Observable.from([one, two, three])
}

example(of: "subscribe") {
    let one = 1
    let two = 2
    let three = 3
    let observable = Observable.of(one, two, three)
    observable.subscribe(onNext: { element in
        print(element)
    })
}

example(of: "empty") {
    let observable = Observable<Void>.empty()
    observable
        .subscribe(
            // 1
            onNext: { element in
                print(element)
        },
            // 2
            onCompleted: {
                print("Completed")
        } )
}

/*
 As opposed to the empty operator, the never operator creates an observable that doesn’t emit anything and never terminates. It can be use to represent an infinite duration
 */
example(of: "never") {
    let observable = Observable<Any>.never()
    observable
        .subscribe(
            onNext: { element in
                print(element)
        },
            onCompleted: {
                print("Completed")
        }
    )
}

example(of: "range") {
    // 1
    let observable = Observable<Int>.range(start: 1, count: 10)
    observable
        .subscribe(onNext: { i in
            // 2
            let n = Double(i)
            let fibonacci = Int(((pow(1.61803, n) - pow(0.61803, n)) /
                2.23606).rounded())
            print(fibonacci)
        })
}

/*
 To explicitly cancel a subscription, call dispose() on it. After you cancel the subscription, or dispose of it, the observable in the current example will stop emitting events
 */
example(of: "dispose") {
    // 1
    let observable = Observable.of("A", "B", "C")
    // 2
    let subscription = observable.subscribe { event in
        // 3
        print(event)
    }
    subscription.dispose()
}

/*
 f you forget to add a subscription to a dispose bag, or manually call dispose on it when you’re done with the subscription, or in some other way cause the observable to terminate at some point, you will probably leak memory
 */
example(of: "DisposeBag") {
    // 1
    let disposeBag = DisposeBag()
    // 2
    Observable.of("A", "B", "C")
        .subscribe { // 3
            print($0) }
        .disposed(by: disposeBag) // 4
}

/*
 Create предоставляет нам более явную запись для обзёрвера, где мы прописываем весь цикл его жизни и то, что он будет возвращать самостоятельно
 */
/*
 What would happen if you emitted neither a .completed nor a .error event, and didn’t add the subscription to disposeBag? Comment out the observer.onError, observer.onCompleted and addDisposableTo(disposeBag) lines of code to find out
 Тогда будет мемори лик. И наш обзервер никогда не уйдёт из памяти
 */
example(of: "create") {
    let disposeBag = DisposeBag()
    Observable<String>.create { observer in
        // 1
        observer.onNext("1")
        // 2
        // Если вызвать здесь ошибку, то наш комплетед дальше не вызовется и обзервер уйдёт из памяти (будет вызван диспоуз)
        //        observer.onError(MyError.anError)
        observer.onCompleted()
        // 3
        // После того, как мы объявили onCompleted это не вызовется. Далее идёт сразу вызов метода Disposed
        observer.onNext("?")
        // 4
        return Disposables.create()
        }.subscribe(
            onNext: { print($0) },
            onError: { print($0) },
            onCompleted: { print("Completed") },
            onDisposed: { print("Disposed") }
    )
    //        .disposed(by: disposeBag)
}

/*
 За счёт flip мы каждый постоянно меняем значение для каждого подписывающегося subscriber. Each time you subscribe to factory, you get the opposite observable
 */
example(of: "deferred") {
    let disposeBag = DisposeBag()
    // 1
    var flip = false
    // 2
    let factory: Observable<Int> = Observable.deferred {
        // 3
        flip = !flip
        // 4
        if flip {
            return Observable.of(1, 2, 3)
        } else {
            return Observable.of(4, 5, 6)
        }
    }
    for _ in 0...3 {
        factory.subscribe(onNext: {
            print($0, terminator: "")
        })
            .disposed(by: disposeBag)
        print()
    }
}

// MARK: - Challenge

example(of: "never challenge") {
    let disposeBag = DisposeBag()
    let observable = Observable<Any>.never()
    /*
     do позволяет сделать некоторый side effect. Мы никак не поменяем элементы нашего обзервера, но мы можем отреаигоравать каким-то обрзаом на любое событие, происходящее с обзервером. Допустим нам нужно как-то обновить UI, если мы подписались на события, через do оператор можно это совершить
     */
    observable
        .do(onNext: {
            print("onNext: \($0)")
        }, onError: {
            print("onError: \($0.localizedDescription)")
        }, onCompleted: {
            print("onCompleted")
        }, onSubscribe: {
            print("onSubscribe")
        }, onSubscribed: {
            print("onSubscribed")
        }, onDispose: {
            print("onDispose")
        })
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}

example(of: "debug operator") {
    let disposeBag = DisposeBag()
    let observable = Observable<Any>.never()
    /*
     Работает примерно также как do вот только мы никак не можем реагировать на события и просто принтим какое событие произошло для некоторого идентификатора
     */
    observable
        .debug("debug example", trimOutput: false)
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}
