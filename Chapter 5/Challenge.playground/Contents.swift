import RxSwift

example(of: "Challenge 1") {

    let disposeBag = DisposeBag()

    let contacts = [
    "603-555-1212": "Florent",
    "212-555-1212": "Junior",
    "408-555-1212": "Marin",
    "617-555-1212": "Scott"
    ]

    func phoneNumber(from inputs: [Int]) -> String {
    var phone = inputs.map(String.init).joined()

    phone.insert("-", at: phone.index(
        phone.startIndex,
        offsetBy: 3)
    )

    phone.insert("-", at: phone.index(
        phone.startIndex,
        offsetBy: 7)
    )
        return phone
    }

    let input = PublishSubject<Int>()

    // Add your code here

    input
        .skipWhile { $0 == 0 }
        .filter { $0 < 10 }
        .take(10)
        .toArray()
        .subscribe(onNext: {
            print("onNext: - \($0)")
            let phone = phoneNumber(from: $0)
            if let contact = contacts[phone] {
                print("Dialing \(contact) (\(phone))...")
            } else {
                print("Contact not found")
            }
        })
        .disposed(by: disposeBag)
    input.onNext(0)
    input.onNext(603)

    input.onNext(2)
    input.onNext(1)

    // Confirm that 7 results in "Contact not found", and then change to 2 and confirm that Junior is found
    input.onNext(2)

    "5551212".forEach {
        if let number = (Int("\($0)")) {
            input.onNext(number)
        }
    }
    
    input.onNext(9)
}

var start = 0
func getStartNumber() -> Int {
    start += 1
    return start
}
/*
 I’ve already mentioned that observables are lazy, pull-driven sequences. Simply calling a bunch of operators on an Observable doesn’t involve any actual work. The moment you call subscribe(...) directly on an observable or on one of the operators applied to it, that’s when the Observable livens up and starts producing elements.
 The observable calls its create closure each time you subscribe to it. in some situations, this might produce some bedazzling effects
 */
/*
The problem is that each time you call subscribe(...), this creates a new Observable for that subscription — and each copy is not guaranteed to be the same as the previous.
*/
/*
Чтобы обойти эту проблему нужно использовать share
To share a subscription, you can use the share() operator. A common pattern in Rx code is to create several sequences from the same source Observable by filtering out different elements in each of the results.
*/
example(of: "Subscription problems") {
//    let numbers = Observable<Int>.interval(1, scheduler: MainScheduler.instance).share()
    
    let numbers = Observable<Int>.create { observer in
        let start = getStartNumber()
        observer.onNext(start)
        observer.onNext(start+1)
        observer.onNext(start+2)
        observer.onCompleted()
        return Disposables.create()
    }
    
    numbers
//        .debug("1 subscriber", trimOutput: false)
        .subscribe(onNext: { el in
            print("element [\(el)]")
        }, onCompleted: {
            print("-------------")
        })
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        // Если переставить код, начинающийся с var start = 0 под этот example, то этот подписчик выдаст 1, 2, 3, так как у нас просто из-за того, что мы ждём 1 секунду или просто сделать async по ассинхронности успеет пробежаться код, начинающийся с var start = 0, и мы в итоге снова придём в изначальное состояние. Этого не случится, если этот код поставить над example
        numbers
//            .debug("2 subscriber", trimOutput: false)
            .subscribe(onNext: { el in
                print("element [\(el)]")
            }, onCompleted: {
                print("-------------")
            })
    }
}
