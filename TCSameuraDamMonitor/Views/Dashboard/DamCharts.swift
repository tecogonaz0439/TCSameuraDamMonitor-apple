// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import Charts
import SwiftUI

private let damChartPercentAxisValues = Array(stride(from: 0.0, through: 100.0, by: 10.0))
private let damChartAxisTickLength: CGFloat = 5
private let damChartLabeledAxisTickLength: CGFloat = 8
private let damChartXAxisLabelTopPadding = damChartLabeledAxisTickLength / 2
private let damChartXAxisReservedLabel = "00/00"

/// チャート上に表示されるツールチップビュー。
private struct DamChartTooltip: View {
    /// ツールチップ内に表示するテキスト行。
    let lines: [String]

    /// ダムチャートツールチップのコンテンツとレイアウト。
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
            }
        }
        .macCardCaptionFont()
        .foregroundStyle(.primary)
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(.regularMaterial)
                .opacity(0.75)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.secondary.opacity(0.25), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// ツールチップを計測した実サイズでチャート領域内へクランプ配置するビュー。
struct ChartTooltipOverlay: View {
    /// ツールチップ内に表示するテキスト行。
    let lines: [String]
    /// 十字線のX座標(オーバーレイ座標系)。
    let anchorX: CGFloat
    /// プロット領域の境界。
    let plotFrame: CGRect
    /// 計測されたツールチップサイズ。
    @State private var size: CGSize = .zero

    /// チャートツールチップオーバーレイのコンテンツとレイアウト。
    var body: some View {
        DamChartTooltip(lines: lines)
            .fixedSize()
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: TooltipSizePreferenceKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(TooltipSizePreferenceKey.self) { newSize in
                if newSize != size { size = newSize }
            }
            .position(clampedPosition)
    }

    /// ツールチップがプロット領域からはみ出さないようクランプされた中心座標。
    private var clampedPosition: CGPoint {
        let halfWidth = min(size.width / 2, plotFrame.width / 2)
        let halfHeight = min(size.height / 2, plotFrame.height / 2)
        let x = min(max(anchorX, plotFrame.minX + halfWidth), plotFrame.maxX - halfWidth)
        let desiredY = plotFrame.minY + 40
        let y = min(max(desiredY, plotFrame.minY + halfHeight), plotFrame.maxY - halfHeight)
        return CGPoint(x: x, y: y)
    }
}

/// グラフオプションを制御するために使用されるインタラクティブな選択チップ。
private struct GraphSelectionChip: View {
    /// チップのタイトルラベル。
    let title: String
    /// チップが現在選択されているかどうかを示す真偽値フラグ。
    let isSelected: Bool
    /// オプションのアクセシビリティ識別子。
    var identifier: String?
    /// タップされたときに実行されるアクション。
    let action: () -> Void

    /// グラフ選択チップのコンテンツとレイアウト。
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .macCardBodyFont()
                        .fontWeight(.semibold)
                }
                Text(title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .macCardBodyFont()
            .padding(.horizontal, 12)
#if os(macOS)
            .frame(minHeight: 26)
            .padding(.vertical, 3)
#else
            .frame(minHeight: 26)
            .padding(.vertical, 3)
#endif
            .foregroundStyle(.primary)
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.35), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier ?? "")
    }
}

/// チップを動的に配置するためのラッパーレイアウトフロー。
private struct GraphChipFlow<Content: View>: View {
    /// 内部のチップビュー。
    @ViewBuilder let content: Content

    /// グラフチップフローのコンテンツとレイアウト。
    var body: some View {
        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            content
        }
    }
}

/// サブビューを水平方向にマッピングし、制限を超えた場合にラップするカスタムフローレイアウト。
private struct FlowLayout: Layout {
    /// 水平方向の間隔。
    let horizontalSpacing: CGFloat
    /// 垂直方向の間隔。
    let verticalSpacing: CGFloat

    /// 動的レイアウトルールに適合するサイズを測定します。
    /// - Parameters:
    ///   - proposal: 提案されたビューサイズ制約。
    ///   - subviews: レイアウトサブビューのリスト。
    ///   - cache: レイアウトキャッシュ。
    /// - Returns: 計算されたレイアウトサイズ。
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, maxWidth: proposal.width ?? .infinity).size
    }

    /// 境界のあるレイアウトガイドライン内にサブビューを配置します。
    /// - Parameters:
    ///   - bounds: レイアウト境界座標空間。
    ///   - proposal: 提案されたサイズ。
    ///   - subviews: レイアウトサブビュー。
    ///   - cache: レイアウトキャッシュ。
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, maxWidth: bounds.width)
        for item in result.items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y),
                proposal: ProposedViewSize(item.size)
            )
        }
    }

    /// サブビューの位置を計算します。
    /// - Parameters:
    ///   - subviews: レイアウトサブビュー。
    ///   - maxWidth: 利用可能な最大幅の制約。
    /// - Returns: 計算されたレイアウト寸法とサブビューオフセット。
    private func layout(subviews: Subviews, maxWidth: CGFloat) -> (size: CGSize, items: [(index: Int, origin: CGPoint, size: CGSize)]) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        var items: [(Int, CGPoint, CGSize)] = []
        let effectiveMaxWidth = maxWidth.isFinite ? maxWidth : .greatestFiniteMagnitude

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > effectiveMaxWidth {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            items.append((index, CGPoint(x: x, y: y), size))
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, min(effectiveMaxWidth, x - horizontalSpacing))
        }

        return (CGSize(width: width, height: y + rowHeight), items)
    }
}

/// スクロールオフセットの最新値を保持する参照型。
/// @Stateの値そのものをスクロールのたびに更新するとObservationGraphCard全体の再評価を
/// 引き起こすため、参照型の中身だけを書き換えて再評価を避ける(復元時のみ@Stateへ反映)。
@MainActor
private final class GraphScrollOffsetBox {
    /// 現在のスクロールオフセット。
    var value: CGFloat = 0
}

/// iOS / iPadOS / macOS 共通の1行横スクロールチップ列。
/// 左右のスクロール余地に応じてエッジフェードを表示する。
/// フェードの可視状態はこのビュー内部の@Stateに閉じ込めることで、スクロールのたびに
/// ObservationGraphCard全体の再評価を引き起こさないようにする。
/// macOS はネイティブの ScrollView がマウスドラッグでスクロールしないため、
/// DragGesture でドラッグ量をスクロールオフセットへ反映する(ボタン上のドラッグでも
/// 動作するよう simultaneousGesture を使う)。
private struct CompactChipScrollRow<Content: View>: View {
    /// スクロール列の中身(チップ群)。
    @ViewBuilder let content: Content
    /// スクロール位置のバインディング。
    @Binding var scrollPosition: ScrollPosition
    /// スクロール列のアクセシビリティ識別子。
    let identifier: String
    /// エッジフェード要素の識別子prefix(例: "graph.year")。
    let fadePrefix: String
    /// スクロールオフセットの保存先(Card開閉での復元用。参照型のため再評価を起こさない)。
    var offsetBox: GraphScrollOffsetBox?

    /// 左端にスクロール余地がある(フェードを表示する)か。
    @State private var isFadeLeadingVisible = false
    /// 右端にスクロール余地がある(フェードを表示する)か。
    @State private var isFadeTrailingVisible = false
#if os(macOS)
    /// ドラッグ開始時の水平スクロールオフセット。
    @State private var dragStartOffset: CGFloat = 0
    /// ドラッグ中か否か(開始オフセットの初期化を1回だけにする)。
    @State private var isDragging = false
    /// 現在の水平スクロールオフセット(onScrollGeometryChange から更新)。
    @State private var currentOffset: CGFloat = 0
    /// スクロール可能な最大水平オフセット。
    @State private var maxScrollOffset: CGFloat = 0
#endif

    /// スクロール列を初期化します。
    /// - Parameters:
    ///   - scrollPosition: スクロール位置のバインディング。
    ///   - identifier: スクロール列のアクセシビリティ識別子。
    ///   - fadePrefix: エッジフェード要素の識別子prefix。
    ///   - offsetBox: スクロールオフセットの保存先(Card開閉での復元用)。
    ///   - content: スクロール列の中身(チップ群)。
    init(
        scrollPosition: Binding<ScrollPosition>,
        identifier: String,
        fadePrefix: String,
        offsetBox: GraphScrollOffsetBox? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self._scrollPosition = scrollPosition
        self.identifier = identifier
        self.fadePrefix = fadePrefix
        self.offsetBox = offsetBox
        self.content = content()
    }

