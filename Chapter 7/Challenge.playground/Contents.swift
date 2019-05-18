import RxSwift
import RxSwiftExt

example(of: "Challenge 1") {
  let disposeBag = DisposeBag()

  let contacts = [
    "603-555-1212": "Florent",
    "212-555-1212": "Junior",
    "408-555-1212": "Marin",
    "617-555-1212": "Scott"
  ]

  let convert: (String) -> UInt? = { value in
    if let number = UInt(value),
      number < 10 {
      return number
    }

    let convert: [String: UInt] = [
      "abc": 2, "def": 3, "ghi": 4,
      "jkl": 5, "mno": 6, "pqrs": 7,
      "tuv": 8, "wxyz": 9
    ]

    var converted: UInt? = nil

    convert.keys.forEach {
      if $0.contains(value.lowercased()) {
        converted = convert[$0]
      }
    }

    return converted
  }

  let format: ([UInt]) -> String = {
    var phone = $0.map(String.init).joined()

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

  let dial: (String) -> String = {
    if let contact = contacts[$0] {
      return "Dialing \(contact) (\($0))..."
    } else {
      return "Contact not found"
    }
  }

  let input = Variable<String>("")

  // Add your code here
    input.asObservable()
        .map(convert)
        .unwrap()
        .skipWhile { $0 == 0 }
        .filter { $0 < 10 }
        .take(10)
        .toArray()
        .map(format)
        .map(dial)
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)


  input.value = ""
  input.value = "0"
  input.value = "408"

  input.value = "6"
  input.value = ""
  input.value = "0"
  input.value = "3"

  "JKL1A1B".forEach {
    input.value = "\($0)"
  }

  input.value = "9"
}
