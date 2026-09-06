// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// 観測履歴テーブルの列幅を表す構造体。
struct ObservationHistoryTableColumnWidths: Hashable {
    /// 日時列の幅。
    var datetime: CGFloat = 120
    /// 雨量列の幅。
    var rainfall: CGFloat = 104
    /// 貯水量列の幅。
    var volume: CGFloat = 104
    /// 流入量列の幅。
    var inflow: CGFloat = 96
    /// 放流量列の幅。
    var outflow: CGFloat = 104
    /// 貯水率列の幅。
    var storage: CGFloat = 88

    /// すべての列の合計幅。
    var columnWidth: CGFloat {
        datetime + rainfall + volume + inflow + outflow + storage
    }

    /// 境界線を含むテーブルの合計幅。
    var tableWidth: CGFloat {
        columnWidth + 5
    }

    /// スクロール可能な列（日時を除く）の幅。
    var scrollableWidth: CGFloat {
        rainfall + volume + inflow + outflow + storage + 4
    }

    /// スクロール可能な列の幅に、右端の予約幅を加えた値を返します。
    /// - Parameter trailingReserve: 右端に確保する余白幅。
    /// - Returns: 予約幅込みのスクロール可能列幅。
    func scrollableWidth(trailingReserve: CGFloat) -> CGFloat {
        scrollableWidth + trailingReserve
    }

    /// 境界線を含むテーブル幅に、右端の予約幅を加えた値を返します。
    /// - Parameter trailingReserve: 右端に確保する余白幅。
    /// - Returns: 予約幅込みのテーブル幅。
    func tableWidth(trailingReserve: CGFloat) -> CGFloat {
        tableWidth + trailingReserve
    }

    /// 利用可能な幅がデフォルトのテーブル幅を超える場合、列幅を拡大して合わせます。
    /// - Parameter availableWidth: 利用可能な幅のレイアウト制約。
    /// - Returns: 拡張された幅を持つ新しいインスタンス。
    func expanded(to availableWidth: CGFloat) -> ObservationHistoryTableColumnWidths {
        guard availableWidth > tableWidth else { return self }
        return scaled(to: availableWidth)
    }

    /// 目標の幅に合わせて列幅を比例縮尺します。
    /// - Parameter availableWidth: 目標とする幅の制約。
    /// - Returns: スケール調整された幅を持つ新しいインスタンス。
    func scaled(to availableWidth: CGFloat) -> ObservationHistoryTableColumnWidths {
        let scale = (availableWidth - 5) / columnWidth
        return ObservationHistoryTableColumnWidths(
            datetime: datetime * scale,
            rainfall: rainfall * scale,
            volume: volume * scale,
            inflow: inflow * scale,
            outflow: outflow * scale,
            storage: storage * scale
        )
    }

    /// 利用可能幅、最小幅、最大幅に基づいて、全画面表示モードの列幅を調整します。
    /// - Parameters:
    ///   - availableWidth: 利用可能な幅。
    ///   - minimumFittingTableWidth: 適切に収まる最小のテーブル幅。
    ///   - maximumTableWidth: 許容される最大のテーブル幅。
    /// - Returns: 調整された列幅。
    func adjustedForFullDisplay(
        to availableWidth: CGFloat,
        minimumFittingTableWidth: CGFloat,
        maximumTableWidth: CGFloat
    ) -> ObservationHistoryTableColumnWidths {
        let targetWidth = min(availableWidth, maximumTableWidth)
        guard targetWidth >= minimumFittingTableWidth else { return self }
        return scaled(to: targetWidth)
    }
}

/// 観測履歴テーブルの単一のエントリを表す行データモデル。
struct ObservationHistoryTableRowModel: Identifiable, Hashable {
    /// 一意の識別子。
    let id: String
    /// フォーマットされた日時。
    let datetime: String
    /// フォーマットされた雨量値。
    let rainfall: String
    /// フォーマットされた貯水量。
    let volume: String
    /// フォーマットされた流入量。
    let inflow: String
    /// フォーマットされた放流量。
    let outflow: String
    /// フォーマットされた貯水率。
    let storage: String

