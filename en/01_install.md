# 1. Installation

We will briefly describe how to start a Scala project using ScalikeJDBC. Here we show an example of using sbt.

## Scala

Scala requires JDK for running on the JVM. Please make sure to have it installed.

## sbt

sbt is a build tool that has become a _de facto_ standard in Scala.

[Http://www.scala-sbt.org/](http://www.scala-sbt.org/)

Although launching sbt is as simple as runing sbt-launch.jar by the java command, Mac users may find it easier to installing it via MacPorts;

    port install sbt

or via Homebrew;

    brew install sbt

For Windows and Linux users, please download a zip file from the sbt official site. For more information there is a guide at the site.

## Adding ScalikeJDBC

Make a project's root directory;

    mkdir scalikejdbc-example
    cd scalikejdbc-example

Make a file named build.sbt with the content such as the following.

    scalaVersion: = "2.11.6"

    libraryDependencies ++ = Seq (
      "Org.scalikejdbc" %% "scalikejdbc"% "2.2.+ ",
      "Org.slf4j"% "slf4j-simple"% "1.7.+ ",
      "Com.h2database"% "h2"% "1.4.+ ",
      "Org.specs2" %% "specs2-core"% "2.4.9"% "test"
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

It's now ready. Let's try writing actual code using ScalikeJDBC in the next section.
