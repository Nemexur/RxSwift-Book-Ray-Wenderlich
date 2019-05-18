import UIKit
import RxSwift
import RxCocoa

let elementsPerSecond = 1
let delayInSeconds = 1.5

let sourceObservable = PublishSubject<Int>()

let sourceTimeline = TimelineView<Int>.make()
let delayedTimeline = TimelineView<Int>.make()

let stack = UIStackView.makeVertical([
  UILabel.makeTitle("delay"),
  UILabel.make("Emitted elements (\(elementsPerSecond) per sec.):"),
  sourceTimeline,
  UILabel.make("Delayed elements (with a \(delayInSeconds)s delay):"),
  delayedTimeline])

var current = 1
let timer = DispatchSource.timer(interval: 1.0 / Double(elementsPerSecond), queue: .main) {
  sourceObservable.onNext(current)
  current = current + 1
}

_ = sourceObservable.subscribe(sourceTimeline)


// Setup the delayed subscription
// ADD CODE HERE

_ = Observable<Int>
   /*
   The idea behind the delaySubscription(_:scheduler:) is, as the name implies, to delay the time a subscriber starts receiving elements from its subscription.
   */
    // Просто мы теперь позднее подпишемся на sourceObservable
    // Первый параметр delaySubscription это время задержки в секундах
//    .delaySubscription(RxTimeInterval(delayInSeconds), scheduler:
//        MainScheduler.instance)
//    .subscribe(delayedTimeline)

/*
Instead of subscribing late, the operator subscribes immediately to the source observable, but delays every emitted element by the specified amount of time. The net result is a concrete time-shift.
*/
    // Теперь мы просто сдвинем по времени получение всех элементов. То есть со сдвигом по времени в 1.5 секунд съедет имиттинг элементов
//    .delay(RxTimeInterval(delayInSeconds), scheduler:
//        MainScheduler.instance)
//    .subscribe(delayedTimeline)
    /*
    Бесконечная последовательность, возрастающая с 0 с шагом 1, с указанной периодичностью и возможность задержки при старте. Никогда не будет сгенерированы события Completed или Error
    */
    /*
    В общем таймер выдаст только один элемент через некоторе время, которые мы укажем в качестве первого параметра, и потом выдаст Completed и Disposed. Затем, если есть параметр период то, она не выдаст Completed и Disposed, а будет продолжать выдавать элементы основываясь на этом периоде
    */
    .timer(3, scheduler: MainScheduler.instance)
    .debug("timer debug", trimOutput: false)
    .flatMap { _ in
        sourceObservable.delay(RxTimeInterval(delayInSeconds), scheduler:
            MainScheduler.instance)
    }
    .subscribe(delayedTimeline)

/*
In Rx, some observables are called “cold” while others are “hot”. Cold observables start emitting elements when you subscribe to them. Hot observables are more like permanent sources like in this example with delay they tend to skip elements however cold won't. Hot and cold observables are a tricky topic that can take some time getting your head around. Remember that cold observables emit events only when subscribed to, but hot observables emit events independent of being subscribed to.
*/

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
  }
}
