//
//  GameScene.swift
//  FlappyBird
//
//  Created by Tatsunori Watabe on 2017/05/07.
//  Copyright © 2017年 konsukeyama. All rights reserved.
//

import SpriteKit
import AVFoundation // 音楽再生用

// 衝突判定のため SKPhysicsContactDelegate を継承
class GameScene: SKScene, SKPhysicsContactDelegate {

    // ノード宣言（SKNode! と SKSpriteNode! の使い分けがまだ理解できず...）
    var scrollNode: SKNode!
    var wallNode: SKNode!                // 壁用ノード
    var itemNode: SKNode!                // アイテム用ノード
    var bird: SKSpriteNode!              // 鳥用ノード
    var scoreLabelNode: SKLabelNode!     // スコア用ノード
    var bestScoreLabelNode: SKLabelNode! // ベストスコア用ノード
    var itemScoreLabelNode: SKLabelNode! // アイテムスコア用ノード
    var statusLabelNode: SKLabelNode!    // ステータス表示用ノード

    // 衝突判定カテゴリ（同じカテゴリのノード同士が衝突判定される　※最大32種類設定できる）
    let birdCategory: UInt32   = 1 << 0     // 0...00001
    let groundCategory: UInt32 = 1 << 1     // 0...00010
    let wallCategory: UInt32   = 1 << 2     // 0...00100
    let scoreCategory: UInt32  = 1 << 3     // 0...01000
    let itemCategory: UInt32   = 1 << 4     // 0...10000
    
    // スコア、アイテム
    var score = 0
    var item = 0
    
    // サウンド
    let jumpSound = SKAudioNode.init(fileNamed: "jump.mp3")
    let itemSound = SKAudioNode.init(fileNamed: "item.mp3")
    let downSound = SKAudioNode.init(fileNamed: "down.mp3")
    let protectSound = SKAudioNode.init(fileNamed: "protect.mp3")

    // ユーザーデフォルトを初期化
    let userDefaults:UserDefaults = UserDefaults.standard

    // SKView上にシーンが表示されたときに呼ばれるメソッド
    override func didMove(to view: SKView) {

        // 重力を設定
        physicsWorld.gravity = CGVector(dx: 0.0, dy: -4.5)

        // 衝突判定をデリゲート
        physicsWorld.contactDelegate = self

        // 背景色を設定
        backgroundColor = Util.RGBA(red: 38, green: 191, blue: 229, alpha: 1)

        // スクロールさせる親ノード（scrollNode）
        scrollNode = SKNode()  // ノード作成
        scrollNode.speed = 1.2 // ノードの速度（1がデフォルト）
        addChild(scrollNode)   // GameSceneにノード追加
        
        // 壁用のノード
        wallNode = SKNode()           // ノード作成
        scrollNode.addChild(wallNode) // scrollNodeに追加

        // アイテム用のノード
        itemNode = SKNode()           // ノード作成
        scrollNode.addChild(itemNode) // scrollNodeに追加

        // 各種スプライトを生成するメソッド
        setupGround() // 地面
        setupCloud()  // 雲
        setupWall()   // 壁
        setupItem()   // アイテム
        setupBird()   // 鳥

        // ラベル初期化
        setupScoreLabel()
        
        // サウンド初期化
        setupSound()
    }

    /// フレームが更新される前に呼ばれる
    override func update(_ currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
        if scrollNode.speed > 0 && self.bird.position.x < 0 {
            // 鳥が画面から見切れたらゲームオーバー
            gameOver()
        }
    }
    
