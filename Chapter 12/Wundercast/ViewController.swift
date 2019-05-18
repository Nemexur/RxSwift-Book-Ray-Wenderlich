/*
 * Copyright (c) 2014-2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController {

    @IBOutlet private weak var searchCityName: UITextField!
    @IBOutlet private weak var tempLabel: UILabel!
    @IBOutlet private weak var humidityLabel: UILabel!
    @IBOutlet private weak var iconLabel: UILabel!
    @IBOutlet private weak var cityNameLabel: UILabel!
    @IBOutlet private weak var tempSwitch: UISwitch!
    @IBOutlet private weak var celsiusTemp: UILabel!
    @IBOutlet private weak var fahrenheitTemp: UILabel!
    
    let bag = DisposeBag()
    
    var didApiRequest = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        style()
        
        setupSearchCityNameSub()
        setupApiSubscription()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        Appearance.applyBottomLine(to: searchCityName)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Style

    private func style() {
        view.backgroundColor = UIColor.aztec
        searchCityName.textColor = UIColor.ufoGreen
        tempLabel.textColor = UIColor.cream
        humidityLabel.textColor = UIColor.cream
        iconLabel.textColor = UIColor.cream
        cityNameLabel.textColor = UIColor.cream
        celsiusTemp.text = "C"
        fahrenheitTemp.text = "F"
    }
    
    private func setupApiSubscription() {
        let tempChanged = tempSwitch.rx.isOn.asDriver(onErrorJustReturn: true).asObservable()
        let defaultWeather = ApiController.shared.currentWeather(city: "London").observeOn(MainScheduler.instance)
        Observable.combineLatest(tempChanged, defaultWeather) { $1 }
            .subscribe(onNext: { data in
                // Нужно чтобы не мигало значение London, когда делаем получение погоды через запрос к API
                if self.didApiRequest { return }
                else {
                    self.tempLabel.text = self.tempSwitch.isOn ? "\(Int(Double(data.temperature) * 1.8 + 32))° F" : "\(data.temperature)° C"
                    self.iconLabel.text = data.icon
                    self.humidityLabel.text = "\(data.humidity)%"
                    self.cityNameLabel.text = data.cityName
                }
            })
            .disposed(by: bag)
    }
    
    private func setupSearchCityNameSub() {
//        /*
//        There’s one you’ve already explored before: text. This function returns an observable that is a ControlProperty<String?>, which conforms to both ObservableType and ObserverType so you can subscribe to it and also emit new values (thus setting the field text).
//        */
//        searchCityName.rx.text
//            .filter { !($0 ?? "").isEmpty }
//            .flatMap { text in
//                //  Так как работаем с запросыми в сеть, то используем flatMap, он позволяет с ними ассинхронно работать, ожидая их выполнения перед тем, как вставить их в последний Observabel sequence
//                return ApiController.shared.currentWeather(city: text ?? "Error")
//                    /*
//                    The catchErrorJustReturn operator will be explained later in this book. It’s required to prevent the observable from being disposed when you receive an error from the API. For instance, an invalid city name returns a 404 as an error for NSURLSession. In this case you want to return an empty value so the app won’t stop working if it encounters an error.
//                    */
//                    .catchErrorJustReturn(ApiController.Weather.empty)
//            }
//            .observeOn(MainScheduler.instance)
//            .subscribe(onNext: { data in
//                self.tempLabel.text = "\(data.temperature)° C"
//                self.iconLabel.text = data.icon
//                self.humidityLabel.text = "\(data.humidity)%"
//                self.cityNameLabel.text = data.cityName
//            })
//            .disposed(by: bag)
//        /*
//        At this point, whenever you change the input, the label will update with the name of the city
//        */
        
        /*
         At this point, the application takes advantage of a lot of the shiny parts of RxCocoa, but there’s still something you can improve. The application uses way too many resources and makes too many API requests — because it fires a request each time you type a character. A bit of overkill, don’t you think?
         throttle would be a good option, but this would still result in some unnecessary requests. Another good option would be to use the ControlProperty of UITextField and fire a request only when the user hits the Search button on the keyboard.
        */
        /*
        Amazing! Now the application retrieves the weather only when the user hits the Search button. There are no wasted network requests, and the code is controlled at compile time by Units.
        */
