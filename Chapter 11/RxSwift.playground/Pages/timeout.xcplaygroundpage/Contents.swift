import UIKit
import RxSwift
import RxCocoa

/*
Its primary purpose is to semantically distinguish an actual timer from a timeout (error) condition. Therefore, when a timeout operator fires, it emits an RxError.TimeoutError error event; if not caught, it terminates the sequence.
*/

let button = UIButton(type: .system)
button.setTitle("Press me now!", for: .normal)
button.sizeToFit()

let tapsTimeline = TimelineView<String>.make()
let stack = UIStackView.makeVertical([
    button,
    UILabel.make("Taps on button above"),
    tapsTimeline])

let _ = button
    .rx.tap
    .map { _ in "•" }
    /*
    If you click the button within five seconds (and within five seconds of subsequent presses), you'll see your taps on the timeline. Stop clicking, and five seconds after that, as the timeout fires, the timeline will stop with an Error.
    */
//    .timeout(5, scheduler: MainScheduler.instance)
    // Разница в том, что теперь такой вариант выдаст Observable.just("X"), Completed и Disposed по истечению 5 секнуд и отсутствию нажатий
    .timeout(5, other: Observable.just("X"), scheduler:
        MainScheduler.instance)
    .subscribe(tapsTimeline)

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
