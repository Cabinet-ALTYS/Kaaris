import SwiftUI

enum ExerciseEquipmentDiagram {
    case floor, wall, bench, lowSupport, dumbbell, goblet, legPress, chestPress, seatedRow, pulldown
    case shoulderPress, cableCurl, hipMachine, hipDumbbell, treadmill
}

enum ExerciseMotion {
    case squat, gobletSquat, legPress, chestPress, floorPress, inclinePushUp, wallPushUp
    case seatedRow, bentRow, proneRow, plank, hinge, pulldown, pullover, ytW
    case overheadPress, wallSlide, curl, reverseLunge, calfRaise, hipThrust, gluteBridge, walk

    var labels: [String] {
        switch self {
        case .ytW: ["Y", "T", "W"]
        case .walk: ["Appui", "Passage", "Appui suivant"]
        default: ["Départ", "Arrivée"]
        }
    }

    fileprivate var symmetrical: Bool { self == .ytW || self == .wallSlide }

    fileprivate var frames: [ExercisePose] {
        switch self {
        case .squat:
            [
                pose(153, 45, 154, 70, 151, 118, 157, 153, 158, 184, 165, 87, 186, 82),
                pose(164, 75, 158, 99, 132, 139, 172, 143, 158, 184, 179, 106, 199, 94)
            ]
        case .gobletSquat:
            [
                pose(153, 45, 154, 70, 151, 118, 157, 153, 158, 184, 164, 104, 176, 87),
                pose(164, 75, 158, 99, 132, 139, 172, 143, 158, 184, 168, 129, 179, 107)
            ]
        case .legPress:
            [
                pose(94, 94, 105, 120, 136, 157, 153, 121, 189, 117, 119, 144, 140, 145),
                pose(94, 94, 105, 120, 136, 157, 177, 126, 211, 95, 119, 144, 140, 145)
            ]
        case .chestPress:
            [
                pose(113, 51, 114, 78, 118, 132, 164, 129, 172, 184, 104, 100, 134, 91),
                pose(113, 51, 114, 78, 118, 132, 164, 129, 172, 184, 153, 87, 186, 86)
            ]
        case .floorPress:
            [
                pose(66, 165, 94, 166, 147, 167, 183, 128, 204, 183, 102, 184, 108, 149),
                pose(66, 165, 94, 166, 147, 167, 183, 128, 204, 183, 101, 132, 106, 99)
            ]
        case .inclinePushUp:
            [
                pose(207, 62, 187, 86, 140, 126, 110, 150, 84, 182, 203, 107, 218, 131),
                pose(222, 93, 198, 112, 147, 140, 113, 160, 84, 182, 184, 133, 218, 131)
            ]
        case .wallPushUp:
            [
                pose(181, 50, 172, 77, 145, 130, 130, 157, 114, 183, 204, 84, 238, 93),
                pose(218, 62, 203, 84, 163, 129, 139, 158, 114, 183, 201, 108, 238, 93)
            ]
        case .seatedRow:
            [
                pose(125, 58, 125, 85, 126, 139, 168, 142, 207, 180, 161, 101, 195, 103),
                pose(125, 58, 125, 85, 126, 139, 168, 142, 207, 180, 103, 110, 145, 112)
            ]
        case .bentRow:
            [
                pose(180, 67, 158, 86, 110, 121, 128, 152, 130, 183, 160, 119, 162, 153),
                pose(180, 67, 158, 86, 110, 121, 128, 152, 130, 183, 126, 101, 123, 132)
            ]
        case .proneRow:
            [
                pose(194, 159, 171, 172, 122, 173, 87, 175, 52, 183, 205, 166, 235, 163),
                pose(194, 156, 171, 170, 122, 173, 87, 175, 52, 183, 143, 166, 163, 143)
            ]
        case .plank:
            [
                pose(216, 118, 193, 145, 144, 160, 106, 185, 75, 182, 192, 183, 225, 183),
                pose(216, 114, 193, 139, 143, 154, 108, 167, 75, 182, 192, 183, 225, 183)
            ]
        case .hinge:
            [
                pose(150, 42, 152, 70, 150, 118, 155, 151, 158, 184, 160, 96, 157, 126),
                pose(188, 87, 164, 102, 117, 121, 145, 151, 158, 184, 163, 132, 157, 158)
            ]
        case .pulldown:
            [
                pose(141, 78, 141, 105, 143, 149, 177, 150, 175, 183, 142, 75, 139, 44),
                pose(141, 78, 141, 105, 143, 149, 177, 150, 175, 183, 164, 125, 150, 91)
            ]
        case .pullover:
            [
                pose(71, 166, 98, 165, 151, 167, 189, 129, 212, 183, 111, 130, 121, 99),
                pose(71, 166, 98, 165, 151, 167, 189, 129, 212, 183, 68, 126, 40, 121)
            ]
        case .ytW:
            [
                pose(150, 55, 150, 86, 150, 134, 168, 157, 169, 181, 179, 63, 205, 40),
                pose(150, 55, 150, 86, 150, 134, 168, 157, 169, 181, 187, 88, 221, 88),
                pose(150, 55, 150, 86, 150, 134, 168, 157, 169, 181, 181, 101, 198, 76)
            ]
        case .overheadPress:
            [
                pose(140, 58, 139, 88, 139, 138, 171, 140, 176, 183, 170, 97, 171, 65),
                pose(140, 58, 139, 88, 139, 138, 171, 140, 176, 183, 151, 55, 151, 24)
            ]
        case .wallSlide:
            [
                pose(150, 56, 150, 82, 150, 128, 166, 152, 166, 183, 187, 98, 190, 67),
                pose(150, 56, 150, 82, 150, 128, 166, 152, 166, 183, 178, 58, 177, 27)
            ]
        case .curl:
            [
                pose(137, 42, 139, 70, 140, 121, 141, 153, 145, 184, 151, 104, 162, 134),
                pose(137, 42, 139, 70, 140, 121, 141, 153, 145, 184, 151, 104, 161, 72)
            ]
        case .reverseLunge:
            [
                pose(158, 43, 158, 69, 155, 119, 159, 151, 162, 183, 169, 98, 167, 127, backKnee: CGPoint(x: 148, y: 153), backFoot: CGPoint(x: 144, y: 183)),
                pose(154, 75, 155, 100, 148, 143, 186, 144, 174, 183, 164, 128, 167, 153, backKnee: CGPoint(x: 109, y: 176), backFoot: CGPoint(x: 84, y: 183))
            ]
        case .calfRaise:
            [
                pose(148, 42, 149, 70, 150, 119, 151, 151, 157, 183, 161, 99, 161, 128),
                pose(148, 36, 149, 64, 150, 113, 151, 145, 155, 177, 161, 93, 161, 122)
            ]
        case .hipThrust:
            [
                pose(71, 100, 98, 120, 142, 159, 185, 136, 207, 183, 109, 139, 143, 151),
                pose(68, 104, 98, 120, 147, 122, 190, 124, 207, 183, 115, 137, 147, 116)
            ]
        case .gluteBridge:
            [
                pose(67, 166, 95, 167, 147, 167, 186, 129, 207, 183, 111, 175, 141, 181),
                pose(67, 166, 95, 167, 148, 134, 188, 122, 207, 183, 111, 175, 141, 181)
            ]
        case .walk:
            [
                pose(150, 42, 151, 70, 148, 120, 167, 148, 190, 183, 136, 93, 151, 112, backKnee: CGPoint(x: 136, y: 147), backFoot: CGPoint(x: 112, y: 183)),
                pose(150, 40, 150, 68, 148, 118, 165, 145, 145, 174, 157, 91, 171, 110, backKnee: CGPoint(x: 146, y: 150), backFoot: CGPoint(x: 144, y: 183)),
                pose(151, 44, 151, 72, 150, 121, 137, 149, 110, 183, 164, 93, 181, 104, backKnee: CGPoint(x: 170, y: 151), backFoot: CGPoint(x: 186, y: 183))
            ]
        }
    }

