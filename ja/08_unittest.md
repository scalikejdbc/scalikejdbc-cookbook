# 8. ユニットテスト

　このセクションでは、ScalikeJDBC を使ったプログラムのテストの例を示します。

## 接続情報

　ConnectionPool を設定する trait を用意して mixin する方法があります。複数のデータソースを使用する場合にも ConnectionPool.add(...) を使用して同様に設定すれば OK です。

　もちろん Web アプリケーションの開発などフレームワーク側で設定を読み込む仕組みがある場合はそれに従うのがスムーズかと思います。

```
trait TestDBSettings {

  def loadJDBCSettings() {
    // https://github.com/typesafehub/config
    val config = ConfigFactory.load()
    val url = config.getString("jdbc.url")
    val user = config.getString("jdbc.user")
    val password = config.getString("jdbc.password")
    ConnectionPool.singleton(url, user, password)
  }

  loadJDBCSettings()

}

import org.specs2.mutable._

object MemberSpec extends Specification with TestDBSettings {

  "Member" should {
    "create new record" in {
      val created = Member.create("Alice", None, DateTime.now)
      created should not beNull
    }
  }

}
```

## 自動ロールバック

　例えば、このように暗黙のパラメータとして DBSession を外部から受け取れるコードになっていれば

```
def create(name: String, memo: Option[String] = None)
  (implicit session: DBSession = AutoSession): Member = {
  val createdAt = DateTime.now
  val id = SQL("insert into members values (?, ?, ?)")
    .bind(name, memo, createdAt).updateAndReturnGeneratedKey.apply()
  Member(id, name, memo, createdAt)
}
```

　このようにテスト終了時に自動ロールバックさせることが可能です。

```
using(DB(ConnectionPool.borrow())) { db =>
  try {
    db.begin()
    DB withinTx { implicit session =>

     // テスト対象の処理
     val created = Member.create("Alice", None)
     // ....

    }
  } finally {
    db.rollbackIfActive()
  }
}
```

　1.4.1 の時点では ScalikeJDBC 標準でこのような自動ロールバックの仕組みを提供していませんが、将来のバージョンで ScalaTest、specs2 あたりのテストフレームワークとの連携を強化したいと考えています。


## ConnectionPoolContext の紹介

　ConnectionPoolContext という動的に DB の向き先を切り替えることができる機能があります。暗黙のパラメータによって一時的に ConnectionPool の向き先を切り替えることができます。

　例えば、以下のメソッドがテスト対象であるとします。

```
object Member {
  def countAll()(implicit session: DBSession = AutoSession
    context: ConnectionPoolContext = NoConnectionPoolContext): Long = {
    SQL("select count(1) c from members").map(rs => rs.long("c")).single.apply.get
  }
}
```

　以下の例は、このテストケースだけは共通の DB 接続設定ではなく H2 のメモリ DB を使用するようにしているサンプルです。

```
import org.scalatest._
import org.scalatest.matchers._

class CPContextWithAutoSessionSpec extends FlatSpec with ShouldMatchers with DBSettings {

  behavior of "Member with in-memory DB"

  it should "count all" in {

    Class.forName("org.h2.Driver")

    implicit val context: ConnectionPoolContext = new MultipleConnectionPoolContext(
      ConnectionPoolContext.DEFAULT_NAME -> CommonsConnectionPoolFactory.apply("jdbc:h2:mem:test", "", "")
    )
    // ConnectionPoolContext が有効化されたので
    // これ以降は H2 の memory DB にアクセスする
 
    DB localTx { implicit session =>
      SQL("create table members (id bigint primary key, name varchar(256), created_at timestamp not null);").execute.apply()
      (1 to 1000) foreach { i =>
        SQL("insert into users values (?,?,?)").bind(i, "user%05d".format(i), DateTime.now).update.apply()
      }
    }

    Member.countAll() should equal(1000L)

    // ConnectionPoolContext ここまで
  }
}
```

　注意点として ConnectionPoolContext を使用するためには、テスト対象のメソッドが暗黙のパラメータとして ConnectionPoolContext を受け取るようになっていなければなりません。そうなっていない場合は暗黙のパラメータに追加する必要があります。


## mapper-generator によるテストの自動生成

　次のセクションで詳しく紹介する mapper-generator は、ソースコードの生成時にそれに対応するテストコードも自動生成してくれます。ScalaTest、specs2 からひな形を選択できるので、お好きなテンプレートを指定してください。


