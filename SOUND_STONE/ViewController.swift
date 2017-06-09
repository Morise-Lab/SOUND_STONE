//
//  ViewController.swift
//
//  Created by 研究室 on 2016/04/24.
//  Copyright © 2016年 YUSUKE_WATANABE. All rights reserved.
//
import AVFoundation
import UIKit
import Foundation
import SpriteKit

class  ViewController: UIViewController {
    @IBOutlet weak var background: UIImageView!
    //UI画面全体
    var standEffect:SKView?
    //sksスタンドエフェクトのパス
    let maleStandPath = Bundle.main.path(forResource:"male_stand_effect",ofType:"sks",inDirectory:"sks")
    //sksスタンドエフェクトの影のパス
    let maleShadowPath = Bundle.main.path(forResource:"male_shadow_effect",ofType:"sks",inDirectory:"sks")
    //sksスタンドエフェクトのパス
    let femaleStandPath = Bundle.main.path(forResource:"female_stand_effect",ofType:"sks",inDirectory:"sks")
    //sksスタンドエフェクトの影のパス
    let femaleShadowPath = Bundle.main.path(forResource:"female_shadow_effect",ofType:"sks",inDirectory:"sks")
    //本UI画面
    var standScene:SKScene?
    //タップ位置に表示するエフェクト
    var particle = SKEmitterNode()
    //影エフェクト
    var shadow = SKEmitterNode()
    let recordLabel = SKLabelNode(text: "Recording!")
    let replayLabel = SKLabelNode(text: "Replaying!")
    //ファイルアクセス先
    let toPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask,true)[0] as String
    
    var f0Array:[CGFloat?]!
    
    var audioEngine: AVAudioEngine!
    var playernode: AVAudioPlayerNode!
    var syntheNode: AVAudioPlayerNode!
    var buffer:AVAudioPCMBuffer!
    var buffers:[AVAudioPCMBuffer] = []
    //128000/16000 [s]まで許容
    let frameCapacity = 128000
    
    var cnt : Int = 0
    var resultSynthesis_ptr:UnsafeMutablePointer<Double>!
    var world_parameter : WorldParameters? = nil
    //var world_synthesizer : UnsafeMutablePointer<WorldSynthesizer>? = nil
    var syntheTimer: Timer!
    var setBufferTimer: Timer!
    let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: AVAudioChannelCount(2))
    var syntheFile:AVAudioFile = AVAudioFile()
    var f0Offset = 10
    var f0Length = 0
    var femaleCnt:Int = 0
    
    let HeaderFooter = 60
    let AllViewY = 760
    var count = 0
    var graphViewHeight:Int = 0
    var next_bufferNum = 1
    var synthe_bufferNum = 2
    var index:CGFloat = 0.0
    let f0_minValue:CGFloat = 40.0
    var preIndex:CGFloat = 0.0
    var preY:CGFloat = 0.0
    var buffer_num = 0
    let moveSpeed = 0.07
    var beganFlag = false
    
    var xAxisMargin:CGFloat = 0.0
    
    
    func InitializeWorldParameter(wavName:String){
        start = 0
        end = 0
        //分析フェーズ
        let str = URL(fileURLWithPath: Bundle.main.path(forResource: wavName, ofType: "wav",inDirectory:"waves")!).absoluteString
        let arr = str.components(separatedBy: "///")
        world_parameter = execute_world(arr[1],toPath+"/output.wav",-1)
        
        Initializer(&world_parameter!,Int32(buffer_size))
        
        
        f0Length = Int((world_parameter?.f0_length)!)
        f0Array = []
        for i in 0 ..< f0Length{
            f0Array.append(CGFloat(world_parameter!.f0[i]))
        }
        xAxisMargin = view.frame.width/CGFloat(f0Array.count)
    }
    var audioRecorder: AVAudioRecorder!
    var start = 0 , end = 0
    func getStartIndexFromWorldParameter(length:Int)->Int{
        var startIndex:Int = 0
        for i in 0 ..< length{
            if world_parameter?.f0[i] != 0{
                startIndex = i
                break
            }
        }
        if startIndex > f0Offset*2{
            startIndex = startIndex - f0Offset
        }
        return startIndex
    }
    func getEndIndexFromWorldParameter(length:Int)->Int{
        var endIndex:Int = 0
        for i in 0 ..< length{
            if world_parameter?.f0[length - i] != 0{
                endIndex = length - i
                break
            }
        }
        if length - endIndex > f0Offset*2{
            endIndex = endIndex + f0Offset
        }
        return endIndex
    }
    @IBAction func TouchUp_Record(_ sender: Any) {
        self.audioRecorder.stop()
        self.audioRecorder = nil
        
        let pathSource = toPath.components(separatedBy: "/")
        var path = ""
        for i in 1 ..< 8{
            path = path + pathSource[i]+"/"
        }
        
        var wp = execute_world(path+"record.wav",toPath+"/output2.wav",-1)
        
        var length = Int((wp.f0_length))
        if length != 0 {
            Initializer(&wp,Int32(buffer_size))
            start = 0
            end = 0
            replayIndexArray = []
            replayF0Array = []
            replayButton.isHighlighted = true
            
            world_parameter = wp
            f0Array = []
            start = getStartIndexFromWorldParameter(length: length)
            end = getEndIndexFromWorldParameter(length: length)
            
            for i in start ..< end{
                f0Array.append(CGFloat(world_parameter!.f0[i]))
            }
            xAxisMargin = view.frame.width/CGFloat(f0Array.count)
            length = end-start
            DrawLineF0(arr: f0Array,count: length)
            execute_Synthesis(world_parameter!,toPath+"/synthe.wav")
            syntheFile = try! AVAudioFile(forReading:URL(string:toPath+"/synthe.wav")!)
            try! syntheFile.read(into: buffer,frameCount: AVAudioFrameCount(frameCapacity))
            playernode.scheduleBuffer(buffer,at:nil,options:AVAudioPlayerNodeBufferOptions.interrupts,completionHandler:nil)
        }else{
            print("RecordingError!")
        }
        let remove = SKAction.removeFromParent()
        recordLabel.run(remove)
    }
    //StartRecording
    @IBAction func TouchDown_Record(_ sender: Any) {
        InitializeRecording()
        self.audioRecorder.record()
    }
    func InitializeRecording(){
        // 初期化ここから
        recordButton.isEnabled = false
        
        ShowLabelWithAnimation(label: recordLabel)
        
        recordButton.isEnabled = true
        // 録音ファイルを指定する
        let filePath = toPath + "/record.wav"
        print("Record:"+filePath)
        let url = NSURL(fileURLWithPath: filePath)
        
        // 再生と録音の機能をアクティブにする
        let session = AVAudioSession.sharedInstance()
        try! session.setCategory(AVAudioSessionCategoryPlayAndRecord)
        try! session.setActive(true)
        
        // 録音の詳細設定
        let recordSetting: [String: Any] = [AVSampleRateKey: NSNumber(value: 16000),//采样率
            AVFormatIDKey: NSNumber(value: kAudioFormatLinearPCM),//音频格式
            AVLinearPCMBitDepthKey: NSNumber(value: 16),//采样位数
            AVNumberOfChannelsKey: NSNumber(value: 1),//通道数
            AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.max.rawValue)//录音质量
        ];
        // 仕上げ
        do {
            self.audioRecorder = try AVAudioRecorder(url: url as URL, settings: recordSetting)
        } catch {
            fatalError("初期設定にエラー")
        }
        print("Record:recorder Setted")
    }
    @IBAction func Tap_Female(_ sender: Any) {
        replayIndexArray = []
        replayF0Array = []
        replayButton.isHighlighted = true
        let femalePath = getNextFemale()
        LoadWavFromPath(path: femalePath)
        loadEffectData(particlePath: femaleStandPath!,shadowParticlePath: femaleShadowPath!)
    }

    @IBAction func Tap_Male(_ sender: Any) {
        replayIndexArray = []
        replayF0Array = []
        replayButton.isHighlighted = true
        LoadWavFromPath(path: "vaiueo2d")
        loadEffectData(particlePath: maleStandPath!,shadowParticlePath: maleShadowPath!)
    }

    
    //すべてに共通するアプリスタート時の一番最初の設定
    func InitializeView(){
        //操作画面の設定
        standEffect = SKView(frame:CGRect(x: 0, y: HeaderFooter, width: Int(self.view.frame.width), height: AllViewY-HeaderFooter*2))
        //本UI画面の設定
        self.standScene = SKScene(size:CGSize(width:self.view.frame.width,height:CGFloat(AllViewY-HeaderFooter*2)))
        standEffect!.presentScene(standScene)
        //グラフの高さの設定
        graphViewHeight = AllViewY - HeaderFooter*2
    }
    //すべてに共通する画像系のデータ読み込み
    func loadingViewData(){
        //Stand背景の設定
        let backGround = SKSpriteNode(imageNamed:"background")
        self.standScene?.addChild(backGround)
        //self.view.sendSubview(toBack: background)
    }
    func loadEffectData(particlePath:String,shadowParticlePath:String){
        particle.removeFromParent()
        shadow.removeFromParent()
        let pos :CGPoint = CGPoint(x:standScene!.frame.size.width/2,y:standScene!.frame.size.height/2)
        
        particle = NSKeyedUnarchiver.unarchiveObject(withFile: particlePath) as! SKEmitterNode
        particle.name = "stand_effect"
        particle.targetNode = standScene
        particle.position = pos
        shadow = NSKeyedUnarchiver.unarchiveObject(withFile: shadowParticlePath) as! SKEmitterNode
        shadow.name = "shadow_effect"
        shadow.targetNode = standScene
        shadow.position = CGPoint(x:    pos.x+10,y:pos.y-15)
        
        self.standScene?.addChild(particle)
        self.standScene?.addChild(shadow)
        
    }
    
    var replayIndexArray:[CGFloat] = []
    var replayF0Array:[CGFloat?]! = []
    
    
    func InitializeBuffer(cnt:Int){
        for _ in 0 ..< cnt{
            let buff:AVAudioPCMBuffer = AVAudioPCMBuffer(pcmFormat:audioFormat,frameCapacity:AVAudioFrameCount(buffer_size))
            buff.frameLength = AVAudioFrameCount(buffer_size)
            buffers.append(buff)
        }
    }
    let shape = SKShapeNode()
    func DrawLineF0(arr:[CGFloat?],count:Int){
        shape.removeFromParent()
        let path = CGMutablePath()
        for i in 0 ..< count-1{
            path.move(to: CGPoint(x:CGFloat(i)*xAxisMargin,y:arr[i]!))
            path.addLine(to:CGPoint(x:CGFloat(i+1)*xAxisMargin,y:arr[i+1]!))
        }
        shape.path = path
        shape.strokeColor = UIColor.darkGray
        shape.lineWidth = 2
        shape.isAntialiased = true
        self.standScene?.addChild(shape)
    }
    func InitializeAudio(file:AVAudioFile){
        audioEngine = AVAudioEngine()
        playernode = AVAudioPlayerNode()
        syntheNode = AVAudioPlayerNode()
        audioEngine.attach(playernode)
        audioEngine.attach(syntheNode)
        let mixer = audioEngine.mainMixerNode
        audioEngine.connect(playernode,to: mixer, format:file.processingFormat)
        audioEngine.connect(syntheNode,to: mixer, format:audioFormat)
        audioEngine.prepare()
        try! audioEngine.start()
        playernode.play()
        syntheNode.play()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //全てに共通するInitialize処理
        InitializeView()
        loadingViewData()
        InitializeBuffer(cnt: buffer_cnt)
        
        //Maleにおけるデータの読み込み処理
        //WORLDの初期化
        loadEffectData(particlePath: maleStandPath!,shadowParticlePath: maleShadowPath!)
        InitializeWorldParameter(wavName: "vaiueo2d")
        //分析されたf0に従って画面上に声の高さを描画
        DrawLineF0(arr: f0Array,count: f0Length)
        //リアルタイム音声合成のための初期化
        execute_Synthesis(world_parameter!,toPath+"/synthe.wav")
        
        
        syntheFile = try! AVAudioFile(forReading:URL(string:toPath+"/synthe.wav")!)
        //全体再生用
        buffer = AVAudioPCMBuffer(pcmFormat:syntheFile.processingFormat,frameCapacity:AVAudioFrameCount(frameCapacity))
        try! syntheFile.read(into: buffer,frameCount: AVAudioFrameCount(frameCapacity))
        //Audio周りの初期化
        InitializeAudio(file: syntheFile)
        playernode.scheduleBuffer(buffer,at:nil,options:AVAudioPlayerNodeBufferOptions.interrupts,completionHandler:nil)
        
        
        //destroyer
        world_parameter?.f0.deinitialize()
        world_parameter?.aperiodicity.deinitialize()
        world_parameter?.spectrogram.deinitialize()
        world_parameter?.time_axis.deinitialize()
        
        self.view.addSubview(standEffect!)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    let buffer_cnt = 5
    
    var replayMode = false
    var replayIndex = 0
    @IBAction func Tap_Replay(_ sender: Any) {
        if replayIndexArray.count != 0{
            replayMode = true
            
            syntheIndex = Int32(replayIndexArray[replayIndex]) + Int32(start)
            SynthesisToBuffer(syntheIndex: syntheIndex, buffer_num: buffer_num)
            syntheNode.scheduleBuffer(buffers[buffer_num],at:nil,completionHandler:nil)
            replayIndex += 1
            FuncAllTap(flag: false)
            
            ShowLabelWithAnimation(label: replayLabel)
        }
    }
    
    let buffer_size =  512
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        setBufferTimer = Timer.scheduledTimer(timeInterval: 0.032, target: self, selector: #selector(self.SetBufferTimer), userInfo: nil, repeats: true)
        setBufferTimer.fire()
        syntheTimer = Timer.scheduledTimer(timeInterval: 0.001, target: self, selector: #selector(self.SynthesisTimer), userInfo: nil, repeats: true)
        syntheTimer.fire()
    }
    
    @IBOutlet weak var replayButton: UIButton!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var femaleButton: UIButton!
    @IBOutlet weak var maleButton: UIButton!
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        setBufferTimer.invalidate()
        syntheTimer.invalidate()
    }
    

    func SynthesisToBuffer(syntheIndex:Int32,buffer_num:Int){
        //WORLDで合成したPCM配列を取得するための配列の定義
        resultSynthesis_ptr = UnsafeMutablePointer<Double>.allocate(capacity:buffer_size)
        let res = Int(AddFrames(&world_parameter!,(world_parameter?.fs)!,syntheIndex,Int32(Int(buffer_size)),resultSynthesis_ptr,Int32(buffer_size),0))
        
        //もし合成に成功したら下記処理を行う。
        if (res == 1){
            //WORLDから得られた値を再生するためのbufferに入れる。
            //マルチプルバッファのため、次に再生するためのバッファに突っ込む
            for i in 0 ..< Int32(buffer_size){
                buffers[buffer_num].floatChannelData?.pointee[Int(i)] = Float(resultSynthesis_ptr.advanced(by: Int(i)).pointee)
            }
        }
        else{
            print("Synthesis is missed")
        }
    }
    var syntheIndex:Int32 = 0
    func SynthesisTimer(tm: Timer) {
        if canSynthe{
            //if beganFlag{
            //    SynthesisToBuffer(syntheIndex: syntheIndex, buffer_num: buffer_num)
            //    beganFlag = false
            //}
            SynthesisToBuffer(syntheIndex: syntheIndex, buffer_num: synthe_bufferNum)
            canSynthe = false
        }
    }
    var canSynthe = false
    func CanReplay(replayMode:Bool,replayIndexArray:[CGFloat]) -> Bool{
        return (replayMode && replayIndexArray.count != 0)
    }
    func SetBufferTimer(tm: Timer) {
        //合成したPCMバッファを再生するためにスケジュールに設定する。
        if CanReplay(replayMode: replayMode, replayIndexArray: replayIndexArray) {
            canSynthe = true
            syntheNode.scheduleBuffer(buffers[next_bufferNum],at:nil,completionHandler:nil)
            syntheIndex = Int32(replayIndexArray[replayIndex]) + Int32(start)
            world_parameter?.f0[Int(syntheIndex)] = Double(replayF0Array[Int(replayIndex)]!)
            
            MoveParticle(x: replayIndexArray[replayIndex] * xAxisMargin,y: replayF0Array[replayIndex]!, moveSpeed: moveSpeed)
            
            replayIndex += 1
            if replayIndexArray.count == replayIndex{
                replayIndex = 0
                replayMode = false
                FuncAllTap(flag:true)
                replayLabel.removeFromParent()
            }
        }else{
            if index != 0.0{
                canSynthe = true
                syntheNode.scheduleBuffer(buffers[next_bufferNum],at:nil,completionHandler:nil)
                syntheIndex = Int32(index + CGFloat(start))
                
                replayIndexArray.append(index)
                replayF0Array.append(f0Array[Int(index)])
                
            }
        }
        //次のバッファの設定
        buffer_num=(buffer_num+1)%buffer_cnt
        next_bufferNum = (buffer_num+1)%buffer_cnt
        synthe_bufferNum = (next_bufferNum+1)%buffer_cnt
        
        if replayIndexArray.count == 0{
            replayButton.isHighlighted =  true
        }
    }

    
    //------------音声操作-----------
    //Tap開始
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard (!replayMode)else {
            return
        }
        canSynthe = true
        replayIndexArray = []
        replayF0Array = []
        replayButton.isHighlighted = false
        for touch: AnyObject in touches{
            let location = touch.location(in:self.view)
            ChangeF0FromTap(location: location)
            beganFlag = true
            canSynthe = true
            SynthesisToBuffer(syntheIndex: syntheIndex, buffer_num: buffer_num)
            syntheNode.scheduleBuffer(buffers[buffer_num],at:nil,completionHandler:nil)
        }
    }
    //Swipe
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard (!replayMode)else {
            return
        }
        for touch:AnyObject in touches{
            let location = touch.location(in:self.view)
            ChangeF0FromTap(location: location)
        }
    }
    //離した
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard (!replayMode)else {
            return
        }
        InitializePlayerParameter()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard (!replayMode)else {
            return
        }
        InitializePlayerParameter()
    }
    
    //--------ProcessMethod------
    func InitializePlayerParameter(){
        index = 0.0
        bufferCleaner()
        buffer_num = 0
        next_bufferNum = 1
        synthe_bufferNum = 2
        preIndex = 0.0
        preY = 0.0
    }

    func bufferCleaner(){
        for i in 0..<buffer_cnt{
            for j in 0..<buffer_size{
                buffers[i].floatChannelData?.pointee[j] = 0.0
            }
        }
    }
    func ChangeF0FromTap(location:CGPoint){
        var location2 = CGPoint(x:location.x,y:self.view.frame.height - CGFloat(HeaderFooter) - location.y)
        if(location2.y < f0_minValue){
            location2.y = f0_minValue
        }
        MoveParticle(x: location2.x,y: location2.y, moveSpeed: moveSpeed)
        index = location2.x / xAxisMargin
        
        //indexが枠外に出たらギリギリで止める
        if index >= CGFloat(f0Length - start){
            index = CGFloat(f0Length - start) - 1
        }
        var y = location2.y
        if(y < f0_minValue){
            y = f0_minValue
        }
        
        let changeWidth = 1
        //触れている場所を検出し、f0配列の値を変える。WORLDParameterも変更する。
        ChangeF0Line(y: y, changeWidth: changeWidth)
        
        preIndex = index
        preY = y
    }
    func ChangeF0Line(y:CGFloat,changeWidth:Int){
        if(preIndex != 0.0)
        {
            var y1:CGFloat = 0
            var y2:CGFloat = 0
            var x1:Int = 0
            var x2:Int = 0
            
            if(y < preY){
                y1 = (y)
                y2 = (preY)
            }else {
                y1 = (preY)
                y2 = (y)
            }
            
            if(preIndex < index){
                x1 = (Int(preIndex))
                x2 = (Int(index))
            }else{
                x2 = (Int(preIndex))
                x1 = (Int(index))
            }
            let dx = x2-x1
            let dy = y2-y1
            var e:CGFloat = 0
            var tempY:CGFloat = 0.0
            
            if(dx > changeWidth){
                for i in 0..<Int(dx){
                    f0Array.remove(at: Int(x1)+i)
                    f0Array.insert(y1+tempY, at: Int(x1)+i)
                    world_parameter!.f0[Int(x1)+i] = Double(f0Array[Int(x1)+i]!)
                    e = e + dy
                    if(2 * e >= CGFloat(dx)){
                        tempY = tempY+1
                        e = e - CGFloat(dx)
                    }
                }
            }
        }
        for i in 0..<changeWidth {
            if(Int(index) + i < f0Array.count){
                f0Array.remove(at: Int(index)+i)
                f0Array.insert( y, at:Int(index)+i)
                world_parameter!.f0[Int(index)+i+start] = Double(f0Array[Int(index)+i]!)
            }
            if(Int(index) - i>0){
                f0Array.remove(at: Int(index)-i)
                f0Array.insert( y, at:Int(index)-i)
                world_parameter!.f0[Int(index)-i+start] = Double(f0Array[Int(index)-i]!)
            }
        }
    }
    func FuncAllTap(flag:Bool){
        recordButton.isEnabled = flag
        femaleButton.isEnabled = flag
        maleButton.isEnabled = flag
        replayButton.isEnabled = flag
    }
    
    func MoveParticle(x:CGFloat,y:CGFloat,moveSpeed:Double){
        let action1 = SKAction.moveTo(x: x, duration: moveSpeed)
        let action2 = SKAction.moveTo(y: y, duration: moveSpeed)
        action1.timingMode = SKActionTimingMode.easeInEaseOut
        action2.timingMode = SKActionTimingMode.easeInEaseOut
        
        let action3 = SKAction.moveTo(x: x + 10, duration: moveSpeed)
        let action4 = SKAction.moveTo(y: y - 15, duration: moveSpeed)
        action3.timingMode = SKActionTimingMode.easeInEaseOut
        action4.timingMode = SKActionTimingMode.easeInEaseOut
        shadow.run(action3)
        shadow.run(action4)
        particle.run(action1)
        particle.run(action2)
    }
    func getNextFemale()->String{
        var path:String = ""
        if femaleCnt == 0{
            path = "vaiueo_female"
        }else if femaleCnt == 1{
            path = "vaiueo_female3"
            femaleCnt = -1
        }
        femaleCnt = femaleCnt+1
        return path
    }
    func ShowLabelWithAnimation(label:SKLabelNode){
        label.fontName = "Snell Roundhand"
        label.position = CGPoint(x:standScene!.size.width / 4 * 2,y:(standScene?.size.height)! / 2)
        label.fontColor  = SKColor.darkGray
        label.fontSize = 36
        label.alpha = 0
        standScene?.addChild(label)
        let fadeIn = SKAction.fadeIn(withDuration:1)
        let fadeOut = SKAction.fadeOut(withDuration:1)
        let act = SKAction.sequence([fadeIn,fadeOut])
        let repeatAct = SKAction.repeat(act,count:100)
        label.run(repeatAct)
    }
    func LoadWavFromPath(path:String){
        InitializeWorldParameter(wavName: path)
        DrawLineF0(arr: f0Array,count: f0Length)
        execute_Synthesis(world_parameter!,toPath+"/synthe.wav")
        syntheFile = try! AVAudioFile(forReading:URL(string:toPath+"/synthe.wav")!)
        try! syntheFile.read(into: buffer,frameCount: AVAudioFrameCount(frameCapacity))
        playernode.scheduleBuffer(buffer,at:nil,options:AVAudioPlayerNodeBufferOptions.interrupts,completionHandler:nil)
    }
}