    private func pose(
        _ hx: CGFloat, _ hy: CGFloat, _ sx: CGFloat, _ sy: CGFloat, _ px: CGFloat, _ py: CGFloat,
        _ kx: CGFloat, _ ky: CGFloat, _ fx: CGFloat, _ fy: CGFloat, _ ex: CGFloat, _ ey: CGFloat,
        _ wx: CGFloat, _ wy: CGFloat, backKnee: CGPoint? = nil, backFoot: CGPoint? = nil
    ) -> ExercisePose {
        ExercisePose(
            head: CGPoint(x: hx, y: hy), shoulder: CGPoint(x: sx, y: sy), hip: CGPoint(x: px, y: py),
            knee: CGPoint(x: kx, y: ky), foot: CGPoint(x: fx, y: fy), elbow: CGPoint(x: ex, y: ey),
            hand: CGPoint(x: wx, y: wy), backKnee: backKnee, backFoot: backFoot
        )
    }
}

private struct ExercisePose {
    let head: CGPoint
    let shoulder: CGPoint
    let hip: CGPoint
    let knee: CGPoint
    let foot: CGPoint
    let elbow: CGPoint
    let hand: CGPoint
    let backKnee: CGPoint?
    let backFoot: CGPoint?

    func interpolated(to other: Self, progress: CGFloat) -> Self {
        func point(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * progress, y: a.y + (b.y - a.y) * progress)
        }

