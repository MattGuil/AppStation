//
//  MyCollectionViewCell.swift
//  AppStation
//
//  Created by Matthieu Guillemin on 18/04/2024.
//

import UIKit

class MyCollectionViewCell: UICollectionViewCell {
    static let identifier = "MyCollectionViewCell"
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    init(frame: CGRect, fuel: String) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        
        imageView.image = UIImage(named: fuel)
        contentView.clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = contentView.bounds
    }
    
}
