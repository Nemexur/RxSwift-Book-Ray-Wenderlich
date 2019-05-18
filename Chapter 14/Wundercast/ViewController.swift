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
import MapKit
import CoreLocation

typealias Weather = ApiController.Weather

class ViewController: UIViewController {

    @IBOutlet weak var keyButton: UIButton!
    @IBOutlet weak var geoLocationButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var searchCityName: UITextField!
    @IBOutlet weak var tempLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var iconLabel: UILabel!
    @IBOutlet weak var cityNameLabel: UILabel!

    let bag = DisposeBag()
    let locationManager = CLLocationManager()
    let maxAttempts = 4
    
    var cache = [String: Weather]()

    var keyTextField: UITextField?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        style()

        _ = RxReachability.shared.startMonitor("openweathermap.org")
        
        keyButton.rx.tap.subscribe(onNext: {
            self.requestKey()
        }).disposed(by: bag)

        let currentLocation = locationManager.rx.didUpdateLocations
            .map() { locations in
                return locations[0]
            }
            .filter() { location in
                return location.horizontalAccuracy == kCLLocationAccuracyNearestTenMeters
        }

        let geoInput = geoLocationButton.rx.tap.asObservable().do(onNext: {
            self.locationManager.requestWhenInUseAuthorization()
            self.locationManager.startUpdatingLocation()

            self.searchCityName.text = "Current Location"
        })

        let geoLocation = geoInput.flatMap {
            return currentLocation.take(1)
        }

        let geoSearch = geoLocation.flatMap() { location in
            return ApiController.shared.currentWeather(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
                .catchErrorJustReturn(ApiController.Weather.empty)
        }

        let searchInput = searchCityName.rx.controlEvent(.editingDidEndOnExit).asObservable()
            .map { self.searchCityName.text }
            .filter { !($0 ?? "").isEmpty }
        
        let retryHandler: (Observable<Error>) -> Observable<Int> = { e in
            // flatMap так как мы тут возвращаем именно Observable<Int> в скоупе enumerated().flatMap, а он если поставить map превратиться в Observable<Observable<Int>>, тогда нужно возвращать Int в enumerated().map
            // То есть если наша обработка значений Observable, должна трансформировать значения (Int, String и тому подобное) в некоторый Observable, то нужно использовать flatMap
            return e.enumerated().flatMap { (attempt, error) -> Observable<Int> in
                if attempt >= self.maxAttempts - 1 {
                    return Observable.error(error)
                } else if let casted = error as? ApiController.ApiError, casted == .invalidKey {
                    return ApiController.shared.apiKey
                        .filter {$0 != ""}
                        /*
                         The return type in the invalidKey case isn’t important, but you have to be consistent. Before, it was an Observable<Int> so you should stick with that return type. For this reason, you’ve used { _ in return 1 }.
                         */
                        .map { _ in return 1 }
                } else if (error as NSError).code == -1009 {
                    return RxReachability.shared.status
                        // Если бы тут было offline, то мы бы пошли дальше и попробовали снова, то есть обработка бы повторилась, до появления ошибки, что в первом if clouse, то есть 3 раза, а так мы тут просто застряли так как в map ничего не приходит, а оно должно прийти, чтобы потом перейти в map и в итоге увеличить каунтер попыток. В результате мы ждём на другом потоке пока, что-то придёт в map, но оно не придёт, так как теперь из-за того, что URLSession выбросило ошибку, он просто isDisposed, теперь мы не можем снова сделать запрос. Это особенность работы URLSession. Затем она больше не выбрасывает ошибку, если сначала всё работало с интернетом, а потом его отключили, в таком случае он только через какое-то время выкенет ошибку и isDisposed, в отличие от незамедлительного действия такого рода. Та же логика работы у if clouse выше
                        .filter { $0 == .online }
                        .map { _ in return 1 }
                }
                print("== retrying after \(attempt + 1) seconds ==")
                return Observable<Int>.timer(Double(attempt + 1), scheduler:
                    MainScheduler.instance)
                    .take(1)
            }
        }

        // Если бы мы тут никак не обрабатывали ошибку то, наш Observable searchInput сразу бы при получении ошибки сделала terminate, а подписчики получили бы isDisposed
        let textSearch = searchInput.flatMap { text in
            return ApiController.shared.currentWeather(city: text ?? "Error")
                .debug("first Response", trimOutput: false)
                .do(onNext: { data in
                    if let text = text {
                        self.cache[text] = data
                    }
                }, onError: { [weak self] e in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.showError(error: e)
                    }
                })
                /*
                To test this, input three or four various cities such as “London”, “New York”, “Amsterdam” and load the weather of these cities. After that, disable your internet connection and perform a search for a different city, such as “Barcelona”; you should receive an error. Leave your internet connection disabled and search for one of the cities you just retrieved data for, and the application should return the cached version.
                */
                // Параметр, переданный в качетсве аргумента в retry обозначает количество повторений и игнорирований ошибки в данном случае, если отключить интернет, то 1 раз повторить блок onError, если 2 или 3, то соответственно 2 или 3
                /*
                If the observable is producing errors, it will be retried three times in succession and in case it errors a fourth time, that error will not be handled and the execution will move on to the catchError operator.
                */
//                .retry(3)
                .retryWhen(retryHandler)
                .catchError { error in
                    if let text = text, let cachedData = self.cache[text] {
                        return Observable.just(cachedData)
                    } else {
                        return Observable.just(ApiController.Weather.empty)
                    }
            }
        }

