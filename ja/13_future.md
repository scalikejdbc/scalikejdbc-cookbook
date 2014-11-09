# 13. 今後と貢献

ScalikeJDBC は既に実績のあるライブラリですが、歴史としては 2011 年 11 月に開発が始まった若いライブラリです。これからも継続的に Scala の進化にあわせてよりよいライブラリになるよう努めたいと思っています。

同時に ScalikeJDBC はオープンソースソフトウェアでもあります。私の力だけでなく ScalikeJDBC に関心を持ってくださった開発者の皆様のお力もお借りできたなら、もっと優れたものになっていく期待もあります。

ここでは ScalikeJDBC の開発に関する情報、何らかの貢献をしていただくために必要な情報をお知らせいたします。


## ライセンス

Apache License, Version 2.0

[http://www.apache.org/licenses/LICENSE-2.0.html](http://www.apache.org/licenses/LICENSE-2.0.html)


## バージョニングポリシー

ScalikeJDBC のバージョニングポリシーは

「2.{メジャーバージョン}.{マイナーバージョン}」

というルールで運用しています。

あまりドラスティックな変更はしない方針ですが、メジャーバージョンアップは何らかの互換性を崩す変更を含みます。例えば @deprecated 指定されていたクラスやメソッドの削除、既存のメソッドのシグネチャ変更などです。互換性を崩す変更内容については必ずリリース時にアナウンスいたします。

マイナーバージョンアップは、バグ修正と比較的小規模な機能追加を含みます。こちらはある程度安心してバージョンアップしていただけるはずです。

なお、トップレベルの 1.x から 2.x は Scala 2.9 サポート打ち切りと Java8 対応のタイミングであげました。このような外部的な要因で大きな非互換を設けざるを得ないケースが発生すれば 3.x がでるかもしれませんが、今のところその予定はありません。

https://github.com/scalikejdbc/scalikejdbc/blob/develop/notes/2.0.0.markdown

また、1.x は現在もメンテナンスは続けています。3.x が出たとしても一定の間は 2.x へのバグフィックスなどはバックポートされます。


## 貢献するには

ScalikeJDBC は [GitHub](http://git.io/scalikejdbc) 上で開発されています。issue の登録、パッチの提供ともに GitHub の issue 管理、pull request で受け付けています。最低限は HSQLDB だけで動作確認、でも十分です。

GitHub 上では、日本以外のユーザの方のためにできる限り英語でのやり取りを希望しています（英語が上手かどうかはともかく！）。まずは日本語で、という場合はお気軽に Twitter 上やメールなどでまずはご連絡いただければと思います。

Twitter: [@seratch](http://twitter.com/seratch) / [@seratch_ja](http://twitter.com/seratch_ja)

メールアドレス: seratch _at_ gmail.com

また、本書の誤りや改善点があれば、ぜひともお知らせください。本書の内容は下記のプロジェクトで公開しております。issue 登録、pull request をお待ちしております。

[https://github.com/scalikejdbc/scalikejdbc-cookbook](https://github.com/scalikejdbc/scalikejdbc-cookbook)


## 最後に

本書を最後までお読みいただき、誠にありがとうございました。

ScalikeJDBC によるスムーズな DB アクセスをご活用いただければ幸いです。


