import UIKit
import RxSwift
import RxCocoa

let bufferTimeSpan: RxTimeInterval = 4
let bufferMaxCount = 2

let sourceObservable = PublishSubject<String>()

let sourceTimeline = TimelineView<String>.make()
let bufferedTimeline = TimelineView<Int>.make()

let stack = UIStackView.makeVertical([
    UILabel.makeTitle("buffer"),
    UILabel.make("Emitted elements:"),
    sourceTimeline,
    UILabel.make("Buffered elements (at most \(bufferMaxCount) every \(bufferTimeSpan) seconds):"),
    bufferedTimeline])

_ = sourceObservable.subscribe(sourceTimeline)

sourceObservable
    /*
    Элементы из SO по определенным правилам объединяются в массивы и генерируются в RO. В качестве параметров передается count, — максимальное число элементов в массиве, и timeSpan время максимального ожидания наполнения текущего массива из элементов SO. Таким образом элемент RO, являет собой массив [T], длинной от 0 до count.
    */
    /*
    То есть timeSpan обозначает время для заполнения массива, затем после прохождения этого промежутка времени подписчик получает результат. Count - максимальное количество элементов в массиве, так как buffer элементы, полученные в этот промежуток времени превращает в массив, если же было получено максимальное количество элементов buffer выкидывает элементы, не дожидаясь окончания таймера. Scheduler - просто на каком потоке выдавать, у нас главный так как работает с UI
    */
    /*
    Even though there is no activity on the source observable, you can witness empty buffers on the buffered timeline. The buffer(_:scheduler:) operators emits empty arrays at regular intervals if nothing has been received from its source observable. The 0s mean that zero elements have been emitted from the source sequence.
    */
    .buffer(timeSpan: bufferTimeSpan, count: bufferMaxCount, scheduler:
        MainScheduler.instance)
    .map { $0.count }
    .subscribe(bufferedTimeline)

let hostView = setupHostView()
hostView.addSubview(stack)
hostView

DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
    sourceObservable.onNext("🐮")
    sourceObservable.onNext("🐮")
    sourceObservable.onNext("🐮")
}

let elementsPerSecond = 0.7
let timer = DispatchSource.timer(interval: 3.0 /
    Double(elementsPerSecond), queue: .main) {
        sourceObservable.onNext("🐮")
        }

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