    /// グラフチップスクロール列のコンテンツとレイアウト。
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content
            }
            .padding(.vertical, 8)
        }
        .scrollPosition($scrollPosition)
        .accessibilityIdentifier(identifier)
        .onScrollGeometryChange(for: ScrollGeometry.self) { geometry in
            geometry
        } action: { _, geometry in
            offsetBox?.value = geometry.contentOffset.x
#if os(macOS)
            currentOffset = geometry.contentOffset.x
            maxScrollOffset = max(geometry.contentSize.width - geometry.containerSize.width, 0)
#endif
            let canLeading = geometry.contentOffset.x > 1
            let canTrailing =
                geometry.contentOffset.x
                < geometry.contentSize.width - geometry.containerSize.width - 1
            isFadeLeadingVisible = canLeading
            isFadeTrailingVisible = canTrailing
        }
        .overlay(alignment: .leading) {
            edgeFade(edge: .leading, visible: isFadeLeadingVisible)
        }
        .overlay(alignment: .trailing) {
            edgeFade(edge: .trailing, visible: isFadeTrailingVisible)
        }
        .animation(.easeOut(duration: 0.15), value: isFadeLeadingVisible)
        .animation(.easeOut(duration: 0.15), value: isFadeTrailingVisible)
#if os(macOS)
        .simultaneousGesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragStartOffset = currentOffset
                    }
                    let target = min(max(dragStartOffset - value.translation.width, 0), maxScrollOffset)
                    if abs(target - currentOffset) > 0.5 {
                        scrollPosition.scrollTo(x: target)
                    }
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
#endif
    }

    /// 指定端のエッジフェード。スクロール余地がある側だけ表示する。
    /// 幅はWeb版mobileの28px・Android版の32dpに合わせた28pt。基調色はカード背景と同じ色で、
    /// フェード面をチップ列の背後に馴染ませる。
    @ViewBuilder
    private func edgeFade(edge: Edge, visible: Bool) -> some View {
        if visible {
            LinearGradient(
                colors: [fadeColor, fadeColor.opacity(0)],
                startPoint: edge == .leading ? .leading : .trailing,
                endPoint: edge == .leading ? .trailing : .leading
            )
            .frame(width: 28)
            .frame(maxWidth: .infinity, alignment: edge == .leading ? .leading : .trailing)
            .allowsHitTesting(false)
            .transition(.opacity)
            .accessibilityElement()
            .accessibilityLabel(AppText.graphChipRowFade)
            .accessibilityIdentifier("\(fadePrefix).fade.\(edge == .leading ? "leading" : "trailing")")
        }
    }

    /// エッジフェードの基調色。カード背景(BackgroundStyle)と同一の色にする。
    private var fadeColor: Color {
#if os(iOS)
        Color(uiColor: .systemBackground)
#else
        Color(nsColor: .windowBackgroundColor)
#endif
    }
}


/// 十字線とグラフ範囲を切り替えるオプションを表示するコントロール行。
private struct GraphControlRow: View {
    /// チャートが過去データ検索結果を表しているかどうかを示す真偽値フラグ。
    let isHistorical: Bool
    /// 利用可能なグラフ範囲オプションのリスト。
    let rangeOptions: [RealtimeGraphRange]
    /// 選択されたグラフ範囲設定へのバインディング。
    @Binding var range: RealtimeGraphRange
    /// 十字線が有効であるかどうかを示すバインディング。
    @Binding var isCrosshairEnabled: Bool
    /// 期間チップ1行横スクロール位置。
    @Binding var rangeScrollPosition: ScrollPosition

    /// グラフコントロール行のコンテンツとレイアウト。
    var body: some View {
        if isHistorical {
            GraphChipFlow {
                crosshairChip
            }
        } else {
            // 期間チップは1行横スクロール列で表示し、縦方向の折返しはしない。
            // 「タップ/ドラッグで値を表示する」チップは期間チップ列の外に別行で固定表示する。
            VStack(alignment: .leading, spacing: 8) {
                CompactChipScrollRow(
                    scrollPosition: $rangeScrollPosition,
                    identifier: "graph.range.scroll",
                    fadePrefix: "graph.range"
                ) {
                    rangeChips
                }
                .onAppear {
                    rangeScrollPosition.scrollTo(edge: .leading)
                }
                GraphChipFlow {
                    crosshairChip
                }
            }
        }
    }

    /// 範囲チップのグループを描画します。
    private var rangeChips: some View {
        GraphChipFlow {
            ForEach(rangeOptions) { item in
                GraphSelectionChip(title: item.localizedLabel, isSelected: item == range, identifier: "graph.range.\(item.rawValue)") {
                    range = item
                }
            }
        }
    }

    /// 十字線コントロールのグループを描画します。
    private var crosshairChip: some View {
        GraphSelectionChip(title: AppText.crosshairEnableLabel, isSelected: isCrosshairEnabled, identifier: "graph.crosshair") {
            isCrosshairEnabled.toggle()
        }
    }
}

/// 過去比較の再読込トリガとなる表示状態のキー。
///
/// 表示種類・履歴モード・表示期間・ダム・日次過去データ行の時刻fingerprintの変化で
/// `.task(id:)` を再実行し、比較データの鮮度を維持します(Android の Card 再生成相当)。
private struct ObservationGraphComparisonReloadKey: Hashable {
    /// 選択中の表示種類。
    let displayKind: ObservationGraphDisplayKind
    /// チャートが過去データ検索結果を表しているかどうか。
    let isHistorical: Bool
    /// sudmonitor 日次過去データの表示モードかどうか。
    let isSudmonitorDaily: Bool
    /// 表示開始日のフィルター文字列。
    let rangeStartDate: String?
    /// 表示終了日のフィルター文字列。
    let rangeEndDate: String?
    /// アクティブなダムの構成設定ID。
    let damConfigId: String?
    /// 日次過去データ行の軽量fingerprint。
    let dailyRowsFingerprint: DailyRowsFingerprint?
}

/// 日次過去データ行の同一性を表す軽量fingerprint。
///
/// 全行の時刻文字列配列をbody評価ごとに生成して比較する代わりに、
/// 件数と先頭・末尾時刻のみを比較する。日次過去データは時系列追記型で
/// 更新されるため、この3要素の組合せで実用上の変更を検出できる。
private struct DailyRowsFingerprint: Hashable {
    /// 行数。
    let count: Int
    /// 先頭行の時刻。
    let firstTime: String
    /// 末尾行の時刻。
    let lastTime: String
}

/// ダム観測データを表示するインタラクティブなチャートを含むカードビュー。
struct ObservationGraphCard: View {
    /// 過去の観測レコードの生の配列。
    let rows: [DamHistoricalData]
    /// 該当する場合、過去データ検索設定を記述するメタデータ。
    let meta: HistoricalSearchMeta?
    /// チャートが過去データ検索結果を表しているかどうかを示す真偽値フラグ。
    let isHistorical: Bool
    /// 表示開始日のフィルター文字列。
    let rangeStartDate: String?
    /// 表示終了日のフィルター文字列。
    let rangeEndDate: String?
    /// アクティブなダムの構成設定。
    let damConfig: DamConfig?
    /// 過去比較グラフ用のサービス。
    let comparisonService: HistoricalComparisonService
    /// グラフ入力データ（ダムデータ・過去履歴行等）の変更ごとに単調増加するリビジョン。
    let dataRevision: Int
    /// sudmonitor 日次過去データの表示モードかどうかを示す真偽値フラグ。
    let isSudmonitorDaily: Bool
    /// 読込済み日次過去データの観測行（通常の過去データ表示の最新年比較系列への合成用）。
    let dailyHistoryRows: [DamHistoricalData]

    /// この折りたたみ式カードの永続化された開閉状態。
    @Binding var isExpanded: Bool
    /// 表示モードを含むCard開閉キー。
    let expansionKey: DashboardCardExpansionKey
    /// 選択された表示メトリックのレイアウトタイプ。
    @State private var displayKind = ObservationGraphDisplayKind.rainfallStorage
    /// 選択されたプレビューグラフ範囲。
    @State private var realtimeRange = RealtimeGraphRange.all
    /// 十字線インタラクションが有効であるかどうかを示す真偽値フラグ。
    @State private var isCrosshairEnabled = false
    /// 過去比較で選択された過去年の集合(今年を含む)。
    @State private var selectedPastYears: Set<Int>
    /// ライン切替チップで選択中のグラフラインの集合。
    @State private var visibleLines: Set<GraphLine>
    /// 年チップ1行横スクロール位置。
    @State private var yearScrollPosition = ScrollPosition()
    /// モードチップ1行横スクロール位置。
    @State private var modeScrollPosition = ScrollPosition()
    /// 期間チップ1行横スクロール位置。
    @State private var rangeScrollPosition = ScrollPosition()
    /// ライン切替チップ(非履歴モード)1行横スクロール位置。
    @State private var lineScrollPosition = ScrollPosition()
    /// 年チップ1行横スクロールのオフセット(Card開閉での復元用)。
    @State private var yearScrollOffsetBox = GraphScrollOffsetBox()
    /// モードチップ1行横スクロールのオフセット(Card開閉での復元用)。
    @State private var modeScrollOffsetBox = GraphScrollOffsetBox()
    /// ライン切替チップ(非履歴モード)1行横スクロールのオフセット(Card開閉での復元用)。
    @State private var lineScrollOffsetBox = GraphScrollOffsetBox()
    /// Cardを閉じる時点のモードチップ列オフセット(Card再表示時の復元用)。
    @State private var savedModeScrollOffset: CGFloat?
    /// Cardを閉じる時点の年チップ列オフセット(Card再表示時の復元用)。
    @State private var savedYearScrollOffset: CGFloat?
    /// Cardを閉じる時点のライン切替チップ列(非履歴モード)オフセット(Card再表示時の復元用)。
    @State private var savedLineScrollOffset: CGFloat?
    /// 過去比較データの読み込み状態を管理するローダー。
    @State private var comparisonLoader: HistoricalComparisonLoader
    /// base/display snapshotのscreen lifetime cacheを管理するローダー。
    @State private var preparedLoader = PreparedGraphLoader()

