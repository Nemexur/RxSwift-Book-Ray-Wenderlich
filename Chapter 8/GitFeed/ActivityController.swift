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

import UIKit
import RxSwift
import RxCocoa
import Kingfisher
import RxSwiftExt

func cachedFileURL(_ fileName: String) -> URL {
    return FileManager.default
        .urls(for: .cachesDirectory, in: .allDomainsMask)
        .first!
        .appendingPathComponent(fileName)
}

class ActivityController: UITableViewController {
    let repo = "ReactiveX/RxSwift"

    fileprivate let events = Variable<[Event]>([])
    fileprivate let bag = DisposeBag()
    /*
    You will work with an NSString object for the same reasons you used an NSArray before — NSString can easily read and write to disk, thanks to a couple of handy methods
    */
    fileprivate let lastModified = Variable<NSString?>(nil)
    
    private let eventsFileURL = cachedFileURL("events.plist")
    private let modifiedFileURL = cachedFileURL("modified.txt")

    override func viewDidLoad() {
        super.viewDidLoad()
        title = repo

        self.refreshControl = UIRefreshControl()
        let refreshControl = self.refreshControl!

        refreshControl.backgroundColor = UIColor(white: 0.98, alpha: 1.0)
        refreshControl.tintColor = UIColor.darkGray
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        
        let eventsArray = (NSArray(contentsOf: eventsFileURL)
            as? [[String: Any]]) ?? []
        events.value = eventsArray.compactMap(Event.init)
        
        lastModified.value = try? NSString(contentsOf: modifiedFileURL, usedEncoding: nil)

        refresh()
    }

