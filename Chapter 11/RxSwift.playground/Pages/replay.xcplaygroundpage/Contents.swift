import UIKit
import RxSwift
import RxCocoa

let elementsPerSecond = 1
let maxElements = 5
let replayedElements = 1
let replayDelay: TimeInterval = 3

//let sourceObservable = Observable<Int>.create { observer in
//    var value = 1
//    let timer = DispatchSource.timer(interval: 1.0 /
//        Double(elementsPerSecond), queue: .main) {
//            if value <= maxElements {
//                observer.onNext(value)
//                value = value + 1
//            }
//    }
//    return Disposables.create {
//        timer.suspend()
//    }
//}/*.replay(replayedElements)*/.replayAll()
/*
Interval timers are incredibly easy to create with RxSwift. Not only that, but they are also easy to cancel: since Observable.interval(_:scheduler:) generates an observable sequence, subscriptions can simply dispose() the returned disposable to cancel the subscription and stop the timer
*/
/*
It is notable that the first value is emitted at the specified duration after a subscriber starts observing the sequence. Also, the timer won't start before this point. The subscription is the trigger that kicks it off.
*/
// You cast elementsPerSecond to the RxTimeInterval type which happens to be a Double. This simply is the number of seconds to wait between emitted elements. If you used a number directly, the compiler would automatically have inferred the literal value to be of the appropriate type.
// Также если ко второму подписчику, который подпишется через 3 секунды сделать некоторый replay в случае если каждый новый элемент появляется через 2 секнуды, то у нас сначала появится replay элемент, а вот уже потом через 1 секунды поступит элемент от Observable
// Будет просто выдавать через 1 секунды элементы, начиная с 0
let sourceObservable = Observable<Int>
    .interval(RxTimeInterval(elementsPerSecond), scheduler:
        MainScheduler.instance)
    /*
    As you can see in the timeline view, values emitted by Observable.interval(_:scheduler:) are signed integers starting from 0. Should you need different values, you can simply map(_:) them. In most real life cases, the value emitted by the timer is simply ignored. But it can make a convenient index.
    */
    .replay(replayedElements)
/*
 The second replay operator you can use is replayAll(). This one should be used with caution: only use it in scenarios where you know the total number of buffered elements will stay reasonable. For example, it’s appropriate to use replayAll() in the context of HTTP requests. You know the approximate memory impact of retaining the data returned by a query. On the other hand, using replayAll() on a sequence that may not terminate and may produce a lot of data will quickly clog
 your memory. This could grow to the point where the OS jettisons your application!
*/

let sourceTimeline = TimelineView<Int>.make()
let replayedTimeline = TimelineView<Int>.make()

let stack = UIStackView.makeVertical([
    UILabel.makeTitle("replay"),
    UILabel.make("Emit \(elementsPerSecond) per second:"),
    sourceTimeline,
    UILabel.make("Replay \(replayedElements) after \(replayDelay) sec:"),
    replayedTimeline])

_ = sourceObservable.subscribe(sourceTimeline)

DispatchQueue.main.asyncAfter(deadline: .now() + replayDelay) {
    /*
    In the settings you used, replayedElements is equal to 1. It configures the replay(_:) operator to only buffer the last element from the source observable. The animated timeline shows that the second subscriber receives elements 3 and 4 in the same time frame. By the time it subscribes, it gets both the latest buffer element (3) and the one that happens to be emitted just right when subscription occurs. The timeline view shows them stacked up since the time they arrive is about the same (although not exactly the same).
    */
    _ = sourceObservable.subscribe(replayedTimeline)
}

/*
Now since replay(_:) creates a connectable observable, you need to connect it to its underlying source to start receiving items. If you forget this, subscribers will never receive anything.
*/
/*
 Connectable observables are a special class of observables. Regardless of their number of subscribers, they won't start emitting items until you call their connect() method. While this is beyond the scope of this chapter, remember that a few operators return ConnectableObservable<E>, not Observable<E>. These operators are:
 replay(_:)
 replayAll()
 multicast(_:)
 publish()
*/
_ = sourceObservable.connect()

let hostView = setupHostView()
hostView.addSubview(stack)
hostView

// Support code -- DO NOT REMOVE
class TimelineView<E>: TimelineViewBase, ObserverType where E: CustomStringConvertible {
  static func make() -> TimelineView<E> {
    return TimelineView(width: 400, height: 100)
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