        return Self(
            head: point(head, other.head),
            shoulder: point(shoulder, other.shoulder),
            hip: point(hip, other.hip),
            knee: point(knee, other.knee),
            foot: point(foot, other.foot),
            elbow: point(elbow, other.elbow),
            hand: point(hand, other.hand),
            backKnee: point(backKnee ?? knee, other.backKnee ?? other.knee),
            backFoot: point(backFoot ?? foot, other.backFoot ?? other.foot)
        )
    }
}

struct ExerciseMotionView: View {
    let motion: ExerciseMotion
    let equipment: ExerciseEquipmentDiagram
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startTime: Date?
    @State private var savedPhase: Double = 0
    @State private var slower = false

    private var playing: Bool { startTime != nil && !reduceMotion }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Démonstration").font(.headline)
                Spacer()
                Text("Schéma").font(.caption).foregroundStyle(muted)
            }

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !playing)) { timeline in
                ExerciseSilhouette(
                    motion: motion, equipment: equipment, progress: progress(at: timeline.date)
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(300.0 / 210.0, contentMode: .fit)
                .background(ink, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            }

            HStack(spacing: 8) {
                ForEach(Array(motion.labels.enumerated()), id: \.offset) { index, title in
                    let position = Double(index) / Double(motion.labels.count - 1)
                    Button {
                        startTime = nil
                        savedPhase = position
                    } label: {
                        Text(title)
                    }
                    .buttonStyle(ActionStyle(filled: !playing && phasePosition(savedPhase) == position))
                }
            }

            if !reduceMotion {
                HStack(spacing: 8) {
                    Button {
                        if playing {
                            pause(at: .now)
                        } else {
                            startTime = .now
                        }
                    } label: {
                        Label(playing ? "Pause" : "Lire", systemImage: playing ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(ActionStyle(filled: false))

                    Button {
                        let now = Date.now
                        if playing { savedPhase = phase(at: now) }
                        slower.toggle()
                        if playing { startTime = now }
                    } label: {
                        Label(slower ? "0,5×" : "1×", systemImage: "speedometer")
                    }
                    .buttonStyle(ActionStyle(filled: false))
                    .accessibilityLabel(slower ? "Vitesse ralentie" : "Vitesse normale")
                }
            }
        }
        .kPanel()
        .onDisappear { pause(at: .now) }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled {
                startTime = nil
                savedPhase = 0
            }
        }
    }

    private func phase(at date: Date) -> Double {
        guard let startTime else { return savedPhase }
        let elapsed = max(0, date.timeIntervalSince(startTime))
        return (savedPhase + elapsed / (slower ? 3.6 : 1.8)).truncatingRemainder(dividingBy: 2)
    }

    private func phasePosition(_ phase: Double) -> Double {
        phase <= 1 ? phase : 2 - phase
    }

    private func progress(at date: Date) -> Double {
        phasePosition(reduceMotion ? savedPhase : phase(at: date))
    }

    private func pause(at date: Date) {
        savedPhase = phase(at: date)
        startTime = nil
    }
}

