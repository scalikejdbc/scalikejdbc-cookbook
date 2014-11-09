# はじめに

この書籍は主に筆者が開発・メンテナンスしている [ScalikeJDBC](https://github.com/scalikejdbc/scalikejdbc) という Scala の DB アクセスライブラリの利用方法について余すことなく解説したものです。

ScalikeJDBC は、その名の通り Scala で直接 JDBC を扱うよりもより Scala らしく書ける API を提供するライブラリです。ストレスなく柔軟に SQL を使った DB アクセスを Scala のアプリケーションで実現することを目指しています。

元々は 2011 年に Twitter 社が公開している [Querulous](https://github.com/twitter/querulous) というライブラリを参考に試作したものでしたが、2012 年の初頭に筆者自身が実務で利用したいシーンがあり、そのタイミングで実用レベルで使えるようにブラッシュアップし、今の形になりました。

その後 Scala の情報源として有名な [Cake Solutions Team Blog](http://www.cakesolutions.net/teamblogs/) の「This week in #Scala」というコーナーで取り上げていただいてから、国内外からのフィードバックや利用報告を徐々にいただけるようになってきたという状況です。

本書の読者はある程度 Scala の知識をお持ちの方を想定しています。前提となる知識について簡単な説明を入れるようには心がけましたが、必要に応じて各種ドキュメントや他の書籍などをあたってください。

本書が ScalikeJDBC に関心を持ってくださった方のお役に立てれば幸いです。

2013 年 1 月 瀬良 和弘 (Kazuhiro Sera [@seratch](http://seratch.net/))


# version 2 対応に添えて

ScalikeJDBC の最初のバージョンを GitHub に公開したのは調べてみると 2011 年 11 月 18 日のことでした。この commit です。

https://github.com/scalikejdbc/scalikejdbc/commit/7dee733278b059969147bba997db0c64512094ba

Scala のバージョンは 2.9.1 で String Interpolation がまだなかった時代でした。今では Scala といえばというくらい有名になった Play Framework 2.x もまだ公開されていない時期です。

当時の ScalikeJDBC は MySQL にしか対応していなかった Querulous という Twitter 社の DB ライブラリを参考に作られたものでした。コードベースは今よりもはるかに素朴なものですが DBSession の API はこの時点で今と変わらないものです。

そこから 3 年が経ち GitHub スター数では Querulous をはるかに上回り、多くの Scala ディベロッパーに利用いただいているライブラリに成長させることができました。
これも多くのフィードバックをしてくださった国内外のディベロッパーの皆様のおかげです。

今回、この Cookbook を ScalikeJDBC 2.2.0 に対応させるために更新しました。ScalikeJDBC をご利用いただいている皆様のお役に立てれば幸いです。

2014 年 11 月 瀬良 和弘 (Kazuhiro Sera [@seratch](http://seratch.net/))

