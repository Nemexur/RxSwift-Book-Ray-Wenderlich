import RxSwift

import UIKit
import RxSwift
import RxCocoa

//Observables are a fundamental part of RxSwift, but a common need when developing apps is to manually add new values onto an observable at runtime that will then be emitted to subscribers. What you want is something that can act as both an observable and as an observer. And that something is called a Subject

// То есть Subject позволяет добавлять объекты, когда нам нужно => он mutable
/*
 There are four subject types in RxSwift:
 • PublishSubject: Starts empty and only emits new elements to subscribers.
 • BehaviorSubject: Starts with an initial value and replays it or the latest element to new subscribers.
 • ReplaySubject: Initialized with a buffer size and will maintain a buffer of elements up to that size and replay it to new subscribers.
 • Variable: Wraps a BehaviorSubject, preserves its current value as state, and replays only the latest/initial value to new subscribers.
 */
example(of: "PublishSubject") {
    /*
     It’s aptly named, because, like a newspaper publisher, it will receive information and then turn around and publish it to subscribers, possibly after modifying that information in some way first. It’s of type String, so it can only receive and publish strings
     */
    /*
     В общем этот объект одновременно является и обзервером и подписчиком
     */
    let subject = PublishSubject<String>()
    let subscriptionOne = subject
        .subscribe(onNext: { string in
            print(string)
        })
    /*
     До этого он ничего не печатал, так как нечего было печать. Обзервер был пустой
     */
    // Есть два способа, чтобы закинуть событие, о котором будет сообщено подписчикам
    subject.on(.next("1"))
    subject.onNext("2")
    let subscriptionTwo = subject
        .subscribe { event in
            print("2)", event.element ?? event)
    }
    subject.onNext("3")
    subscriptionOne.dispose()
    subject.onNext("4")
    // 1
    subject.onCompleted()
    // 2
    subject.onNext("5")
    // 3
    subscriptionTwo.dispose()
    let disposeBag = DisposeBag()
    // 4
    // После того, как мы сделали onCompleted никакой подписчик не сможет далешь возобновить нормальную работу subject. Он больше не будет посылать события, однако он пошлёт событие последнее событие своим подписчикам о завершении работы
    subject
        .subscribe {
            print("3)", $0.element ?? $0)
        }
        .disposed(by: disposeBag)
    subject.onNext("?")
    /*
     Нужно всегда диспозить подписчиков, чтобы не было мемори ликов. Делать это либо через dispose(), либо через DisposeBag()
     */
}

// 1
enum MyError: Error {
    case anError
}
// 2
// С CustomStringConvertible мы можем сделать кастомный вариант description
func print<T: CustomStringConvertible>(label: String, event: Event<T>) {
    print(label, event.element ?? event.error ?? event)
}
// 3
example(of: "BehaviorSubject") {
    // 4
    let subject = BehaviorSubject(value: "Initial value")
    let disposeBag = DisposeBag()
    // Если раскоментить вот эту строчку, то теперь значение, которое будет у подписчика это "Х"
    //    subject.onNext("X")
    subject
        .subscribe {
            print(label: "1)", event: $0)
        }
        .disposed(by: disposeBag)
    // 1
    subject.onError(MyError.anError)
    // 2
    subject
        .subscribe {
            print(label: "2)", event: $0)
        }
        .disposed(by: disposeBag)
    // Событие о закрытии subject попадёт и ко второму подписчику, хотя он и подписался после того, как мы объявили об ошибки. Это из-за особенностей BehaviorSubject. Он послыает последнее событие новому подписчику
}

/*
 ReplaySubject использует баффер для того чтобы записать несколько последних событий (из число определяется размером баффера) и затем передать их новому подписчику. В отличие от BehaviorSubject мы теперь сохраняем несколько событий
 */
example(of: "ReplaySubject") {
    // 1
    let subject = ReplaySubject<String>.create(bufferSize: 2)
    let disposeBag = DisposeBag()
    // 2
    subject.onNext("1")
    subject.onNext("2")
    subject.onNext("3")
    // 3
    subject
        .subscribe {
            print(label: "1)", event: $0)
        }
        .disposed(by: disposeBag)
    subject
        .subscribe {
            print(label: "2)", event: $0)
        }
        .disposed(by: disposeBag)
    subject.onNext("4")
    // Если добавить onError то,тогда он пошлёт 3 подписчику и это, кроме двух значений в баффере, если мы уберём subject.dispose()
    /*
     3) 3
     3) 4
     3) Optional(Optional(__lldb_expr_49.MyError.anError))
     */
    subject.onError(MyError.anError)
    // После добавления этой строчки мы просто пошлём 3 подписчику сообщение о том, что наш subject был dispose
    subject.dispose()
    subject
        .subscribe {
            print(label: "3)", event: $0)
        }
        .disposed(by: disposeBag)
}

// Особенность Variable заключается в том, что он никогда не выбросит ошибку
example(of: "Variable") {
    // 1
    var variable = Variable("Initial value")
    let disposeBag = DisposeBag()
    // 2
    variable.value = "New initial value"
    // 3
    variable.asObservable()
        .subscribe {
            print(label: "1)", event: $0)
        }
        .disposed(by: disposeBag)
}

example(of: "BehaviourRelay") {
    // 1
    var variable = BehaviorRelay(value: "Initial value")
    let disposeBag = DisposeBag()
    // 2
    variable.accept("New Initial Value")
    // 3
    variable.asObservable()
        .subscribe {
            print(label: "1)", event: $0)
        }
        .disposed(by: disposeBag)
}
