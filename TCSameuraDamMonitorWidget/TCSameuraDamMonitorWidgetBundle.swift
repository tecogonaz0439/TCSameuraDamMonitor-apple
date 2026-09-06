// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import WidgetKit
import SwiftUI

/// TCSameuraDamMonitor 拡張機能によって提供されるすべてのウィジェットを集約するウィジェットバンドル。
///
/// 現在は、早明浦ダムの情報を表示するための ``TCSameuraDamMonitorWidget`` を含んでいます。
@main
struct TCSameuraDamMonitorWidgetBundle: WidgetBundle {
    /// ウィジェットバンドルの本体。
    var body: some Widget {
        TCSameuraDamMonitorWidget()
    }
}
