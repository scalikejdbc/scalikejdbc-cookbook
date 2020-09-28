# 1. Installation

We will briefly describe how to start a Scala project using ScalikeJDBC. Here we show an example of using sbt.

## Scala

Make sure to have the JDK installed because Scala runs on the JVM.

## sbt

sbt is the _de facto_ standard build tool in Scala.

[Http://www.scala-sbt.org/](http://www.scala-sbt.org/)

Although launching sbt is as simple as running sbt-launch.jar by the java command, Mac users may find it easier to installing it via MacPorts;

    port install sbt

or via Homebrew;

    brew install sbt

For Windows and Linux users, please download a zip file from the sbt official site. You can see the guide on the site for more detail.

## Adding ScalikeJDBC

Make a project's root directory;

    mkdir scalikejdbc-example
    cd scalikejdbc-example

Make a file named build.sbt with the content such as the following.

    scalaVersion := "2.12.2"

    libraryDependencies ++= Seq (
      "org.scalikejdbc" %% "scalikejdbc"  % "3.2.+ ",
      "org.slf4j"       %  "slf4j-simple" % "1.7.+ ",
      "com.h2database"  %  "h2"           % "1.4.+ ",
      "org.scalatest"   %% "scalatest"    % "3.0.+" % "test"
    )

Start the sbt console. If all goes well, you can then import the scalikejdbc package.

    $ Sbt console
    [Info] Loading global plugins from /Users/seratch/.sbt/plugins
    [Info] Set current project to default-de841d (in build file: / Users / seratch / tmp / cookbok /)
    [Info] Starting scala interpreter ...
    [Info]
    Welcome to Scala version 2.11.6 (Java HotSpot (TM) 64-Bit Server VM, Java 1.7.0_15).
    Type in expressions to have them evaluated.
    Type: help for more information.

    scala> import scalikejdbc._
    import scalikejdbc._

    scala>: q

    [Success] Total time: 8 s, completed Nov 9, 2014 10:35:46 PM
    $

Ok, now you are ready. Let's try writing actual code using ScalikeJDBC in the next section.