    /// 観測グラフカードを初期化します。
    /// - Parameters:
    ///   - rows: 過去の観測レコードの生の配列。
    ///   - meta: 該当する場合、過去データ検索設定を記述するメタデータ。
    ///   - isHistorical: チャートが過去データ検索結果を表しているかどうか。
    ///   - rangeStartDate: 表示開始日のフィルター文字列。
    ///   - rangeEndDate: 表示終了日のフィルター文字列。
    ///   - isExpanded: この折りたたみ式カードの永続化された開閉状態。
    ///   - expansionKey: 表示モードを含むCard開閉キー。
    ///   - damConfig: アクティブなダムの構成設定。
    ///   - comparisonService: 過去比較グラフ用のサービス。
    ///   - dataRevision: グラフ入力データの変更ごとに単調増加するリビジョン。
    ///   - isSudmonitorDaily: sudmonitor 日次過去データの表示モードかどうか。
    ///   - dailyHistoryRows: 読込済み日次過去データの観測行（通常の過去データ表示の最新年比較系列への合成用）。
    init(
        rows: [DamHistoricalData],
        meta: HistoricalSearchMeta?,
        isHistorical: Bool,
        rangeStartDate: String?,
        rangeEndDate: String?,
        isExpanded: Binding<Bool>,
        expansionKey: DashboardCardExpansionKey,
        damConfig: DamConfig?,
        comparisonService: HistoricalComparisonService,
        dataRevision: Int,
        isSudmonitorDaily: Bool = false,
        dailyHistoryRows: [DamHistoricalData] = []
    ) {
        self.rows = rows
        self.meta = meta
        self.isHistorical = isHistorical
        self.rangeStartDate = rangeStartDate
        self.rangeEndDate = rangeEndDate
        self._isExpanded = isExpanded
        self.expansionKey = expansionKey
        self.damConfig = damConfig
        self.comparisonService = comparisonService
        self.dataRevision = dataRevision
        self.isSudmonitorDaily = isSudmonitorDaily
        self.dailyHistoryRows = dailyHistoryRows
        let currentYear = comparisonService.currentJstYear()
        _selectedPastYears = State(initialValue: Set(comparisonService.availablePastYears()).union([currentYear]))
        _visibleLines = State(initialValue: Set(GraphLine.allCases))
        _comparisonLoader = State(initialValue: HistoricalComparisonLoader(service: comparisonService))
    }

    /// グラフ入力のsource identityを解決します。
    ///
    /// 過去データ検索結果はmeta IDと表示期間フィルタ境界で、リアルタイムはダムIDで
    /// 区別します。過去データ検索の表示時はmetaが必ず存在する（Dashboard側の不変条件）。
    private var graphInputIdentity: GraphInputSnapshot.SourceIdentity {
        if isSudmonitorDaily {
            return .sudmonitorHistory(damID: damConfig?.id ?? "daily", filterStart: rangeStartDate, filterEnd: rangeEndDate)
        }
        if let meta {
            return .historicalSearch(metaID: meta.id, filterStart: rangeStartDate, filterEnd: rangeEndDate)
        }
        return .realtime(damID: damConfig?.id ?? "realtime")
    }

    /// 過去比較グラフの表示が有効かどうか(早明浦ダムのリアルタイム・過去データ(日次)・通常の過去データ表示のみ)。
    private var showsComparison: Bool {
        damConfig?.id == HistoricalComparisonService.sameuraDamId
    }

    /// 通常の過去データ表示の主系列年(表示対象データの年)。
    ///
    /// 表示対象データの先頭行のJST年を返し、行から取得できない場合は表示開始日・検索開始日の
    /// 先頭4桁へフォールバックします。リアルタイム・日次表示はJST現在年を使うため nil です。
    private var comparisonMainYear: Int? {
        guard isHistorical, !isSudmonitorDaily else { return nil }
        if let firstRow = rows.first,
           let millis = TimeFormatters.millisIfValid(fromDamTime: firstRow.time) {
            return Calendar.jst.component(.year, from: Date(timeIntervalSince1970: millis / 1000))
        }
        for candidate in [rangeStartDate, meta?.searchBgnDate] {
            guard let candidate, let year = Int(candidate.prefix(4)), candidate.count >= 8 else { continue }
            return year
        }
        return nil
    }

    /// 過去比較の対象年(過去年+今年)の集合。
    private var allYears: Set<Int> {
        Set(comparisonService.availablePastYears()).union([comparisonService.currentJstYear()])
    }

    /// 履歴モード(比較表示)かどうか。このときだけ年チップと全対象年チップを表示します。
    private var isHistoryComparisonMode: Bool {
        displayKind.isHistory && showsComparison
    }

    /// 現在の表示種類に対応する過去比較ペイロード。
    private var comparisonPayload: HistoricalComparisonPayload? {
        guard let metric = displayKind.comparisonMetric,
              case let .ready(payload) = comparisonLoader.state(for: metric) else {
            return nil
        }
        return payload
    }

    /// 過去比較の再読込トリガとなる表示状態のキー。
    private var comparisonReloadKey: ObservationGraphComparisonReloadKey {
        ObservationGraphComparisonReloadKey(
            displayKind: displayKind,
            isHistorical: isHistorical,
            isSudmonitorDaily: isSudmonitorDaily,
            rangeStartDate: rangeStartDate,
            rangeEndDate: rangeEndDate,
            damConfigId: damConfig?.id,
            dailyRowsFingerprint: dailyRowsFingerprint
        )
    }

    /// 日次過去データ行の軽量fingerprint(空ならnil)。
    private var dailyRowsFingerprint: DailyRowsFingerprint? {
        guard let first = dailyHistoryRows.first, let last = dailyHistoryRows.last else { return nil }
        return DailyRowsFingerprint(count: dailyHistoryRows.count, firstTime: first.time, lastTime: last.time)
    }

