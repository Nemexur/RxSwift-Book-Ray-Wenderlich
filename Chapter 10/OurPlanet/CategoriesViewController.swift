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

class CategoriesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet var tableView: UITableView!
    var activityIndicator: UIActivityIndicatorView!
    let download = DownloadView()
    
    let categories = Variable<[EOCategory]>([])
    let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        activityIndicator = UIActivityIndicatorView()
        activityIndicator.color = .black
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
        activityIndicator.startAnimating()
        
        view.addSubview(download)
        view.layoutIfNeeded()

        startDownload()
    }

    func startDownload() {
        download.progress.progress = 0.0
        download.label.text = "Download: 0%"
        /*
        bindTo(_:) connects a source observable (EONET.categories) to an observer (the categories variable).
        */
        /*
        Фактически это просто соединение, то есть наши значения будут передавать сразу же categories. И притом сигнал об обновлении value будет посылаться подписчику, так как bindTo при этом обновлеяет значение categories
        */
        let eoCategories = EONET.categories
        /*
        First, you get all the categories. You then call flatMap to transform them into an observable emitting one observable of events for each category. You then merge all these observables into a single stream of event arrays.
        */
        /*
        flatMap ассинхронно получает значения
        */
        let downloadedEvents = eoCategories.flatMap { categories in
            return Observable.from(categories.map { category in
                EONET.events(forLast: 360, category: category)
            })
            }
            /*
            Say you have 25 categories, which trigger 2 API requests each. That’s 50 API requests going out simultaneously to the EONET server. You want to limit the number of concurrent outgoing requests so you don’t hit the free-use threshold of the APIs.
            */
            /*
            This very simple change means that regardless of the number of event download observables flatMap(_:) pushes to its observable, only two will be subscribed to at the same time. Since each event download makes two outgoing requests (for open events and closed events), no more than four requests will fire at once. Others will be on hold until a slot is free.
            */
            .merge(maxConcurrent: 2)
        // Всё будет работать правильно, так как у нас категории не меняются, следовательно мы каждый раз будем вызвать блок ниже при изменение ивентов
        let updatedCategories = eoCategories.flatMap { categories in
            /*
            For every element emitted by its source observable, it calls your closure and emits the accumulated value. In your case, this accumulated value is the updated list of categories.
            */
            /*
            So every time a new group of events arrives, scan emits a category update. Since the updatedCategories observable is bound to the categories variable, the table view updates.
            */
            // events - новое значение из последовательности downloadedEvents, а updated - результат слияния events and updated определённым образом, превоначально updated = categories
            // Мы некоторым обрзаом обрабатывем обзервабл, основываясь на значение событий из downloadedEvents
            //MARK: - Challenge 1
//            downloadedEvents.scan((initial: 0, categories: categories)) { tuple, events in
//                // при map мы никак не меняем значение
//                return (tuple.initial + 1, tuple.categories.map { category in
//                    let eventsForCategory = EONET.filteredEvents(events: events,
//                                                                 forCategory: category)
//                    if !eventsForCategory.isEmpty {
//                        var cat = category
//                        cat.events = cat.events + eventsForCategory
//                        return cat
//                    }
//                    return category
//                })
//            }
            downloadedEvents.scan(categories) { updated, events in
                return updated.map { category in
                    let eventsForCategory = EONET.filteredEvents(events: events, forCategory: category)
                    if !eventsForCategory.isEmpty {
                        var cat = category
                        cat.events = cat.events + eventsForCategory
                        return cat
                    }
                    return category
                }
            }
        }
            /*
            FlatMap completes when it completes with next events from each observable and eoCategories is finite, so do will work properly
            */
            /*
             Это рабоает вот таким образом: Сначала вызывает блок для downloadedEvents.scan и как только проходит map, то мы первый раз имитим значение к do(onNext и потом снова к downloadedEvents.scan и при этом у нас сохранится значение initial, то есть после того как этот блок снова пройдёт к нам в do(onNext придёт tuple.0 = 2 и при этом значение tuple.1 не меняется
            */
            // MARK: - Challenge 1
            .do(/*onNext: { [weak self] tuple in
                DispatchQueue.main.async {
                    let progress = Float(tuple.0) / Float(tuple.1.count)
                    self?.download.progress.progress = progress
                    let percent = Int(progress * 100.0)
                    self?.download.label.text = "Download: \(percent)%"
                }
            }, */onCompleted: { [weak self] in
                DispatchQueue.main.async {
                    self?.activityIndicator.stopAnimating()
                    self?.download.isHidden = true
                }
            })
        
        // MARK: - Challenge 2
        // Теперь работа updatedCategories начнётся с этого места, так как ленивая загрузка. Scan подписывается на изменения, так как он работает со значениями, которые имитятся updatedCategories, поэтому нужна подписка на onNext (можно это проверить по дебагу)
        eoCategories.flatMap { categories in
            return updatedCategories.scan(0) { count, _ in
                return count + 1
                }
                .startWith(0)
                .map { ($0, categories.count) }
            }
            .subscribe(onNext: { tuple in
                DispatchQueue.main.async { [weak self] in
                    let progress = Float(tuple.0) / Float(tuple.1)
                    self?.download.progress.progress = progress
                    let percent = Int(progress * 100.0)
                    self?.download.label.text = "Download: \(percent)%"
                }
            })
            .disposed(by: disposeBag)
        /*
        This will work just fine because eoCategories emits one element (an array of categories) then completes. This allows the concat(_:) operator to subscribe to the next observable, updatedCategories.
        */
        /*
        У нас сначала показываем просто категории с нулевым количеством элементов, потом оно меняется из-за updatedCategories
        */
        eoCategories
            // MARK: - Challenge 1
            .concat(/*updatedCategories.map { $0.1 }*/ updatedCategories)
            .bind(to: categories)
            .disposed(by: disposeBag)
        /*
        Сначала первый раз подписчик выдаст значение по-умолчания, то есть 0
        Потом он уже на другом потоке, так как URLSession.rx.reponse возвращает результат на другом потоке, поэтому в результате bind появится изменение categories.value и будет вызван блок onNext на другом потоке
        */
        categories
            .asObservable()
            .subscribe(onNext: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.tableView?.reloadData()
                }
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        /*
        Since Variable implements locking internally, you’re safe even if updates come from a background thread.
        Следовательно при прохождении запроса этот элемент будет залочен
        */
        return categories.value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "categoryCell")!
        let category = categories.value[indexPath.row]
        cell.textLabel?.text = "\(category.name) (\(category.events.count))"
        cell.accessoryType = (category.events.count > 0) ? .disclosureIndicator
            : .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath:
        IndexPath) {
        let category = categories.value[indexPath.row]
        if !category.events.isEmpty {
            let eventsController =
                storyboard!.instantiateViewController(withIdentifier: "events") as!
            EventsViewController
            // Установка значения events не вызовет ошибку, так как мы ещё не уставновили подписчика, то есть не был вызван viewDidLoad
            eventsController.title = category.name
            eventsController.events.value = category.events
            navigationController!.pushViewController(eventsController, animated:
                true) }
        tableView.deselectRow(at: indexPath, animated: true)
    }
  
}

