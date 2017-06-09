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
    //------音声パラメタ管理構造体-------
    //------------------------------------------
    //----------i!i!i!  WORLD  i!i!i!-----------
    var world_parameter : WorldParameters? = nil
    
    var f0Array:[CGFloat?]!             //F0管理用配列
    
    //------------画面UI-------------
    var standEffect:SKView?
    var standScene:SKScene?
    let HeaderFooter = 60               //実質ボタンのサイズ
    let AllViewY = 760                  //操作画面のサイズ
    let GraphOffset = 10                //録音時の左右の余裕
    let F0Line = SKShapeNode()          //画面上にF0の線を描画するためのShape
    
    //--------エフェクト系の設定--------
    let MaleStandPath = Bundle.main.path(forResource:"male_stand_effect",ofType:"sks",inDirectory:"sks")
    let MaleShadowPath = Bundle.main.path(forResource:"male_shadow_effect",ofType:"sks",inDirectory:"sks")
    let FeMaleStandPath = Bundle.main.path(forResource:"female_stand_effect",ofType:"sks",inDirectory:"sks")
    let FemaleShadowPath = Bundle.main.path(forResource:"female_shadow_effect",ofType:"sks",inDirectory:"sks")
    
    var particle = SKEmitterNode()      //タップ位置に表示するエフェクト
    var shadow = SKEmitterNode()        //影エフェクト
    let ParticleMoveSpeed = 0.07        //追尾particle速度
    
    //画面表示用ラベル
    let RecordLabel = SKLabelNode(text: "Recording!")
    let ReplayLabel = SKLabelNode(text: "Replaying!")

    
    //音声ファイル等ファイルアクセス先
    let ToPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask,true)[0] as String

    //--------音声再生関連変数------
    //AVAudio系
    var audioEngine: AVAudioEngine!
    var playerNode: AVAudioPlayerNode!
    var syntheNode: AVAudioPlayerNode!
    
    //再生用PCMBuffer
    var buffer:AVAudioPCMBuffer!        //音声全体再生用バッファ
    var buffers:[AVAudioPCMBuffer] = [] //リアルタイム再生用バルチバッファ
    let BufferCnt = 5                  //バッファ数(5が最小)
    let BufferSize =  512              //バッファ単位のサイズ
    var bufferNum = 0                  //現在再生中バッファの番号
    var nextBufferNum = 1              //次に再生予定のバッファ番号 (事前にバッファを追加しておくため)
    var syntheBufferNum = 2            //次の次に再生予定のバッファ番号 (バッファに追加する前に合成しておくため)
    let FrameCapacity = 128000          //128000/16000 [s]まで許容
    
    //リアルタイム再生のためのタイマー
    var syntheTimer: Timer!             //事前合成用タイマー
    var setBufferTimer: Timer!          //バッファに書き込むためのタイマー
    
    
    //---------録音機能関連変数----------
    //音声フォーマット(16 [kHz] , 2)
    let AudioFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: AVAudioChannelCount(2))
    var audioRecorder: AVAudioRecorder! //録音用レコーダ
    var f0Start = 0 , f0End = 0             //F0のSTARTとEND

    //--------スワイプ操作時関連変数-------
    var tapIndex:CGFloat = 0.0          //現在タップしているxIndex
    var syntheIndex:Int32 = 0           //合成するxIndex (=tapIndex + startIndex)
    var preIndex:CGFloat = 0.0          //直前にタップしていたxIndex
    var preY:CGFloat = 0.0              //直前にタップしていたY座標
    var canSynthe = false               //合成タイミングフラグ
    var xAxisMargin:CGFloat = 0.0       //xIndexの座標Margin
    let F0MinValue:CGFloat = 40.0      //操作の最低の基本周波数は40 [Hz]まで
    
    //----------Replay機能用変数---------
    var replayMode = false              //Replay状態管理フラグ
    var replayIndex = 0                 //Replay再生時の位置
    var replayIndexArray:[CGFloat] = [] //Replay操作xIndex管理用配列
    var replayF0Array:[CGFloat?]! = []  //Replay操作F0管理用配列
    
    //---------UIボタンのOutlet---------
    @IBOutlet weak var replayButton: UIButton!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var femaleButton: UIButton!
    @IBOutlet weak var maleButton: UIButton!

    var femaleCnt:Int = 0               //現在再生中の女性発話者番号

    override func viewDidLoad() {
        super.viewDidLoad()
        //Initialize処理
        InitializeView()
        InitializeBuffer(cnt: BufferCnt)
        
        //エフェクト読み込み
        loadEffectData(particlePath: MaleStandPath!,shadowParticlePath: MaleShadowPath!)
        self.view.addSubview(standEffect!)
        
        //WORLDの初期化
        InitializeWorldParameter(wavName: "vaiueo2d")
        
        let F0Length = Int((world_parameter?.f0_length)!)
        //分析されたf0に従って画面上に声の高さを描画
        DrawLineF0(arr: f0Array,count: F0Length)
        
        //リアルタイム音声合成のための初期化と合成音声synthe.wavの生成
        execute_Synthesis(world_parameter!,ToPath+"/synthe.wav")
        
        //生成されたsyntheファイルの読み込み
        let syntheFile = try! AVAudioFile(forReading:URL(string:ToPath+"/synthe.wav")!)
        //Bufferの初期化
        buffer = AVAudioPCMBuffer(pcmFormat:syntheFile.processingFormat,frameCapacity:AVAudioFrameCount(FrameCapacity))
        //ファイルからバッファへ読み込み
        try! syntheFile.read(into: buffer,frameCount: AVAudioFrameCount(FrameCapacity))
        
        //Audio周りの初期化
        InitializeAudio(file: syntheFile)
        //再生
        playerNode.scheduleBuffer(buffer,at:nil,options:AVAudioPlayerNodeBufferOptions.interrupts,completionHandler:nil)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    //起動時、viewDidLoadのあとに呼び出し
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        //バッファ書き込みタイマーの設定
        setBufferTimer = Timer.scheduledTimer(timeInterval: 0.032, target: self, selector: #selector(self.SetBufferTimer), userInfo: nil, repeats: true)
        //着火
        setBufferTimer.fire()
        
        //合成タイミング用タイマーの設定
        syntheTimer = Timer.scheduledTimer(timeInterval: 0.001, target: self, selector: #selector(self.SynthesisTimer), userInfo: nil, repeats: true)
        //Bomb
        syntheTimer.fire()
    }
    //終了時、画面遷移時に呼び出し
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        setBufferTimer.invalidate()
        syntheTimer.invalidate()
    }
    
    //--------------------------
    //------SwipeFunction-------
    //--------------------------
    
    //タップ開始
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //リプレイモード時はタップ受け付けない
        guard (!replayMode)else {
            return
        }
        //再生開始するからもう合成していいよ
        canSynthe = true
        //タップ開始時にリプレイに関する配列は初期化
        replayIndexArray = []
        replayF0Array = []
        //少しでも操作すればリプレイ機能使えます
        replayButton.isHighlighted = false
        
        //タップした位置にもとづいてF0変更・バッファに書き込み・再生とか行う
        for touch: AnyObject in touches{
            let location = touch.location(in:self.view)
            ChangeF0FromTap(location: location)
            SynthesisToBuffer(syntheIndex: syntheIndex, bufferNum: bufferNum)
            syntheNode.scheduleBuffer(buffers[bufferNum],at:nil,completionHandler:nil)
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
    //指離した
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

    //--------------------------
    //------RecordFunction------Recordボタンを押してる間は録音、離したら終了という流れ
    //--------------------------
    
    //録音ボタン押した 録音開始
    @IBAction func TouchDown_Record(_ sender: Any) {
        InitializeRecording()
        self.audioRecorder.record()
    }
    //録音ボタン離した 録音ファイル保存
    @IBAction func TouchUp_Record(_ sender: Any) {
        self.audioRecorder.stop()
        self.audioRecorder = nil
        
        //録音ファイルまでのパス
        let pathSource = ToPath.components(separatedBy: "/")
        var path = ""
        for i in 1 ..< 8{
            path = path + pathSource[i]+"/"
        }
        //録音した音声のWORLD分析
        var wp = execute_world(path+"record.wav",ToPath+"/output2.wav",-1)
        
        var length = Int((wp.f0_length))
        //しっかり録音されたら加工可能
        if length != 0 {
            //----初期化処理----
            Initializer(&wp,Int32(BufferSize))
            f0Start = 0
            f0End = 0
            replayIndexArray = []
            replayF0Array = []
            replayButton.isHighlighted = true
            //----------------
            
            world_parameter = wp
            f0Array = []
            //f0発話開始と終了タイミングを取得
            f0Start = getStartIndexFromWorldParameter(length: length)
            f0End = getEndIndexFromWorldParameter(length: length)
            
            for i in f0Start ..< f0End{
                f0Array.append(CGFloat(world_parameter!.f0[i]))
            }
            xAxisMargin = view.frame.width/CGFloat(f0Array.count)
            length = f0End-f0Start
            DrawLineF0(arr: f0Array,count: length)
            execute_Synthesis(world_parameter!,ToPath+"/synthe.wav")
            //合成音声の読み込みと再生
            let syntheFile = try! AVAudioFile(forReading:URL(string:ToPath+"/synthe.wav")!)
            try! syntheFile.read(into: buffer,frameCount: AVAudioFrameCount(FrameCapacity))
            playerNode.scheduleBuffer(buffer,at:nil,options:AVAudioPlayerNodeBufferOptions.interrupts,completionHandler:nil)
        }else{
            print("RecordingError!")
        }
        //Recording!っていうラベルを消す
        let removeAction = SKAction.removeFromParent()
        RecordLabel.run(removeAction)
    }

    //--------------------------
    //----LoadVoiceFunction-----
    //--------------------------
    //女性発話の読み込み
    @IBAction func Tap_Female(_ sender: Any) {
        replayIndexArray = []
        replayF0Array = []
        replayButton.isHighlighted = true
        let femalePath = getNextFemale()
        //複数回押すと女性発話が変わる(2音声だけ)
        LoadWavFromPath(path: femalePath)
        loadEffectData(particlePath: FeMaleStandPath!,shadowParticlePath: FemaleShadowPath!)
    }
    //男性発話の読み込み
    @IBAction func Tap_Male(_ sender: Any) {
        replayIndexArray = []
        replayF0Array = []
        replayButton.isHighlighted = true
        LoadWavFromPath(path: "vaiueo2d")
        loadEffectData(particlePath: MaleStandPath!,shadowParticlePath: MaleShadowPath!)
    }
    
    //--------------------------
    //------ReplayFunction------
    //--------------------------
    //直前の一連操作において操作位置とF0を保存しておいたものを、現状のタイマー環境を用いて無理やり再現してるだけ
    @IBAction func Tap_Replay(_ sender: Any) {
        if replayIndexArray.count != 0{ //何かしら操作があったら
            replayMode = true           //Replay使えるよ！このMode変更によってSetBufferTimerの動きが変更
            
            //バッファ再生の構成上、予め最初のバッファは読み込んで再生する。
            syntheIndex = Int32(replayIndexArray[replayIndex]) + Int32(f0Start)
            SynthesisToBuffer(syntheIndex: syntheIndex, bufferNum: bufferNum)
            syntheNode.scheduleBuffer(buffers[bufferNum],at:nil,completionHandler:nil)
            replayIndex += 1
            
            FuncAllTap(flag: false)
            
            //Replay中だよ！って画面にフェードイン・フェードアウトしながら表示する豪華なエフェクト
            ShowLabelWithAnimation(label: ReplayLabel)
        }
    }
    
    //--------------------------
    //-------TimerProcess-------
    //--------------------------

    //すごい早く繰り返されるタイマーで、合成可能になったら大急ぎで合成してPCMBufferに一時保存する
    func SynthesisTimer(tm: Timer) {
        if canSynthe{
            SynthesisToBuffer(syntheIndex: syntheIndex, bufferNum: syntheBufferNum)
            canSynthe = false
        }
    }

    //BufferSizeに対応した速度で繰り返されるタイマーで、ちょうどいい素晴らしいタイミングで次のバッファを再生用のNodeに詰め込む
    //ここでは、リプレイモードか、操作モードかで大きく機構が分岐する
    func SetBufferTimer(tm: Timer) {
        //リプレイモード時の動作
        if CanReplay(replayMode: replayMode, replayIndexArray: replayIndexArray) {
            //次の合成していいよ
            canSynthe = true
            //次のバッファを再生用Nodeに末尾追加
            syntheNode.scheduleBuffer(buffers[nextBufferNum],at:nil,completionHandler:nil)
            //次の合成位置を格納しておく
            syntheIndex = Int32(replayIndexArray[replayIndex]) + Int32(f0Start)
            //その位置のF0worldParameterを操作時のf0に変えておく
            world_parameter?.f0[Int(syntheIndex)] = Double(replayF0Array[Int(replayIndex)]!)
            //再現位置にParticleを移動
            MoveParticle(x: replayIndexArray[replayIndex] * xAxisMargin,y: replayF0Array[replayIndex]!, moveSpeed: ParticleMoveSpeed)
            //次のリプレイ位置へ加算
            replayIndex += 1
            
            //リプレイ終了時の処理
            if replayIndexArray.count == replayIndex{
                replayIndex = 0
                replayMode = false
                FuncAllTap(flag:true)
                ReplayLabel.removeFromParent()
            }
        }else{
        //操作モード時の動作
            if tapIndex != 0.0{ //どこかタップしていたら
                //次の合成していいよ
                canSynthe = true
                //次のバッファを再生用Nodeに末尾追加
                syntheNode.scheduleBuffer(buffers[nextBufferNum],at:nil,completionHandler:nil)
                //合成位置を格納
                syntheIndex = Int32(tapIndex + CGFloat(f0Start))
                
                //Replay時のためにIndexとF0を保存
                replayIndexArray.append(tapIndex)
                replayF0Array.append(f0Array[Int(tapIndex)])
                
            }
        }
        //次のバッファの設定
        bufferNum=(bufferNum+1)%BufferCnt
        nextBufferNum = (bufferNum+1)%BufferCnt
        syntheBufferNum = (nextBufferNum+1)%BufferCnt
        
        if replayIndexArray.count == 0{
            replayButton.isHighlighted =  true
        }
    }

    
    //--------------------------
    //-------Initializer--------
    //--------------------------
    
    //画面上の初期化
    func InitializeView(){
        standEffect = SKView(frame:CGRect(x: 0, y: HeaderFooter, width: Int(self.view.frame.width), height: AllViewY-HeaderFooter*2))
        self.standScene = SKScene(size:CGSize(width:self.view.frame.width,height:CGFloat(AllViewY-HeaderFooter*2)))
        standEffect!.presentScene(standScene)
        let backGround = SKSpriteNode(imageNamed:"background")
        self.standScene?.addChild(backGround)
    }
    
    //エフェクトデータの読み込み
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
    
    //再生用Bufferの初期化
    func InitializeBuffer(cnt:Int){
        for _ in 0 ..< cnt{
            let buff:AVAudioPCMBuffer = AVAudioPCMBuffer(pcmFormat:AudioFormat,frameCapacity:AVAudioFrameCount(BufferSize))
            buff.frameLength = AVAudioFrameCount(BufferSize)
            buffers.append(buff)
        }
    }
    
    //WorldParameterの初期化
    func InitializeWorldParameter(wavName:String){
        f0Start = 0
        f0End = 0
        //分析フェーズ
        let str = URL(fileURLWithPath: Bundle.main.path(forResource: wavName, ofType: "wav",inDirectory:"waves")!).absoluteString
        let arr = str.components(separatedBy: "///")
        world_parameter = execute_world(arr[1],ToPath+"/output.wav",-1)
        
        Initializer(&world_parameter!,Int32(BufferSize))
        
        
        let f0Length = Int((world_parameter?.f0_length)!)
        f0Array = []
        for i in 0 ..< f0Length{
            f0Array.append(CGFloat(world_parameter!.f0[i]))
        }
        xAxisMargin = view.frame.width/CGFloat(f0Array.count)
    }
    
    //再生用のAVAudio周りの初期化
    func InitializeAudio(file:AVAudioFile){
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        syntheNode = AVAudioPlayerNode()
        audioEngine.attach(playerNode)
        audioEngine.attach(syntheNode)
        let mixer = audioEngine.mainMixerNode
        audioEngine.connect(playerNode,to: mixer, format:file.processingFormat)
        audioEngine.connect(syntheNode,to: mixer, format:AudioFormat)
        audioEngine.prepare()
        try! audioEngine.start()
        playerNode.play()
        syntheNode.play()
    }
    
    //何かと初期化するときの便利なメソッド
    func InitializePlayerParameter(){
        tapIndex = 0.0
        bufferCleaner()
        bufferNum = 0
        nextBufferNum = 1
        syntheBufferNum = 2
        preIndex = 0.0
        preY = 0.0
    }
    
    //録音機能における初期化
    func InitializeRecording(){
        // 初期化ここから
        recordButton.isEnabled = false
        
        ShowLabelWithAnimation(label: RecordLabel)
        
        recordButton.isEnabled = true
        // 録音ファイルを指定する
        let filePath = ToPath + "/record.wav"
        print("Record:"+filePath)
        let url = NSURL(fileURLWithPath: filePath)
        
        // 再生と録音の機能をアクティブにする
        let session = AVAudioSession.sharedInstance()
        try! session.setCategory(AVAudioSessionCategoryPlayAndRecord)
        try! session.setActive(true)
        
        // 録音の詳細設定
        let recordSetting: [String: Any] = [AVSampleRateKey: NSNumber(value: 16000),
            AVFormatIDKey: NSNumber(value: kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: NSNumber(value: 16),
            AVNumberOfChannelsKey: NSNumber(value: 1),
            AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.max.rawValue)
        ];
        
        do {
            self.audioRecorder = try AVAudioRecorder(url: url as URL, settings: recordSetting)
        } catch {
            fatalError("初期設定にエラー")
        }
    }

    
    //--------------------------
    //------UtilityMethod-------
    //--------------------------
    
    //バッファ全部キレイキレイする
    func bufferCleaner(){
        for i in 0..<BufferCnt{
            for j in 0..<BufferSize{
                buffers[i].floatChannelData?.pointee[j] = 0.0
            }
        }
    }
    
    //リプレイ可能かどうかの判定
    func CanReplay(replayMode:Bool,replayIndexArray:[CGFloat]) -> Bool{
        return (replayMode && replayIndexArray.count != 0)
    }
    
    //タップ位置に対応してF0を変更する
    func ChangeF0FromTap(location:CGPoint){
        var location2 = CGPoint(x:location.x,y:self.view.frame.height - CGFloat(HeaderFooter) - location.y)
        if(location2.y < F0MinValue){
            location2.y = F0MinValue
        }
        MoveParticle(x: location2.x,y: location2.y, moveSpeed: ParticleMoveSpeed)
        tapIndex = location2.x / xAxisMargin
        
        let F0Length = Int((world_parameter?.f0_length)!)
        //indexが枠外に出たらギリギリで止める
        if tapIndex >= CGFloat(F0Length - f0Start){
            tapIndex = CGFloat(F0Length - f0Start) - 1
        }
        var y = location2.y
        if(y < F0MinValue){
            y = F0MinValue
        }
        
        let changeWidth = 1
        //触れている場所を検出し、f0配列の値を変える。WORLDParameterも変更する。
        ChangeF0Line(y: y, changeWidth: changeWidth,tapIndex:Int(tapIndex))
        
        preIndex = tapIndex
        preY = y
    }
    
    //F0操作時に点と点を結ぶ
    func ChangeF0Line(y:CGFloat,changeWidth:Int,tapIndex:Int){
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
            
            if(preIndex < CGFloat(tapIndex)){
                x1 = (Int(preIndex))
                x2 = tapIndex
            }else{
                x2 = (Int(preIndex))
                x1 = tapIndex
            }
            let dx = x2-x1
            let dy = y2-y1
            var e:CGFloat = 0
            var tempY:CGFloat = 0.0
            
            if dx > changeWidth {
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
            if tapIndex + i < f0Array.count {
                f0Array.remove(at: Int(tapIndex)+i)
                f0Array.insert( y, at:Int(tapIndex)+i)
                world_parameter!.f0[Int(tapIndex)+i+f0Start] = Double(f0Array[Int(tapIndex)+i]!)
            }
            if tapIndex - i>0 {
                f0Array.remove(at: tapIndex - i)
                f0Array.insert( y, at:tapIndex - i)
                world_parameter!.f0[tapIndex - i + f0Start] = Double(f0Array[tapIndex - i]!)
            }
        }
    }
    
    //flagに対応してボタンを押せるかどうかをまとめて変更
    func FuncAllTap(flag:Bool){
        recordButton.isEnabled = flag
        femaleButton.isEnabled = flag
        maleButton.isEnabled = flag
        replayButton.isEnabled = flag
    }
    
    //Particleを座標(x,y)にMoceSpeedの速さで移動させる
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
    
    //次の女性発話者のファイル名を取得
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
    
    //Recording!とかReplay!とかのラベルを豪華なアニメーションで再生してくれるメソッド
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
    
    //指定したPathの音声を読み込み再生する
    func LoadWavFromPath(path:String){
        InitializeWorldParameter(wavName: path)
        let F0Length = Int((world_parameter?.f0_length)!)
        DrawLineF0(arr: f0Array,count: F0Length)
        execute_Synthesis(world_parameter!,ToPath+"/synthe.wav")
        let syntheFile = try! AVAudioFile(forReading:URL(string:ToPath+"/synthe.wav")!)
        try! syntheFile.read(into: buffer,frameCount: AVAudioFrameCount(FrameCapacity))
        playerNode.scheduleBuffer(buffer,at:nil,options:AVAudioPlayerNodeBufferOptions.interrupts,completionHandler:nil)
    }
    
    //WorldParameterからF0の開始Indexを取得
    func getStartIndexFromWorldParameter(length:Int)->Int{
        var startIndex:Int = 0
        for i in 0 ..< length{
            if world_parameter?.f0[i] != 0{
                startIndex = i
                break
            }
        }
        if startIndex > GraphOffset*2{
            startIndex = startIndex - GraphOffset
        }
        return startIndex
    }
    //WorldParameterからF0の終了Indexを取得
    func getEndIndexFromWorldParameter(length:Int)->Int{
        var endIndex:Int = 0
        for i in 0 ..< length{
            if world_parameter?.f0[length - i] != 0{
                endIndex = length - i
                break
            }
        }
        if length - endIndex > GraphOffset*2{
            endIndex = endIndex + GraphOffset
        }
        return endIndex
    }
    
    //画面上にF0の線分を表示
    func DrawLineF0(arr:[CGFloat?],count:Int){
        F0Line.removeFromParent()
        let path = CGMutablePath()
        for i in 0 ..< count-1{
            path.move(to: CGPoint(x:CGFloat(i)*xAxisMargin,y:arr[i]!))
            path.addLine(to:CGPoint(x:CGFloat(i+1)*xAxisMargin,y:arr[i+1]!))
        }
        F0Line.path = path
        F0Line.strokeColor = UIColor.darkGray
        F0Line.lineWidth = 2
        F0Line.isAntialiased = true
        self.standScene?.addChild(F0Line)
    }
    
    //指定座標の合成音声を指定バッファへ書き込み
    func SynthesisToBuffer(syntheIndex:Int32,bufferNum:Int){
        //WORLDで合成したPCM配列を取得するための配列の定義
        let resultSynthesis_ptr = UnsafeMutablePointer<Double>.allocate(capacity:BufferSize)
        let res = Int(AddFrames(&world_parameter!,(world_parameter?.fs)!,syntheIndex,Int32(Int(BufferSize)),resultSynthesis_ptr,Int32(BufferSize),0))
        
        //もし合成に成功したら下記処理を行う。
        if (res == 1){
            //WORLDから得られた値を再生するためのbufferに入れる。
            //マルチプルバッファのため、次に再生するためのバッファに突っ込む
            for i in 0 ..< Int32(BufferSize){
                buffers[bufferNum].floatChannelData?.pointee[Int(i)] = Float(resultSynthesis_ptr.advanced(by: Int(i)).pointee)
            }
        }
        else{
            print("Synthesis is missed")
        }
    }
}