    /// 履歴データから新しい行モデルを初期化します。
    /// - Parameter item: 日付付きの履歴レコード。
    init(_ item: DatedHistoricalRow) {
        id = item.id
        datetime = DisplayFormatters.historyRowDateTime(item.row.time)
        rainfall = DisplayFormatters.rainfall(item.row.catchmentAverageRainfall)
        volume = DisplayFormatters.value(item.row.storageVolume)
        inflow = DisplayFormatters.value(item.row.inflow, decimals: 2)
        outflow = DisplayFormatters.value(item.row.outflow, decimals: 2)
        storage = DisplayFormatters.value(item.row.storagePercentage, decimals: 2)
    }
}

/// 観測履歴テーブルの表示モード。
enum ObservationHistoryTableDisplayMode {
    /// 限られた列を表示するプレビューモード。
    case preview
    /// 詳細をすべて表示する全画面モード。
    case full
}

/// 全期間表示で横スクロール位置を同期する対象。
private enum ObservationHistoryHorizontalScrollSource {
    /// データ部分の横スクロール。
    case data
}

/// リアルタイム観測データまたは履歴データを表形式で表示するグリッドビュー。
struct ObservationHistoryTable: View {
    /// 表示するデータの行。
    let rows: [ObservationHistoryTableRowModel]
    /// テーブルが履歴データ検索結果を表示しているかどうかを示す真偽値フラグ。
    let isHistorical: Bool
    /// 表示モード（プレビューまたは全画面表示）。
    var displayMode: ObservationHistoryTableDisplayMode = .preview
    /// デフォルトの列幅の仕様。
    var columnWidths = ObservationHistoryTableColumnWidths()
    /// 指定されている場合、テーブルコンテナの明示的な幅。
    var containerWidth: CGFloat?

    /// ヘッダーの水平スクロール位置のバインディング。
    @State private var headerHorizontalPosition = ScrollPosition(edge: .leading)
    /// 全期間表示のデータ部分の水平スクロール位置のバインディング。
    @State private var dataHorizontalPosition = ScrollPosition(edge: .leading)
    /// 同期済みの水平スクロール位置。
    @State private var horizontalScrollOffset: CGFloat = 0
    /// ジオメトリ測定によって取得された利用可能な幅。
    @State private var availableWidth: CGFloat = 0

    /// 各観測データ行の高さ。
    private static let rowHeight: CGFloat = 25
    /// テーブルヘッダーの高さ。
    private static let headerHeight: CGFloat = 41
    /// クリッピングなしでテーブル全体が適切に収まるために必要な最小の幅。
    private let minimumFittingFullTableWidth: CGFloat = 560
    /// 全画面テーブルレイアウトで許容される最大の幅。
    private let maximumFullTableWidth: CGFloat = .infinity
    /// 境界線の色スタイル。
    private let borderColor = Color.secondary.opacity(0.75)

    /// 行数に基づいてテーブルの推奨高さを計算します。
    /// - Parameter rowCount: データ行の数。
    /// - Returns: 要求された合計の高さ。
    static func preferredHeight(rowCount: Int) -> CGFloat {
        Self.headerHeight + 1 + CGFloat(rowCount) * Self.rowHeight
    }

    /// プレビュー表と下部操作の間に追加する余白。
    static var previewBottomControlSpacing: CGFloat {
        #if os(macOS)
        8
        #else
        0
        #endif
    }

