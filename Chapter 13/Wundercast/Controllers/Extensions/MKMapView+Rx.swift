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

import Foundation
import MapKit
import RxSwift
import RxCocoa

class RxMKMapViewDelegateProxy: DelegateProxy<MKMapView, MKMapViewDelegate>, MKMapViewDelegate, DelegateProxyType {
    init(parentObject: MKMapView) {
        super.init(parentObject: parentObject, delegateProxy: RxMKMapViewDelegateProxy.self)
    }
    
    static func registerKnownImplementations() {
        self.register { RxMKMapViewDelegateProxy(parentObject: $0) }
    }
    
    static func currentDelegate(for object: MKMapView) -> MKMapViewDelegate? {
        return object.delegate
    }
    
    static func setCurrentDelegate(_ delegate: MKMapViewDelegate?, to object: MKMapView) {
        object.delegate = delegate
    }
}
extension Reactive where Base: MKMapView {
    var delegate: RxMKMapViewDelegateProxy {
        return RxMKMapViewDelegateProxy.proxy(for: base)
    }
    
    /*
    You’re basically getting the best of both worlds: you want the practicality of conforming to delegate methods with return values as you do with normal UIKit development, but you also want the ability to use observables from delegate functions. This time, for once, you can have it both ways
    То есть всё будет происходить также как в RxCLLocationManagerProxy. То есть так будто у нас метод делегат ничего не возвращает
    */
    public func setDelegate(_ delegate: MKMapViewDelegate) -> Disposable {
        return RxMKMapViewDelegateProxy.installForwardDelegate(delegate,
                                                               retainDelegate: false,
                                                               onProxyForObject: self.base)
    }
    /*
    Using UIBindingObserver gives you the opportunity to use the bindTo or drive functions — very convenient!
    Inside the overlays binding observable, the previous overlays will be removed and re-created every single time an array is sent to the Subject.
    */
    // Мы не можем биндиться к результатам работы этого элемента, только отправлять обработку результата через bind(to: (и вставить сюда overlays, чтобы они всё обработали на карте)). Эти оба действия может делать ControlProperty как у TextField
    var overlays: Binder<[MKOverlay]> {
        return Binder(self.base) { mapView, overlays in
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlays(overlays)
        }
    }
    
    public var regionDidChangeAnimated: ControlEvent<Bool> {
        let source = delegate
            .methodInvoked(#selector(MKMapViewDelegate.mapView(_:regionDidChangeAnimated:)))
            .map { parameters in
                return (parameters[1] as? Bool) ?? false
        }
        return ControlEvent(events: source)
    }
    
    var center: Binder<CLLocationCoordinate2D> {
        return Binder(self.base) { mapView, coordinates in
            let region = MKCoordinateRegion(center: coordinates, latitudinalMeters: CLLocationDistance(exactly: 500000)!, longitudinalMeters: CLLocationDistance(exactly: 500000)!)
            mapView.setRegion(mapView.regionThatFits(region), animated: true)
        }
    }
}
