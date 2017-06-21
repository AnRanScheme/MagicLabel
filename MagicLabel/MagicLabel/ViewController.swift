//
//  ViewController.swift
//  MagicLabel
//
//  Created by 安然 on 2017/6/21.
//  Copyright © 2017年 MacBook. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var magicLabel: MagicLabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        magicLabel.patterns = ["安然",
        "啊哈哈"]
        magicLabel.delegate = self
        magicLabel.text = "的核算的\n会撒娇暗杀时间安然,啊速度哈\n时间啊哈哈是的环境内三科"
        magicLabel.textColor = UIColor.black
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

extension ViewController: MagicLabelDelegate {
    func labelDidSelectedLinkText(_ label: MagicLabel, text: String) {
        print("测试")
    }
}
