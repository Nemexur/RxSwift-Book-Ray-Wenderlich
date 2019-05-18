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

class ViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var mapButton: UIButton!
    @IBOutlet weak var geoLocationButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var searchCityName: UITextField!
    @IBOutlet weak var tempLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var iconLabel: UILabel!
    @IBOutlet weak var cityNameLabel: UILabel!

    let bag = DisposeBag()
    /*
    Declaring a location manager instance inside viewDidLoad() would cause a release of the object and the subsequent weird behavior of the alert being displayed and immediately removed once requestWhenInUseAuthorization() was called.
    */
    let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        style()
        
        setupObservables()
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
    
    private func setupObservables() {
        mapButton.rx.tap
            .subscribe(onNext: {
                self.mapView.isHidden = !self.mapView.isHidden
            })
            .disposed(by: bag)
        
        mapView.rx.setDelegate(self)
            .disposed(by: bag)
        /*
        didUpdateLocations emits an array of fetched locations but you need only one to work with, that's why you use map to get only the first location. Then you use filter to prevent working with completely disparate data and to make sure the location is accurate to within a hundred meters.
        */
        
        // ******************************************************
        // MARK: - Geo
        // ******************************************************
        let currentLocation = locationManager.rx.didUpdateLocations
            .map { locations in
                return locations[0]
            }
            .filter { location in
                return location.horizontalAccuracy < kCLLocationAccuracyHundredMeters
        }
        
        let geoInput = geoLocationButton.rx.tap.asObservable()
            .do(onNext: {
                self.locationManager.requestWhenInUseAuthorization()
                self.locationManager.startUpdatingLocation()
            })
        
        /*
        This makes sure the location manager is updating and providing information about the current location, and that only a single value is forwarded. This prevents the application from updating every single time a new value arrives from the location manager.
        */
        /*
        flatMap так как мы ожидаем результат и к нам может приходить ещё
        Плюс мы можем делать несколько тапов и поэтому на каждый тап нужен отедельный обзервабл, который будет постоянно получать значения и передавать их окончательному, финальному обзервараблу, но брать мы в итоге будем только один
        */
        let geoLocation = geoInput.flatMap {
            return currentLocation.take(1)
        }
        let geoSearch = geoLocation.flatMap { location in
            return ApiController.shared.currentWeather(lat:
                location.coordinate.latitude, lon: location.coordinate.longitude)
                .catchErrorJustReturn(ApiController.Weather.dummy)
        }
        // ******************************************************
        // MARK: - Search
        // ******************************************************
        let searchInput =
            searchCityName.rx.controlEvent(.editingDidEndOnExit).asObservable()
                .map { self.searchCityName.text }
                .filter { !($0 ?? "").isEmpty }
        
        let textSearch = searchInput
            .flatMap { text in
                return ApiController.shared.currentWeather(city: text ?? "Error")
                    .catchErrorJustReturn(ApiController.Weather.dummy)
            }
        
        // ******************************************************
        // MARK: - Challenge
        // ******************************************************
        let mapCenter = Observable.from([textSearch, geoSearch])
            .merge()
            .asDriver(onErrorJustReturn: ApiController.Weather.dummy)
        
        mapCenter.map { $0.coordinate }
            .drive(mapView.rx.center)
            .disposed(by: bag)
        // ******************************************************
        
        // ******************************************************
        // MARK: - Map Search
        // ******************************************************
        // То есть теперь при любом дрэге у нас будет показываеть картинка о погоде региона, который находится в центре
        let mapInput = mapView.rx.regionDidChangeAnimated
            /*
            skip(1) prevents the application from firing a search right after the mapView has initialized
            */
            .skip(1)
            .map { _ in self.mapView.centerCoordinate }
        
        let mapSearch = mapInput.flatMap { coordinate in
            return ApiController.shared.currentWeather(lat: coordinate.latitude, lon: coordinate.longitude)
                .catchErrorJustReturn(ApiController.Weather.dummy)
        }
        
        // ******************************************************
        // MARK: - Challenge 2
        // ******************************************************
        mapInput.flatMap { coordinate in
            return ApiController.shared.currentWeatherAround(lat: coordinate.latitude, lon: coordinate.longitude)
                .catchErrorJustReturn([ApiController.Weather.dummy])
            }
            .asDriver(onErrorJustReturn: [ApiController.Weather.dummy])
            .map{ $0.map { $0.overlay() } }
            // Можно не ставить массив, так как это уже будет массив из overlay'eв, значит можно тогда сразу применить mapView.rx.overlays. До этого был просто массив из одного overlay
            .drive(mapView.rx.overlays)
            .disposed(by: bag)
        // ******************************************************
        
        // ******************************************************
        // MARK: - Combine
        // ******************************************************
        // Так как работу через обычный инпут похожа на ту же самую работу выполненную через то же нажатие на локацию, то их можно объединить
        let search = Observable.from([geoSearch, textSearch, mapSearch])
            .merge()
            .asDriver(onErrorJustReturn: ApiController.Weather.dummy)
        
        /*
         Теперь если мы получили значение от searchInput и geoInput, то, скорее всего, сейчас начнётся поиск, поэтому нужно передать true, чтобы поставить его в isHidden тогда, когда мы получим значение от search в результате поиска (flatMap будет ожидать результата от запроса), поэтому нам нужен false, что означает окончание работы индикатора
         */
        /*
         The .asObservable() call is necessary on one of the array elements to help out Swift’s type inferrer. You then merge the two observables. .startWith(true) is an extremely convenient call to avoid having to manually hide all the labels at application start.
         */
        let running = Observable.from([
            searchInput.map { _ in true },
            geoInput.map { _ in true },
            mapInput.map { _ in true},
            search.map { _ in false }.asObservable()
            ])
            .merge()
            .startWith(true)
            .asDriver(onErrorJustReturn: false)
        
        running
            /*
             You have to remember that the first value is injected manually, so you have to skip the first value or else the activity indicator will display immediately once the application has been opened.
             */
            .skip(1)
            .drive(activityIndicator.rx.isAnimating)
            .disposed(by: bag)
        
        /*
         Then add the following to hide and show the labels accordingly to the status:
         Теперь мы будем прятать элементы UI на основе значения running. Значит, если мы ждём запрос, то всё спрятано, а если нет, то всё показать
         Также мы делаем skip, значит мы будем вначале всегда скарывать это
         */
        running
            .drive(tempLabel.rx.isHidden)
            .disposed(by: bag)
        running
            .drive(iconLabel.rx.isHidden)
            .disposed(by: bag)
        running
            .drive(humidityLabel.rx.isHidden)
            .disposed(by: bag)
        running
            .drive(cityNameLabel.rx.isHidden)
            .disposed(by: bag)
        
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
        
        search.map { [$0.overlay()] }
            .drive(mapView.rx.overlays)
            .disposed(by: bag)
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

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let overlay = overlay as? ApiController.Weather.Overlay {
            let overlayView = ApiController.Weather.OverlayView(overlay: overlay, overlayIcon: overlay.icon)
                return overlayView
            }
        return MKOverlayRenderer()
    }
}
