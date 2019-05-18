//: Please build the scheme 'RxSwiftPlayground' first
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

import RxSwift

/*
 The startWith(_:) operator prefixes an observable sequence with the given initial
 value. This value must be of the same type as the observable elements
*/
/*
То есть сначал будет выведена 1, а вот уже затем будут выведены цифры в Observable.of(2, 3, 4)
*/
/*
As it turns out, startWith(_:) is the simple variant of the more general concat family of operators. Your initial value is a sequence of one element, to which RxSwift appends the sequence that startWith(_:) chains to. The Observable.concat(_:) static function chains two sequences.
*/
/*
StartsWith является строгои типизорованным следовательно тип элементов и у него и обзервера, у которого мы его вызвали должны совпадать
*/
example(of: "startWith") {
    // 1
    Observable.of(2, 3, 4)
        .startWith(1)
        .subscribe(onNext: { value in
            print(value)
        })
}

/*
The Observable.concat(_:) static function takes an ordered collection of observables (i.e. an array). The observable it creates subscribes to the first sequence of the collection, relays its elements until it completes, then moves to the next one. The process repeats until all the observables in the collection have been used. If at any point an inner observable emits an error, the concatenated observable in turns emits the error and terminates.
*/
/*
Если хоть бы один из Observable, над которыми был применён Observable.concat выдаст .error or .completed, то Observable.concat незамедлительно прекаращет работу и .disposed
*/
example(of: "Observable.concat") {
    // 1
    let first = Observable.of(1, 2, 3)
    let second = Observable.of(4, 5, 6)
    // 2
    let observable = Observable.concat([first, second])
    observable.subscribe(onNext: { value in
        print(value)
    })
}

/*
This variant applies to an existing observable. It waits for the source observable to complete, then subscribes to the parameter observable. Aside from instantiation, it works just like Observable.concat(_:). Check the playground output; you’ll see a list of German cities followed by a list of Spanish cities
*/
/*
Работу абсолютно также как и Observable.concat. Только инстанциация другая
*/
/*
Observable sequences are strongly typed. You can only concatenate sequences whose elements are of the same type!
*/
example(of: "concat") {
    let germanCities = Observable.of("Berlin", "Münich", "Frankfurt")
    let spanishCities = Observable.of("Madrid", "Barcelona", "Valencia")
    let observable = germanCities.concat(spanishCities)
    observable.subscribe(onNext: { value in
        print(value)
    })
}

example(of: "concat one element") {
    let numbers = Observable.of(2, 3, 4)
    let observable = Observable
        .just(1)
        .concat(numbers)
    observable.subscribe(onNext: { value in
        print(value)
    })
}

/*
Чтобы понять принцип соединения смотри на диграмму страница 172
*/
/*
The function arc4random_uniform(_:) takes one parameter, the upper bound. It’ll return a random number between 0 and this upper bound, minus 1.
*/
example(of: "merge") {
    // 1
    let left = PublishSubject<String>()
    let right = PublishSubject<String>()
    // 2
    let source = Observable.of(left.asObservable(), right.asObservable())
    // 3
    /*
     A merge() observable subscribes to each of the sequences it receives and emits the
     elements as soon as they arrive — there’s no predefined order.
    */
    /*
     You may be wondering when and how merge() completes. Good question! As with everything in RxSwift, the rules are well-defined:
     • merge() completes after its source sequence completes and all inner sequences have completed.
     • The order in which the inner sequences complete is irrelevant.
     • If any of the sequences emit an error, the merge() observable immediately relays the error, then terminates.
    */
    /*
    To limit the number of sequences subscribed to at once, you can use merge(maxConcurrent:). This variant keeps subscribing to incoming sequences until it reaches the maxConcurrent limit. After that, it puts incoming observables in a queue. It will subscribe to them in order, as soon as one of current sequences completes.
    */
    let observable = source.merge()
    let disposable = observable.subscribe(onNext: { value in
        print(value)
    })
    // 4
    var leftValues = ["Berlin", "Munich", "Frankfurt"]
    var rightValues = ["Madrid", "Barcelona", "Valencia"]
    /*
    Вариант do while
    */
    repeat {
        /*
        То есть между 0 и 1
        */
        let random = arc4random_uniform(2)
        print("Random value is: \(random)")
        if random == 0 {
            if !leftValues.isEmpty {
                left.onNext("Left:  " + leftValues.removeFirst())
            }
        } else if !rightValues.isEmpty {
            right.onNext("Right: " + rightValues.removeFirst())
        }
    } while !leftValues.isEmpty || !rightValues.isEmpty
    // 5
    disposable.dispose()
}