    /// 履歴モードのセクションへ渡す読み込み状態オーバーレイ。
    /// - Parameter rows: 時系列の昇順にソートされた日付付き履歴レコード。
    private func comparisonOverlay(rows: [DatedHistoricalRow]) -> AnyView? {
        guard let metric = displayKind.comparisonMetric else { return nil }
        switch comparisonLoader.state(for: metric) {
        case .loading:
            return AnyView(
                VStack(spacing: 8) {
                    ProgressView()
                    Text(AppText.graphLoadingHistoricalData)
                        .macCardCaptionFont()
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(AppText.graphLoadingHistoricalData)
                .accessibilityIdentifier("graph.historicalLoading")
                .allowsHitTesting(false)
            )
        case .failed:
            return AnyView(
                VStack(spacing: 8) {
                    Text(AppText.graphHistoricalDataLoadFailed)
                        .macCardCaptionFont()
                        .multilineTextAlignment(.center)
                    Button(AppText.graphRetry) {
                        comparisonLoader.load(
                            metric: metric,
                            damConfigId: damConfig?.id ?? "",
                            rows: rows.map(\.row),
                            mainYear: comparisonMainYear,
                            dailyRows: dailyHistoryRows
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("graph.historicalRetry")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("graph.historicalError")
            )
        default:
            return AnyView(EmptyView())
        }
    }

    /// セクションへ渡す十字線有効状態。履歴モードで読み込み完了前は無効化します。
    private var sectionCrosshairEnabled: Bool {
        guard displayKind.isHistory else { return isCrosshairEnabled }
        guard let metric = displayKind.comparisonMetric else { return false }
        if case .ready = comparisonLoader.state(for: metric) { return isCrosshairEnabled }
        return false
    }

    /// summary等のlocale依存出力を区別するfingerprint。
    private var localeFingerprint: String {
        "\(AppLocale.isJapanese)-\(TimeZone.current.identifier)"
    }

    /// ライン切替チップ行(履歴モードでは全対象年チップと年チップも含む)を構築します。
    /// グラフ本体の直下・期間チップ(GraphControlRow)の上に常時表示します。
    /// 履歴モードは既存の年チップ行(graph.year.scroll)をそのまま使い、非履歴モードは
    /// 専用のライン切替チップ行(graph.line.scroll)を使います。いずれも1行横スクロール表示
    /// (エッジフェード付き)で、スクロール位置はmode切替とCardの開閉を越えて維持し、
    /// 初期表示は先頭(左端)とする。iOS / iPadOS / macOS すべて同じ表示とする。
    @ViewBuilder
    private var lineChipRow: some View {
        CompactChipScrollRow(
            scrollPosition: lineChipScrollPosition,
            identifier: lineChipScrollIdentifier,
            fadePrefix: lineChipFadePrefix,
            offsetBox: lineChipOffsetBox
        ) {
            lineChips
        }
        .onAppear {
            if isHistoryComparisonMode {
                let target = savedYearScrollOffset
                savedYearScrollOffset = nil
                if let target {
                    Task { @MainActor in
                        yearScrollPosition.scrollTo(x: target)
                    }
                }
            } else {
                let target = savedLineScrollOffset
                savedLineScrollOffset = nil
                if let target {
                    Task { @MainActor in
                        lineScrollPosition.scrollTo(x: target)
                    }
                }
            }
        }
    }

    /// ライン切替チップ行の1行横スクロール位置。
    private var lineChipScrollPosition: Binding<ScrollPosition> {
        isHistoryComparisonMode ? $yearScrollPosition : $lineScrollPosition
    }

    /// ライン切替チップ行の1行横スクロールのオフセット保存先。
    private var lineChipOffsetBox: GraphScrollOffsetBox {
        isHistoryComparisonMode ? yearScrollOffsetBox : lineScrollOffsetBox
    }

    /// ライン切替チップ行のスクロール列識別子。
    /// 履歴モードは既存の年チップ行(graph.year.scroll)を維持し、非履歴モードは
    /// ライン切替チップ行(graph.line.scroll)を使います。
    private var lineChipScrollIdentifier: String {
        isHistoryComparisonMode ? "graph.year.scroll" : "graph.line.scroll"
    }

    /// ライン切替チップ行のエッジフェード識別子prefix。
    private var lineChipFadePrefix: String {
        isHistoryComparisonMode ? "graph.year" : "graph.line"
    }

    /// 現在の表示モードに応じたライン切替チップ群を構築します。
    /// 履歴モード(比較表示)は「全て」チップ+年チップ+他方のライン、非履歴モードはラインのみです。
    @ViewBuilder
    private var lineChips: some View {
        if isHistoryComparisonMode {
            switch displayKind {
            case .rainfallStorageHistory:
                allYearsChip(metric: .storageRate)
                ForEach(allYears.sorted(), id: \.self) { year in
                    yearChip(year: year)
                }
                lineChip(.rainfall)
            case .volumeFlowHistory:
                allYearsChip(metric: .storageVolume)
                ForEach(allYears.sorted(), id: \.self) { year in
                    yearChip(year: year)
                }
                lineChip(.inflow)
                lineChip(.outflow)
            default:
                EmptyView()
            }
        } else {
            switch displayKind {
            case .rainfallStorage:
                lineChip(.storageRate)
                lineChip(.rainfall)
            case .volumeFlow:
                lineChip(.storageVolume)
                lineChip(.inflow)
                lineChip(.outflow)
            default:
                EmptyView()
            }
        }
    }

    /// 表示モード選択チップの行を構築します。
    /// 1行横スクロール表示(エッジフェード付き。スクロール位置はmode切替とCardの開閉を
    /// 越えて維持)で、iOS / iPadOS / macOS すべて同じ表示とする。
    @ViewBuilder
    private var modeChipFlow: some View {
        CompactChipScrollRow(
            scrollPosition: $modeScrollPosition,
            identifier: "graph.mode.scroll",
            fadePrefix: "graph.mode",
            offsetBox: modeScrollOffsetBox
        ) {
            modeChips
        }
        .onAppear {
            let target = savedModeScrollOffset
            savedModeScrollOffset = nil
            if let target {
                Task { @MainActor in
                    modeScrollPosition.scrollTo(x: target)
                }
            }
        }
    }

    /// 表示モード選択チップ群を構築します。
    @ViewBuilder
    private var modeChips: some View {
        GraphSelectionChip(title: AppText.graphRainfallStorageSelect, isSelected: displayKind == .rainfallStorage, identifier: "graph.kind.rainfallStorage") {
            displayKind = .rainfallStorage
        }
        GraphSelectionChip(title: AppText.graphVolumeFlowSelect, isSelected: displayKind == .volumeFlow, identifier: "graph.kind.volumeFlow") {
            displayKind = .volumeFlow
        }
        if showsComparison {
            GraphSelectionChip(title: AppText.graphRainfallStorageHistorySelect, isSelected: displayKind == .rainfallStorageHistory, identifier: "graph.kind.rainfallStorageHistory") {
                displayKind = .rainfallStorageHistory
            }
            GraphSelectionChip(title: AppText.graphVolumeFlowHistorySelect, isSelected: displayKind == .volumeFlowHistory, identifier: "graph.kind.volumeFlowHistory") {
                displayKind = .volumeFlowHistory
            }
        }
    }

    /// 表示種類に応じたグラフセクションを構築します。
    /// - Parameters:
    ///   - display: 表示用snapshot（rows・domain・summary・segments等を保持）。
    ///   - baseRows: 比較再試行等に使う全区間の日付付き履歴レコード。
    ///   - displayResetKey: 表示keyの変更で十字線選択をリセットするための識別子。
    @ViewBuilder
    private func graphSection(display: GraphDisplaySnapshot, baseRows: [DatedHistoricalRow], displayResetKey: String) -> some View {
        switch displayKind {
        case .rainfallStorage:
            RainfallStorageGraphSection(
                display: display,
                isHistorical: isHistorical,
                isCrosshairEnabled: sectionCrosshairEnabled,
                displayResetKey: displayResetKey,
                visibleLines: visibleLines
            )
        case .rainfallStorageHistory:
            RainfallStorageGraphSection(
                display: display,
                isHistorical: isHistorical,
                isCrosshairEnabled: sectionCrosshairEnabled,
                displayResetKey: displayResetKey,
                comparisonPayload: comparisonPayload,
                selectedPastYears: selectedPastYears,
                visibleLines: visibleLines,
                comparisonOverlay: comparisonOverlay(rows: baseRows)
            )
        case .volumeFlow:
            VolumeFlowGraphSection(
                display: display,
                isHistorical: isHistorical,
                isCrosshairEnabled: sectionCrosshairEnabled,
                displayResetKey: displayResetKey,
                visibleLines: visibleLines
            )
        case .volumeFlowHistory:
            VolumeFlowGraphSection(
                display: display,
                isHistorical: isHistorical,
                isCrosshairEnabled: sectionCrosshairEnabled,
                displayResetKey: displayResetKey,
                comparisonPayload: comparisonPayload,
                selectedPastYears: selectedPastYears,
                visibleLines: visibleLines,
                comparisonOverlay: comparisonOverlay(rows: baseRows)
            )
        }
    }

    /// 過去年(今年含む)の全選択チップを構築します。
    /// チップはmode別に1つだけ表示し、アクセシビリティ識別子もmode別に分けます
    /// (mode 3=graph.year.all.storageRate、mode 4=graph.year.all.storageVolume)。
    /// - Parameter metric: 主系列の測定値の種類(貯水率/貯水量)。
    private func allYearsChip(metric: GraphLine) -> GraphSelectionChip {
        let isStorageRate = metric == .storageRate
        return GraphSelectionChip(
            title: isStorageRate ? AppText.graphAllStorageRate : AppText.graphAllStorageVolume,
            isSelected: HistoricalYearSelection.isAllSelected(selectedPastYears, allYears: allYears),
            identifier: isStorageRate ? "graph.year.all.storageRate" : "graph.year.all.storageVolume"
        ) {
            selectedPastYears = HistoricalYearSelection.togglingAll(selectedPastYears, allYears: allYears)
        }
    }

    /// 指定された年の選択チップを構築します。
    /// - Parameter year: 対象年(過去年または今年)。
    private func yearChip(year: Int) -> GraphSelectionChip {
        GraphSelectionChip(
            title: String(year),
            isSelected: selectedPastYears.contains(year),
            identifier: "graph.year.\(year)"
        ) {
            selectedPastYears = HistoricalYearSelection.togglingYear(year, current: selectedPastYears)
        }
    }

    /// 指定されたラインの表示/非表示チップを構築します。
    /// - Parameter line: 対象のライン。
    private func lineChip(_ line: GraphLine) -> GraphSelectionChip {
        GraphSelectionChip(
            title: line.localizedTitle,
            isSelected: visibleLines.contains(line),
            identifier: "graph.line.\(line.rawValue)"
        ) {
            visibleLines = GraphLineVisibility.togglingLine(line, current: visibleLines)
        }
    }

    /// 観測グラフカードのコンテンツとレイアウト。
    var body: some View {
        let input = GraphInputSnapshot.current(
            identity: graphInputIdentity,
            rawRows: rows,
            dataRevision: dataRevision,
            loader: comparisonLoader,
            metric: displayKind.comparisonMetric
        )
        let base = preparedLoader.baseSnapshot(for: input)
        let rangeOptions = base.rangeOptions
        let display = preparedLoader.displaySnapshot(
            base: input,
            kind: displayKind,
            range: realtimeRange,
            selectedYears: selectedPastYears,
            isHistorical: isHistorical,
            comparisonPayload: comparisonPayload,
            rangeStartDate: rangeStartDate,
            rangeEndDate: rangeEndDate,
            meta: meta,
            localeFingerprint: localeFingerprint
        )
        let displayResetKey = "\(input.dataRevision)-\(displayKind)-\(realtimeRange)-\(selectedPastYears.sorted())-\(isHistorical)-\(input.identity)"
        CollapsibleCard(
            title: AppText.graphObservationData,
            isExpanded: $isExpanded,
            toggleIdentifier: expansionKey.toggleIdentifier,
            cardIdentifier: "dashboard.graphCard"
        ) {
            if base.rows.isEmpty {
                ContentUnavailableView(AppText.noData, systemImage: "chart.line.uptrend.xyaxis", description: Text(AppText.noCachedData))
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    modeChipFlow

                    graphSection(display: display, baseRows: base.rows, displayResetKey: displayResetKey)

                    // ライン切替チップ行と期間チップ行を内側VStack間隔0で並べ、
                    // チップ間の縦間隔を期間チップ行と「タップ/ドラッグで値を表示する」行の
                    // 間隔(チップ間16pt)と一致させる(各行の上下パディング8ptずつで16ptになる)。
                    // iOS / iPadOS / macOS すべて同じ表示とする。
                    VStack(alignment: .leading, spacing: 0) {
                        lineChipRow

                        GraphControlRow(
                            isHistorical: isHistorical,
                            rangeOptions: rangeOptions,
                            range: $realtimeRange,
                            isCrosshairEnabled: $isCrosshairEnabled,
                            rangeScrollPosition: $rangeScrollPosition
                        )
                    }
                }
            }
        }
        .onChange(of: isExpanded) { _, newValue in
            if !newValue {
                savedModeScrollOffset = modeScrollOffsetBox.value
                savedYearScrollOffset = yearScrollOffsetBox.value
                savedLineScrollOffset = lineScrollOffsetBox.value
                realtimeRange = .all
                isCrosshairEnabled = false
            }
        }
        .onChange(of: rangeOptions) { _, newValue in
            if !newValue.contains(realtimeRange) {
                realtimeRange = .all
            }
        }
        .task(id: comparisonReloadKey) {
            guard displayKind.isHistory, showsComparison, let metric = displayKind.comparisonMetric else { return }
            comparisonLoader.cancel()
            comparisonLoader.load(
                metric: metric,
                damConfigId: damConfig?.id ?? "",
                rows: rows,
                mainYear: comparisonMainYear,
                dailyRows: dailyHistoryRows
            )
        }
        .onChange(of: isHistorical) { _, newValue in
            if newValue, displayKind.isHistory {
                displayKind = .rainfallStorage
                comparisonLoader.cancel()
            }
        }
        .onChange(of: damConfig?.id) { _, _ in
            displayKind = .rainfallStorage
            comparisonLoader.cancel()
        }
    }
}

/// 流域平均雨量および貯水率データのレンダリング専用のグラフセクションビュー。
private struct RainfallStorageGraphSection: View {
    /// 表示用snapshot（rows・domain・summary・segments等を保持）。
    let display: GraphDisplaySnapshot
    /// これが過去データ検索結果を表示しているかどうかを示す真偽値フラグ。
    let isHistorical: Bool
    /// 十字線が有効であるかどうかを示す真偽値フラグ。
    let isCrosshairEnabled: Bool
    /// 表示keyの変更で十字線選択をリセットするための識別子。
    let displayResetKey: String
    /// 過去比較の読み込み結果ペイロード。
    var comparisonPayload: HistoricalComparisonPayload?
    /// 過去比較で選択された年の集合(過去年+今年)。
    var selectedPastYears: Set<Int> = []
    /// ライン切替チップで選択中のグラフラインの集合。
    var visibleLines: Set<GraphLine> = []
    /// 過去比較の読み込み状態オーバーレイ。
    var comparisonOverlay: AnyView?

    /// 過去比較モードかどうか。
    private var isHistoryMode: Bool {
        comparisonPayload != nil
    }

    /// ツールチップの年別行の比較対象となる過去年の系列
    /// (選択中かつ線が実際に描画されている年のみ)。
    private var displayedTooltipPastSeries: [HistoricalComparisonSeries] {
        guard let comparisonPayload else { return [] }
        return HistoricalComparisonDisplay.tooltipPastSeries(
            selectedYears: selectedPastYears,
            drawnYears: display.drawnPastYears,
            pastSeries: comparisonPayload.pastSeries
        )
    }

    /// 主系列(主系列年の貯水率線)を描画するかどうか。
    /// 比較モードは主系列年チップの選択状態、非比較モードは「貯水率」ラインの選択状態に従います。
    private var shouldDrawCurrentYearLine: Bool {
        isCurrentLineVisible(.storageRate)
    }

    /// 現行系列の線と操作中markerに共通する表示判定です。
    private func isCurrentLineVisible(_ line: GraphLine) -> Bool {
        GraphLineVisibility.isLineVisible(
            line,
            isComparisonMode: isHistoryMode,
            mainLine: .storageRate,
            visibleLines: visibleLines,
            comparisonMainYear: comparisonPayload?.mainYear,
            selectedYears: selectedPastYears
        )
    }

    /// 雨量・貯水率グラフセクションのコンテンツとレイアウト。
    var body: some View {
        let rows = display.rows
        let summary = display.summary
        let domain = display.domain
        let rainfallAxisMax = display.rainfallAxisMax ?? ObservationGraphCalculator.rainfallAxisMaxDefault
        let timestamps = display.timestamps

        VStack(alignment: .leading, spacing: 10) {
            Text(summary)
                .macCardCaptionFont()
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            unitLabels(left: AppText.graphUnitStorageRate, right: rainfallUnitLabel)

            ResponsiveChartContainer { plotWidth in
                Chart {
                    if isHistoryMode {
                        pastSeriesMarks(display.pastStorageSeries)
                    }
                    if shouldDrawCurrentYearLine {
                        ForEach(display.storageSegments) { segment in
                            ForEach(segment.points) { point in
                                LineMark(
                                    x: .value(AppText.mainHistoryColDatetime, point.date),
                                    y: .value(AppText.mainStoragePercentage, point.value),
                                    series: .value("segment", segment.id)
                                )
                                .foregroundStyle(.blue)
                                .interpolationMethod(.linear)
                            }
                        }
                    }
                    if isCurrentLineVisible(.rainfall) {
                        ForEach(display.rainfallSegments) { segment in
                            ForEach(segment.points) { point in
                                LineMark(
                                    x: .value(AppText.mainHistoryColDatetime, point.date),
                                    y: .value(AppText.mainRainfall, point.value),
                                    series: .value("segment", segment.id)
                                )
                                .foregroundStyle(.purple)
                                .interpolationMethod(.linear)
                            }
                        }
                    }
                }
                .chartXScale(domain: domain)
                .chartYScale(domain: 0...ObservationGraphCalculator.chartYScaleUpperBound)
                .chartYAxis { percentRainfallAxis(rainfallAxisMax: rainfallAxisMax) }
                .chartXAxis { xAxis(range: domain, plotWidth: plotWidth) }
                .chartOverlay { proxy in
                    GraphInteractionOverlay(
                        rows: rows,
                        timestamps: timestamps,
                        xDomain: domain,
                        proxy: proxy,
                        isEnabled: isCrosshairEnabled,
                        xAxisPlotWidth: plotWidth,
                        leftYTickValues: damChartPercentAxisValues,
                        rightYTickValues: damChartPercentAxisValues,
                        tooltip: { row in
                            if isHistoryMode, let comparisonPayload {
                                historicalTooltipLines(
                                    for: row,
                                    date: ObservationGraphCalculator.date(fromDamTime: row.time),
                                    pastSeries: displayedTooltipPastSeries,
                                    metric: .storageRate,
                                    currentYearValue: row.storagePercentage,
                                    mainYear: comparisonPayload.mainYear
                                )
                            } else {
                                tooltipLines(row)
                            }
                        },
                        markers: [
                            GraphInteractionMarker(
                                line: .storageRate,
                                color: .blue,
                                isVisible: isCurrentLineVisible(.storageRate),
                                yValue: { $0.row.storagePercentage.map(Double.init) }
                            ),
                            GraphInteractionMarker(
                                line: .rainfall,
                                color: .purple,
                                isVisible: isCurrentLineVisible(.rainfall),
                                yValue: { row in
                                    row.row.catchmentAverageRainfall.map {
                                        scaled(Double($0), max: rainfallAxisMax)
                                    }
                                }
                            )
                        ],
                        displayResetKey: displayResetKey
                    )
                    .id(displayResetKey)
                }
                .macChartDrawingGroup()
            }
            .overlay {
                if let comparisonOverlay {
                    comparisonOverlay
                }
            }
            .accessibilityLabel(AppText.graphRainfallStorageSelect)
            .accessibilityValue(summary)
        }
    }

    /// 雨量単位を定義するヘッダーテキスト。
    private var rainfallUnitLabel: String {
        isHistorical ? AppText.graphUnitRainfallPerHour : AppText.graphUnitRainfall
    }

    /// 過去年の系列を表す線分マーカーを作成します。
    /// - Parameter seriesList: display snapshotに事前計算済みの過去年系列。
    @ChartContentBuilder
    private func pastSeriesMarks(_ seriesList: [PastYearChartSeries]) -> some ChartContent {
        ForEach(seriesList) { series in
            ForEach(series.segments) { segment in
                ForEach(segment.points) { point in
                    LineMark(
                        x: .value(AppText.mainHistoryColDatetime, point.date),
                        y: .value(series.axisLabel, point.value),
                        series: .value("segment", segment.id)
                    )
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.linear)
                }
            }
        }
    }

    /// ツールチップのテキストディスクリプタをフォーマットします。
    private func tooltipLines(_ row: DamHistoricalData) -> [String] {
        let rainfall = row.catchmentAverageRainfall.map { String(format: "%.1f", $0) } ?? "--"
        let storage = row.storagePercentage.map { String(format: "%.2f%%", $0) } ?? "-- %"
        return [
            DisplayFormatters.damDateTime(row.time),
            "\(AppText.graphTooltipRainfall) \(rainfall)\(rainfallUnitLabel.trimmedUnit)",
            "\(AppText.graphTooltipStorageRate) \(storage)",
        ]
    }
}

/// 貯水量、流入量、放流量データのレンダリング専用のグラフセクションビュー。
private struct VolumeFlowGraphSection: View {
    /// 表示用snapshot（rows・domain・summary・segments等を保持）。
    let display: GraphDisplaySnapshot
    /// これが過去データ検索結果を表示しているかどうかを示す真偽値フラグ。
    let isHistorical: Bool
    /// 十字線が有効であるかどうかを示す真偽値フラグ。
    let isCrosshairEnabled: Bool
    /// 表示keyの変更で十字線選択をリセットするための識別子。
    let displayResetKey: String
    /// 過去比較の読み込み結果ペイロード。
    var comparisonPayload: HistoricalComparisonPayload?
    /// 過去比較で選択された年の集合(過去年+今年)。
    var selectedPastYears: Set<Int> = []
    /// ライン切替チップで選択中のグラフラインの集合。
    var visibleLines: Set<GraphLine> = []
    /// 過去比較の読み込み状態オーバーレイ。
    var comparisonOverlay: AnyView?

    /// 過去比較モードかどうか。
    private var isHistoryMode: Bool {
        comparisonPayload != nil
    }

    /// ツールチップの年別行の比較対象となる過去年の系列
    /// (選択中かつ線が実際に描画されている年のみ)。
    private var displayedTooltipPastSeries: [HistoricalComparisonSeries] {
        guard let comparisonPayload else { return [] }
        return HistoricalComparisonDisplay.tooltipPastSeries(
            selectedYears: selectedPastYears,
            drawnYears: display.drawnPastYears,
            pastSeries: comparisonPayload.pastSeries
        )
    }

    /// 主系列(主系列年の貯水量線)を描画するかどうか。
    /// 比較モードは主系列年チップの選択状態、非比較モードは「貯水量」ラインの選択状態に従います。
    private var shouldDrawCurrentYearLine: Bool {
        isCurrentLineVisible(.storageVolume)
    }

    /// 現行系列の線と操作中markerに共通する表示判定です。
    private func isCurrentLineVisible(_ line: GraphLine) -> Bool {
        GraphLineVisibility.isLineVisible(
            line,
            isComparisonMode: isHistoryMode,
            mainLine: .storageVolume,
            visibleLines: visibleLines,
            comparisonMainYear: comparisonPayload?.mainYear,
            selectedYears: selectedPastYears
        )
    }

    /// 貯水量・流量グラフセクションのコンテンツとレイアウト。
    var body: some View {
        let rows = display.rows
        let summary = display.summary
        let domain = display.domain
        let volumeMax = display.volumeMax ?? 0
        let flowMax = display.flowMax ?? 0
        let hasFlowScaleData = display.hasFlowScaleData
        let volumeTickValues = display.volumeTickValues
        let flowTickValues = display.flowTickValues
        let timestamps = display.timestamps

        VStack(alignment: .leading, spacing: 10) {
            Text(summary)
                .macCardCaptionFont()
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            unitLabels(left: AppText.graphUnitStorageVolume, right: AppText.graphUnitFlow)

            ResponsiveChartContainer { plotWidth in
                Chart {
                    if hasFlowScaleData {
                        flowGridMarks(flowMax: flowMax)
                    }
                    if isHistoryMode {
                        pastSeriesMarks(display.pastVolumeSeries)
                    }
                    if shouldDrawCurrentYearLine {
                        ForEach(display.volumeSegments) { segment in
                            ForEach(segment.points) { point in
                                LineMark(
                                    x: .value(AppText.mainHistoryColDatetime, point.date),
                                    y: .value(AppText.mainStorageVolume, point.value),
                                    series: .value("segment", segment.id)
                                )
                                .foregroundStyle(.blue)
                                .interpolationMethod(.linear)
                            }
                        }
                    }
                    if isCurrentLineVisible(.inflow) {
                        ForEach(display.inflowSegments) { segment in
                            ForEach(segment.points) { point in
                                LineMark(
                                    x: .value(AppText.mainHistoryColDatetime, point.date),
                                    y: .value(AppText.mainInflow, point.value),
                                    series: .value("segment", segment.id)
                                )
                                .foregroundStyle(.gray)
                                .interpolationMethod(.linear)
                            }
                        }
                    }
                    if isCurrentLineVisible(.outflow) {
                        ForEach(display.outflowSegments) { segment in
                            ForEach(segment.points) { point in
                                LineMark(
                                    x: .value(AppText.mainHistoryColDatetime, point.date),
                                    y: .value(AppText.mainOutflow, point.value),
                                    series: .value("segment", segment.id)
                                )
                                .foregroundStyle(.purple)
                                .interpolationMethod(.linear)
                            }
                        }
                    }
                }
                .chartXScale(domain: domain)
                .chartYScale(domain: 0...ObservationGraphCalculator.chartYScaleUpperBound)
                .chartYAxis { volumeFlowAxis(volumeMax: volumeMax, flowMax: flowMax, hasFlowScaleData: hasFlowScaleData) }
                .chartXAxis { xAxis(range: domain, plotWidth: plotWidth) }
                .chartOverlay { proxy in
                    GraphInteractionOverlay(
                        rows: rows,
                        timestamps: timestamps,
                        xDomain: domain,
                        proxy: proxy,
                        isEnabled: isCrosshairEnabled,
                        xAxisPlotWidth: plotWidth,
                        leftYTickValues: volumeTickValues,
                        rightYTickValues: flowTickValues,
                        tooltip: { row in
                            if isHistoryMode, let comparisonPayload {
                                historicalTooltipLines(
                                    for: row,
                                    date: ObservationGraphCalculator.date(fromDamTime: row.time),
                                    pastSeries: displayedTooltipPastSeries,
                                    metric: .storageVolume,
                                    currentYearValue: row.storageVolume,
                                    mainYear: comparisonPayload.mainYear
                                )
                            } else {
                                tooltipLines(row)
                            }
                        },
                        markers: [
                            GraphInteractionMarker(
                                line: .storageVolume,
                                color: .blue,
                                isVisible: isCurrentLineVisible(.storageVolume),
                                yValue: { row in
                                    row.row.storageVolume.map { scaled(Double($0), max: volumeMax) }
                                }
                            ),
                            GraphInteractionMarker(
                                line: .inflow,
                                color: .gray,
                                isVisible: isCurrentLineVisible(.inflow),
                                yValue: { row in
                                    row.row.inflow.map { scaled(Double($0), max: flowMax) }
                                }
                            ),
                            GraphInteractionMarker(
                                line: .outflow,
                                color: .purple,
                                isVisible: isCurrentLineVisible(.outflow),
                                yValue: { row in
                                    row.row.outflow.map { scaled(Double($0), max: flowMax) }
                                }
                            )
                        ],
                        displayResetKey: displayResetKey
                    )
                    .id(displayResetKey)
                }
                .macChartDrawingGroup()
            }
            .overlay {
                if let comparisonOverlay {
                    comparisonOverlay
                }
            }
            .accessibilityLabel(AppText.graphVolumeFlowSelect)
            .accessibilityValue(summary)
        }
    }

    /// 過去年の系列を表す線分マーカーを作成します。
    /// - Parameter seriesList: display snapshotに事前計算済みの過去年系列。
    @ChartContentBuilder
    private func pastSeriesMarks(_ seriesList: [PastYearChartSeries]) -> some ChartContent {
        ForEach(seriesList) { series in
            ForEach(series.segments) { segment in
                ForEach(segment.points) { point in
                    LineMark(
                        x: .value(AppText.mainHistoryColDatetime, point.date),
                        y: .value(series.axisLabel, point.value),
                        series: .value("segment", segment.id)
                    )
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.linear)
                }
            }
        }
    }

    /// ツールチップのテキストディスクリプタをフォーマットします。
    private func tooltipLines(_ row: DamHistoricalData) -> [String] {
        let volume = row.storageVolume.map { "\(Int($0))" } ?? "--"
        let inflow = row.inflow.map { String(format: "%.2f", $0) } ?? "--"
        let outflow = row.outflow.map { String(format: "%.2f", $0) } ?? "--"
        return [
            DisplayFormatters.damDateTime(row.time),
            "\(AppText.graphTooltipStorageVolume) \(volume)\(AppText.graphUnitStorageVolume.trimmedUnit)",
            "\(AppText.graphTooltipInflow) \(inflow)\(AppText.graphUnitFlow.trimmedUnit)",
            "\(AppText.graphTooltipOutflow) \(outflow)\(AppText.graphUnitFlow.trimmedUnit)",
        ]
    }
}

/// チャート幅の量子化ユーティリティ。
///
/// ウインドウリサイズやサイドバー開閉アニメ中は幅が毎フレーム変化するため、
/// 生の幅を状態に持つとチャート全体（全LineMark）が毎フレーム再構築されて
/// フリーズする。量子化により、幅がバケットを跨いだときだけコンテンツを再構築する。
private enum ChartWidthQuantizer {
    /// 幅の量子化ステップ(px)。
    fileprivate static let widthQuantum: CGFloat = 16