private struct ExerciseSilhouette: View {
    let motion: ExerciseMotion
    let equipment: ExerciseEquipmentDiagram
    let progress: Double

    var body: some View {
        Canvas { context, size in
            let frames = motion.frames
            let phase = min(max(progress, 0), 1) * Double(frames.count - 1)
            let segment = min(Int(phase), frames.count - 2)
            let fraction = phase - Double(segment)
            let blend = CGFloat(fraction * fraction * (3 - 2 * fraction))
            let pose = frames[segment].interpolated(to: frames[segment + 1], progress: blend)
            let width = min(size.width / 300, size.height / 210)
            var canvas = context
            canvas.translateBy(x: (size.width - 300 * width) / 2, y: (size.height - 210 * width) / 2)
            canvas.scaleBy(x: width, y: width)

            line(&canvas, [point(36, 188), point(265, 188)], lineColor, 1.5)
            drawEquipment(&canvas, pose: pose)
            let pale = Color(white: 0.94)
            let far = Color(white: 0.45)
            let oppositeKnee = motion.symmetrical ? mirror(pose.knee) : pose.backKnee ?? pose.knee
            let oppositeFoot = motion.symmetrical ? mirror(pose.foot) : pose.backFoot ?? pose.foot
            line(&canvas, [pose.hip, oppositeKnee, oppositeFoot], far, 6)
            if motion.symmetrical {
                let otherShoulder = point(136, pose.shoulder.y)
                line(&canvas, [otherShoulder, mirror(pose.elbow), mirror(pose.hand)], pale, 6)
                line(&canvas, [otherShoulder, point(164, pose.shoulder.y)], pale, 8)
            }
            if motion == .bentRow {
                line(&canvas, [pose.shoulder, point(179, 102), point(190, 128)], far, 6)
            }
            if equipment == .lowSupport {
                line(&canvas, [pose.shoulder, point(120, 106), point(93, 97)], far, 6)
            }
            line(&canvas, [pose.hip, pose.knee, pose.foot], pale, 7)
            line(&canvas, [pose.foot, point(pose.foot.x + 12, min(184, pose.foot.y + 2))], pale, 6)
            line(&canvas, [pose.hip, pose.shoulder, pose.head], pale, 10)
            let leadingShoulder = motion.symmetrical ? point(164, pose.shoulder.y) : pose.shoulder
            let hand = equipment == .hipDumbbell ? point(pose.hip.x, pose.hip.y - 6) : pose.hand
            line(&canvas, [leadingShoulder, pose.elbow, hand], pale, 7)
            circle(&canvas, pose.head, radius: 12, color: pale)
            for joint in [pose.shoulder, pose.hip, pose.knee, pose.elbow] {
                circle(&canvas, joint, radius: 3, color: acid)
            }
            if equipment == .dumbbell || equipment == .hipDumbbell { dumbbell(&canvas, hand) }
            if equipment == .goblet {
                line(&canvas, [point(hand.x, hand.y - 11), point(hand.x, hand.y + 11)], acid, 4)
                line(&canvas, [point(hand.x - 8, hand.y - 9), point(hand.x + 8, hand.y - 9)], acid, 5)
                line(&canvas, [point(hand.x - 8, hand.y + 9), point(hand.x + 8, hand.y + 9)], acid, 5)
            }
        }
    }

