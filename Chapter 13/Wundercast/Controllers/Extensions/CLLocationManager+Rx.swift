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
import CoreLocation
import RxSwift
import RxCocoa
import RxSwiftExt

// В КНИГЕ СТАРЫМ ОБРАЗОМ СДЕЛАНА ЭТА ЧАСТЬ
/*
 CLLocationManager requires a delegate, and for this reason you need to create the necessary proxy to drive all the data from the necessary location manager delegates to the dedicated observables. The mapping is a simple one-to-one relationship, so a single protocol function will correspond to a single observable that returns the given data.
*/
/*
То есть при помощи этого делегата мы будем доставлять всю необходимую информацию нашим подписчикам. Этого как раз и позволяет делать DelegateProxy, он может обернуть работу паттерна делегат для работы с реактившиной
*/
/*
RxCLLocationManagerDelegateProxy is going to be your proxy that attaches to the CLLocationManager instance right after an observable is created and has a subscription.
*/
class RxCLLocationManagerDelegateProxy: DelegateProxy<CLLocationManager, CLLocationManagerDelegate>,
CLLocationManagerDelegate, DelegateProxyType {
    /*
    By using these two functions, you can get and set the delegate, which will be the proxy used to drive the data from the CLLocationManager instance to the connected observables. This is how you expand a class to use the delegate proxy pattern from RxCocoa.
    */
    class func setCurrentDelegate(_ delegate: CLLocationManagerDelegate?, to object: CLLocationManager) {
        let locationManager = object
        locationManager.delegate = delegate
    }
    class func currentDelegate(for object: CLLocationManager) -> CLLocationManagerDelegate? {
        let locationManager = object
        return locationManager.delegate
    }
    
    init(parentObject: CLLocationManager) {
        super.init(parentObject: parentObject, delegateProxy: RxCLLocationManagerDelegateProxy.self)
    }
    
    static func registerKnownImplementations() {
        self.register { RxCLLocationManagerDelegateProxy(parentObject: $0) }
    }
}

/*
Using the Reactive extension will expose the methods within that extension in the rx namespace for an instance of CLLocationManager. You now have an exposed extension rx available for every CLLocationManager instance, but unfortunately you have no real observables to get the real data.
Теперь мы можем использовать методы из rx для CLLocationManager
 Это можно увидеть во ViewController.swift
*/
extension Reactive where Base: CLLocationManager {
    var delegate: RxCLLocationManagerDelegateProxy {
        return RxCLLocationManagerDelegateProxy.proxy(for: base)
    }
    var didUpdateLocations: Observable<[CLLocation]> {
        return
            /*
            With this function, the delegate used as the proxy will listen to all the calls of didUpdateLocations, getting the data and casting it to an array of CLLocation. methodInvoked(_:) is part of the Objective-C code present in RxCocoa and is basically a low-level observer for delegates.
            methodInvoked(_:) returns an observable that sends next events whenever the specified method is invoked (то есть происходит обновление местположения через делегат didUpdateLocations). The elements included in those events are an array of the parameters the method was invoked with. You access this array with parameters[1] and cast it to an array of CLLocation.
            */
            // didUpdateLocations ничего не возвращает он просто получает новое значение локации
            delegate.methodInvoked(#selector(CLLocationManagerDelegate.locationManager(_:didUpdateLocations:)))
                .map { parameters in
                    return parameters[1] as? [CLLocation]
                }
                .unwrap()
    }
}