    /// 画面をタップした時に呼ばれる
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // スクロールノードのスピードでゲームオーバー判定
        if scrollNode.speed > 0 {
            // ゲームオーバーでない場合は鳥ジャンプ
            bird.physicsBody?.velocity = CGVector.zero // 鳥の動きをゼロにする
            
            // 鳥に縦方向の力を与える（瞬間的な力を与える。※PS.継続的に与える場合は .ApplyForce()）
            bird.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 16))
            
            // 効果音（停止＆再生）
            let stopSound = SKAction.stop()
            self.jumpSound.run(stopSound)
            let playSound = SKAction.play()
            self.jumpSound.run(playSound)
        } else if bird.speed == 0 {
            // ゲームオーバーの場合はリスタートする
            restart()
        }
    }
    
    /// 衝突したときに呼ばれる（SKPhysicsContactDelegateのメソッド）
    func didBegin(_ contact: SKPhysicsContact) {
        // ゲームオーバー判定
        if scrollNode.speed <= 0 {
            return // 何もしない
        }
        
        // 衝突判定（bodyAとbodyBは取得順序が保証されないため、両方で判定する必要あり。※「&」はビット演算子のAND）
        if (contact.bodyA.categoryBitMask & itemCategory) == itemCategory || (contact.bodyB.categoryBitMask & itemCategory) == itemCategory {
            // アイテムとの衝突した場合
            item += 1
            itemScoreLabelNode.text = "ガッツ:\(item)" // アイテムスコアを描画

            // アイテムを削除する
            if (contact.bodyA.categoryBitMask & itemCategory) == itemCategory {
                contact.bodyA.node!.removeFromParent()
            } else {
                contact.bodyB.node!.removeFromParent()
            }

            // 効果音
            let playSound = SKAction.play()
            itemSound.run(playSound)
        } else if (contact.bodyA.categoryBitMask & scoreCategory) == scoreCategory || (contact.bodyB.categoryBitMask & scoreCategory) == scoreCategory {
            // スコア用の物体と衝突した場合
            score += 1
            scoreLabelNode.text = "Score:\(score)" // スコアを描画
            
            // ベストスコアか確認する
            var bestScore = userDefaults.integer(forKey: "BEST") // ユーザーデフォルトから key:BEST で整数値を取得。無ければ0が帰る。
            if score > bestScore {
                // ベストスコアを更新した場合
                bestScore = score // ベストスコアを更新
                // bestScoreLabelNode.text = "Best Score:\(bestScore)" // ベストスコアを描画
                userDefaults.set(bestScore, forKey: "BEST") // ユーザーデフォルトに更新値をセット
                userDefaults.synchronize() // ユーザーデフォルトへ保存する
            }
        } else {
            // 壁か地面と衝突した場合
            if item > 1 {
                // アイテム（ガッツ）が残っていた場合はGameOverにならない
                item -= 1
                itemScoreLabelNode.text = String("ガッツ:\(item)") // アイテムを描画
                
                // 効果音（停止＆再生）
                let stopSound = SKAction.stop()
                self.protectSound.run(stopSound)
                let playSound = SKAction.play()
                protectSound.run(playSound)
                
                return
            } else {
                // ゲームオーバー
                item -= 1
                itemScoreLabelNode.text = String("ガッツ:\(item)") // アイテムを描画

                gameOver()
            }
        }
    }

    /// ラベル初期化処理
    func setupScoreLabel() {
        // スコア
        score = 0
        scoreLabelNode = SKLabelNode(fontNamed: "Arial Bold")                        // ノードを作成
        scoreLabelNode.fontSize = 20                                                 // 文字サイズ
        scoreLabelNode.fontColor = UIColor.black                                     // 文字色
        scoreLabelNode.position = CGPoint(x: 10, y: self.frame.size.height - 30)     // 表示位置
        scoreLabelNode.zPosition = 100                                               // zポジション（一番手前に）
        scoreLabelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.left // 文字を左寄せ
        scoreLabelNode.text = "Score:\(score)"                                       // 表示する内容
        self.addChild(scoreLabelNode)                                                // GameSceneに追加
        
        // ベストスコア
        bestScoreLabelNode = SKLabelNode(fontNamed: "Arial Bold")
        bestScoreLabelNode.fontSize = 20
        bestScoreLabelNode.fontColor = UIColor.black
        bestScoreLabelNode.position = CGPoint(x: 10, y: self.frame.size.height - 50)
        bestScoreLabelNode.zPosition = 100
        bestScoreLabelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.left
        
        let bestScore = userDefaults.integer(forKey: "BEST") // ユーザーデフォルトからベストスコアを取得
        bestScoreLabelNode.text = "Best Score:\(bestScore)"  // 表示内容
        self.addChild(bestScoreLabelNode)                    // GameSceneに追加

        // アイテムスコア
        item = 1
        itemScoreLabelNode = SKLabelNode(fontNamed: "Arial Bold")
        itemScoreLabelNode.fontSize = 20
        itemScoreLabelNode.fontColor = Util.RGBA(red: 255, green: 20, blue: 147, alpha: 1)
        itemScoreLabelNode.position = CGPoint(x: 10, y: self.frame.size.height - 70)
        itemScoreLabelNode.zPosition = 100
        itemScoreLabelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.left
        itemScoreLabelNode.text = "ガッツ:\(item)"
        self.addChild(itemScoreLabelNode)

        // ステータス
        statusLabelNode = SKLabelNode(fontNamed: "Arial Bold")
        statusLabelNode.fontSize = 45
        statusLabelNode.fontColor = UIColor.black
        statusLabelNode.position = CGPoint(x: self.frame.size.width / 2, y: self.frame.size.height / 2)
        statusLabelNode.zPosition = 100
        statusLabelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.center
        statusLabelNode.text = String("")
        self.addChild(statusLabelNode)
    }
    
    /// サウンド初期化処理
    func setupSound() {
        // ジャンプ時
        jumpSound.autoplayLooped = false // 自動再生＆ループさせない
        self.addChild(jumpSound)         // GameSceneに追加

        // アイテムゲット時
        itemSound.autoplayLooped = false
        self.addChild(itemSound)

        // ダウン時
        downSound.autoplayLooped = false
        self.addChild(downSound)

        // ガッツ消費音
        protectSound.autoplayLooped = false
        self.addChild(protectSound)
    }
    
    /// 地面を生成する
    func setupGround() {
        // 地面の画像（テクスチャ）を読み込む
        let groundTexture = SKTexture(imageNamed: "ground")
        groundTexture.filteringMode = SKTextureFilteringMode.nearest // 画質より処理速度優先（画質優先は .linear）

        // スクロールに必要な枚数を計算（端末の全幅に収まる枚数＋2枚とする）
        let needNumber = 2.0 + (frame.size.width / groundTexture.size().width)
        
        //--- アクションを作成
        // 1.左方向に画像一枚分スクロールさせるアクション（引数：duration：アニメに要する時間）
        let moveGround = SKAction.moveBy(x: -groundTexture.size().width , y: 0, duration: 5.0)
        
        // 2.元の位置に戻すアクション（一瞬で戻す）
        let resetGround = SKAction.moveBy(x: groundTexture.size().width, y: 0, duration: 0.0)
        
        // 3.1〜2を無限に繰り替えすアクション（repeatForever：繰り返し、sequence：アクションを繋げる）
        let repeatScrollGround = SKAction.repeatForever(SKAction.sequence([moveGround, resetGround]))
        
        //--- groundのスプライトを配置する
        stride(from: 0.0, to: needNumber, by: 1.0).forEach { i in // 0〜needNumber（3.1 -> 実質3）まで1飛びでループ
            let sprite = SKSpriteNode(texture: groundTexture) // スプライトを作成

            // スプライトの表示する位置を指定する　※【重要】スプライトの座標は「中心」が基準！
            sprite.position = CGPoint(x: i * sprite.size.width, y: groundTexture.size().height / 2)
            
            // スプライトにアクションを設定する
            sprite.run(repeatScrollGround)

            // スプライトに物理演算を設定する
            sprite.physicsBody = SKPhysicsBody(rectangleOf: groundTexture.size())
            
            // 衝突のカテゴリー設定
            sprite.physicsBody?.categoryBitMask = groundCategory // 衝突カテゴリの設定

            // 衝突の時に動かないように設定する（false：物理演算の影響を受けない。バウンドまでする！）
            sprite.physicsBody?.isDynamic = false

            // scrollNodeに追加する
            scrollNode.addChild(sprite)
        }
    }
    
    /// 雲を生成する
    func setupCloud() {
        // 雲の画像（テクスチャ）を読み込む
        let cloudTexture = SKTexture(imageNamed: "cloud")
        cloudTexture.filteringMode = SKTextureFilteringMode.nearest
        
        // 必要な枚数を計算
        let needCloudNumber = 2.0 + (frame.size.width / cloudTexture.size().width)
        
        //--- アクションを作成
        // 1.左方向に画像一枚分スクロールさせるアクション
        let moveCloud = SKAction.moveBy(x: -cloudTexture.size().width , y: 0, duration: 20.0)
        
        // 2.元の位置に戻すアクション
        let resetCloud = SKAction.moveBy(x: cloudTexture.size().width, y: 0, duration: 0.0)
        
        // 3.1〜2を無限に繰り替えすアクション
        let repeatScrollCloud = SKAction.repeatForever(SKAction.sequence([moveCloud, resetCloud]))
        
        //--- スプライトを配置する
        stride(from: 0.0, to: needCloudNumber, by: 1.0).forEach { i in
            let sprite = SKSpriteNode(texture: cloudTexture) // スプライトを作成
            sprite.zPosition = -100
            
            // スプライトの表示する位置を指定する
            sprite.position = CGPoint(x: i * sprite.size.width, y: size.height - cloudTexture.size().height / 2)
            
            // スプライトにアクションを設定する
            sprite.run(repeatScrollCloud)

            // scrollNodeに追加する
            scrollNode.addChild(sprite)
        }
    }

    /// 壁を生成する
    func setupWall() {
        // 壁の画像（テクスチャ）を読み込む
        let wallTexture = SKTexture(imageNamed: "wall")
        wallTexture.filteringMode = SKTextureFilteringMode.linear // 当たり判定を行う場合は「画質優先」がベスト
        
        // 移動（右から左）する距離を計算
        let movingDistance = CGFloat(self.frame.size.width + wallTexture.size().width)
        
        //--- アクションを作成
        // 1.画面外まで移動するアクションを作成（右から左へ移動）
        let moveWall = SKAction.moveBy(x: -movingDistance, y: 0, duration:4.0)
        
        // 2.自身を取り除くアクションを作成
        let removeWall = SKAction.removeFromParent()
        
        // 3.1〜2を順に実行するアクションを作成
        let wallAnimation = SKAction.sequence([moveWall, removeWall])
        
        // 壁を生成するアクションを作成
        let createWallAnimation = SKAction.run({
            let wall = SKNode() // 壁スプライトを乗せるノードを作成
            wall.position = CGPoint(x: self.frame.size.width + wallTexture.size().width / 2, y: 0.0)
            wall.zPosition = -50.0 // 雲より手前、地面より奥
            
            // 画面のY軸の中央値
            let center_y = self.frame.size.height / 2
            // 壁のY座標を上下ランダムにさせるときの最大値
            let random_y_range = self.frame.size.height / 4
            // 下の壁のY軸の下限
            let under_wall_lowest_y = UInt32(center_y - wallTexture.size().height / 2 -  random_y_range / 2)
            // ランダムな整数（0 〜 random_y_range）を生成
            let random_y = arc4random_uniform(UInt32(random_y_range))
            // Y軸の下限にランダムな値を足して、下の壁のY座標を決定
            let under_wall_y = CGFloat(under_wall_lowest_y + random_y)
            
            // キャラが通り抜ける隙間の高さ　※固定値が良さそうなので固定値に変更
            // let slit_length = self.frame.size.height / 6
            let slit_length = CGFloat(111)
            
            //--- スプライトを配置する
            // 下側の壁を作成
            let under = SKSpriteNode(texture: wallTexture) // スプライトを作成
            under.position = CGPoint(x: 0.0, y: under_wall_y)
            wall.addChild(under) // wallに追加

            // スプライトに物理演算を設定する
            under.physicsBody = SKPhysicsBody(rectangleOf: wallTexture.size())
            under.physicsBody?.categoryBitMask = self.wallCategory // 衝突カテゴリを設定
            under.physicsBody?.isDynamic = false                   // 重力の影響を受けない
            
            // 上側の壁を作成
            let upper = SKSpriteNode(texture: wallTexture)
            upper.position = CGPoint(x: 0.0, y: under_wall_y + wallTexture.size().height + slit_length)
            wall.addChild(upper)  // wallに追加
            
            // スプライトに物理演算を設定する
            upper.physicsBody = SKPhysicsBody(rectangleOf: wallTexture.size())
            upper.physicsBody?.categoryBitMask = self.wallCategory // 衝突カテゴリを設定
            upper.physicsBody?.isDynamic = false                   // 重力の影響を受けない
            
            // wallにアクション（壁が右から左へ移動して消える）設定
            wall.run(wallAnimation)

            // スコアアップ用のノード（衝突判定用）
            let scoreNode = SKNode()
            scoreNode.position = CGPoint(x: upper.size.width + self.bird.size.width / 2, y: self.frame.height / 2.0) // 表示位置
            scoreNode.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: upper.size.width, height: self.frame.size.height)) // 物理演算を設定
            scoreNode.physicsBody?.isDynamic = false                      // 重力の影響を受けない
            scoreNode.physicsBody?.categoryBitMask = self.scoreCategory   // 衝突カテゴリを設定
            scoreNode.physicsBody?.contactTestBitMask = self.birdCategory // 衝突する相手のノード
            
            // wallに追加する
            wall.addChild(scoreNode)

            // 壁用ノードに wall を追加する
            self.wallNode.addChild(wall)
        })
        
        // 次の壁作成までの待ち時間のアクションを作成
        let waitAnimation = SKAction.wait(forDuration: 2)
        
        // 壁を作成->待ち時間->壁を作成を無限に繰り替えるアクションを作成
        let repeatForeverAnimation = SKAction.repeatForever(SKAction.sequence([createWallAnimation, waitAnimation]))
        
        // 壁用ノードにアクションを設定
        wallNode.run(repeatForeverAnimation)
    }

    /// アイテムを生成する
    func setupItem() {
        // アイテムの画像（テクスチャ）を読み込む
        let itemTexture = SKTexture(imageNamed: "bird_a")
        itemTexture.filteringMode = SKTextureFilteringMode.linear
        
        // 移動する距離を計算
        let movingDistance = CGFloat(self.frame.size.width + itemTexture.size().width)
        
        //--- アクションを作成
        // 1.画面外まで移動するアクションを作成（右から左へ移動）
        let moveItem = SKAction.moveBy(x: -movingDistance, y: 0, duration:4.0)
        
        // 2.自身を取り除くアクションを作成
        let removeItem = SKAction.removeFromParent()
        
        // 3.1〜2を順に実行するアクションを作成
        let itemAnimation = SKAction.sequence([moveItem, removeItem])
        
        // アイテムを生成するアクションを作成
        let createItemAnimation = SKAction.run({
            //--- スプライトを配置する
            let item = SKSpriteNode(texture: itemTexture) // スプライト作成
            
            // 画面のY軸の中央値
            let center_y = self.frame.size.height / 2
            // アイテムのY座標を上下ランダムにさせるときの最大値
            let random_y_range = self.frame.size.height / 4
            // アイテムのY座標の下限
            let under_item_lowest_y = UInt32(center_y - random_y_range / 2)
            // ランダムな整数（0 〜 random_y_range）を生成
            let random_y = arc4random_uniform(UInt32(random_y_range))
            // アイテムのY座標
            let under_item_y = CGFloat(under_item_lowest_y + random_y)
            
            // スプライトの表示する位置を指定する
            item.position = CGPoint(x: self.frame.size.width + itemTexture.size().width / 2, y: under_item_y)
            item.zPosition = -50.0 // 雲より手前、地面より奥

            // スプライトを変形
            item.xScale = -1.0 // 左右反転
            item.size = CGSize(width: itemTexture.size().width * 0.8, height: itemTexture.size().height * 0.7) // 縮小

            // 物理演算を設定（円形の物理体を設定）
            item.physicsBody = SKPhysicsBody(circleOfRadius: item.size.height / 2.0)
            item.physicsBody?.isDynamic = false // 重力の影響を受けない

            // 衝突のカテゴリー設定
            item.physicsBody?.categoryBitMask = self.itemCategory    // 衝突カテゴリ設定
            item.physicsBody?.contactTestBitMask = self.birdCategory // 衝突させる相手のノード
            
            // スプライトにアクションを設定
            item.run(itemAnimation)
            
            // アイテム用ノードに追加する
            self.itemNode.addChild(item)
        })
        
        // 次のアイテム作成までの待ち時間のアクションを作成
        let waitAnimation_1 = SKAction.wait(forDuration: 1) // 1秒待つ
        let waitAnimation_14 = SKAction.wait(forDuration: 14) // 14秒待つ
        
        // アイテムを作成->待ち時間->アイテムを作成を無限に繰り替えるアクションを作成
        let repeatForeverAnimation = SKAction.repeatForever(SKAction.sequence([createItemAnimation, waitAnimation_14]))
        
        // ノードにアクションを設定
        itemNode.run(SKAction.sequence([waitAnimation_1, repeatForeverAnimation]))
    }
    
    /// 鳥を生成する
    func setupBird() {
        // 鳥の画像（テクスチャ）を2種類読み込む
        let birdTextureA = SKTexture(imageNamed: "bird_a")
        birdTextureA.filteringMode = SKTextureFilteringMode.linear
        let birdTextureB = SKTexture(imageNamed: "bird_b")
        birdTextureB.filteringMode = SKTextureFilteringMode.linear
        
        //--- アクションを作成
        // 2種類のテクスチャを交互に変更するアニメーションを作成（timePerFrame：各テクスチャが表示される時間[秒]）
        let texuresAnimation = SKAction.animate(with: [birdTextureA, birdTextureB], timePerFrame: 0.2)
        let flap = SKAction.repeatForever(texuresAnimation)
        
        //--- スプライトを配置する
        // スプライトを作成
        bird = SKSpriteNode(texture: birdTextureA) // スプライト作成
        bird.position = CGPoint(x: self.frame.size.width * 0.2, y:self.frame.size.height * 0.8)
        bird.name = "piyo"
        
        // 物理演算を設定（円形の物理体を設定）
        bird.physicsBody = SKPhysicsBody(circleOfRadius: bird.size.height / 2.0)
        
        // 衝突した時に回転させない
        bird.physicsBody?.allowsRotation = false
        
        // 衝突のカテゴリー設定
        bird.physicsBody?.categoryBitMask = birdCategory                     // 衝突カテゴリ設定
        bird.physicsBody?.collisionBitMask = groundCategory | wallCategory   // 衝突した時に跳ね返る相手
        bird.physicsBody?.contactTestBitMask = groundCategory | wallCategory // 衝突させる相手のノード

        // アニメーションを設定
        bird.run(flap)

        // scrollNodeに追加する
        addChild(bird)
    }

    /// リスタート処理
    func restart() {
        score = 0 // スコアをリセット
        item = 1  // アイテム（ガッツ）をリセット
        scoreLabelNode.text = String("Score:\(score)")       // スコアを描画
        itemScoreLabelNode.text = String("ガッツ:\(item)")    // アイテムを描画
        let bestScore = userDefaults.integer(forKey: "BEST") // ユーザーデフォルトから key:BEST で整数値を取得。無ければ0が帰る。
        bestScoreLabelNode.text = "Best Score:\(bestScore)"  // ベストスコアを描画
        
        bird.position = CGPoint(x: self.frame.size.width * 0.2, y:self.frame.size.height * 0.7) // 鳥を元の場所へ戻す
        bird.physicsBody?.velocity = CGVector.zero // 鳥の動きをゼロにする
        bird.physicsBody?.collisionBitMask = groundCategory | wallCategory // 衝突相手に地面と壁を設定
        bird.zRotation = 0.0 // 鳥の回転アクションをゼロにする
        
        wallNode.removeAllChildren()      // 全ての壁を取り除く
        itemNode.removeAllChildren()      // 全てのアイテムを取り除く
        statusLabelNode.text = String("") // ステータス表示クリア
        
        // アクションを通常の速度に戻す
        bird.speed = 1
        scrollNode.speed = 1.2
    }

    /// ゲームオーバー処理
    func gameOver() {
        // スクロールを停止させる
        scrollNode.speed = 0
        
        bird.physicsBody?.velocity = CGVector.zero // 鳥の動きをゼロに（壁との衝突で反動させない）

        // 効果音
        let playSound = SKAction.play()
        downSound.run(playSound)
        
        // 落下時は地面とだけ衝突させる
        bird.physicsBody?.collisionBitMask = groundCategory
        
        // 鳥に回転アクションを加える（Double.pi：円周率、円周率×鳥の高さ×閾値で回転量を調整。※鳥の位置が高いほど早く回転する）
        let roll = SKAction.rotate(byAngle: CGFloat(Double.pi) * CGFloat(bird.position.y) * 0.03, duration:1)
        bird.run(roll, completion:{
            // アクションが完了したら動きを停止させる
            self.bird.speed = 0
            print("GameOver")
            self.statusLabelNode.text = String("GAME OVER") // ステータス表示
        })
    }
}