/*
Every time one of the inner (combined) sequences emits a value, it calls a closure you provide. You receive the last value from each of the inner sequences. This has many concrete applications, such as observing several text fields at once and combining their value, watching the status of multiple sources, and so on.
*/
/*
На основе этого примере можно понять, что как только появятся события как у left, так и right, то начинается выполнение блока кода у combineLatest. Для его выполнения какждый раз будет браться последнее значение из left и right соответственно, что можно заметить в данном коде. Этот блок будет каждый раз вызываться при появлении нового значения хотя бы у одного из двух PublishSubject'ов
*/
/*
 A few notable points about this example:
 1. You combine observables using a closure receiving the latest value of each sequence as arguments. In this example, the combination is the concatenated string of both left and right values. It could be anything else that you need, as the type of the elements emitted by the combined observable is the return type of the closure. In practice, this means you can combine sequences of heterogeneous types. It is the only core operator that permits this.
 2. Nothing happens until each of the combined observables emits one value. After that, each time one emits a new value, the closure receives the latest value of each of the observable and produces its element.
*/
/*
Это единственный оператор, который позволяет совмещать обзерверабле разных типов
*/
/*
Note: Last but not least, combineLatest completes only when the last of its inner sequences completes. Before that, it keeps sending combined values. If some sequences terminate, it uses the last value emitted to combine with new values from other sequences.
*/
/*
То есть для завершения combineLatest необходимо завершение абслоютно всех внутренних последовательностей
*/
example(of: "combineLatest") {
    let left = PublishSubject<String>()
    let right = PublishSubject<String>()
    // 1
    /*
    let observable = Observable.combineLatest(left, right, resultSelector:
    {
        lastLeft, lastRight in
        "\(lastLeft) \(lastRight)"
    })
    */
    // 1
    // Варинат через коллекцию работает по тому же принципу как и тот, что выше
    let observable = Observable.combineLatest([left, right]) {
        strings in strings.joined(separator: " ")
    }
    let disposable = observable.subscribe(onNext: { value in
        print(value)
    })
    // 2
    print("> Sending a value to Left")
    left.onNext("Hello,")
    print("> Sending a value to Right")
    right.onNext("world")
    print("> Sending another value to Right")
    right.onNext("RxSwift")
    print("> Sending another value to Left")
    left.onNext("Have a good day,")
    disposable.dispose()
}

example(of: "combine user choice and value") {
    let choice : Observable<DateFormatter.Style> =
        Observable.of(.short, .long)
    let dates = Observable.of(Date())
    let observable = Observable.combineLatest(choice, dates) { (format, when) -> String in
        let formatter = DateFormatter()
        formatter.dateStyle = format
        return formatter.string(from: when)
    }
    observable.subscribe(onNext: { value in
        print(value)
    })
}

/*
Here’s what zip(_:_:resultSelector:) did for you:
 • Subscribed to the observables you provided.
 • Waited for each to emit a new value.
 • Called your closure with both new values.
*/
/*
 Did you notice how Vienna didn’t show up in the output? Why is that?
 The explanation lies in the way zip operators work. They wait until each of the inner observables emits a new value. If one of them completes, zip completes as well. It doesn’t wait until all of the inner observables are done! This is called indexed sequencing, which is a way to walk though sequences in lockstep.
*/
example(of: "zip") {
    enum Weather {
        case cloudy
        case sunny }
    let left: Observable<Weather> = Observable.of(.sunny, .cloudy, .cloudy,
                                                  .sunny)
    let right = Observable.of("Lisbon", "Copenhagen", "London", "Madrid",
                              "Vienna")
    let observable = Observable.zip(left, right) { weather, city in
        return "It's \(weather) in \(city)"
    }
    observable.subscribe(onNext: { value in
        print(value)
    })
}

/*
Note: Don’t forget that withLatestFrom(_:) takes the data observable as a parameter, while sample(_:) takes the trigger observable as a parameter. This can easily be a source of mistakes — so be careful!
*/
/*
То есть там всё обратно пропорционально. В sample передаём триггер, а для withLatestFrom вызываем его на триггере
*/
/*
Мы каждый раз будем использовать только последний элемент у того PublishSubject, с которым мы связались
*/
example(of: "withLatestFrom") {
    // 1
    let button = PublishSubject<Void?>()
    let textField = PublishSubject<String>()
    // 2
    let observable = button.withLatestFrom(textField)
    let disposable = observable.subscribe(onNext: { value in
        print(value)
    })
    // 3
    textField.onNext("Par")
    textField.onNext("Pari")
    textField.onNext("Paris")
    textField.onNext("Paris Hey")
    button.onNext(nil)
    button.onNext(nil)
}

