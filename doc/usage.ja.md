# 利用ガイド

TclTaskRunner (ttr) は、コマンドラインツールとしても、他の Tcl スクリプトからのライブラリとしても利用可能です。

## コマンドラインでの利用

`TclTaskRunner.tcl` を実行する場合、基本形式は以下の通りです。

```bash
TclTaskRunner.tcl [options] [taskfile.tcltask] [key=value ...] [target_or_method] [args...]
```

### 引数の解釈
1.  **システムオプション**: `--dry-run`, `--debug`, `--silent` など、ttr 自体の動作を制御します。
2.  **タスクファイル**: 読み込む `.tcltask` ファイル。省略時は `main.tcltask` が探されます。
3.  **タスクオプション (`key=value`)**: `.tcltask` 内で `option -key` として定義されている変数に値を渡します。
4.  **ターゲットまたはメソッド**: 
    - 実行したい `target` 名。
    - または、`.tcltask` 内で `method` として定義されている名前。
    - 省略時は `default target` が実行されます。

### 実例
`tests/080_option/main.tcltask` を例にします。

```tcl
option -name -default foo
method clean {} { ... }
target all { ... }
```

このファイルを呼び出す場合：
- `ttr main.tcltask`: `all` ターゲットを `-name foo` で実行。
- `ttr main.tcltask name=bar`: `all` ターゲットを `-name bar` で実行。
- `ttr main.tcltask clean`: `clean` メソッドを実行。

### 状態レポート (`--status`)

`--status` を付けると、action を一切実行せずに、指定ターゲット(省略時は
default target)とその依存関係の `check` だけを評価し、成立状況を一覧表示します。
構成ドリフトの検知に使えます。

```console
$ ttr --status main.tcltask
# @main effective options: -flavor plain
✔ @main#ok-leaf note fine
✘ @main#ng-leaf got missing
# 1 ok, 1 needs-action, 0 error
```

- `✔` = check 成立、`✘` = 未成立(action が必要)、`!!` = check の実行エラー
  または依存ファイルの欠落、`⊘` = 依存先のエラーにより判定不能
- `check` が返した key-value 形式の診断情報が各行にそのまま表示されます
- 冒頭の `# ... effective options:` 行で、各タスクセットに実際に適用された
  オプション値を確認できます
- exit code は diff 流です: 0 = すべて成立、1 = 未成立あり、2 = エラーあり
- `check` も `action` も持たない集約ターゲットは表示されません
- `-n` (dry-run) が「実行されるはずのコマンド列」を見せるのに対し、
  `--status` は「各ターゲットの現在の検査結果」を見せます

cron などで定期実行して exit code を監視すれば、簡易的なドリフト監視になります。
なお `check` スクリプトは副作用を持たないように書くのが規約です
(`--status` はそれを前提に check を実行します)。

## ライブラリとしての利用

自作の Tcl スクリプト内から ttr を制御する手順は以下の通りです。

### 1. 初期化とロード
```tcl
source TclTaskRunner.tcl

# インスタンスの作成
TclTaskRunner dep -debug 0 -silent 1

# タスクファイルのロード
set taskset [dep use path/to/my.tcltask name=value]
```

### 2. タスクの実行
```tcl
# デフォルトターゲットの実行
dep run @my

# 特定のターゲットを実行
dep run @my mytarget

# メソッドの実行
dep run @my mymethod arg1 arg2
```

### 3. レジストリの活用
ロードされたすべてのタスクセットは、ファイル名のベース名に `@` を付けた名前（例: `@my`）でレジストリに登録されます。

- **依存関係での利用**: `dependsTasks @my` のように記述することで、他のタスクセットのデフォルトターゲットに依存させることができます。
- **オブジェクトの取得**: `set obj [dep registry get @my]` のようにして、タスクセットオブジェクトを直接操作できます。

## .tcltask の構造と露出
`.tcltask` 内で定義した要素は、以下のように外部へ露出します。

- **`target`**: CLI の引数や `dep run` で指定可能な実行単位となります。
- **`option`**: CLI の `key=value` 引数、または `dep use` 時の引数として設定可能です。内部では `$options(-key)` で参照します。
- **`method`**: オブジェクトのメソッドとして定義され、`target` と同様に外部から名前を指定して呼び出せます。
- **`proc`**: そのタスクセット内でのみ有効なプライベート関数となります。
- **`variable`**: タスクセット内で共有される変数です。
