import SwiftUI

struct ContentView: View {
    var body: some View {
        DokusaiView()
    }
}

struct DokusaiView: View {
    @State private var people: [Person] = []
    @State private var sliderValue: Double = 5
    @State private var deleteButtonPressCount: Int = 0
    @State private var lastButtonPressTime: Date = Date()
    @State private var frameSize: CGSize = CGSize(width: UIScreen.main.bounds.width, height: 300)
    @State private var timer: Timer?
    let iconSize: CGFloat = 50  // アイコンのサイズ

    var body: some View {
        VStack {
            // 上部のアイコンたち
            GeometryReader { geometry in
                ZStack {
                    ForEach(people) { person in
                        if person.isVisible {
                            PersonView(person: person)
                        }
                    }
                }
                .onAppear {
                    frameSize = geometry.size
                    if people.isEmpty {
                        // ユーザーを追加
                        people.append(Person(isUser: true, frameSize: frameSize))
                    }
                    adjustPeople(to: Int(sliderValue), frameSize: frameSize)
                    startTimer()
                }
                .onDisappear {
                    stopTimer()
                }
            }
            .frame(height: 300)
            .background(Color.blue.opacity(0.1))
            
            // DOKUSAI スイッチ
            Button(action: {
                deletePerson()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                }
            }
            .padding()
            .keyboardShortcut(.delete, modifiers: [])
            
            // スライダー（左にperson.slash.fill、右にperson.2.fill）
            HStack {
                Image(systemName: "person.slash.fill")
                Slider(value: $sliderValue, in: 0...10, step: 1) {
                    Text("Adjust People")
                }
                .onChange(of: sliderValue) { _ in
                    adjustPeople(to: Int(sliderValue), frameSize: frameSize)
                }
                Image(systemName: "person.2.fill")
            }
            .padding()
        }
    }
    
    // アイコンを削除する機能
    func deletePerson() {
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastButtonPressTime) > 1 {
            // 1秒以上経過していたらカウントをリセット
            deleteButtonPressCount = 0
        }
        
        deleteButtonPressCount += 1
        lastButtonPressTime = currentTime
        
