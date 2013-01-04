# 6. 一般的な利用のサンプル例

　このセクションでは、ScalikeJDBC を使ったよくある実装のサンプルを例示します。

## Select

### PK 検索

　PK 検索では、0 件または 1 件の結果がヒットすることが想定されます。このような場合は Option 型で結果が取得できるのが自然です。ScalikeJDBC は #single という指定で Option 型の結果が返ります。2 件以上ヒットした場合は例外を throw します。

```
val member: Option[Member] = DB readOnly { implicit s =>
  SQL("select * from members where id = ?").bind(id).map(*).single.apply()
}
```

### 件数取得

　count の結果は #single で取得して Some#get() で取り出します。

```
val count: Long = DB readOnly { implicit s =>
  SQL("select count(1) from members").map(rs => rs.long(1)).single.apply().get()
}
```

### 複数件取得

　結果が複数件あるときは #list を指定します。

```
val members: List[Member] = DB readOnly { implicit s =>
  SQL("select * from members limit 10").map(*).list.apply()
}
```

　複数行から最初の 1 行だけ取得する場合は #first を指定します。存在しない可能性があるので Option 型で返ります。

```
val members: Option[Member] = DB readOnly { implicit s =>
  SQL("select * from members where group = ?")
    .bind("Engineers").map(*).first.apply()
}
```

### 巨大な結果に対する操作

　巨大な検索結果に対して一度に全体を読み込まず、1 行ずつ読み込んではそれぞれに対して何らかの処理をしたい場合は #foreach メソッドを使います。

```
DB readOnly { implicit s =>
  SQL("select * from members") foreach { rs =>
    output.write(rs.long("id") + "," + rs.string("name") + "\n")
  }
}
```

### in 句

　in 句をサポートする特別な構文はありません。以下のように SQL を組み立てて対応してください。これには通常の JDBC の SQL テンプレートが適しているかもしれません。

```
val members = DB readOnly { implicit s => 
  val * = (rs: WrappedResultSet) => Member(rs.long("id"), rs.string("name"))
  val memberIds = List(1, 2, 3)
  val query = "select * from members where id in (%s)".format(memberIds.map(_ => "?").mkString(","))
  SQL(query).bind(memberIds: _*).map(*).list.apply()
}
```

### ジョインクエリ

　ScalikeJDBC には O/R マッパーのようにジョインクエリを生成してくれるような機能はありません。ジョインしたクエリの ResultSet からマッピングする処理を適切に定義する必要があります。

