# 12. Skinny ORM

2013 年から開発が始まった Skinny Framework というフルスタック Web フレームワークのコンポーネントとして Skinny ORM という ORM を筆者を中心としたチームでメンテナンスしています。

この Skinny ORM は ScalikeJDBC をベースにした Ruby on Rails の ActiveRecord ライブラリに似た ORM です。ActiveRecord と同様に Skinny Framework を使っていないアプリケーションでも ORM だけを単体で利用できるようになっています。

http://skinny-framework.org/documentation/orm.html

ScalikeJDBC の API を直接使うこともできるので SQL をベースにした柔軟性とほぼボイラープレートな CRUD 処理を簡略化させたいというニーズの両方を満たすことができます。

ここでは ScalikeJDBC と Skinny ORM を使った開発について紹介いたします。

## ライブラリを追加

    libraryDependencies ++= Seq(
      "org.skinny-framework" %% "skinny-orm"      % "2.0.+",
      "com.h2database"       %  "h2"              % "1.4.+",
      "ch.qos.logback"       %  "logback-classic" % "1.2.+"
    )

## SkinnyCRUDMapper

Skinny ORM でよく使うベース trait は SkinnyCRUDMapper です。これは一つのテーブルに対して insert/select/update/delete の処理を行うための土台です。

SkinnyCRUDMapper だけでなく Skinny ORM の *Mapper trait は ScalikeJDBC の SQLSyntaxSupport を継承しているので SQLSyntaxSupport の使い方を知っている方であればすぐに使うことができるはずです。

    import scalikejdbc._
    import skinny.orm._
    import org.joda.time._

    case class Member(id: Long, name: Option[String], createdAt: DateTime)
    object Member extends SkinnyMapper[Member] {
      override lazy val defaultAlias = createAlias("m")
      override def extract(rs: WrappedResultSet, n: ResultName[Member]): Member = autoConstruct(rs, n)
    }

これだけで以下のようなメソッドが使えます。

    // Create
    Member.createWithAttributes('name -> "Alice", 'createdAt -> DateTime.now)
    // Read
    val member: Option[Member] = Member.findById(123)
    val members: Seq[Member] = Member.where('name -> "Alice").apply()
    // Update
    Member.updateById(123).withAttributes('name -> "Bob")
    Member.updateBy(sqls.eq(Member.column.name, "Bob")).withAttributes('name -> "Bob")
    // Delete
    Member.deleteById(123)
    Member.deleteBy(sqls.eq(Member.column.name, "Alice"))

ScalikeJDBC の API もそのまま使えます。

    object Member extends SkinnyMapper[Member] {
      override lazy val defaultAlias = createAlias("m")
      override def extract(rs: WrappedResultSet, n: ResultName[Member]): Member = autoConstruct(rs, n)

      def findByName(name: String): Seq[Member] = {
        val m = defaultAlias
        findAllBy {
          // SQLSyntax を渡すと where 句として使ってくれる
          sqls.eq(m.name, name)
            .and
            .isNotNull(m.createdAt)
        }
      }
    }

ORM なので関連の解決など豊富な機能を提供しています。ここでは導入の紹介のみにとどめますので、詳しくは公式サイトのドキュメントをご覧ください。

http://skinny-framework.org/documentation/orm.html
