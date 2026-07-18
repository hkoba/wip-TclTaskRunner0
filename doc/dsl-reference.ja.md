# DSL リファレンス

TclTaskRunner のタスク定義ファイル (`*.tcltask`) で使用可能なコマンドと変数の解説です。

## 基本コマンド

### `target`
新しいタスクを定義します。

```tcl
target name \
    check { ... } \
    action { ... } \
    dependsTasks { ... } \
    dependsFiles { ... } \
    values { var1 val1 var2 val2 ... }
```

- **check**: タスクが完了しているかを確認するスクリプト。真を返せばスキップされます。
    - デバッグを容易にするため、真理値以外に `[list $bool key1 val1 ...]` 形式で詳細情報を返すこともできます。
- **action**: タスクを実行するスクリプト。
- **dependsTasks**: 依存する他のターゲット名のリスト。
- **dependsFiles**: 依存するファイルパスのリスト。
- **values** (エイリアス: **let**): `check` や `action` 内で使用可能なローカル変数を定義します。

### `target-file` (または `FILE`)
ファイル生成タスクを定義します。`target` と同様ですが、ターゲット名がファイルパスとして扱われます。

### `default`
ファイルのデフォルトターゲットを指定します。`default target all ...` のように接頭辞として使います。

### `public`
ターゲットを外部から参照可能にします。

### `use`
他の `.tcltask` ファイルをロードします。

```tcl
use other.tcltask as @other
```

`as 名前` の後にオプション(`-key value` の組)を続けると、同じタスクファイルから
パラメータの異なる独立したインスタンスを複数作ることができます。

```tcl
use vhost.tcltask as @blog -domain blog.example.jp -port 8080
use vhost.tcltask as @shop -domain shop.example.jp -port 8081

default target all dependsTasks {@blog @shop}
```

- オプション付きの `use` には `as 名前` の指定が必須です。
- 各インスタンスは `親タスクセット名::名前`(例: `@main::blog`)として
  レジストリに登録され、`--status` の表示にもこの名前で現れます。
- 渡せるオプションは、対象タスクファイル側で `option -domain ...` として
  宣言されているものに限られます([タスクセットのパラメータ化](#タスクセットのパラメータ化)参照)。

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

### `RUN` / `=RUN`
外部コマンドを実行するための便利なショートカットです。

- **RUN**: `exec ... >@ stdout 2>@ stderr` と同等。コマンドを標準出力・標準エラーに出力しながら実行します。
- **=RUN**: `exec ... 2>@ stderr` と同等。標準エラーのみを出力します。
- `**` と同様、ドライラン時は実行がスキップされます。

### `IS_DRY_RUN`
現在の実行モードがドライラン (`-n`) かどうかを判定します。真理値を返します。

## Tcl 標準コマンドの拡張
`.tcltask` は `snit::type` に変換されるため、以下のコマンドでタスクセット固有の変数や関数を定義できます。

- `variable`: タスクセット内の共有変数。
- `proc`: タスクセット内のプライベート関数。
- `option`: 外部から設定可能なオプション。
- `method`: 外部から呼び出し可能なメソッド。

## タスクセットのパラメータ化

タスクファイルは `option` 宣言によってパラメータ化できます。
`check` や `action` の中からは `$options(-key)` で参照します。
値は以下の 3 つの経路で与えられ、後のものほど優先されます。

1. `option -key デフォルト値` — 宣言時のデフォルト
2. `.tcldict` サイドカーファイル — タスクファイルの隣に置く設定ファイル
3. 実行時の指定 — コマンド行の `key=value`、または `use ... as @x -key value`

### `.tcldict` サイドカー設定ファイル

`foo.tcltask` をロードする際、同じディレクトリに `foo.tcldict` があれば、
その内容(`key value` を並べた Tcl dict 形式)がオプション値として自動的に
読み込まれます。

```tcl
# foo.tcldict
name baz
content {Lorem ipsum dolor sit amet}
```

### symlink によるインスタンス化パターン

汎用タスク `lib/lib.tcltask` に対して symlink `foo.tcltask -> lib/lib.tcltask`
を張り、隣に `foo.tcldict` を置くと、同じタスク本体を異なるパラメータで
運用できます(実例: `tests/090_option_file/`)。

「タスク本体はリポジトリで共有し、ホスト固有の値は配置先(例:
`/etc/xxx.d/tasks/` の symlink + `.tcldict`)に置く」という規約にすると、
オペレータは引数なしでタスクを起動でき、コマンド行の `key=value` を
一時的なオーバーライド専用にできます。タスクの汎用化と運用時の簡潔さを
両立する推奨構成です。

一つのタスクファイルの中から複数インスタンスを作る場合は、symlink の代わりに
`use ... as @名前 -key value` が使えます([`use`](#use) 参照)。

### オプションの型検証

`option` には snit の検証型を指定できます。不正な値は実行前にエラーになります。

```tcl
option -name -default foo -type {snit::enum -values {foo bar baz}}
```

実行時に各タスクセットへ実際に適用されたオプション値は、`--status` の
ヘッダ行(`# @名前 effective options: ...`)で確認できます。