　しかし、カラム数の多いテーブル同士をジョインする場合はさすがに手作業で SQL やマッピングを書くのはなかなか厳しいものがあります。そういうケースではぜひ [mapper-generator](https://github.com/seratch/scalikejdbc/tree/master/scalikejdbc-mapper-generator) を活用してください。mapper-generator は DB からリバースエンジニアリングしてソースコードを生成する sbt プラグインです。

　mapper-generator の使い方は後で詳しく触れるのでここでは割愛し、実際に生成されるコードについてのみ説明します。

　たとえば、このようなテーブルがあるとして

```
create table members (
  id int generated always as identity,
  name varchar(30) not null,
  member_group_id int,
  description varchar(1000),
  created_at timestamp not null,
  primary key(id)
)
```

　「sbt "scalikejdbc-gen members Member"」を実行すると以下のようなコードが生成されます（ここでの説明に不要な箇所は省略しています）。

```
import scalikejdbc._
import org.joda.time._

case class Member(
  id: Int,
  name: String,
  memberGroupId: Option[Int] = None,
  description: Option[String] = None,
  createdAt: DateTime)

object Member {

  val tableName = "MEMBERS"

  object columnNames {
    val id = "ID"
    val name = "NAME"
    val memberGroupId = "MEMBER_GROUP_ID"
    val description = "DESCRIPTION"
    val createdAt = "CREATED_AT"
    val all = Seq(id, name, memberGroupId, description, createdAt)
  }

  val * = {
    import columnNames._
    (rs: WrappedResultSet) => Member(
      id = rs.int(id),
      name = rs.string(name),
      memberGroupId = rs.intOpt(memberGroupId),
      description = rs.stringOpt(description),
      createdAt = rs.timestamp(createdAt).toDateTime)
  }

  object joinedColumnNames {
    val delimiter = "__ON__"
    def as(name: String) = name + delimiter + tableName
    val id = as(columnNames.id)
    val name = as(columnNames.name)
    val memberGroupId = as(columnNames.memberGroupId)
    val description = as(columnNames.description)
    val createdAt = as(columnNames.createdAt)
    val all = Seq(id, name, memberGroupId, description, createdAt)
    val inSQL = columnNames.all.map(name => tableName + "." + name + " AS " + as(name)).mkString(", ")
  }

  val joined = {
    import joinedColumnNames._
    (rs: WrappedResultSet) => Member(
      id = rs.int(id),
      name = rs.string(name),
      memberGroupId = rs.intOpt(memberGroupId),
      description = rs.stringOpt(description),
      createdAt = rs.timestamp(createdAt).toDateTime)
  }

}
```

　通常のクエリは

```
SQL("select * from members limit 10").map(Member.*).list.apply()
```

もう少し丁寧にやるならば

```
SQL("select " + columnNames.all.mkString(",") + " from members limit 10").map(Member.*).list.apply()
```

のような形で OK ですが join の場合は他のテーブルのカラムも混ざってくるのでそうもいきません。

　しかし Member オブジェクト、MemberGroup オブジェクトにそれぞれ上記のようなコードが生成されていれば、このように対応させることができます。

```
val memberAndGroup: (Member, Option[MemberGroup]) = DB readOnly { implicit s =>
  SQL("select " 
    + Member.joinedColumnNames.inSQL + ", " 
    + MemberGroup.joinedColumnnames.inSQL + 
    """ from 
      members left join member_groups
      on mebers.member_group_id = member_groups.id
    where members.id = {id} """)
    .bindByName('id -> 123)
    .map { rs => 
      val member: Member = Member.joined(rs)
      val group: Option[MemberGroup] = rs.longOpt(MemberGroup.joinedColumnNames.id)
        .map(id => MemberGroup.joined(rs)) 
      (member, group)
    }.list.apply()
}
```

　この例では Tuple を返していますが、Member クラスに Option[MemberGroup] をフィールドとして持たせて copy メソッドで group を設定するようにしてもよいかと思います。

　mapper-generator 自体については、別のセクションでより詳細に解説します。ここでは left join query を例に結果をどのようにマッピングするかの一例を示しました。


## Insert

　ScalikeJDBC では nullable な値を考慮して Option 型をバインド引数として受け入れます。また、java.sql.* の型を利用するよりも Joda Time の DateTime や LocalDate といったクラスを使用することを推奨します。これらの型の値はそのままバインド引数として渡すことが可能です。

```
DB autoCommit { implicit s =>
  SQL("insert into members values ({name}, {memo}, {createdAt})")
    .bindByName(
      'name -> "Alice",
      'memo -> Some("Wonderland")
      'createdAt -> org.joda.DateTime.now
    ).update.apply()
}
```

　サポートされていない型の場合はそのまま java.lang.Object として JDBC ドライバーに渡します。1.4.3 の時点で拡張ポイントは提供していないので、もしまだ対応されていない型で対応すべき型があれば、GitHub での issue 登録、pull request をお待ちしております。

### auto-increment な id を取得する

　auto-increment な PK を扱うには #updateAndReturnGeneratedKey を指定します。auto-increment な PK の値が Long 型で返ります。

```
val id = DB localTx { implicit s =>
  SQL("insert into members values ({name}, {createdAt})")
    .bindByName(
      'name -> "Alice",
      'createdAt -> org.joda.DateTime.now
    ).updateAndReturnGeneratedKey.apply()
}
val createdMember = Member(id = id, name = name, createdAt = createdAt)
```

## Update

　insert と何ら変わりません。#update を指定します。

```
DB localTx { implicit s =>
  SQL("update members set name = {newName} where name = {name}")
    .bindByName('name -> "Bob", 'newName -> "Bobby")
    .update.apply()
}
```

## Delete

　こちらも insert と同様に #update を指定します。

```
DB localTx { implicit s =>
  SQL("delete from members where id = {id}")
    .bindByName('id -> 123).update.apply()
}
```

## Batch

　バッチ処理では #batch、#batchByName を使用し、バインド引数のリストを実行数分だけ一括で渡します。ある程度の件数以上であれば大きくパフォーマンスが変わってくるので、大量の更新処理などではこちらを使うことをおすすめします。

#batch は通常の JDBC の SQL テンプレートに対して Seq[Any] を実行数分渡すためのメソッドです。

```
val params: Seq[Seq[Any]] = (1 to 1000).map(i => Seq(i, "user_" + i))
SQL("insert into members values (?, ?)").batch(params: _*).apply()
```

　#batchByName は 名前付き SQL テンプレート、または実行可能な SQL テンプレートに Seq[(Symbol, Any)] を実行数分渡すためのメソッドです。

```
val params: Seq[Seq[(Symbol, Any)]] = (1 to 1000).map(i => Seq('id -> i, 'name -> "user_" + i))
SQL("insert into members values ({id}, {name})").batchByName(params: _*).apply()
```