        let search = Observable.from([geoSearch, textSearch])
            .merge()
            .asDriver(onErrorJustReturn: ApiController.Weather.empty)

        let running = Observable.from([searchInput.map { _ in true },
                                       geoInput.map { _ in true },
                                       search.map { _ in false }.asObservable()])
            .merge()
            .startWith(true)
            .asDriver(onErrorJustReturn: false)

        search.map { "\($0.temperature)° C" }
            .drive(tempLabel.rx.text)
            .disposed(by: bag)

        search.map { $0.icon }
            .drive(iconLabel.rx.text)
            .disposed(by: bag)

        search.map { "\($0.humidity)%" }
            .drive(humidityLabel.rx.text)
            .disposed(by: bag)

        search.map { $0.cityName }
            .drive(cityNameLabel.rx.text)
            .disposed(by: bag)

        running.skip(1).drive(activityIndicator.rx.isAnimating).disposed(by: bag)
        running.drive(tempLabel.rx.isHidden).disposed(by: bag)
        running.drive(iconLabel.rx.isHidden).disposed(by: bag)
        running.drive(humidityLabel.rx.isHidden).disposed(by: bag)
        running.drive(cityNameLabel.rx.isHidden).disposed(by: bag)

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

    func requestKey() {

        func configurationTextField(textField: UITextField!) {
            self.keyTextField = textField
        }

        let alert = UIAlertController(title: "Api Key",
                                      message: "Add the api key:",
                                      preferredStyle: .alert)

        alert.addTextField(configurationHandler: configurationTextField)

        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler:{ (UIAlertAction) in
            ApiController.shared.apiKey.onNext(self.keyTextField?.text ?? "")
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive))

        self.present(alert, animated: true)
    }
    
    private func showError(error e: Error) {
        if let e = e as? ApiController.ApiError {
            switch (e) {
            case .cityNotFound:
                InfoView.showIn(viewController: self, message: "City Name is invalid")
            case .serverFailure:
                InfoView.showIn(viewController: self, message: "Server error")
            case .invalidKey:
                InfoView.showIn(viewController: self, message: "Key is invalid")
            }
        } else if (e as NSError).code == -1009 {
            InfoView.showIn(viewController: self, message: e.localizedDescription)
        } else {
            InfoView.showIn(viewController: self, message: "An error occurred")
        }
    }

    // MARK: - Style

    private func style() {
        view.backgroundColor = UIColor.aztec
        searchCityName.textColor = UIColor.ufoGreen
        tempLabel.textColor = UIColor.cream
        humidityLabel.textColor = UIColor.cream
        iconLabel.textColor = UIColor.cream
        cityNameLabel.textColor = UIColor.cream
    }
}
