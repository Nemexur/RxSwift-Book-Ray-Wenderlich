import UIKit
import RxSwift

// MARK: - Ignoring operators -

/*
 Ignore игноририует все возможные .next значения и пропускает только .completed and .error
 */
example(of: "ignoreElements") {
    // 1
    let strikes = PublishSubject<String>()
    let disposeBag = DisposeBag()
    // 2
    strikes
        .ignoreElements()
        .subscribe { _ in
            print("You're out!")
        }
        .disposed(by: disposeBag)
    // Ничего не напишет
    strikes.onNext("X")
    strikes.onNext("X")
    strikes.onNext("X")
    // Теперь появится сообщение
    strikes.onCompleted()
}

// MARK: - Element At -
/*
 Не пропускаем к подписчику никакие элементы, кроме второго, начиная с нуля
 */
example(of: "elementAt") {
    // 1
    let strikes = PublishSubject<String>()
    let disposeBag = DisposeBag()
    // 2
    strikes
        .elementAt(2)
        .subscribe(onNext: { _ in
            print("You're out!")
        })
        .disposed(by: disposeBag)
    strikes.onNext("X")
    strikes.onNext("X")
    strikes.onNext("X")
    strikes.onNext("X")
}

/*
 Обычный фильтр
 */
example(of: "filter") {
    let disposeBag = DisposeBag()
    // 1
    Observable.of(1, 2, 3, 4, 5, 6)
        // 2
        .filter { $0 % 2 == 0 }
        // 3
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}

/*
 Противоположен .elementAt (теперь мы пропускаем все элементы до того, как нам не попадётся элемент с определённым индексом)
 */
example(of: "skip") {
    let disposeBag = DisposeBag()
    // 1
    Observable.of("A", "B", "C", "D", "E", "F")
        // 2
        .skip(3)
        .subscribe(onNext: {
            print($0) })
        .disposed(by: disposeBag)
}

/*
 SkipWhile будет скипать элементы до тех пор пока ему не попадётся первый false, затем он будет всё пропускать независимо от ответа(true or false)
 */
example(of: "skipWhile") {
    let disposeBag = DisposeBag()
    // 1
    Observable.of(2, 2, 3, 4, 4)
        // 2
        .skipWhile { $0 % 2 == 0 }
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}

/*
 What if you wanted to dynamically filter elements based on some other observable?
 SkipUntil предоставляет эту возможность, теперь  мы можем сделать так, что мы не будем передавать элементы обзерверу до тех пора, пока некоторый обзервер не начнёт передавать элементы, после этого подписчик всегда будет получать новые элементы от обзервера, на который он подписался
 */
example(of: "skipUntil") {
    let disposeBag = DisposeBag()
    // 1
    let subject = PublishSubject<String>()
    let trigger = PublishSubject<String>()
    // 2
    subject
        .skipUntil(trigger)
        .subscribe(onNext: { print($0) })
        .disposed(by: disposeBag)
    // Ничего не происходит
    subject.onNext("A")
    subject.onNext("B")
    // Триггер передал значение
    trigger.onNext("X")
    // Теперь подписчик будет получать элементы всегда
    subject.onNext("C")
    subject.onNext("K")
}

/*
 Take можно дословно перевести как "Возьми первые (числовой параметр, который мы передали) элементы"
 */
example(of: "take") {
    let disposeBag = DisposeBag()
    // 1
    Observable.of(1, 2, 3, 4, 5, 6)
        // 2
        .take(3)
        .subscribe(onNext: {
            print($0) })
        .disposed(by: disposeBag)
}

example(of: "takeWhileWithIndex") {
    let disposeBag = DisposeBag()
    // 1
    Observable.of(2, 2, 4, 4, 6, 6)
        // 2
        .enumerated()
        // 3
        .takeWhile { $1 % 2 == 0 && $0 < 3 }
        .map { $1 }
        // 4
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}

/*
 TakeUntil работает противоположно skipUntil теперь мы будем предоставлять элементы подписчику до тех пора trigger не выдаст какой-либо элемент, затем элементы не будут доходить до подписчика
 */
example(of: "takeUntil") {
    let disposeBag = DisposeBag()
    // 1
    let subject = PublishSubject<String>()
    let trigger = PublishSubject<String>()
    // 2
    subject
        .takeUntil(trigger)
        .subscribe(onNext: { print($0) })
        .disposed(by: disposeBag)
    // 3
    // Доходят до подписчика
    subject.onNext("1")
    subject.onNext("2")
    // Триггер выдал элемент
    trigger.onNext("X")
    // Теперь подписчик больше не получает элементы
    subject.onNext("3")
}

/*
 someObservable
 .takeUntil(self.rx.deallocated)
 .subscribe(onNext: {
 print($0) })
 */
// Таким образом можно использовать takeUntil вместе с RxCocoa. В общем запись выше обозначает, что подписчик будет получает значения до тех пор пока элемент self.rx.deallocated. Как только self исчезнет подписчик не будет больше получать значения

/*
 DistinctUntilChanged only prevents duplicates that are right next to each other, so the thrid A gets through.
 */
example(of: "distinctUntilChanged") {
    let disposeBag = DisposeBag()
    // 1
    Observable.of("A", "A", "B", "B", "B", "A")
        // 2
        .distinctUntilChanged()
        .subscribe(onNext: {
            print($0) })
        .disposed(by: disposeBag)
}

/*
 Subscribe and print out elements that are considered distinct based on the comparing logic you provided
 */
example(of: "distinctUntilChanged(_:)") {
    let disposeBag = DisposeBag()
    // 1
    let formatter = NumberFormatter()
    // SpellOut выдаёт формат числа в виде слова 10 - ten
    formatter.numberStyle = .spellOut
    // 2
    Observable<NSNumber>.of(10, 110, 20, 200, 210, 310)
        // 3
        /*
         UsedistinctUntilChanged(_:),which takes a closure that receives each sequential pair of elements
         */
        .distinctUntilChanged { a, b in
            // 4
            guard let aWords = formatter.string(from: a)?.components(separatedBy: " "),
                let bWords = formatter.string(from: b)?.components(separatedBy: " ")
                else {
                    return false
            }
            var containsMatch = false
            // 5
            for aWord in aWords {
                for bWord in bWords {
                    if aWord == bWord {
                        containsMatch = true
                        break
                    }
                }
            }
            return containsMatch
        }
        // 4
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}