    /// 幅を量子化ステップ刻みへ丸めます（0以下は0）。
    fileprivate static func quantized(_ width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        return (width / widthQuantum).rounded(.down) * widthQuantum
    }
}

/// 測定された幅に従ってチャートの高さを動的にスケーリングするコンテナビュー。
///
/// 幅は`ChartWidthQuantizer`の刻みで量子化して状態へ反映する。
private struct ResponsiveChartContainer<Content: View>: View {
    /// 内部チャートのビュービルダー。
    let content: (CGFloat) -> Content
    /// ローカルコンテナ幅トラッキング状態（量子化済み）。
    @State private var containerWidth: CGFloat = 0
    /// Swift Charts のプロット領域幅トラッキング状態（量子化済み）。
    @State private var plotWidth: CGFloat = 0

    /// 高さおよび軸密度計算に使う有効幅。
    private var layoutWidth: CGFloat {
        ObservationGraphCalculator.chartLayoutWidth(plotWidth: plotWidth, containerWidth: containerWidth)
    }

    /// レスポンシブチャートを初期化します。
    init(@ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.content = content
    }

    /// レスポンシブチャートコンテナのコンテンツとレイアウト。
    var body: some View {
        content(layoutWidth)
            .frame(maxWidth: .infinity)
            .frame(height: ObservationGraphCalculator.chartHeight(for: layoutWidth))
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: ChartWidthPreferenceKey.self, value: geometry.size.width)
                }
            }
            .onPreferenceChange(ChartWidthPreferenceKey.self) { newValue in
                let quantized = ChartWidthQuantizer.quantized(newValue)
                if quantized != containerWidth { containerWidth = quantized }
            }
            .onPreferenceChange(ChartPlotWidthPreferenceKey.self) { newValue in
                let quantized = ChartWidthQuantizer.quantized(newValue)
                if quantized != plotWidth { plotWidth = quantized }
            }
    }
}