//        let search = searchCityName.rx.controlEvent(.editingDidEndOnExit).asObservable()
//            .map { self.searchCityName.text }
//            .filter { !($0 ?? "").isEmpty }
//            /*
//            This change, specifically flatMapLatest, makes the search result reusable and transforms a single-use data source into a multi-use Observable. The power of this change will be covered later in the chapter dedicated to MVVM, but for now simply realize that observables can be heavily reusable entities in Rx, and the correct modeling can make a long, difficult-to-read, single-use observer into a multi-use and easy to understand observer instead.
//            */
//            .flatMapLatest { text in
//                return ApiController.shared.currentWeather(city: text ?? "Error")
//            }
////            .observeOn(MainScheduler.instance)
//            .asDriver(onErrorJustReturn: ApiController.Weather.empty)
//
//        /*
//         An important thing to know here is that in RxCocoa, a binding is a unidirectional (одностороннее) stream of data. This greatly simplifies data flow in the app so you won't cover bi- directional bindings in this book.
//         */
//        /*
//         The easiest way to understand binding is to think of the relationship as a connection between two entities:
//         • A producer, which produces the value
//         • A receiver, which processes the values from the producer (то, что мы вставляем в аргумент bind(to:))
//         A receiver cannot return a value. this is a general rule when using bindings of RxSwift.
//         */
//        /*
//         The fundamental function of binding is bindTo(_:). To bind an observable to another entity, the receiver must conform to ObserverType. This entity has been explained in previous chapters: it’s a Subject which can process values, but can also be written to manually. Subjects are extremely important when working with the imperative nature of Cocoa, considering that the fundamental components such as UILabel, UITextField, and UIImageView have mutable data that can be set or retrieved.
//         */
//        /*
//         It’s important to remember that bindTo(_:) can also be used for other purposes — not just to bind user interfaces to the underlaying data. For example, you could use bindTo(_:) to create dependent processes, so that a certain observable would trigger a subject to perform some background tasks without displaying anything on the screen.
//         */
//
//        /*
//        drive works quite similarly to bindTo; the difference in the name better expresses the intent while using Units.
//        */
//
//        search.map { self.tempSwitch.isOn ? "\(Double($0.temperature) * 1.8 + 32)° F" : "\($0.temperature)° C" }
//            // Binder у tempLabel.rx.text отличается тем, что мы, что вполне очевидно, можем только биндиться к нему, но вот ControlProperty у searchCityName.rx.text пердоставляет оба функционала: и возможность биндиться и возможность отслеживать изменения
////            .bind(to: tempLabel.rx.text)
//            .drive(tempLabel.rx.text)
//            .disposed(by: bag)
//
//        search.map { $0.icon }
////            .bind(to: iconLabel.rx.text)
//            .drive(iconLabel.rx.text)
//            .disposed(by: bag)
//
//        search.map { "\($0.humidity)%" }
////            .bind(to: humidityLabel.rx.text)
//            .drive(humidityLabel.rx.text)
//            .disposed(by: bag)
//
//        search.map { $0.cityName }
////            .bind(to: cityNameLabel.rx.text)
//            .drive(cityNameLabel.rx.text)
//            .disposed(by: bag)
        
        // MARK: - Challenge
        let tempChange = tempSwitch.rx.controlEvent(.valueChanged).asObservable()
        let searchChanged = searchCityName.rx.controlEvent(.editingDidEndOnExit).asObservable()
        
        // Однако в этом решении есть один минус. У нас каждый раз будет повторяться запрос в сеть при любом изменении switch
        let combine = Observable.from([searchChanged, tempChange])
            .merge()
            .map { self.searchCityName.text }
            .filter { !($0 ?? "").isEmpty }
            .flatMapLatest { text in
                return ApiController.shared.currentWeather(city: text ?? "Error")
            }
            .asDriver(onErrorJustReturn: ApiController.Weather.empty)
        
        combine.map {self.didApiRequest = true; return self.tempSwitch.isOn ? "\(Int(Double($0.temperature) * 1.8 + 32))° F" : "\($0.temperature)° C" }
            .drive(tempLabel.rx.text)
            .disposed(by: bag)
        
        combine.map { $0.icon }
            .drive(iconLabel.rx.text)
            .disposed(by: bag)
        
        combine.map { "\($0.humidity)%" }
            .drive(humidityLabel.rx.text)
            .disposed(by: bag)
        
        combine.map { $0.cityName }
            .drive(cityNameLabel.rx.text)
            .disposed(by: bag)
        
        /*
         When binding to UI components, RxCocoa will check that the observation is performed on the main thread. If not, it will call a fatalError()
         and the application will crash with the following message: fatal error: Element can be bound to user interface only on MainThread.
        */
        // Поэтому нужен MainScheduler выше в observeOn(MainScheduler.instance)
        
        /*
        The original schema used a single observable that updated the entire UI; through a breakdown of multiple blocks, you’ve switched from subscribe to bindTo and reused the same observables across the view controller. This approach makes the code quite reusable and easy to work with.
        */
    }
}

