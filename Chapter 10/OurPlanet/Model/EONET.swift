/*
 * Copyright (c) 2016 Razeware LLC
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
import RxSwift
import RxCocoa

class EONET {
    static let API = "https://eonet.sci.gsfc.nasa.gov/api/v2.1"
    static let categoriesEndpoint = "/categories"
    static let eventsEndpoint = "/events"

    static var ISODateReader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"
        return formatter
    }()
    
    /*
    To get categories from EONET, you’ll hit the categories API endpoint. Since these categories seldom change, you can make them a singleton. But you are fetching them asynchronously, so the best way to expose them is with an Observable<[EOCategory]>.
    */
    /*
     Так как категории редко меняются, то нам нужен share replay: 1, чтобы при подключении к ним нового подписчика мы получили уже существующие данные и не делали запрос снова. Также потому, что этот элемент как бы синглтон и статик, следовательно он не должен меняться
    */
    /*
     The categories observable you created is a singleton (static var). All subscribers will get the same one. Therefore:
     • The first subscriber triggers the subscription to the request observable.
     • The response maps to an array of categories.
     • shareReplay(1) relays all elements to the first subscriber.
     • It then replays the last received element to any new subscriber, without re- requesting the data. It acts much like a cache.
    */
    static var categories: Observable<[EOCategory]> = {
        return EONET.request(endpoint: categoriesEndpoint)
            .map { data in
                let categories = data["categories"] as? [[String: Any]] ?? []
                return categories
                    .compactMap(EOCategory.init)
                    .sorted { $0.name < $1.name }
            }
            .share(replay: 1)
    }()

    static func filteredEvents(events: [EOEvent], forCategory category: EOCategory) -> [EOEvent] {
        return events.filter { event in
            return event.categories.contains(category.id) &&
                !category.events.contains {
                    $0.id == event.id
             }
            }
            .sorted(by: EOEvent.compareDates)
    }
    
    static func request(endpoint: String, query: [String: Any] = [:]) ->
        Observable<[String: Any]> {
            do {
                guard let url = URL(string: API)?.appendingPathComponent(endpoint),
                    var components = URLComponents(url: url,
                                                   resolvingAgainstBaseURL: true) else {
                                                    throw EOError.invalidURL(endpoint)
                }
                components.queryItems = try query.compactMap { (key, value) in
                    guard let v = value as? CustomStringConvertible else {
                        throw EOError.invalidParameter(key, value)
                    }
                    return URLQueryItem(name: key, value: v.description)
                }
                guard let finalURL = components.url else {
                    throw EOError.invalidURL(endpoint)
                }
                let request = URLRequest(url: finalURL)
                return URLSession.shared.rx.response(request: request)
                    .map { _, data -> [String: Any] in
                        guard let jsonObject = try? JSONSerialization.jsonObject(with: data,
                                                                                 options: []),
                            let result = jsonObject as? [String: Any] else {
                                throw EOError.invalidJSON(finalURL.absoluteString)
                        }
                        return result
                }
            } catch {
                return Observable.empty()
            }
    }
    
    /*
    The API requires that you download open and closed events separately. Still, you want to make them appear as one flow to subscribers. The initial plan involves making two requests and concatenating their result.
    */
    static func events(forLast days: Int = 360, category: EOCategory) ->
        Observable<[EOEvent]> {
        /*
        Это очень удобно, так как понятно, что они потом вернут результат, то concat создаст Observable, с которым мы потом с можем нормально работать, так как рез прийдёт на другом потоке
        */
            let openEvents = events(forLast: days, closed: false, endpoint: category.endpoint)
            let closedEvents = events(forLast: days, closed: true, endpoint: category.endpoint)
        /*
        This is sequential processing. concat creates an observable that first runs its source observable (openEvents) to completion. It then subscribes to closedEvents and will complete along with it. It relays all events emitted by the first, and then the second observable. If either of those errors out, it immediately relays the error and terminates.
        */
        /*
        То есть, если к нам и придёт результат с закрытого раньше открытого, то мы не будем его использовать, сначала должен пройти первый
        */
        /*
        Тут пока мы не подпишемся на closedEvents, он даже не начнёт проводить запрос на получение элементов, так как для обзервера обязательно подписка. Он ленивый
        */
        // return openEvents.concat(closedEvents)
        /*
        Remember that the EONET API delivers open and closed events separately. Until now, you’ve been using concat(_:) to get them sequentially. It would be a good idea to download them in parallel instead.
        */
        /*
        То есть теперь мы можем получить открытое событи, после него закрытое событие, и опять открытое
        */
        return Observable.of(openEvents, closedEvents)
            /*
            Нужно помнить, что merge подписывается сразу на обоих, то есть начнётся параллельное исполнение запросов
            */
            .merge()
            /*
            Finally, you reduce the result to an array. You start with an empty array, and each time one of the observables delivers an array of events, your closure gets called. There you add the new array to the existing array and return it. This is your ongoing state that grows until all the observables complete. Once complete, reduce emits a single value (its current state) and completes.
            */
            .reduce([]) { running, new in
                running + new
        }
    }
    
    fileprivate static func events(forLast days: Int, closed: Bool, endpoint:
        String) -> Observable<[EOEvent]> {
        return request(endpoint: endpoint, query: [
            "days": NSNumber(value: days),
            "status": (closed ? "closed" : "open")
            ])
            .map { json in
                /*
                 This time, you added proper error handling for invalid JSON. This guard statement that throws an error will propagate to an Observable error. You'll learn more about error handling in Chapter 14, “Error Handling in Practice”. Now you can go back to the categories observable and fix it in the same way.
                 */
                guard let raw = json["events"] as? [[String: Any]] else {
                    throw EOError.invalidJSON(endpoint)
                }
                return raw.compactMap(EOEvent.init)
        }
    }
}