/// 測定されたチャート幅の変更をビュー階層に伝達するためのプリファレンスキー。
private struct ChartWidthPreferenceKey: PreferenceKey {
    /// デフォルトのプリファレンス値。
    static let defaultValue: CGFloat = 0

    /// プリファレンスキーのレイアウト状態をマージします。
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// 測定されたプロット領域幅の変更をビュー階層に伝達するためのプリファレンスキー。
struct ChartPlotWidthPreferenceKey: PreferenceKey {
    /// デフォルトのプリファレンス値。
    static let defaultValue: CGFloat = 0

    /// プリファレンスキーのレイアウト状態をマージします。
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

/// 測定されたツールチップサイズの変更をビュー階層に伝達するためのプリファレンスキー。
private struct TooltipSizePreferenceKey: PreferenceKey {
    /// デフォルトのプリファレンス値。
    static let defaultValue: CGSize = .zero

    /// プリファレンスキーのレイアウト状態をマージします。
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

private extension View {
    @ViewBuilder
    func macChartDrawingGroup() -> some View {
        #if os(macOS)
        self.drawingGroup()
        #else
        self
        #endif
    }

    @ViewBuilder
    func macChartAxisReservationFont() -> some View {
        #if os(macOS)
        self.macCardCaptionFont()
        #else
        self
        #endif
    }
}

/// チャートの上の左右に整列された単位ラベルを描画します。
/// - Parameters:
///   - left: 左の単位文字列。
///   - right: 右の単位文字列。
/// - Returns: スタイル付きのラベルビュー表現。
private func unitLabels(left: String, right: String) -> some View {
    HStack {
        Text(left)
        Spacer()
        Text(right)
    }
    .macCardCaptionFont()
    .foregroundStyle(.primary)
}

/// 過去比較モードのツールチップの年別行を組み立てます(1行目はJST日時)。
/// - Parameters:
///   - row: 十字線で選択された主系列年の行。
///   - date: ツールチップの基準日時（行の日時がパースできない場合のフォールバック）。
///   - pastSeries: 表示対象の比較年の系列。
///   - metric: 測定値の種類。
///   - currentYearValue: 主系列年の値(nil=欠測)。
///   - mainYear: 主系列の年(通常の過去データ表示では表示対象データの年、他はJST現在年)。
/// - Returns: ツールチップ行の一覧。
private func historicalTooltipLines(
    for row: DamHistoricalData,
    date: Date?,
    pastSeries: [HistoricalComparisonSeries],
    metric: HistoricalComparisonMetric,
    currentYearValue: Float?,
    mainYear: Int
) -> [String] {
    let rowDate = ObservationGraphCalculator.date(fromDamTime: row.time) ?? date
    let yearLines = rowDate.map {
        HistoricalComparisonDisplay.yearValueLines(
            selectedDate: $0,
            currentYearValue: currentYearValue,
            pastSeries: pastSeries,
            metric: metric,
            isJapanese: AppLocale.isJapanese,
            calendar: Calendar.jst,
            mainYear: mainYear
        )
    } ?? []
    return [DisplayFormatters.damDateTime(row.time)] + yearLines
}

/// 流量の増分を示す水平方向のグリッドルールマークを描画します。
/// - Parameter flowMax: 最大流量の制約。
/// - Returns: チャートマーク。
@ChartContentBuilder
private func flowGridMarks(flowMax: Double) -> some ChartContent {
    ForEach(PreparedGraphDataBuilder.scaledAxisTickValues(maxValue: flowMax), id: \.self) { value in
        RuleMark(y: .value(AppText.graphUnitFlow, value))
            .foregroundStyle(.purple.opacity(0.28))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 2, 1, 2, 1, 2]))
    }
}

