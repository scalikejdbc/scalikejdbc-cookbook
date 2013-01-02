# 4. DB ブロックとトランザクション

## DB ブロックの種類

　ScalikeJDBC には 4 種類の DB ブロックがあります。

### readOnly

　リードオンリーモードで実行します。select 文以外はすべて実行時に例外が発生します。

```
val count: Long = DB readOnly { implicit session =>
  SQL("select count(1) from members").map(_.long(1)).single.apply().get
}

// java.sql.SQLException が発生する
DB readOnly { implicit session =>
  SQL("update members set name = ? where id = ?").bind("Alice", 1).update.apply()
}
```

　デフォルトでないデータソースの場合は以下のように記述します。

```
val name: Option[String] = NamedDB('legacydb) readOnly { implicit session =>
  SQL("select name from members where id = ?").bind(id).map(_.string("name")).single.apply()
}
```

　自分でリソースの close まで面倒を見る必要がありますが DBSession を取り出して値として使用することもできます。

```
// DBSession 型の暗黙のパラメータとしてリードオンリーなセッションを取得
implicit val session: DBSession = DB.readOnlySession

try {
  val names: List[String] = SQL("select * from members").map(_.string("name")).list.apply()
} finally { 
  session.close()
}
```

### autoCommit

　クエリや更新をオートコミットモードで実行します。

```
val count = DB autoCommit { implicit session =>
  val updateMembers = SQL("update members set name = ? where id = ?")

  updateMembers.bind("Alice", 1).update.apply() // auto-commit
  updateMembers.bind("Bob", 2).update.apply() // auto-commit
}

NamedDB('yetanother) autoCommit { implicit session =>
  SQL("insert into events values (?, ?, ?)")
   .bind(12345, "Click", "{'user_id': 345, 'url': 'http://www.example.com/xxx'}").update.apply()
}
```

　readOnlySession と同様に autoCommitSession もあります。

```
implicit val session: DBSession = DB.autoCommitSession()
implicit val session: DBSession = NamedDB('yetanother).autoCommitSession()
```

### localTx

　クエリや更新をブロックのスコープに閉じた同一トランザクションで実行します。ブロック内で例外が throw された場合、自動的にトランザクションはロールバックされます。

```
val count = DB localTx { implicit session =>
  // トランザクション開始

  val updateMembers = SQL("update members set name = ? where id = ?")

  updateMembers.bind("Alice", 1).update.apply() 
  updateMembers.bind("Bob", 2).update.apply() 

  // トランザクション終了
} 
// 途中で例外が発生したらすべてロールバックされる

NamedDB('yetanother) localTx { implicit session =>
  SQL("insert into events ..").bind(...).update.apply()
}
```

　localTx はトランザクションのスコープを明示するものなので DBSession を取り出して値として利用することはできません。


### withinTx

　クエリや更新を既に存在しているトランザクション内で実行します。トランザクションについての操作はすべてライブラリ利用者によって制御される必要があります。

```
using(DB(ConnectionPool.borrow())) { db =>
  try {
    db.begin() // トランザクションの開始

    val names = DB withinTx { implicit session => 
      // トランザクションが開始されていない場合 IllegalStateException が throw される
      SQL("select name from members").map(_.string("name")).list.apply()
    }

    db.commit() // トランザクションをコミット
  } catch { case e: Exception =>
    db.rollback() // 例外が throw される可能性がある
    db.rollbackIfActive() // 例外が throw される可能性はない
    throw e
  }
} 
```

## 自動セッションを活用したトランザクション管理

　ScalikeJDBC には AutoSession、NamedAutoSession というオブジェクト、クラスがあります。これらの活用方法について解説します。

　まず、以下のような insert 処理があるとします。

```
object Member {
  def create(name: String, birthday: Option[LocalDate]): Member = {
    val createdAt = DateTime.now
    val id: Long = DB localTx { implicit session =>
      SQL("insert into members (name, birthday, created_at) values (?, ?, ?)")
        .bind(name, birthday, createdAt)
        .updateAndReturnGeneratedKey.apply()
    }
    new Member(id = id, name = name, birthday = birthday, createdAt = createdAt)
  }
}

val alice: Memebr = Member.create("Alice", None)
```

　これはこれで正常に動作はしますが、この create メソッドの中でトランザクションが閉じてしまっています。

　例えば、以下のような処理を書いた場合に NotFoundException が throw されても Member.create はロールバックされません。これは意図する挙動ではないはずです。

```
DB localTx { implicit session =>
  val member = Member.create("Alice", None)
  Group.findByName("Japan Scala Users Group") map { group =>
    GroupMember.create(group.id, member.id)
  } orElse {
    throw new NotFoundException
    // Member.create は別トランザクションでコミット済、ロールバックされない
  }
}
```

　そこで Member.create を暗黙のパラメータとして DBSession 型を受け取るよう書き換えます。メソッドの中で DB ブロックがなくなりましたが DBSession を暗黙のパラメータとして受け取って SQL を発行するようになりました。

```
object Member {

  def create(name: String, birthday: Option[LocalDate])(implicit session: DBSession): Member = {

    val createdAt = DateTime.now
    val id: Long = SQL("insert into members (name, birthday, created_at) values (?, ?, ?)")
      .bind(name, birthday, createdAt)
      .updateAndReturnGeneratedKey.apply()
    new Member(id = id, name = name, birthday = birthday, createdAt = createdAt)
  }
}
```

　これで外側で有効になっていた暗黙のパラメータとしての DBSession 型を受け取ることができるようになるので、同一トランザクションで処理ができるようになります。

```
DB localTx { implicit session =>
  val member = Member.create("Alice", None) // 同一トランザクションで処理
  Group.findByName("Japan Scala Users Group") map { group =>
    GroupMember.create(group.id, member.id)
  } orElse {
    throw new NotFoundException
    // Member.create がロールバックされる
  }
}
```

　しかし、まだ問題が残っています。このままだと Member.create 単体で実行ができないので、必ず DB ブロックで囲む必要があります。

```
scala> Member.create("Chris", None)
<console>:18: error: could not find implicit value for parameter session: scalikejdbc.DBSession
              Member.create("Chris", None)
                           ^

scala> DB autoCommit { implicit session =>
     |   Member.create("Chris", None)
     | }
res5: Member = Member(3,Chris,None,None,2012-12-31T11:37:40.349+09:00)
```

　この問題への解が AutoSession です。Member.create をさらに以下のように書き換えて暗黙のパラメータのデフォルト値に AutoSession オブジェクトを指定します。

```
object Member {

  def create(name: String, birthday: Option[LocalDate])
    (implicit session: DBSession = AutoSession): Member = {

    // 処理内容は同様
  }
}
```

　これで DB ブロックなしで Member.create を呼び出すことができるようになりました。

```
scala> Member.create("Chris", None)
res5: Member = Member(3,Chris,None,None,2012-12-31T11:37:40.349+09:00)
```

　AutoSession は、select 文の場合は read-only、更新系の場合は auto-commit として新しいセッションをスタートして実行します。AutoSession はあくまでデフォルト値なので、もし外部から DBSession が渡された場合はそちらが優先されます。

　NamedDB の場合は NamedAutoSession(name) で同じように自動セッションを利用できます。

```
def create(name: String)(implicit session: DBSession = NamedDBSession('another)) = {
  // ...
}
```

DB からソースコードを自動生成する mapper-generator（後述）は、この AutoSession を使用するソースコードを生成します。

以上、DB ブロックとトランザクション管理について解説しました。