    /// macOSの全期間表示で右端スクロールバーと値の重なりを避けるための予約幅。
    static var fullDisplayTrailingScrollbarReserve: CGFloat {
        #if os(macOS)
        max(NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy), 16)
        #else
        0
        #endif
    }

    /// 全期間表示で下端に常時表示する横スクロールバー領域の高さ。
    static var fullDisplayBottomScrollbarHeight: CGFloat {
        #if os(macOS)
        max(NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy), 16)
        #else
        0
        #endif
    }

    /// 解決されたレイアウトの幅。
    private var layoutWidth: CGFloat {
        containerWidth ?? availableWidth
    }

    /// 現在の表示モードで右端に確保する予約幅。
    private var trailingScrollbarReserve: CGFloat {
        displayMode == .full ? Self.fullDisplayTrailingScrollbarReserve : 0
    }

    /// 列幅の拡縮計算に使う幅。
    private var columnLayoutWidth: CGFloat {
        max(layoutWidth - trailingScrollbarReserve, 0)
    }

    /// レイアウトモードと制約に従ってスケール調整された列幅。
    private var resolvedColumnWidths: ObservationHistoryTableColumnWidths {
        switch displayMode {
        case .preview:
            columnWidths.expanded(to: columnLayoutWidth)
        case .full:
            columnWidths.adjustedForFullDisplay(
                to: columnLayoutWidth,
                minimumFittingTableWidth: minimumFittingFullTableWidth,
                maximumTableWidth: maximumFullTableWidth
            )
        }
    }

    /// 該当する場合、フレーム幅の制限を計算します。
    private var tableFrameWidth: CGFloat? {
        let resolvedTableWidth = resolvedColumnWidths.tableWidth(trailingReserve: trailingScrollbarReserve)
        guard displayMode == .full, layoutWidth >= resolvedTableWidth else { return nil }
        return resolvedTableWidth
    }

    /// 全期間表示のスクロール可能列の表示幅。
    private func scrollableViewportWidth(columnWidths: ObservationHistoryTableColumnWidths) -> CGFloat {
        let tableWidth = tableFrameWidth ?? layoutWidth
        return max(tableWidth - columnWidths.datetime - 1, 0)
    }

    /// 観測履歴テーブル of コンテンツとレイアウト。
    var body: some View {
        switch displayMode {
        case .preview:
            previewTable(columnWidths: resolvedColumnWidths)
                .commonTableModifiers(borderColor: borderColor)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { _, w in availableWidth = w }
                .modifier(ObservationHistoryTableWidthModifier(width: tableFrameWidth))
        case .full:
            fullTable(columnWidths: resolvedColumnWidths)
                .commonTableModifiers(borderColor: borderColor)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { _, w in availableWidth = w }
                .modifier(ObservationHistoryTableWidthModifier(width: tableFrameWidth))
        }
    }

    /// テーブルのプレビューレイアウトを描画します。
    /// - Parameter columnWidths: 解決された列幅。
    /// - Returns: プレビューテーブルのレイアウト。
    private func previewTable(columnWidths: ObservationHistoryTableColumnWidths) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                datetimeHeaderCell(columnWidths: columnWidths)
                horizontalDivider
                datetimeDataRows(columnWidths: columnWidths)
            }
            .frame(width: columnWidths.datetime)
            verticalDivider

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    scrollableHeaderCells(columnWidths: columnWidths)
                        .frame(height: Self.headerHeight)
                    horizontalDivider
                    scrollableDataRows(columnWidths: columnWidths)
                }
                .frame(width: columnWidths.scrollableWidth)
            }
        }
    }

    /// テーブルの詳細レイアウトを描画します。
    /// - Parameter columnWidths: 解決された列幅。
    /// - Returns: 詳細テーブルのレイアウト。
    private func fullTable(columnWidths: ObservationHistoryTableColumnWidths) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                datetimeHeaderCell(columnWidths: columnWidths)
                verticalDivider

                ScrollView(.horizontal, showsIndicators: false) {
                    scrollableHeaderCells(columnWidths: columnWidths, trailingReserve: trailingScrollbarReserve)
                        .frame(height: Self.headerHeight)
                }
                .frame(height: Self.headerHeight)
                .scrollPosition($headerHorizontalPosition)
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .allowsHitTesting(false)
            }
            .frame(height: Self.headerHeight)
            horizontalDivider

            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    datetimeDataRows(columnWidths: columnWidths)
                        .frame(width: columnWidths.datetime)
                    verticalDivider

                    ScrollView(.horizontal, showsIndicators: false) {
                        scrollableDataRows(columnWidths: columnWidths, trailingReserve: trailingScrollbarReserve)
                            .frame(width: columnWidths.scrollableWidth(trailingReserve: trailingScrollbarReserve))
                    }
                    .scrollPosition($dataHorizontalPosition)
                    .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                    .onScrollGeometryChange(for: CGFloat.self) {
                        $0.contentOffset.x
                    } action: { _, x in
                        syncHorizontalScroll(to: x, source: .data)
                    }
                }
            }

            #if os(macOS)
            if Self.fullDisplayBottomScrollbarHeight > 0 {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: columnWidths.datetime)
                        .accessibilityHidden(true)
                    verticalDivider

                    MacFixedHorizontalScrollbar(
                        offset: horizontalScrollOffset,
                        contentWidth: columnWidths.scrollableWidth(trailingReserve: trailingScrollbarReserve),
                        viewportWidth: scrollableViewportWidth(columnWidths: columnWidths),
                        onChange: applyExternalHorizontalScroll
                    )
                    .frame(height: Self.fullDisplayBottomScrollbarHeight)
                }
                .frame(height: Self.fullDisplayBottomScrollbarHeight)
                .accessibilityHidden(true)
            }
            #endif
        }
    }

    /// 全期間表示のヘッダー、データ、下端スクロールバーの横位置を同期します。
    /// - Parameters:
    ///   - x: 同期先の水平スクロール位置。
    ///   - source: 同期元のスクロールビュー。
    private func syncHorizontalScroll(to x: CGFloat, source: ObservationHistoryHorizontalScrollSource) {
        let target = max(x, 0)
        guard abs(horizontalScrollOffset - target) > 0.5 else { return }
        horizontalScrollOffset = target
        headerHorizontalPosition.scrollTo(x: target)
        if source != .data {
            dataHorizontalPosition.scrollTo(x: target)
        }
    }

    /// 下端に固定表示する横スクロールバーからの操作を表へ反映します。
    /// - Parameter x: 同期先の水平スクロール位置。
    private func applyExternalHorizontalScroll(_ x: CGFloat) {
        let target = max(x, 0)
        horizontalScrollOffset = target
        headerHorizontalPosition.scrollTo(x: target)
        dataHorizontalPosition.scrollTo(x: target)
    }

    /// 日時ヘッダーセルを描画します。
    /// - Parameter columnWidths: 解決された列幅。
    /// - Returns: テーブルセル。
    private func datetimeHeaderCell(columnWidths: ObservationHistoryTableColumnWidths) -> some View {
        tableCell(
            AppText.mainHistoryColDatetime,
            width: columnWidths.datetime,
            alignment: .leading,
            textAlignment: .leading,
            isHeader: true
        )
        .frame(height: Self.headerHeight)
    }

    /// 日時データ行を描画します。
    /// - Parameter columnWidths: 解決された列幅。
    /// - Returns: セルのスタック。
    private func datetimeDataRows(columnWidths: ObservationHistoryTableColumnWidths) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                tableCell(
                    row.datetime,
                    width: columnWidths.datetime,
                    alignment: .leading,
                    textAlignment: .leading,
                    isHeader: false
                )
                .frame(height: Self.rowHeight)
            }
        }
    }

    /// スクロール可能なヘッダーセルを描画します。
    /// - Parameter columnWidths: 解決された列幅.
    /// - Returns: ヘッダーセルの行。
    private func scrollableHeaderCells(
        columnWidths: ObservationHistoryTableColumnWidths,
        trailingReserve: CGFloat = 0
    ) -> some View {
        HStack(spacing: 0) {
            headerCell(rainfallHeader, width: columnWidths.rainfall)
            verticalDivider
            headerCell(AppText.mainHistoryColVolume, width: columnWidths.volume)
            verticalDivider
            headerCell(AppText.mainHistoryColInflow, width: columnWidths.inflow)
            verticalDivider
            headerCell(AppText.mainHistoryColOutflow, width: columnWidths.outflow)
            verticalDivider
            headerCell(AppText.mainHistoryColStorage, width: columnWidths.storage)
            if trailingReserve > 0 {
                Color.clear
                    .frame(width: trailingReserve)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: columnWidths.scrollableWidth(trailingReserve: trailingReserve))
    }

    /// スクロール可能なデータ行を描画します。
    /// - Parameter columnWidths: 解決された列幅。
    /// - Returns: データ行のスタック。
    private func scrollableDataRows(
        columnWidths: ObservationHistoryTableColumnWidths,
        trailingReserve: CGFloat = 0
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                scrollableDataCells(row, columnWidths: columnWidths, trailingReserve: trailingReserve)
                    .frame(width: columnWidths.scrollableWidth(trailingReserve: trailingReserve), height: Self.rowHeight)
            }
        }
    }

    /// 単一の行のスクロール可能なデータセルを描画します。
    /// - Parameters:
    ///   - row: 行データモデル。
    ///   - columnWidths: 解決された列幅。
    /// - Returns: データセルの行。
    private func scrollableDataCells(
        _ row: ObservationHistoryTableRowModel,
        columnWidths: ObservationHistoryTableColumnWidths,
        trailingReserve: CGFloat = 0
    ) -> some View {
        HStack(spacing: 0) {
            dataCell(row.rainfall, width: columnWidths.rainfall)
            verticalDivider
            dataCell(row.volume, width: columnWidths.volume)
            verticalDivider
            dataCell(row.inflow, width: columnWidths.inflow)
            verticalDivider
            dataCell(row.outflow, width: columnWidths.outflow)
            verticalDivider
            dataCell(row.storage, width: columnWidths.storage)
            if trailingReserve > 0 {
                Color.clear
                    .frame(width: trailingReserve)
                    .accessibilityHidden(true)
            }
        }
    }

    /// 雨量パラメータのローカライズされたヘッダーラベルを解決します。
    private var rainfallHeader: String {
        isHistorical ? AppText.mainHistoryColRainfallPerHour : AppText.mainHistoryColRainfall
    }

    /// 垂直の境界区切り線。
    private var verticalDivider: some View {
        Rectangle()
            .fill(borderColor)
            .frame(width: 1)
    }

    /// 水平の境界区切り線。
    private var horizontalDivider: some View {
        Rectangle()
            .fill(borderColor)
            .frame(height: 1)
    }

    /// 右寄せのヘッダーセルを描画します。
    /// - Parameters:
    ///   - text: ラベルテキスト。
    ///   - width: 列幅の制約。
    /// - Returns: スタイル付きセルビュー。
    private func headerCell(_ text: String, width: CGFloat) -> some View {
        tableCell(text, width: width, alignment: .trailing, textAlignment: .trailing, isHeader: true)
    }

    /// 右寄せのデータセルを描画します。
    /// - Parameters:
    ///   - text: 値テキスト。
    ///   - width: 列幅の制約。
    /// - Returns: スタイル付きセルビュー。
    private func dataCell(_ text: String, width: CGFloat) -> some View {
        tableCell(text, width: width, alignment: .trailing, textAlignment: .trailing, isHeader: false)
    }

    /// 単一のテーブルセルビューを描画します。
    /// - Parameters:
    ///   - text: テキストコンテンツ。
    ///   - width: 列幅。
    ///   - alignment: レイアウト配置制約。
    ///   - textAlignment: 複数行テキスト配置スタイル。
    ///   - isHeader: このセルがヘッダーセルであるかどうかを示すフラグ。
    /// - Returns: スタイル付きテキストビュー。
    private func tableCell(
        _ text: String,
        width: CGFloat,
        alignment: Alignment,
        textAlignment: TextAlignment,
        isHeader: Bool
    ) -> some View {
        Text(headerText(text, isHeader: isHeader))
            .foregroundStyle(.primary)
            .multilineTextAlignment(textAlignment)
            .lineLimit(isHeader ? 2 : 1)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
            .frame(width: width, alignment: alignment)
            .clipped()
            .accessibilityLabel(accessibilityText(text))
    }

    /// 必要に応じて末尾に改行を追加してヘッダーテキストをフォーマットします。
    /// - Parameters:
    ///   - text: 生のテキスト文字列。
    ///   - isHeader: ヘッダー文脈フラグ。
    /// - Returns: フォーマットされたテキスト文字列。
    private func headerText(_ text: String, isHeader: Bool) -> String {
        guard isHeader, !text.contains("\n") else { return text }
        return "\(text)\n"
    }

    /// 改行文字を取り除くことでアクセシビリティの読み上げ用テキストを正規化します。
    /// - Parameter text: 生のテキスト文字列。
    /// - Returns: 正規化されたテキスト。
    private func accessibilityText(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ")
    }
}

