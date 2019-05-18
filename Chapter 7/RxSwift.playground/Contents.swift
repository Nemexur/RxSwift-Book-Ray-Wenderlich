import Foundation
import RxSwift

// MARK: - Transforming elements -

/*
 A convenient way to transform an observable of individual elements into an array of all those elements is by using toArray
 */
example(of: "toArray") {
    let disposeBag = DisposeBag()
    // 1
    Observable.of("A", "B", "C")
        // 2
        .toArray()
        .subscribe(onNext: {
            print($0) })
        .disposed(by: disposeBag)
}

/*
 RxSwift’s map operator works just like Swift’s standard map, except it operates on observables
 */
example(of: "map") {
    let disposeBag = DisposeBag()
    // 1
    let formatter = NumberFormatter()
    formatter.numberStyle = .spellOut
    // 2
    Observable<NSNumber>.of(123, 4, 56)
        // 3
        .map {
            formatter.string(from: $0) ?? ""
        }
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}

example(of: "mapWithIndex") {
    let disposeBag = DisposeBag()
    // 1
    Observable.of(1, 2, 3, 4, 5, 6)
        // 2
        .enumerated()
        .map { $0 > 2 ? $1 * 2 : $1 }
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}

// MARK: - Transforming inner observables

struct Student {
    /*
     RxSwift includes a few operators in the flatMap family that allow you to reach into an observable and work with its observable properties.
     */
    var score: Variable<Int>
}

example(of: "flatMap") {
    let disposeBag = DisposeBag()
    // 1
    let ryan = Student(score: Variable(80))
    let charlotte = Student(score: Variable(90))
    // 2
    let student = PublishSubject<Student>()
    // 3
    student.asObservable()
        .flatMap { $0.score.asObservable() }
        // 4
        .subscribe(onNext: { print($0) })
        .disposed(by: disposeBag)
    
    student.onNext(ryan)
    // Как раз вот это подразумевалось над трансформацией 1 в 4 в примере flatMap в книге. This is because flatMap keeps up with each and every observable it creates, one for each element added onto the source observable. То есть она сохраняет те обзерверы, которые она создала на прошлом шаге, что как раз можно заметить на диаграмме
    ryan.score.value = 85
    student.onNext(charlotte)
    ryan.score.value = 95
    charlotte.score.value = 100
}

/*
 Особенность flatMapLatest заключается в том, что теперь мы будем смотреть на изменения самого последнего обзервера. Допустим, у нас как на диаграмме 3 обзервера мы трансфиормируем результат и переводим их на новую последовательность обзервера. И начинаем следить за её изменения. То есть если на придёт новое значение для свойства этого обзервера, то мы его покажем. Однако, когда нам из основного обзервера приходит новый обзервер, то мы трансформируем его и переводим на новую последовательно обзервера и теперь будем следить за его изменениями, то есть, если нам придёт новое значение на первом обзервере мы его трансформируем, но не спроецируем на уже последнюю последовательно обзервера, однако для второго обзервера мы это сделаем
 */
/*
 flatMapLatest works just like flatMap to reach into an observable element to access its observable property, it applies a transform and projects the transformed value onto a new sequence for each element of the source observable. Those elements are flattened down into a target observable that will provide elements to the subscriber. What makes flatMapLatest different is that it will automatically switch to the latest observable and unsubscribe from the the previous one.
 In the above marble diagram, O1 is received by flatMapLatest, it transforms its value to 10, projects it onto a new observable for O1, and flattens it down to the target observable. Just like before. But then flatMapLatest receives O2 and it does its thing, switching to O2’s observable because it’s now the latest.
 When O1’s value changes, flatMapLatest actually still does the transform (something to be mindful of if your transform is an expensive operation), but then it ignores the result. The process repeats when O3 is received by flatMapLatest. It then switches to its sequence and ignores the previous one (O2). The result is that the target observable only receives elements from the latest observable.
 */
/*
 Ниже пример, объясняющий всё, что написано выше
 */
example(of: "flatMapLatest") {
    let disposeBag = DisposeBag()
    let ryan = Student(score: Variable(80))
    let charlotte = Student(score: Variable(90))
    let student = PublishSubject<Student>()
    student.asObservable()
        .flatMapLatest {
            $0.score.asObservable()
        }
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
    student.onNext(ryan)
    ryan.score.value = 85
    ryan.score.value = 75
    student.onNext(charlotte)
    // 1
    ryan.score.value = 95
    charlotte.score.value = 100
    charlotte.score.value = 110
}
