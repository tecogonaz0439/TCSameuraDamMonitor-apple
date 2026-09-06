// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import UniformTypeIdentifiers

/// デバッグログを表示および管理するビュー。
struct DebugLogView: View {
    /// デバッグログを含むアプリケーションデータモデル。
    let appModel: DamAppModel
    /// デバッグログの CSV としてのエクスポートフローを制御するステート変数。
    @State private var exportingCSV = false
    /// 削除確認アラートの表示状態を制御するステート変数。
    @State private var showDeleteConfirm = false

    /// デバッグログビューのコンテンツとレイアウト。
    var body: some View {
        List {
            if appModel.debugLogs.isEmpty {
                DebugLogEmptyRow()
            }
            ForEach(appModel.debugLogs) { entry in
                DebugLogRow(entry: entry)
            }
        }
        .task {
            appModel.refreshDebugLogs()
        }
        .navigationTitle(AppText.debugLogTitle)
        .toolbar {
            ShareLink(item: appModel.debugLogCSV()) {
                Label(AppText.share, systemImage: "square.and.arrow.up")
            }
            Button {
                exportingCSV = true
            } label: {
                Label(AppText.export, systemImage: "square.and.arrow.down")
            }
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label(AppText.deleteAll, systemImage: "trash")
            }
            .disabled(appModel.debugLogs.isEmpty)
        }
        .fileExporter(
            isPresented: $exportingCSV,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: appModel.generateDebugLogFileName()
        ) { _ in }
        .alert(AppText.debugLogDeleteTitle, isPresented: $showDeleteConfirm) {
            Button(AppText.deleteAll, role: .destructive) { appModel.clearDebugLog() }
            Button(AppText.cancel, role: .cancel) {}
        } message: {
            Text(AppText.debugLogDeleteMessage)
        }
    }

    /// デバッグログを CSV ファイルとしてエクスポートするために使用されるドキュメントユーティリティ。
    private var csvDocument: DataDocument {
        DataDocument(data: Data(appModel.debugLogCSV().utf8), contentType: .commaSeparatedText)
    }
}

/// デバッグログが存在しない場合に表示される空の行を表すビュー。
private struct DebugLogEmptyRow: View {
    /// 空の行のコンテンツとレイアウト。
    var body: some View {
        Text(AppText.debugLogEmpty)
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
    }
}

/// デバッグログリスト内の単一の行を表すビュー。
private struct DebugLogRow: View {
    /// 表示するデバッグログエントリ。
    let entry: DebugLogEntry

    /// デバッグログ行のコンテンツとレイアウト。
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(TimeFormatters.iso8601JST.string(from: entry.timestamp))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.message)
                .font(.headline)
            if !entry.details.isEmpty {
                Text(entry.details)
                    .font(.caption)
            }
        }
    }
}