    private func drawEquipment(_ canvas: inout GraphicsContext, pose: ExercisePose) {
        let steel = Color(white: 0.33)
        switch equipment {
        case .floor, .goblet, .hipDumbbell:
            break
        case .dumbbell:
            if motion == .bentRow {
                line(&canvas, [point(172, 131), point(222, 131)], steel, 8)
                line(&canvas, [point(184, 136), point(184, 185)], steel, 4)
            }
            if motion == .overheadPress {
                line(&canvas, [point(123, 143), point(160, 143)], steel, 8)
                line(&canvas, [point(135, 148), point(135, 184)], steel, 4)
            }
        case .wall:
            line(&canvas, [point(239, 28), point(239, 188)], steel, 5)
            if motion == .wallSlide {
                line(&canvas, [point(61, 30), point(239, 30), point(239, 187), point(61, 187), point(61, 30)], steel, 2)
            }
        case .bench:
            let x: CGFloat = motion == .bentRow ? 170 : 211
            line(&canvas, [point(x, 131), point(x + 54, 131)], steel, 8)
            line(&canvas, [point(x + 9, 136), point(x + 9, 185)], steel, 4)
            line(&canvas, [point(x + 49, 136), point(x + 49, 185)], steel, 4)
        case .lowSupport:
            line(&canvas, [point(93, 94), point(93, 187), point(71, 187)], steel, 5)
        case .legPress:
            line(&canvas, [point(83, 111), point(125, 165), point(148, 165)], steel, 9)
            line(&canvas, [point(166, 158), point(241, 77)], steel, 3)
            line(&canvas, [point(pose.foot.x - 6, pose.foot.y - 13), point(pose.foot.x + 13, pose.foot.y + 8)], acid, 5)
        case .chestPress:
            line(&canvas, [point(96, 77), point(109, 134), point(148, 134)], steel, 9)
            line(&canvas, [point(113, 141), point(113, 183)], steel, 4)
            line(&canvas, [point(211, 144), point(201, 83), pose.hand], steel, 4)
        case .seatedRow:
            line(&canvas, [point(109, 144), point(160, 144)], steel, 8)
            line(&canvas, [point(126, 147), point(126, 184)], steel, 4)
            line(&canvas, [point(236, 70), point(236, 185)], steel, 6)
            line(&canvas, [point(236, 111), pose.hand], acid, 2)
        case .pulldown:
            line(&canvas, [point(96, 21), point(96, 185), point(71, 185)], steel, 5)
            line(&canvas, [point(96, 21), point(146, 21), pose.hand], steel, 2)
            line(&canvas, [point(115, 155), point(163, 155)], steel, 6)
            line(&canvas, [point(pose.hand.x - 13, pose.hand.y), point(pose.hand.x + 13, pose.hand.y)], acid, 4)
        case .shoulderPress:
            line(&canvas, [point(120, 84), point(127, 140), point(158, 140)], steel, 8)
            line(&canvas, [point(127, 144), point(127, 183)], steel, 5)
            line(&canvas, [point(198, 30), point(204, 112), pose.hand], steel, 4)
        case .cableCurl:
            line(&canvas, [point(232, 82), point(232, 185)], steel, 6)
            line(&canvas, [point(232, 176), pose.hand], acid, 2)
        case .hipMachine:
            line(&canvas, [point(56, 125), point(101, 125), point(101, 184)], steel, 7)
            line(&canvas, [point(pose.hip.x - 19, pose.hip.y - 4), point(pose.hip.x + 20, pose.hip.y - 4)], acid, 7)
        case .treadmill:
            line(&canvas, [point(91, 188), point(225, 188), point(243, 78), point(212, 78)], steel, 6)
        }
    }

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private func mirror(_ source: CGPoint) -> CGPoint { CGPoint(x: 300 - source.x, y: source.y) }

    private func line(_ canvas: inout GraphicsContext, _ points: [CGPoint], _ tint: Color, _ width: CGFloat) {
        var path = Path()
        path.addLines(points)
        canvas.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func circle(_ canvas: inout GraphicsContext, _ center: CGPoint, radius: CGFloat, color: Color) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        canvas.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private func dumbbell(_ canvas: inout GraphicsContext, _ center: CGPoint) {
        line(&canvas, [point(center.x - 13, center.y), point(center.x + 13, center.y)], acid, 4)
        line(&canvas, [point(center.x - 11, center.y - 7), point(center.x - 11, center.y + 7)], acid, 5)
        line(&canvas, [point(center.x + 11, center.y - 7), point(center.x + 11, center.y + 7)], acid, 5)
    }
}
