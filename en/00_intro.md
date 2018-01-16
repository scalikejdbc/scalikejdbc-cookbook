# Introduction

This book guides you exhaustively through the usage of [ScalikeJDBC](https://github.com/scalikejdbc/scalikejdbc), a DB access library in Scala, mainly developed and maintained by myself.

ScalikeJDBC, as it's name suggests, is a library that provides an API to allow writing of JDBC-handling code more Scala-like than using it directly. It aims to enable flexible and stress-free DB accesses using SQL in Scala applications.

The library was originally written as an experiment by referring to [Querulous](https://github.com/twitter/querulous) which Twitter Inc. published in 2011, but in early 2012 I came across a scene where I myself wanted to use it. It was then brushed up to its form today so as to be used in production level.

Then since [Cake Solutions Team Blog](http://www.cakesolutions.net/teamblogs/), a famous information source for Scala, picked it up at the corner of "This week in #Scala", feedback and usage reports have gradually been sent more often.

Readers of this book are assumed to have some knowledge of Scala. I've kept in mind to put a brief description about the background knowledge, but please consult various documents and other books as necessary.

I'd be glad if this book became a help to those who is interested in ScalikeJDBC.

January 2013, Kazuhiro Sera ([@seratch] (http://seratch.net/))


# On updates to version 2

According to the record, the first version of ScalikeJDBC was published on GitHub on November 18, 2011, which was this commit:

https://github.com/scalikejdbc/scalikejdbc/commit/7dee733278b059969147bba997db0c64512094ba

At that time, the latest Scala version was 2.9.1 when String Interpolation was still not around. Play Framework 2.x, which nowadays has become a best known Scala framework, was not released yet.

ScalikeJDBC was then written based on Twitter's DB library called Querulous which only supported MySQL. The code base was much simpler than it is now, but the API of DBSession is still the same.

It has been three years since then. The library has grown to the one that is used by many Scala developers as well as having far exceeded Querulous in its GitHub star count.
I would like to thank all the developers who gave a lot of feedback.

The Cookbook has been revised to keep up with ScalikeJDBC 2.2.0. I hope ScalikeJDBC users find it useful.

November 2014, Kazuhiro Sera ([@seratch] (http://seratch.net/))

# On updates to version 3

I am so glad to release ScalikeJDBC 3.0 in 2017. The first time I tried Scala was in 2010. Time goes by very quickly. That's 7 years ago!

The major changes in ScalikeJDBC 3.0 are:

- ScalikeJDBC 3.0 requires Java 8+
- The JSR-310 module has been merged into core library
- An optional module which supports Reactive Streams

https://github.com/scalikejdbc/scalikejdbc/blob/master/notes/3.0.0.markdown

The Cookbook has been revised to keep up with ScalikeJDBC 3.0.0. I hope ScalikeJDBC users find it useful.

May 2017, Kazuhiro Sera ([@seratch] (https://twitter.com/seratch))
