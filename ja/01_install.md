# 1. インストール

ScalikeJDBC を使った Scala のプロジェクトの始め方について簡単に説明します。ここでは sbt を使った例を示します。

## Scala

Scala 自体は JVM 上で動作するため JDK が必要です。もしインストールされていない場合はインストールしておいてください。

## sbt 

sbt は Scala でデファクトスタンダードになっているビルドツールです。

[http://www.scala-sbt.org/](http://www.scala-sbt.org/)

sbt の起動自体は sbt-launch.jar を java コマンドで起動するだけですが、Mac ユーザの方は MacPorts や 

    port install sbt

Homebrew でインストールするのが簡単かと思います。

    brew install sbt

Windows や Linux ユーザの方は公式サイトから zip ファイルなどをダウンロードしてきて設定してください。手順の詳細は上記の sbt 公式サイトにガイドがあります。

## ScalikeJDBC を追加

作業用のプロジェクトのルートディレクトリを作ってください。

    mkdir scalikejdbc-example
    cd scalikejdbc-example

ここに build.sbt というファイルを作成して以下のような内容を記述してください。

    scalaVersion := "2.11.4"

    libraryDependencies ++= Seq(
      "org.scalikejdbc"  %% "scalikejdbc"  % "2.2.+",
      "org.slf4j"        %  "slf4j-simple" % "1.7.+",
      "com.h2database"   %  "h2"           % "1.4.+",
      "org.specs2"       %% "specs2-core"  % "2.4.9" % "test"
    )

この状態で sbt console を起動してください。 scalikejdbc という package が import できるようになっていれば OK です。

    $ sbt console
    [info] Loading global plugins from /Users/seratch/.sbt/plugins
    [info] Set current project to default-de841d (in build file:/Users/seratch/tmp/cookbok/)
    [info] Starting scala interpreter...
    [info]
    Welcome to Scala version 2.11.4 (Java HotSpot(TM) 64-Bit Server VM, Java 1.7.0_15).
    Type in expressions to have them evaluated.
    Type :help for more information.

    scala> import scalikejdbc._
    import scalikejdbc._

    scala> :q

    [success] Total time: 8 s, completed Nov 9, 2014 10:35:46 PM
    $

　これで準備が整ったので、次のセクションからは実際に ScalikeJDBC を使ったコードを試してみましょう。