private extension View {
    /// 境界線、フォント、等幅数字などの基本的なテーブルフォーマットスタイルを適用します。
    /// - Parameter borderColor: 境界線の色。
    /// - Returns: フォーマットされたテーブルビュー。
    func commonTableModifiers(borderColor: Color) -> some View {
        self
            .background {
                Rectangle()
                    .stroke(borderColor, lineWidth: 1)
            }
            #if os(macOS)
            .font(.body)
            #else
            .font(.system(size: 15))
            #endif
            .monospacedDigit()
            .accessibilityElement(children: .contain)
    }
}

/// 観測履歴テーブルの幅の制約を設定するビューモディファイア。
private struct ObservationHistoryTableWidthModifier: ViewModifier {
    /// 明示的な幅の制約。
    let width: CGFloat?

    /// コンテンツの幅の制約を変更します。
    /// - Parameter content: ビューコンテンツ。
    /// - Returns: 変更されたビュー。
    func body(content: Content) -> some View {
        if let width {
            content.frame(width: width, alignment: .leading)
        } else {
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if os(macOS)
/// macOS の全期間表下端に常時表示する横スクロールバー。
private struct MacFixedHorizontalScrollbar: View {
    /// 現在の水平スクロール位置。
    let offset: CGFloat
    /// スクロール対象コンテンツの幅。
    let contentWidth: CGFloat
    /// 表示領域の幅。
    let viewportWidth: CGFloat
    /// スクロール位置変更時のコールバック。
    let onChange: (CGFloat) -> Void

    /// ドラッグ開始時の水平スクロール位置。
    @State private var activeDragStartOffset: CGFloat?

    /// スクロール可能な最大水平位置。
    private var maxOffset: CGFloat {
        max(contentWidth - viewportWidth, 0)
    }

    /// 固定スクロールバーの描画。
    var body: some View {
        GeometryReader { geometry in
            let trackWidth = max(geometry.size.width - 4, 0)
            let trackHeight = max(min(geometry.size.height - 4, 12), 8)
            let knobWidth = knobWidth(trackWidth: trackWidth)
            let travelWidth = max(trackWidth - knobWidth, 0)
            let knobX = maxOffset > 0 ? min(max(offset / maxOffset * travelWidth, 0), travelWidth) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(nsColor: .separatorColor).opacity(maxOffset > 0 ? 0.55 : 0.25))
                    .frame(width: trackWidth, height: trackHeight)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                guard maxOffset > 0, trackWidth > 0 else { return }
                                let x = min(max(value.location.x - 2 - knobWidth / 2, 0), travelWidth)
                                onChange(travelWidth > 0 ? x / travelWidth * maxOffset : 0)
                            }
                    )
                Capsule()
                    .fill(Color(nsColor: .systemGray).opacity(maxOffset > 0 ? 0.8 : 0.35))
                    .frame(width: knobWidth, height: trackHeight)
                    .offset(x: knobX)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard maxOffset > 0, travelWidth > 0 else { return }
                                if activeDragStartOffset == nil {
                                    activeDragStartOffset = offset
                                }
                                let proposed = (activeDragStartOffset ?? offset) + value.translation.width / travelWidth * maxOffset
                                onChange(min(max(proposed, 0), maxOffset))
                            }
                            .onEnded { _ in
                                activeDragStartOffset = nil
                            }
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 2)
        }
        .accessibilityHidden(true)
    }

    /// 表示領域とコンテンツ幅からつまみ幅を算出します。
    /// - Parameter trackWidth: スクロールバーのトラック幅。
    /// - Returns: つまみ幅。
    private func knobWidth(trackWidth: CGFloat) -> CGFloat {
        guard contentWidth > 0, viewportWidth > 0, contentWidth > viewportWidth else {
            return trackWidth
        }
        return max(trackWidth * viewportWidth / contentWidth, min(trackWidth, 36))
    }
}
#endif
