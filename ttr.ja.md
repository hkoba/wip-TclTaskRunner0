
[//000000001]: # (ttr \- Tcl Task Runner)
[//000000002]: # (Generated from file 'ttr\.ja\.man' by tcllib/doctools with format '/home/hkoba/blob/src/tcl/tcllib/modules/doctools/mpformats/fmt\.markdown')
[//000000003]: # (Copyright &copy; 2020, by Hiroaki Kobayashi \(hkoba\))
[//000000004]: # (ttr\(n\) 0\.1 ttr\.ja "Tcl Task Runner")

# NAME

ttr \- Tcl Task Runner \- Yet another Makefile alternative, based on Tcl

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [CLI](#section2)

  - [Task定義ファイル"\*\.tcltask"](#section3)

      - [ターゲット定義](#subsection1)

      - [スクリプト内で使用可能な変数](#subsection2)

      - [$self のメソッド](#subsection3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

[__TclTaskRunner\.tcl__ ?\-\-option?=value?\.\.\.? ?main\.tcltask? ?\-\-option=value\.\.\.? ?target\_or\_method?](#1)  
[__\./main\.tcltask__ ?\-\-option=value\.\.\.? ?target\_or\_method?](#2)  
[?__default__? __target__ *name* __check__ *checkScript* __action__ *actionScript* __dependsTasks__ *targetList*](#3)  
[__check__ *script*](#4)  
[__action__ *script*](#5)  
[__dependsTasks__ *targetNameList*](#6)  
[__dependsFiles__ *FileNameList*](#7)  
[__proc__ *name* *arglist* *body*](#8)  
[__target list__](#9)  

# <a name='description'></a>DESCRIPTION

TclTaskRunner\.tcl \(仮称\. 以下 ttr\)は Make に似た機能を持ったタスクランナー / ビルドツールです。

ttr ではタスクを "main\.tcltask" ファイルに記述します。 各タスクは __target__ コマンドで定義されます。

    #
    # all という名前でデフォルトのタスクを定義
    #
    default target all dependsTasks {
       webmaster
       devel
    }
    #
    # webmaster というタスクは webmaster アカウントの有無を検査して、無ければ作成
    #
    target webmaster check {
        check-user $target
    } action {
        ** exec useradd -s /sbin/nologin $target
    }
    #
    # コマンドの前の ** は dry-run 用のマーカー
    #
    # devel というタスクは devel グループの有無を検査して、無ければ作成
    #
    target devel check {
        check-group $target
    } action {
        ** exec groupadd $target
    }
    #
    # 以下は下請けの手続き
    #
    proc check-user {user} {...}
    proc check-group {user} {...}

tcltask ファイルの中身は snit::type へと変換されるので、通常の method, proc, option, variable
を定義して、check や action の中で使うことが出来ます。

# <a name='section2'></a>CLI

  - <a name='1'></a>__TclTaskRunner\.tcl__ ?\-\-option?=value?\.\.\.? ?main\.tcltask? ?\-\-option=value\.\.\.? ?target\_or\_method?

    コマンド行からの起動する場合の、引数の与え方です。 引数省略時はカレントディレクトリ―の "main\.tcltask"
    をタスク定義ファイルとして使用します。 オプションはタスク定義ファイルの前か後に、__\-\-option__ 又は
    __\-\-option=value__ 形式で指定します。 タスク定義ファイルの後には起動したいターゲット名か、メソッド名を渡すことが出来ます。
    （将来的にはタスク定義のオプションや変数オーバーライドも渡せるようにしたいと考えています）

      * __\-n__

      * __\-\-dry\-run__

        タスク定義の Action の __\*\*__ コマンドを dry\-run モードに切り替えます。

      * __\-d__

      * __\-\-debug__

      * __\-\-debug=*integer*__

        デバッグモードで実行します。

      * __\-s__

      * __\-\-silent__

        __\*\*__ コマンドのトレース出力を抑制します。

  - <a name='2'></a>__\./main\.tcltask__ ?\-\-option=value\.\.\.? ?target\_or\_method?

    Unix 系 OS の場合は tcltask ファイルに実行bit を立て、 ファイルの先頭に

    #!/usr/bin/env TclTaskRunner.tcl

    という行を 書けば、 tcltask ファイル自体をコマンドとして使用することも出来ます。

# <a name='section3'></a>Task定義ファイル"\*\.tcltask"

ttr ではタスク定義ファイルには拡張子 "\*\.tcltask" を使います。 ファイルの中身は（定義読み込み専用の tcl interpreter
で実行された後に） snit の snit::type 定義へと変換されます。

## <a name='subsection1'></a>ターゲット定義

  - <a name='3'></a>?__default__? __target__ *name* __check__ *checkScript* __action__ *actionScript* __dependsTasks__ *targetList*

    *name* という名前でターゲット\(タスク\)を定義します。 __default__
    を付けたターゲットはタスク定義ファイル全体のデフォルトターゲットとなります。 ターゲットの定義には以下の項目を渡すことが出来ます。

      * <a name='4'></a>__check__ *script*

        ターゲットが既に成立しているか否かを検査するためのスクリプトを書きます。 成立している場合は Tcl の真 \(yes\) を返して下さい。

    file exists $target

        デバッグを容易にするため、真理値以外に任意個の key value リストを返すことも出来ます。

    set data [read_file $target]
    list [expr {$data eq "foobar"}] data $data

      * <a name='5'></a>__action__ *script*

        ターゲットが未成立な時に実行される Tcl スクリプトを書きます。 破壊的な変更を行なうコマンドは必ず __\*\*__
        コマンド経由で呼び出すようにします。 こうすると、 dry\-run モードの時は画面に表示を行なうだけになります。

    ** exec cat foo > $target

        bash などのシェルと違って Tcl の場合はリダイレクトも __exec__ コマンドの引数に過ぎない\(exec
        の中で評価\)ので、リダイレクトも安全に dry\-run 出来ます。

      * <a name='6'></a>__dependsTasks__ *targetNameList*

        このターゲットが依存するターゲット名の一覧を Tcl リスト形式で渡して下さい。 リストの構築に不安が有る場合は Tcl 標準の
        __list__ 操作コマンドを 使って下さい。

      * <a name='7'></a>__dependsFiles__ *FileNameList*

        このターゲットが依存するファイル名の一覧を Tcl リスト形式で渡して下さい。

  - <a name='8'></a>__proc__ *name* *arglist* *body*

    （ほぼ）通常の Tcl手続きが定義出来ます。

## <a name='subsection2'></a>スクリプト内で使用可能な変数

ターゲット定義のスクリプトでは以下の変数が使用可能です。

  - __$target__

    ターゲット名

  - __$self__

    このタスク定義を表す snit オブジェクト\.

## <a name='subsection3'></a>$self のメソッド

  - <a name='9'></a>__target list__

    このタスク定義に含まれる、全てのターゲットの名前一覧

# <a name='seealso'></a>SEE ALSO

Tcl\(n\), make\(1\), snit\(n\)

# <a name='keywords'></a>KEYWORDS

Task Runner, make

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2020, by Hiroaki Kobayashi \(hkoba\)