/*
It does nearly the same thing with just one variation: each time the trigger observable emits a value, sample(_:) emits the latest value from the “other” observable, but only if it arrived since the last “tick”. If no new data arrived, sample(_:) won’t emit anything.
*/
/*
В данном случае нашим триггер обзервабле является именно button, на любой новый элемент в нём мы будем вытаскивать элемент у того обзервабл, с которым мы его связали
*/
/*
Notice that "Paris" now prints only once! This is because no new value was emitted by the text field between your two fake button presses. You could have achieved the same behavior by adding a distinctUntilChanged() to the withLatestFrom(_:) observable
*/
example(of: "sample") {
    // 1
    let button = PublishSubject<Void?>()
    let textField = PublishSubject<String>()
    // 2
    let observable = textField.sample(button)
    let disposable = observable.subscribe(onNext: { value in
        print(value)
    })
    // 3
    textField.onNext("Par")
    textField.onNext("Pari")
    textField.onNext("Paris")
    textField.onNext("Paris Hey")
    button.onNext(nil)
    button.onNext(nil)
}

/*
Далее рассмотрим некоторые способы совмещения обзерверабле
*/
/*
Amb призван решить ambigious (неясность) между двумя обзерварабле. The amb(_:) operator subscribes to left and right observables. It waits for any of them to emit an element, then unsubscribes from the other one. After that, it only relays elements from the first active observable. It really does draw its name from the term ambiguous: at first, you don’t know which sequence you’re interested in, and want to decide only when one fires.
*/
/*
То есть если первой выдаст значение правая, то результатом будет Copenhagen, Vienna
*/
example(of: "amb") {
    let left = PublishSubject<String>()
    let right = PublishSubject<String>()
    // 1
    let observable = left.amb(right)
    let disposable = observable.subscribe(onNext: { value in
        print(value)
    })
    // 2
    left.onNext("Lisbon")
    right.onNext("Copenhagen")
    left.onNext("London")
    left.onNext("Madrid")
    right.onNext("Vienna")
    disposable.dispose()
}

example(of: "switchLatest") {
    // 1
    let one = PublishSubject<String>()
    let two = PublishSubject<String>()
    let three = PublishSubject<String>()
    let source = PublishSubject<Observable<String>>()
    // 2
    /*
    Смотри описание switchLatest. Оно очень понятное
    */
    let observable = source.switchLatest()
    let disposable = observable.subscribe(onNext: { value in
        print(value)
    })
    // 3
    source.onNext(one)
    // Теперь будем брать новые значения у первого
    one.onNext("Some text from sequence one")
    two.onNext("Some text from sequence two")
    source.onNext(two)
    // Теперь будем брать новые значения только у второго
    two.onNext("More text from sequence two")
    one.onNext("and also from sequence one")
    source.onNext(three)
    // Теперь будем брать новые значения только у третьего
    two.onNext("Why don't you seem me?")
    one.onNext("I'm alone, help me")
    three.onNext("Hey it's three. I win.")
    source.onNext(one)
    // Теперь будем брать новые значения только у первого
    one.onNext("Nope. It's me, one!")
    disposable.dispose()
}

/*
The operator “accumulates” a summary value. It starts with the initial value you provide (in this example, you start with 0). Each time the source observable emits an item, reduce(_:_:) calls your closure to produce a new summary. When the source observable completes, reduce(_:_:) emits the summary value, then completes.
*/
/*
То есть после того, как мы пройдёмся по всем элементам обзерверабле reduce, мы передадим результат от reduce подписчику
*/
/*
Note: reduce(_:_:) produces its summary (accumulated) value only when the source observable completes. Applying this operator to sequences that never complete won’t emit anything. This is a frequent source of confusion and hidden problems.
*/
example(of: "reduce") {
    let source = Observable.of(1, 3, 5, 7, 9)
    // 1
    let observable = source.reduce(0, accumulator: +)
    /*
     let observable = source.reduce(0, accumulator: { summary, newValue in
     return summary + newValue
     })
    */
    observable.subscribe(onNext: { value in
        print(value)
    })
}

/*
Основная разница в том, что мы имитим значение на каждой работе scan. То есть сложили 0 + 1 и передали результат подписчику. Потом сложини 0 + 1 + 3 и передали результат подписчику и так далее до тех пор пока не закончится обзервабл
*/
example(of: "scan") {
    let source = Observable.of(1, 3, 5, 7, 9)
//    let observable = source.scan(0, accumulator: +)
    let observable = source.scan(0, accumulator: { sum, val in
        print(sum, val)
        return sum + val
    })
    observable.subscribe(onNext: { value in
        print(value)
    })
}

// MARK: - Challenge -

example(of: "scan + zip") {
    let source = Observable.of(1, 3, 5, 7, 9)
    let scanSource = source.scan(0, accumulator: +)
    let observable = Observable.zip(source, scanSource) {
        return "Source: \($0) Scan: \($1)"
    }
    observable
        .subscribe(onNext: { print($0) })
        .dispose()
}

example(of: "scan + tuple") {
    let source = Observable.of(1, 3, 5, 7, 9)
    source.scan((previous: 0, current: 0)) { ($1, $0.current + $1) }
        .subscribe(onNext: { print("Source: \($0.0) Scan: \($0.1)") })
        .dispose()
}
