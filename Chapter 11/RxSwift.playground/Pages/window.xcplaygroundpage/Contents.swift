import UIKit
import RxSwift
import RxCocoa
import RxSwiftExt

/*
A last buffering technique very close to buffer(timeSpan:count:scheduler:) is window(timeSpan:count:scheduler:). It has roughly the same signature and nearly does the same thing. The only difference is that it emits an Observable of the buffered items, instead of emitting an array.
*/
let elementsPerSecond = 3
let windowTimeSpan: RxTimeInterval = 4
let windowMaxCount = 10
let sourceObservable = PublishSubject<String>()

let sourceTimeline = TimelineView<String>.make()
let stack = UIStackView.makeVertical([
    UILabel.makeTitle("window"),
    UILabel.make("Emitted elements (\(elementsPerSecond) per sec.):"),
    sourceTimeline,
    UILabel.make("Windowed observables (at most \(windowMaxCount) every \(windowTimeSpan) sec):")])

let timer = DispatchSource.timer(interval: 1.0 /
    Double(elementsPerSecond), queue: .main) {
        sourceObservable.onNext("🐮")
        }

_ = sourceObservable.subscribe(sourceTimeline)
//_ = sourceObservable
//    // Работает точно также как и buffer, только теперь возвращаем Observable of Observable sequences
//    // Как только собирается windowMaxCount мы сразу передаём Observable Sequence далее. Обрабатывать его будем через flatMap, что очевидно, так как на выходе Observable of Observable sequences. После обработки в нужный формат, а именно в один единственный Observable такого типа Observable<(TimelineView<Int>, String?, потом работаем
//    .window(timeSpan: windowTimeSpan, count: windowMaxCount, scheduler:
//        MainScheduler.instance)
//    // Every time flatMap gets a new observable, you insert a new timeline view.
//    // You flatMap(_:) the sequence of resulting observables of tuple to a single sequence of tuples.
//    .flatMap { windowedObservable -> Observable<(TimelineView<Int>, String?)>
//        in
//        let timeline = TimelineView<Int>.make()
//        // Вставляем новый TimeLine
//        stack.insert(timeline, at: 4)
//        // Обозначает, что максимально может быть восемь вьюх в стэке. Затем обновляем, вставляя элемент наверх, то есть 3 место снизу
//        stack.keep(atMost: 8)
//        return windowedObservable
//            .map { value in (timeline, value) }
//            // Обозначает окончание работы данного обзервера
//            .concat(Observable.just((timeline, nil)))
//    }
//    .subscribe(onNext: { tuple in
//        let (timeline, value) = tuple
//        if let value = value {
//            timeline.add(.Next(value))
//        } else {
//            timeline.add(.Completed(true))
//        }
//    })

// MARK: - Challenge

// Возвращает Observabel of Observabel sequences
let windowedObservable = sourceObservable
    .window(timeSpan: windowTimeSpan, count: windowMaxCount, scheduler: MainScheduler.instance)

// Создадим отдельно Observabel<TimelineView<Int>>, который будет вызываться на каждый обзервабл из window, то есть по достижению count или по истечению timeSpan будем выдавать сюда Observable, будем ставить его на 4 место и сразу возвращать его через map
let timelineObservable = windowedObservable
    .do(onNext: { _ in
        let timeline = TimelineView<Int>.make()
        stack.insert(timeline, at: 4)
        stack.keep(atMost: 8)
    })
    .map { _ in stack.arrangedSubviews[4] as? TimelineView<Int> }
    .unwrap()

// Теперь делаем zip этих элементов, то есть будем брать два новых элемента (zip будет ждать два новых элемента для каждого из тех элементов, что мы включили в коллекцию) и будем его флэтмэпить, так как у нас будет возвращаться Observable<(Observabel<String>, TimelineView<Int>)>, а нам нужно избавить от Observabel<String>
_ = Observable
    .zip(windowedObservable, timelineObservable) { obs, timeline in
        (obs, timeline)
    }
    .flatMap { tuple -> Observable<(TimelineView<Int>, String?)> in
        let obs = tuple.0
        let timeline = tuple.1
        return obs
            .map { value in (timeline, value) }
            // Cозадём элементы некоторого обзервера, которые будут по очереди передаваться подписчику
            // Сделаём так чтобы было completed
            .concat(Observable.just((timeline, nil)))
    }
    .subscribe(onNext: { tuple in
        let (timeline, value) = tuple
        if let value = value {
            timeline.add(.Next(value))
        } else {
            timeline.add(.Completed(true))
        }
    })

let hostView = setupHostView()
hostView.addSubview(stack)
hostView

// Support code -- DO NOT REMOVE
class TimelineView<E>: TimelineViewBase, ObserverType where E: CustomStringConvertible {
  static func make() -> TimelineView<E> {
    let view = TimelineView(frame: CGRect(x: 0, y: 0, width: 400, height: 100))
    view.setup()
    return view
  }
  public func on(_ event: Event<E>) {
    switch event {
    case .next(let value):
      add(.Next(String(describing: value)))
    case .completed:
      add(.Completed())
    case .error(_):
      add(.Error())
    }
    // Тут отсутствует обработке dipose, так как она нам ненужна из-за постоянного перезапуска окна
  }
}
