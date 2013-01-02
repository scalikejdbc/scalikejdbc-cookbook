# 1. インストール

　ScalikeJDBC を使った Scala のプロジェクトの始め方について簡単に説明します。ここでは sbt を使った例を示します。

## Scala

　Scala 自体は JVM 上で動作するため JDK が必要です。もしインストールされていない場合はインストールしておいてください。

## sbt 

　sbt は Scala でデファクトスタンダードになっているビルドツールです。

　[http://www.scala-sbt.org/](http://www.scala-sbt.org/)

　sbt の起動自体は sbt-launch.jar を java コマンドで起動するだけですが、Mac ユーザの方は MacPorts や 

```
port install sbt
```

Homebrew でインストールするのが簡単かと思います。

```
brew install sbt
```

　Windows や Linux ユーザの方は公式サイトから zip ファイルなどをダウンロードしてきて設定してください。手順の詳細は上記の sbt 公式サイトにガイドがあります。

## ScalikeJDBC を追加

　作業用のプロジェクトのルートディレクトリを作ってください。

```
mkdir scalikejdbc-example
cd scalikejdbc-example
```

　ここに build.sbt というファイルを作成して以下のような内容を記述してください。

```
libraryDependencies ++= Seq(
  "com.github.seratch" %% "scalikejdbc"  % "[1.4,)",
  "org.slf4j"          %  "slf4j-simple" % "[1.7,)",
  "com.h2database"     %  "h2"           % "[1.3,)",
  "org.specs2"         %% "specs2"       % "1.12.2" % "test"
)
```

　この状態で sbt console を起動してください。 scalikejdbc という package が import できるようになっていれば OK です。

```
$ sbt console
[info] Loading global plugins from /Users/seratch/.sbt/plugins
[info] Set current project to default-53c1f0 (in build file:/Users/seratch/tmp/scalikejdbc-example/)
[info] Updating {file:/Users/seratch/tmp/scalikejdbc-example/}default-53c1f0...
[info] Resolving org.specs2#specs2-scalaz-core_2.9.2;6.0.1 ...
[info] downloading http://repo1.maven.org/maven2/com/github/seratch/scalikejdbc_2.9.2/1.4.1/scalikejdbc_2.9.2-1.4.1.jar ...
[info] 	[SUCCESSFUL ] com.github.seratch#scalikejdbc_2.9.2;1.4.1!scalikejdbc_2.9.2.jar (988ms)
[info] Done updating.
[info] Starting scala interpreter...
[info] 
Welcome to Scala version 2.9.2 (Java HotSpot(TM) 64-Bit Server VM, Java 1.6.0_37).
Type in expressions to have them evaluated.
Type :help for more information.

scala> import scalikejdbc._
import scalikejdbc._

scala> :q

[success] Total time: 17 s, completed Dec 30, 2012 11:25:00 PM
$ 
```

　これで準備が整ったので、次のセクションからは実際に ScalikeJDBC を使ったコードを試してみましょう。