/// チャートプロットを囲む境界軸線、目盛り、およびラベルを描画します。
/// - Parameters:
///   - plotFrame: 境界線付きの矩形。
///   - xDomain: 時間領域の制限。
///   - xAxisPlotWidth: 幅の詳細。
///   - leftYTickValues: 左の目盛り値。
///   - rightYTickValues: 右の目盛り値。
/// - Returns: デコレーションオーバーレイ。
func chartAxisDecoration(
    plotFrame: CGRect,
    xDomain: ClosedRange<Date>,
    xAxisPlotWidth: CGFloat,
    leftYTickValues: [Double],
    rightYTickValues: [Double]
) -> some View {
    let xTicks = ObservationGraphCalculator.xAxisTickData(
        start: xDomain.lowerBound,
        end: xDomain.upperBound,
        plotWidth: xAxisPlotWidth
    )
    let gridLineSegments = ObservationGraphCalculator.xAxisGridLineSegments(
        start: xDomain.lowerBound,
        end: xDomain.upperBound,
        plotFrame: plotFrame,
        plotWidth: xAxisPlotWidth
    )
    let labeledXDates = Set(xTicks.labels.keys)

    let labelCenterY = plotFrame.maxY + damChartLabeledAxisTickLength + damChartXAxisLabelTopPadding + 8

    return ZStack(alignment: .topLeading) {
        Path { path in
            for segment in gridLineSegments {
                path.move(to: CGPoint(x: segment.x, y: segment.minY))
                path.addLine(to: CGPoint(x: segment.x, y: segment.maxY))
            }
        }
        .stroke(.primary.opacity(0.24), style: StrokeStyle(lineWidth: 1, lineCap: .butt, dash: [5, 5]))

        Path { path in
            guard plotFrame.width > 0, plotFrame.height > 0 else { return }
            path.move(to: CGPoint(x: plotFrame.minX, y: plotFrame.minY))
            path.addLine(to: CGPoint(x: plotFrame.minX, y: plotFrame.maxY))
            path.addLine(to: CGPoint(x: plotFrame.maxX, y: plotFrame.maxY))
            path.move(to: CGPoint(x: plotFrame.maxX, y: plotFrame.minY))
            path.addLine(to: CGPoint(x: plotFrame.maxX, y: plotFrame.maxY))

            for value in leftYTickValues {
                let y = yPosition(forScaledValue: value, in: plotFrame)
                path.move(to: CGPoint(x: plotFrame.minX - damChartAxisTickLength, y: y))
                path.addLine(to: CGPoint(x: plotFrame.minX, y: y))
            }

            for value in rightYTickValues {
                let y = yPosition(forScaledValue: value, in: plotFrame)
                path.move(to: CGPoint(x: plotFrame.maxX, y: y))
                path.addLine(to: CGPoint(x: plotFrame.maxX + damChartAxisTickLength, y: y))
            }

            for date in xTicks.tickDates {
                guard let x = xPosition(for: date, domain: xDomain, plotFrame: plotFrame) else { continue }
                let tickLength = labeledXDates.contains(date) ? damChartLabeledAxisTickLength : damChartAxisTickLength
                path.move(to: CGPoint(x: x, y: plotFrame.maxY))
                path.addLine(to: CGPoint(x: x, y: plotFrame.maxY + tickLength))
            }
        }
        .stroke(.primary.opacity(0.82), lineWidth: 1)

        ForEach(Array(xTicks.labels.keys).sorted(), id: \.self) { date in
            if let x = xPosition(for: date, domain: xDomain, plotFrame: plotFrame),
               let label = xTicks.labels[date],
               plotFrame.width > 0 {
                Text(label)
                    .macCardCaptionFont()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .position(x: x, y: labelCenterY)
            }
        }
    }
    .allowsHitTesting(false)
}

