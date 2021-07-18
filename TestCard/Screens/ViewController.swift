//
//  ViewController.swift
//  TestCard
//
//  Created by John on 7/14/21.
//  Copyright © 2021 Abraham Shenghur. All rights reserved.
//

import UIKit
//import CardSlider

struct Movie: CardSliderItem {
    let image: UIImage
    let rating: Int?
    let title: String
    let subtitle: String?
    let description: String?
}

class ViewController: UIViewController {
    let movies = [
        Movie(image: #imageLiteral(resourceName: "trueCar"), rating: nil, title: "TrueCar", subtitle: nil, description: nil),
        Movie(image: #imageLiteral(resourceName: "carGurus"), rating: nil, title: "CarGurus", subtitle: nil, description: nil),
        Movie(image: #imageLiteral(resourceName: "carsDotCom"), rating: nil, title: "Cars.com", subtitle: nil, description: nil),
        Movie(image: #imageLiteral(resourceName: "autotrader"), rating: nil, title: "Autotrader", subtitle: nil, description: nil),
        Movie(image: #imageLiteral(resourceName: "craigslist"), rating: nil, title: "Craigslist", subtitle: nil, description: nil),
    ]
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let cardSlider = CardSliderViewController.with(dataSource: self)
        cardSlider.title = "Websites"
        cardSlider.modalPresentationStyle = .fullScreen
        present(cardSlider, animated: true, completion: nil)
    }
}

extension ViewController: CardSliderDataSource {
    func item(for index: Int) -> CardSliderItem {
        return movies[index]
    }
    
    func numberOfItems() -> Int {
        return movies.count
    }
}
