# yayalint - Linter of YAYA

伺かのSHIORI「YAYA」のlinterです。

## How to Build

使うだけならlua.exeとか用意する方が楽かもしれません。

Linuxでのコンパイル方法しか載せられませんが同じようにしてWindowsでもビルド出来ます。

用意するもの

1. lua5.4
2. lpeglabel
3. luafilesystem
4. sol.hpp
5. luastatic

4のsol.hppをinclude出来るようにしてconv/windows.ccをコンパイルしてstatic-library(windows.a)を作ります。

```
clang++ -std=c++17 -I /path/to/sol windows.cc -c -o windows.o
llvm-ar r windows.a windows.o
```

1-3のstatic libraryを頑張ってコンパイルします。

コンパイルが終わったらluastaticを使って次のコマンドを打ち込みます。

```
CC= luastatic yayalint.lua class/*.lua conv/*.lua string_buffer/*.lua relabel.lua func_list.lua argparse.lua conv/conv_windows.a lfs.a lpeglabel.a lua54.a
```

yayalint.luastatic.cが出来上がるのでclangでコンパイル

```
clang -o yayalint conv/conv_windows.a lfs.a lpeglabel.a lua54.a
```

Windowsで同じようにやるならばClang\+MSVCの組み合わせでコンパイルするのがいいでしょう。

## 使い方

```
Usage: yayalint [-F] [-s] [-f] [-u] [-d] [-l] [-g] [-h] <path>

Arguments:
   path                  yaya.txtが置いてあるフォルダのパス

Options:
   -F, --nofile          ファイルが見つからないことを出力しない
   -s, --nosyntaxerror   構文エラーに関する情報を出力しない
   -f, --nofunction      未使用の関数に関する情報を出力しない
   -u, --nounused        未使用の変数に関する情報を出力しない
   -d, --noundefined     未定義の変数に関する情報を出力しない
   -l, --nolocal         ローカル変数に関する情報を出力しない
   -g, --noglobal        グローバル変数/関数に関する情報を出力しない
   -h, --help            ヘルプの表示
```

各オプションについて出力する、ではなく出力**しない**、であることに留意して下さい。

読み込む辞書の文字コードはUTF-8とShift\_JIS**のみ**対応しています。

出力はUTF-8なので、非ASCII文字を変数/関数/ファイル名に使う場合は注意。 コマンドプロンプトで実行すると多分文字化けします。

なので、文字化けしないようにするbatファイルを用意したのでそちらを使ってください。 batファイルにyaya.dllのあるフォルダ(一般的にはmasterフォルダ)をD&Dするだけです。