/// 貯水率および雨量のy軸目盛りを設定します。
/// - Parameter rainfallAxisMax: 最大雨量。
/// - Returns: 軸目盛り。
@AxisContentBuilder
private func percentRainfallAxis(rainfallAxisMax: Double) -> some AxisContent {
    AxisMarks(position: .leading, values: damChartPercentAxisValues) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        AxisTick()
        AxisValueLabel {
            if let percent = value.as(Double.self) {
                Text("\(Int(percent))")
                    .foregroundStyle(Color.primary)
                    .foregroundColor(.primary)
            }
        }
        .foregroundStyle(Color.primary)
    }
    AxisMarks(position: .trailing, values: damChartPercentAxisValues) { value in
        AxisTick()
        AxisValueLabel {
            if let percent = value.as(Double.self) {
                Text(String(format: "%.1f", percent / 100 * rainfallAxisMax))
                    .foregroundStyle(Color.primary)
                    .foregroundColor(.primary)
            }
        }
        .foregroundStyle(Color.primary)
    }
}

/// 貯水量および流量のy軸目盛りを設定します。
/// - Parameters:
///   - volumeMax: 最大貯水量。
///   - flowMax: 最大流量。
///   - hasFlowScaleData: データが存在するかどうかを示す真偽値。
/// - Returns: 軸目盛り。
@AxisContentBuilder
private func volumeFlowAxis(volumeMax: Double, flowMax: Double, hasFlowScaleData: Bool) -> some AxisContent {
    let volumeTicks = ObservationGraphCalculator.axisTickValues(maxValue: volumeMax)
    let flowTicks = ObservationGraphCalculator.axisTickValues(maxValue: flowMax)
    AxisMarks(position: .leading, values: volumeTicks.map { scaled($0, max: volumeMax) }) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        AxisTick()
        AxisValueLabel {
            if let percent = value.as(Double.self) {
                let tick = axisTickValue(forScaledValue: percent, maxValue: volumeMax, tickValues: volumeTicks)
                Text(ObservationGraphCalculator.axisTickLabel(tick, fractionDigits: 0))
                    .foregroundStyle(Color.primary)
                    .foregroundColor(.primary)
            }
        }
        .foregroundStyle(Color.primary)
    }
    if hasFlowScaleData {
        AxisMarks(position: .trailing, values: flowTicks.map { scaled($0, max: flowMax) }) { value in
            AxisTick()
            AxisValueLabel {
                if let percent = value.as(Double.self) {
                    let tick = axisTickValue(forScaledValue: percent, maxValue: flowMax, tickValues: flowTicks)
                    Text(ObservationGraphCalculator.axisTickLabel(tick, fractionDigits: 1))
                        .foregroundStyle(Color.primary)
                        .foregroundColor(.primary)
                }
            }
            .foregroundStyle(Color.primary)
        }
    }
}

/// x軸の時系列ラベルの間隔を設定します。
/// - Parameters:
///   - range: 有効なカレンダーの境界範囲。
///   - plotWidth: 水平幅の制約。
/// - Returns: 軸目盛り。
@AxisContentBuilder
private func xAxis(range: ClosedRange<Date>, plotWidth: CGFloat) -> some AxisContent {
    let ticks = ObservationGraphCalculator.xAxisTickData(
        start: range.lowerBound,
        end: range.upperBound,
        plotWidth: max(plotWidth, 1)
    )
    AxisMarks(values: ticks.tickDates) { value in
        AxisValueLabel {
            if let date = value.as(Date.self), ticks.labels[date] != nil {
                Text(xAxisReservedLabel)
                    .macChartAxisReservationFont()
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.top, xAxisReservedLabelTopPadding)
                    .opacity(0)
            }
        }
    }
}

private var xAxisReservedLabelTopPadding: CGFloat {
    #if os(macOS)
    damChartLabeledAxisTickLength + damChartXAxisLabelTopPadding + 16
    #else
    damChartXAxisLabelTopPadding
    #endif
}

private var xAxisReservedLabel: String {
    #if os(macOS)
    damChartXAxisReservedLabel
    #else
    " "
    #endif
}

/// パーセンテージにスケーリングされた目盛り値を元のパラメータ座標にマッピングし直します。
/// - Parameters:
///   - scaledValue: 比例スケール。
///   - maxValue: 最大制限値。
///   - tickValues: プリセット目盛りレベル。
/// - Returns: 計算された目盛り値。
private func axisTickValue(forScaledValue scaledValue: Double, maxValue: Double, tickValues: [Double]) -> Double {
    let rawValue = scaledValue / 100 * maxValue
    return tickValues.min { lhs, rhs in
        abs(lhs - rawValue) < abs(rhs - rawValue)
    } ?? rawValue
}

/// パーセンテージ値を垂直プロットの座標境界に変換します。
/// - Parameters:
///   - value: パーセンテージ値。
///   - plotFrame: 境界フレームの境界。
/// - Returns: 計算された y オフセット。
private func yPosition(forScaledValue value: Double, in plotFrame: CGRect) -> CGFloat {
    ObservationGraphCalculator.yPosition(forScaledValue: value, in: plotFrame)
}

/// 日付を水平プロットの座標境界に変換します。
/// - Parameters:
///   - date: 対象の日付。
///   - domain: カレンダーの制限範囲。
///   - plotFrame: プロット領域の境界。
/// - Returns: 計算された x 座標（存在しない場合は nil）。
private func xPosition(for date: Date, domain: ClosedRange<Date>, plotFrame: CGRect) -> CGFloat? {
    ObservationGraphCalculator.xPosition(for: date, start: domain.lowerBound, end: domain.upperBound, plotFrame: plotFrame)
}

extension RealtimeGraphRange {
    /// グラフ範囲オプションのローカライズされた表示ラベル。
    var localizedLabel: String {
        switch self {
        case .all: AppText.graphRangeAll
        case .past72Hours: AppText.graphRangePast72Hours
        case .past48Hours: AppText.graphRangePast48Hours
        case .past24Hours: AppText.graphRangePast24Hours
        }
    }
}

extension GraphLine {
    /// ライン切替チップのローカライズされた表示ラベル。
    var localizedTitle: String {
        switch self {
        case .storageRate: AppText.graphLineStorageRate
        case .rainfall: AppText.graphLineRainfall
        case .storageVolume: AppText.graphLineStorageVolume
        case .inflow: AppText.graphLineInflow
        case .outflow: AppText.graphLineOutflow
        }
    }
}

extension String {
    /// 単位テキストラベルから囲んでいる括弧を取り除きます。
    var trimmedUnit: String {
        trimmingCharacters(in: CharacterSet(charactersIn: "()"))
    }
}