    @objc func refresh() {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            self.fetchEvents(repo: self.repo)
        }
    }

    func fetchEvents(repo: String) {
        /*
         When you insert a flatMap in between, you can achieve different effects:
         • You can flatten observables that instantly emit elements and complete, such as
         the Observable instances you create out of arrays of strings or numbers.
         • You can flatten observables that perform some asynchronous work and effectively “wait” for the observable to complete, and only then let the rest of the chain continue working.
        */
        /*
        То есть flatMap в данном случае выравнивает все элементы на последнюю последовательность обзервера, которая пройдёт дальше и ожидает от них ответа/завершения (получает completed), притом не блокируя UI, и только после этого пропускает дальше по операторам или подписчикам
        */
        /*
        Consider the fact that flatMap only emits the values of an observable when the observable completes. Therefore, if an observable does not complete, flatMap will never emit any values. You’ll use that phenomenon to filter responses that don’t feature a Last-Modified header
        */
        let response = Observable.from(["https://api.github.com/search/repositories?q=language:swift&per_page=5"])
            .map { URL(string: $0) }
            .unwrap()
            .map { URLRequest(url: $0) }
            .flatMap { URLSession.shared.rx.json(request: $0) }
            .flatMap { json -> Observable<String> in
                guard let json = json as? [String: Any],
                    let items = json["items"] as? [[String: Any]]
                else {
                        return Observable.never()
                }
                return Observable<String>.from(items.compactMap { $0["full_name"] as? String })
            }
            .map { URL(string: "https://api.github.com/repos/\($0)/events?per_page=5") }
            .unwrap()
            .map { [weak self] url -> URLRequest in
                /*
                In this new piece of code, you create a URLRequest just as you did before, but you add an extra condition: if lastModified contains a value, no matter whether it’s loaded from a file or stored after fetching JSON, add that value as a Last-Modified header to the request
                */
                /*
                This extra header tells GitHub that you aren’t interested in any events older than the header date. This will not only save you traffic, but responses which don’t return any data won’t count towards your GitHub API usage limit. Everybody wins!
                */
                var request = URLRequest(url: url)
                if let modifiedHeader = self?.lastModified.value {
                    request.addValue(modifiedHeader as String,
                                     forHTTPHeaderField: "Last-Modified")
                }
                return request
            }
            /*
            That method returns an Observable<(response: HTTPURLResponse, data: Data)>, which completes whenever your app receives the full response from the web server
            */
            .flatMap { request -> Observable<(response: HTTPURLResponse, data: Data)> in
                /*
                URLSession.rx.response(request:) sends your request to the server and upon receiving the response emits once a .next event with the returned data, and then completes.
                */
                print("main: \(Thread.isMainThread)")
                return URLSession.shared.rx.response(request: request)
            }
            /*
            You will use shareReply(1) to share the observable and keep in a buffer the last emitted event
            */
            /*
             Если же мы не добавим строчку ниже, то будет происходить вот это: In this situation, if the observable completes and then you subscribe to it again, that will create a new subscription and will fire another identical request to the server. Therefore if your request has completed and a new observer subscribes to the shared sequence (via shareReply(_)) it will immediately receive the response from the server that's being kept in the buffer
            */
            .share(replay: 1)
            /*
            The rule of thumb for using shareReply(_) is to use it on any sequences you expect to complete - this way you prevent the observable from being re-created. You can also use this if you'd like observers to automatically receive the last X emitted events.
            */
        response
            .filter { response, _ in
                // ~= означает, что range из 200..<300 содержит response.statusCode. Фактически просто contains
                // when used with a range on its left side, checks if the range includes the value on its right side
                print("main: \(Thread.isMainThread)")
                return 200..<300 ~= response.statusCode
            }
            .map { _, data -> [[String: Any]] in
                guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                    let result = jsonObject as? [[String: Any]] else { return [] }
                return result
            }
            .filter { $0.count > 0 }
            /*
            The first "map" is a method on an Observable<Array<[String: Any]>> instance and is acting asynchronously on each emitted element. The second "map" is a method on an Array; this map synchronously iterates over the array elements and converts them using Event.init
            */
            /*
            Это как раз и есть применение паттерна итератор относительно описания выше
            */
            .map { $0.compactMap(Event.init) }
            .map { $0.sorted(by: { $0.name < $1.name }) }
            .subscribe(onNext: { [weak self] in
                self?.processEvents($0)
            })
            .disposed(by: bag)
        response
            .filter { response, _ in
                print("main: \(Thread.isMainThread)")
                return 200..<300 ~= response.statusCode
            }
            .flatMap { response, _ -> Observable<NSString> in
                guard let value = response.allHeaderFields["Last-Modified"] as? NSString else {
                    // Observable, который никогда не выдаёт элементы
                    return Observable.never()
                }
                return Observable.just(value)
            }
            .subscribe(onNext: { [weak self] in
                self?.saveModifiedHeader(header: $0)
            })
            .disposed(by: bag)
    }
    
    func processEvents(_ newEvents: [Event]) {
        print("main: \(Thread.isMainThread)")
        var updatedEvents = newEvents + events.value
        if updatedEvents.count > 50 {
            updatedEvents = Array<Event>(updatedEvents.prefix(upTo: 50))
        }
        events.value = updatedEvents
        // Так как "return URLSession.shared.rx.response(request: request)" возвращает результат не на главном потоке, то эта часть кода тоже выполняется не на главном потоке, следовательно нужно сделать обновление таблицы на главном
        // Since that observable emits its .next event from a background thread, all the operators you use from then on also run on that same thread
        DispatchQueue.main.async { [weak self] in
            print("main: \(Thread.isMainThread)")
            guard let self = self else { return }
            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        }
        saveEvents(events: updatedEvents)
    }
    
    func saveEvents(events: [Event]) {
        DispatchQueue.global(qos: .default).async { [weak self] in
            print("main: \(Thread.isMainThread)")
            guard let self = self else { return }
            let eventsArray = events.map{ $0.dictionary } as NSArray
            eventsArray.write(to: self.eventsFileURL, atomically: true)
        }
    }
    
    func saveModifiedHeader(header: NSString) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            print("main: \(Thread.isMainThread)")
            guard let self = self else { return }
            self.lastModified.value = header
            try? header.write(to: self.modifiedFileURL,
                                      atomically: true,
                                      encoding: String.Encoding.utf8.rawValue)
        }
    }

    // MARK: - Table Data Source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return events.value.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let event = events.value[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        cell.textLabel?.text = event.name
        cell.detailTextLabel?.text = event.repo + ", " + event.action.replacingOccurrences(of: "Event", with: "").lowercased()
        cell.imageView?.kf.setImage(with: event.imageUrl, placeholder: UIImage(named: "blank-avatar"))
        return cell
    }
}
