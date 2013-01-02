# 3. 接続設定とコネクション管理

## コネクションプールの設定と使用方法

　ConnectionPool というオブジェクトに JDBC の設定を渡します。JDBC ドライバーの読み込みは自動で行われないので Class.forName(String) を呼び出してください。

```
import scalikejdbc._
Class.forName("org.h2.Driver")
ConnectionPool.singleton("jdbc:h2:mem:db", "username", "password")
```

　これで DB への接続設定は終了です。この処理以降であれば以下のように DB に接続することができます。

```
val names: List[String] = DB readOnly { implicit session =>
  SQL("select name from members").map(rs => rs.string("name")).list.apply()
}
```

　なぜこれで接続設定が読み込まれるのでしょうか？それは DB.readOnly が内部的には以下のような処理をしているためです。

```
val names: List[String] = using(DB(ConnectionPool.borrow())) { db => 
  db.readOnly { implicit session => 
    SQL("select name from members").map(rs => rs.string("name")).list.apply()
  }
}
```

　毎回このような記述をしていては非常に冗長なので、上記のように DB.readOnly で書けるようになっているというわけです。

## 複数データソースへの接続

　ScalikeJDBC では、一つのアプリケーションから複数のデータソースに接続したいというニーズに以下のようにして対応します。第一引数でデータソースの名前を指定します。型は Any ですが Symbol で指定することを推奨します。

```
ConnectionPool.add('db1, "jdbc:xxx:db1", "user", "pass")
ConnectionPool.add('db2, "jdbc:xxx:db2", "user", "pass")
```

　使うときは「DB readOnly { implicit session => }」ではなく「NamedDB('db1) readOnly { implicit session => }」と記述します。

```
NamedDB('db1) readOnly { implicit session =>
  // ...
}

NamedDB('db2) readOnly { implicit session =>
  // ...
}
```

　上記の ConnectionPool.singleton(...) で指定されたデータソースには「'default」という名前がついています。別のデータソースにこの名前は使用できません。


## その他のオプション設定

　JDBC の url、ユーザ名、パスワード以外の設定は ConnectionPoolSettings を使ってカスタマイズすることができます。

```
ConnectionPool.singleton("jdbc:h2:mem:db", "", "", 
  new ConnectionPoolSettings(initialSize = 20, maxSize = 50))
```

　設定の一覧は以下の通りです



| キー | 内容 |
|:--|:--|
| initialSize | プールするコネクション数の最小値 |
| maxSize | プールするコネクション数の最大値 |
| validationQuery | 正常に接続できているか確認するための SQL |


## Commons DBCP 以外のコネクションプールを使う

　上記の ConnectionPool は [Commons DBCP](http://commons.apache.org/dbcp/) をコネクションプールの実装として使用しています。version 1.4.1 時点では標準ではこの実装のみを提供しています。

　別のコネクションプールの実装を使いたいという場合は以下のようにして拡張することができます。

```
class MyConnectionPoolFactory extends ConnectionPoolFactory {
  def apply(url: String, user: String, password: String, settings: ConnectionPoolSettings) = {
    new MyConnectionPool(url, user, password)
  }
}

ConnectionPool.add('xxxx, url, user, password)(new MyConnectionPoolFactory)
```


## スレッドローカルなコネクション

　スレッドローカルな値として DB クラスのインスタンスを使い回すことができます。DB インスタンスは java.sql.Connection を保持した値です。同じ DB インスタンスであれば同じコネクションを使用します。

```
def init() = {
  val newDB = ThreadLocalDB.create(conn)
  newDB.begin()
}
// init が呼び出された後で
def action() = {
  val db = ThreadLocalDB.load()
}
def finalize() = {
  try { ThreadLocalDB.load().close() } catch { case e: Exception => }
}
```

　以上、コネクション管理について説明しました。トランザクション管理については次のセクションで解説します。