        if deleteButtonPressCount == 3 {
            // 全員を消す
            sliderValue = 0
            adjustPeople(to: Int(sliderValue), frameSize: frameSize)
            deleteButtonPressCount = 0
        } else if sliderValue > 0 {
            // 一人を減らす
            sliderValue -= 1
            adjustPeople(to: Int(sliderValue), frameSize: frameSize)
        }
    }
    
    // スライダーでアイコンを調整する機能
    func adjustPeople(to count: Int, frameSize: CGSize) {
        // 自分を含めた人数
        let totalCount = count + 1
        if totalCount > people.count {
            for _ in 0..<(totalCount - people.count) {
                people.append(Person(isUser: false, frameSize: frameSize))
            }
        } else if totalCount < people.count {
            people.removeLast(people.count - totalCount)
        }
        // 全員を表示状態にする
        for person in people {
            person.isVisible = true
        }
    }
    
    // タイマーを開始する
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            updatePositions(frameSize: frameSize)
        }
    }
    
    // タイマーを停止する
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // アイコンの位置を更新する機能
    func updatePositions(frameSize: CGSize) {
        let currentTime = Date()
        let minX = iconSize / 2
        let maxX = frameSize.width - iconSize / 2
        let minY = iconSize / 2
        let maxY = frameSize.height - iconSize / 2
        
        // アイコン同士の衝突をチェック
        for i in 0..<people.count {
            for j in (i + 1)..<people.count {
                let personA = people[i]
                let personB = people[j]
                
                let dx = personB.position.x - personA.position.x
                let dy = personB.position.y - personA.position.y
                let distance = sqrt(dx * dx + dy * dy)
                let minDistance = iconSize
                
                if distance < minDistance {
                    // 正規化された法線ベクトル
                    let nx = dx / distance
                    let ny = dy / distance
                    // 相対速度
                    let dvx = personB.velocity.dx - personA.velocity.dx
                    let dvy = personB.velocity.dy - personA.velocity.dy
                    // 法線方向の相対速度
                    let relVel = dvx * nx + dvy * ny
                    // アイコンが近づいている場合のみ処理
                    if relVel < 0 {
                        let e: CGFloat = 1.2  // 反発係数
                        // インパルスの大きさ
                        let j = -(1 + e) * relVel / 2  // 質量は等しいと仮定
                        // インパルスのベクトル
                        let impulseX = j * nx
                        let impulseY = j * ny
                        // 速度を更新
                        personA.velocity.dx -= impulseX
                        personA.velocity.dy -= impulseY
                        personB.velocity.dx += impulseX
                        personB.velocity.dy += impulseY
                    }
                    // 重なりを解消するために位置を補正
                    let overlap = 0.5 * (minDistance - distance)
                    personA.position.x -= overlap * nx
                    personA.position.y -= overlap * ny
                    personB.position.x += overlap * nx
                    personB.position.y += overlap * ny
                }
            }
        }
        
        for person in people {
            // 位置を更新
            person.position.x += person.velocity.dx
            person.position.y += person.velocity.dy
            
            // 壁にぶつかったら反射
            if person.position.x <= minX || person.position.x >= maxX {
                person.velocity.dx *= -1
                person.position.x = max(minX, min(person.position.x, maxX))
            }
            if person.position.y <= minY || person.position.y >= maxY {
                person.velocity.dy *= -1
                person.position.y = max(minY, min(person.position.y, maxY))
            }
            
            // ランダムな間隔で速度をゆっくり変化
            if currentTime.timeIntervalSince(person.lastSpeedChangeTime) > person.nextSpeedChangeInterval {
                person.lastSpeedChangeTime = currentTime
                person.nextSpeedChangeInterval = TimeInterval.random(in: 3...6)
                
                // 目標速度を設定（最小速度を設定）
                let minSpeed: CGFloat = 0.1
                let maxSpeed: CGFloat = 0.3
                person.targetSpeed = CGFloat.random(in: minSpeed...maxSpeed)
                person.speedChangeStartTime = currentTime
            }
            
            // 速度を徐々に変化
            if let targetSpeed = person.targetSpeed, let startTime = person.speedChangeStartTime {
                let elapsed = currentTime.timeIntervalSince(startTime)
                if elapsed < person.speedChangeDuration {
                    let t = CGFloat(elapsed / person.speedChangeDuration)
                    person.speed = person.speed * (1 - t) + targetSpeed * t
                    // 速度ベクトルを更新（速度の大きさのみ変化、方向はそのまま）
                    let angle = atan2(person.velocity.dy, person.velocity.dx)
                    person.velocity.dx = cos(angle) * person.speed
                    person.velocity.dy = sin(angle) * person.speed
                } else {
                    // 速度変化終了
                    person.speed = targetSpeed
                    let angle = atan2(person.velocity.dy, person.velocity.dx)
                    person.velocity.dx = cos(angle) * person.speed
                    person.velocity.dy = sin(angle) * person.speed
                    person.targetSpeed = nil
                    person.speedChangeStartTime = nil
                }
            }
        }
    }
}

struct PersonView: View {
    @StateObject var person: Person

    var body: some View {
        Image(systemName: person.isUser ? "person.circle.fill" : "person.circle")
            .resizable()
            .foregroundColor(person.isUser ? .orange : .gray)
            .frame(width: 50, height: 50)
            .position(person.position)
    }
}

// 人のモデル
class Person: ObservableObject, Identifiable {
    let id = UUID()
    @Published var isVisible: Bool = true
    @Published var position: CGPoint
    @Published var velocity: CGVector
    @Published var speed: CGFloat
    var lastSpeedChangeTime: Date
    var nextSpeedChangeInterval: TimeInterval
    var targetSpeed: CGFloat?
    var speedChangeDuration: TimeInterval = 2.0  // 速度変化にかける時間
    var speedChangeStartTime: Date?
    var isUser: Bool

    init(isUser: Bool, frameSize: CGSize) {
        self.isUser = isUser
        let iconSize: CGFloat = 50
        // フレーム内のランダムな位置に配置（アイコンがはみ出さないように調整）
        let x = CGFloat.random(in: iconSize / 2...(frameSize.width - iconSize / 2))
        let y = CGFloat.random(in: iconSize / 2...(frameSize.height - iconSize / 2))
        self.position = CGPoint(x: x, y: y)
        
        // ランダムな方向と速度で初期化
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let minSpeed: CGFloat = 0.1
        let maxSpeed: CGFloat = 0.3
        let speed = CGFloat.random(in: minSpeed...maxSpeed)
        self.speed = speed
        self.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
        
        self.lastSpeedChangeTime = Date()
        self.nextSpeedChangeInterval = TimeInterval.random(in: 3...6)
    }
}

struct DokusaiView_Previews: PreviewProvider {
    static var previews: some View {
        DokusaiView()
    }
}
