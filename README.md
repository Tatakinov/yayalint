# yayalint - Linter of YAYA

伺かのSHIORI「YAYA」のlinterです。

## バイナリ

Releaseからどうぞ。
yayalint.zipはyayalint.exeとyayalint.bat、
yayalint\_lua.zipはlua.exeとyayalint.luaと依存ファイル群が入っています。

## How to Build

以下にWindowsでClang\+MSVCの組み合わせでコンパイルする場合の方法を載せます。


用意するもの

1. [lua5.4](https://www.lua.org/) v5.4.4
2. [lpeglabel](https://github.com/Tatakinov/lpeglabel) gitの最新コミット
3. [luafilesystem(lfs)](https://github.com/keplerproject/luafilesystem) v1.8.0
4. [argparse](https://github.com/mpeterv/argparse) v0.6.0
5. [sol.hpp](https://github.com/ThePhD/sol2) v3.3.0
6. [luastatic](https://github.com/ers35/luastatic) v0.0.12

1-6をダウンロードしてきてこんな感じのフォルダ構成にします。

```
---- yayalint.lua
  |- ...
  |
  |- lua
  | |- src
  | |- ...
  |
  |- lpeglabel
  | |- HISTORY
  | |- ...
  |
  |- lfs
  | |- LICENSE
  | |- ...
  |
  |- argparse
  | |- CHANGELOG.md
  | |- ...
  |
  |- sol
  | |- config.hpp
  | |- forward.hpp
  | |- sol.hpp
  |
  |- luastatic
  | |- Makefile
  | |- ...
```

yayalint.luaのあるフォルダでmakeします。
```
cd /path/to/yayalint/
make
```

## 使い方

```
Usage: yayalint [-F] [-s] [-w] [-f] [-u] [-d] [-l] [-g] [-h] <path>

Arguments:
   path                  yaya.txt(or aya.txt)のパス(e.g. C:\ssp\ghost\test\ghost\master\yaya.txt)

Options:
   -F, --nofile          ファイルが見つからないことを出力しない
   -s, --nosyntaxerror   構文エラーに関する情報を出力しない
   -w, --nowarning       警告を出力しない
   -f, --nofunction      未使用の関数に関する情報を出力しない
   -u, --nounused        未使用の変数に関する情報を出力しない
   -d, --noundefined     未定義の変数に関する情報を出力しない
   -l, --nolocal         ローカル変数に関する情報を出力しない
   -g, --noglobal        グローバル変数に関する情報を出力しない
   -h, --help            ヘルプの表示
```

各オプションについて出力する、ではなく出力**しない**、であることに留意して下さい。

読み込む辞書の文字コードはUTF-8とShift\_JIS**のみ**対応しています。

出力はUTF-8なので、非ASCII文字を変数/関数/ファイル名に使う場合は注意。 コマンドプロンプトで実行すると多分文字化けします。

なので、文字化けしないようにするbatファイルを用意したのでそちらを使ってください。 ~~batファイルにyaya.dllのあるフォルダ(一般的にはmasterフォルダ)をD&Dするだけです。~~

v1.1.0以降ではyaya.txt(aya.txt)をbatファイルにD&Dするようになりました。

