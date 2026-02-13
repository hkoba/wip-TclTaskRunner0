# DSL リファレンス

TclTaskRunner のタスク定義ファイル (`*.tcltask`) で使用可能なコマンドと変数の解説です。

## 基本コマンド

### `target`
新しいタスクを定義します。

```tcl
target name 
    check { ... } 
    action { ... } 
    dependsTasks { ... } 
    dependsFiles { ... }
```

- **check**: タスクが完了しているかを確認するスクリプト。真を返せばスキップされます。
- **action**: タスクを実行するスクリプト。
- **dependsTasks**: 依存する他のターゲット名のリスト。
- **dependsFiles**: 依存するファイルパスのリスト。

### `target-file` (または `FILE`)
ファイル生成タスクを定義します。`target` と同様ですが、ターゲット名がファイルパスとして扱われます。

### `default`
ファイルのデフォルトターゲットを指定します。`default target all ...` のように接頭辞として使います。

### `public`
ターゲットを外部から参照可能にします。

### `use`
他の `.tcltask` ファイルをロードします。

```tcl
use other.tcltask as other
```

### `import`
外部の Tcl スクリプトからコマンドをインポートします。

```tcl
import {mycmd1 mycmd2} from utils.tcl
```

## 自動変数

`check` や `action` 内で Makefile 同様の自動変数が使用可能です。

- `$@`: 現在のターゲット名。
- `$<`: 最初の依存先。
- `$^`: すべての依存先のリスト。
- `$self`: 現在のタスクセットオブジェクト。

## ユーティリティ

### `**` (ドライラン・マーカー)
`action` スクリプト内で破壊的な操作を行うコマンドの前に置きます。

```tcl
** exec rm -rf /tmp/cache
```

- 通常実行時: そのまま実行。
- ドライラン時 (`-n`): 実行せずにコマンドを表示。

## Tcl 標準コマンドの拡張
`.tcltask` は `snit::type` に変換されるため、以下のコマンドでタスクセット固有の変数や関数を定義できます。

- `variable`: タスクセット内の共有変数。
- `proc`: タスクセット内のプライベート関数。
- `option`: 外部から設定可能なオプション。
- `method`: 外部から呼び出し可能なメソッド。
