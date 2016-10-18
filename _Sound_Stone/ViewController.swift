//
//  ViewController.swift
//  PLAYSOUND
//
//  Created by 研究室 on 2016/04/24.
//  Copyright © 2016年 YUSUKE_WATANABE. All rights reserved.
//
import AVFoundation
import UIKit
import Foundation

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}


class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    var musicPlayer:AVAudioPlayer!
    let music_data = URL(fileURLWithPath: Bundle.main.path(forResource: "vaiueo2d", ofType: "wav")!)
    
    func playsound(){
        do {
            musicPlayer = try AVAudioPlayer(contentsOf: music_data)
            musicPlayer.play()
        }catch let error as NSError {
            //エラーをキャッチした場合
            print(error)
        }
    }
    //@IBOutlet weak var slider: UISlider!
    @IBAction func TouchSynthesisButton(_ sender: AnyObject) {
        let toPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask,true)[0] as String
        //
        //execute_world(NSURL(fileURLWithPath: Bundle.mainBundle().pathForResource("vaiueo2d", ofType: "wav")!).absoluteString,"output.wav")
        //
        let str = URL(fileURLWithPath: Bundle.main.path(forResource: "vaiueo2d", ofType: "wav")!).absoluteString
        let arr = str.components(separatedBy: "///")
        
        
        let length = Int((world_parameter?.f0_length)!)
        for i in 0 ..< length{
            world_parameter!.f0[i] = Double(f0Array[i]!)
        }
        execute_Synthesis(world_parameter!,toPath+"/synthe.wav")
        
        do {
            musicPlayer = try AVAudioPlayer(contentsOf: URL(string:toPath+"/synthe.wav")!)
            musicPlayer.play()
        }catch let error as NSError {
            //エラーをキャッチした場合
            print(error)
        }
    }
    var f0Array:[CGFloat?]!
    var world_parameter : WorldParameters? = nil
    @IBAction func TouchPlayButton(_ sender: AnyObject) {
        print("touched")
        playsound();
        let toPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask,true)[0] as String
        //
        //execute_world(NSURL(fileURLWithPath: Bundle.mainBundle().pathForResource("vaiueo2d", ofType: "wav")!).absoluteString,"output.wav")
        //
        let str = URL(fileURLWithPath: Bundle.main.path(forResource: "vaiueo2d", ofType: "wav")!).absoluteString
        let arr = str.components(separatedBy: "///")
        print(str)
        print(toPath)
        world_parameter = execute_world(arr[1],toPath+"/output.wav",-1)
        
        let length = Int((world_parameter?.f0_length)!)
        f0Array = []
        
        for i in 0 ..< length{
            f0Array.append(CGFloat(world_parameter!.f0[i]))
            //world_parameter!.f0[i] = Double(f0Array[i])
            print(CGFloat(world_parameter!.f0[i]))
            print(",")
        }
        //destroyer
        world_parameter?.f0.deinitialize()
        world_parameter?.aperiodicity.deinitialize()
        world_parameter?.spectrogram.deinitialize()
        world_parameter?.time_axis.deinitialize()
        drawLineGraph(f0Array)
    }
    let graphViewY = 200
    var count = 0
    let graphViewHeight = 200
    var graphFrame = LineStrokeGraphFrame()
    var lineGraphView:UIView = UIView()
    
    func drawLineGraph(_ array:[CGFloat?]) {
        let stroke1 = LineStroke(graphPoints: array)
        stroke1.color = UIColor.cyan
        
        if(count == 0){
            graphFrame = LineStrokeGraphFrame(array: f0Array,strokes: [stroke1])
            lineGraphView = UIView(frame: CGRect(x: 0, y: graphViewY, width: Int(view.frame.width), height: graphViewHeight))
            lineGraphView.backgroundColor = UIColor.gray
            lineGraphView.addSubview(graphFrame)
            graphFrame.isUserInteractionEnabled = true
            graphFrame.addGestureRecognizer(UIPanGestureRecognizer(target:self,action: #selector(ViewController.strokeTapped(_:))))
            view.addSubview(lineGraphView)
        }else{
            graphFrame.removeFromSuperview()
            graphFrame.replaceLines(f0Array,strokes2: [stroke1])
            lineGraphView.addSubview(graphFrame)
        }
    }
    func getMaxIndexFromArray(_ array:[CGFloat?]) -> CGFloat{
        var max = array[0]
        for i in 0..<array.count{
            if(array[i] > max){
                max = array[i]
            }
        }
        return max!
    }
    func strokeTapped(_ sender:UITapGestureRecognizer){
        let tapLocation = sender.location(in: self.view)
        let xAxisMargin = view.frame.width/CGFloat(f0Array.count)
        let index = tapLocation.x/xAxisMargin
        let y = CGFloat(graphViewHeight) - ((tapLocation.y-CGFloat(graphViewY)))
        for i in 0..<7{
            if(Int(index) + i < f0Array.count){
                f0Array.remove(at: Int(index)+i)
                f0Array.insert( y, at:Int(index)+i)
            }
            if(Int(index) - i>0){
                f0Array.remove(at: Int(index)-i)
                f0Array.insert( y, at:Int(index)-i)
            }
        }
        drawLineGraph(f0Array)
        
    }
    
}

protocol GraphObject {
    var view: UIView { get }
}

extension GraphObject {
    var view: UIView {
        return self as! UIView
    }
    func drawLine(_ from: CGPoint, to: CGPoint) {
        let linePath = UIBezierPath()
        
        linePath.move(to: from)
        linePath.addLine(to: to)
        
        linePath.lineWidth = 0.5
        
        let color = UIColor.white
        color.setStroke()
        linePath.stroke()
        linePath.close()
    }
}

protocol GraphFrame: GraphObject {
    var strokes: [GraphStroke] { get }
}

extension GraphFrame {
    // 保持しているstrokesの中で最大値
    var yAxisMax: CGFloat {
        return strokes.map{ $0.graphPoints }.flatMap{ $0 }.flatMap{ $0 }.max()!+20
    }
    
    // 保持しているstrokesの中でいちばん長い配列の長さ
    var xAxisPointsCount: Int {
        return strokes.map{ $0.graphPoints.count }.max()!
    }
    
    // X軸の点と点の幅
    var xAxisMargin: CGFloat {
        return view.frame.width/CGFloat(xAxisPointsCount)
    }
}

class LineStrokeGraphFrame: UIView, GraphFrame {
    var strokes = [GraphStroke]()
    var arr = [CGFloat?]()
    convenience init(array:[CGFloat?],strokes: [GraphStroke]) {
        self.init()
        self.strokes = strokes
        self.arr = array
    }
    internal func replaceLines(_ array : [CGFloat?],strokes2:[GraphStroke]){
        for j in 0 ..< array.count{
            if arr[j] != array[j]{
                for i in 0..<self.subviews.count{
                    if(j == self.subviews[i].tag-1)
                    {
                        self.subviews[i].removeFromSuperview()
                        let temp :UIView = strokes2[j] as! UIView
                        temp.tag = j
                        self.addSubview(temp)
                    }
                }
            }
        }
        
    }
    override func didMoveToSuperview() {
        if self.superview == nil { return }
        self.frame.size = self.superview!.frame.size
        self.view.backgroundColor = UIColor.white
        
        draw(CGRect(x: 0,y: 200,width: self.frame.size.width,height: 200))
        strokeLines()
    }
    
    func strokeLines() {
        var cnt :Int = 1
        for stroke in strokes {
            let view = stroke as! UIView
            view.tag = cnt
            self.addSubview(view)
            cnt = cnt + 1
        }
    }
    
    override func draw(_ rect: CGRect) {
        drawTopLine()
        drawBottomLine()
        //drawVerticalLines()
    }
    
    func drawTopLine() {
        self.drawLine(
            CGPoint(x: 0, y: frame.height),
            to: CGPoint(x: frame.width, y: frame.height)
        )
    }
    
    func drawBottomLine() {
        self.drawLine(
            CGPoint(x: 0, y: 0),
            to: CGPoint(x: frame.width, y: 0)
        )
    }
    
    func drawVerticalLines() {
        for i in 1..<xAxisPointsCount {
            let x = xAxisMargin*CGFloat(i)
            self.drawLine(
                CGPoint(x: x, y: 0),
                to: CGPoint(x: x, y: frame.height)
            )
        }
    }
}


protocol GraphStroke: GraphObject {
    var graphPoints: [CGFloat?] { get }
}

extension GraphStroke {
    var graphFrame: GraphFrame? {
        return ((self as! UIView).superview as? GraphFrame)
    }
    
    var graphHeight: CGFloat {
        return view.frame.height
    }
    
    var xAxisMargin: CGFloat {
        return graphFrame!.xAxisMargin
    }
    
    var yAxisMax: CGFloat {
        return graphFrame!.yAxisMax
    }
    
    // indexからX座標を取る
    func getXPoint(_ index: Int) -> CGFloat {
        return CGFloat(index) * xAxisMargin
    }
    
    // 値からY座標を取る
    func getYPoint(_ yOrigin: CGFloat) -> CGFloat {
        let y: CGFloat = yOrigin/yAxisMax * graphHeight
        return graphHeight - y
    }
}


class LineStroke: UIView, GraphStroke {
    var graphPoints = [CGFloat?]()
    var color = UIColor.white
    
    convenience init(graphPoints: [CGFloat?]) {
        self.init()
        self.graphPoints = graphPoints
    }
    
    override func didMoveToSuperview() {
        if self.graphFrame == nil { return }
        self.frame.size = self.graphFrame!.view.frame.size
        self.view.backgroundColor = UIColor.clear
    }
    
    override func draw(_ rect: CGRect) {
        let graphPath = UIBezierPath()
        
        graphPath.move(
            to: CGPoint(x: getXPoint(0), y: getYPoint(graphPoints[0] ?? 0))
        )
        var index = 0
        for graphPoint in graphPoints.enumerated() {
            if graphPoint.element == nil { continue }
            index = index+1
            let nextPoint = CGPoint(x: getXPoint(index),
                                    y: getYPoint(graphPoint.element!))
            graphPath.addLine(to: nextPoint)
        }
        
        graphPath.lineWidth = 5.0
        color.setStroke()
        graphPath.stroke()
        graphPath.close()
    }
}

