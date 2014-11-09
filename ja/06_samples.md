# 6. 一般的な利用のサンプル例

このセクションでは、ScalikeJDBC を使ったよくある実装のサンプルを例示します。

## Select

### PK 検索

PK 検索では、0 件または 1 件の結果がヒットすることが想定されます。このような場合は Option 型で結果が取得できるのが自然です。ScalikeJDBC は #single という指定で Option 型の結果が返ります。2 件以上ヒットした場合は例外を throw します。

    val id = 12345
    val * = (rs: WrappedResultSet) => Member(rs.long("id"), rs.string("name"))
    val member: Option[Member] = DB readOnly { implicit s =>
      sql"select * from members where id = ${id}".map(*).single.apply()
    }

### 件数取得

count の結果は #single で取得して Some#get() で取り出します。

    val count: Long = DB readOnly { implicit s =>
      sql"select count(1) from members".map(_.long(1)).single.apply().get()
    }

### 複数件取得

結果が複数件あるときは #list を指定します。

    val members: List[Member] = DB readOnly { implicit s =>
      sql"select * from members limit 10".map(*).list.apply()
    }

複数行から最初の 1 行だけ取得する場合は #first を指定します。存在しない可能性があるので Option 型で返ります。

    val members: Option[Member] = DB readOnly { implicit s =>
      sql"select * from members where group = ${"Engineers"}".map(*).first.apply()
    }

### 巨大な結果に対する操作

巨大な検索結果に対して一度に全体を読み込まず、1 行ずつ読み込んではそれぞれに対して何らかの処理をしたい場合は #foreach メソッドを使います。

    DB readOnly { implicit s =>
      sql"select * from members".foreach { rs =>
        output.write(rs.long("id") + "," + rs.string("name") + "\n")
      }
    }

### in 句

SQLInterpolation は Seq でパラメータを受け取ることができます。

    val members = DB readOnly { implicit s =>
      val memberIds = List(1, 2, 3)
      sql"select * from members where id in (${memberIds})".map(*).list.apply()
    }

従来の SQL 構文では in 句をサポートする特別な構文はありません。以下のように SQL を組み立てて対応してください。

    val members = DB readOnly { implicit s => 
      val * = (rs: WrappedResultSet) => Member(rs.long("id"), rs.string("name"))
      val memberIds = List(1, 2, 3)
      val query = "select * from members where id in (%s)".format(memberIds.map(_ => "?").mkString(","))
      SQL(query).bind(memberIds: _*).map(*).list.apply()
    }

### join クエリ

すべて生の SQL を書いているとジョインクエリを書くのはなかなか骨の折れる作業になります。

元々存在する SQL があればそれを引き継いで組み込むのも現実かと思いますが、新しいプログラムであればなるべくメンテナンスしやすいものにしたいところです。

前のセクションで SQLInterpolation に SQLSyntaxSupport という機能を紹介しましたが join クエリを多く書く場合はぜひこれを活用してください。

### Joda Time ではなく Java SE 8 の Date Time API を使う

ScalikeJDBC は Java SE 7 のサポートも続けているので、拡張用の別のライブラリとして Date Time API をサポートしています。以下の通りライブラリを追加します。

    libraryDependencies += "org.scalikejdbc" %% "scalikejdbc-jsr310" % "2.2.+"

使い方は以下のようになります。`import scalikejdbc.jsr310._` を追加するだけですね。

    import scalikejdbc._, jsr310._
    import java.time._
                                    
    case class Group(id: Long, name: Option[String], createdAt: ZonedDateTime)
    object Group extends SQLSyntaxSupport[Group] {
      def apply(g: SyntaxProvider[Group])(rs: WrappedResultSet): Group = apply(g.resultName)(rs)
      def apply(g: ResultName[Group])(rs: WrappedResultSet): Group = Group(rs.get(g.id), rs.get(g.name), rs.get(g.createdAt))
    }

## Insert

ScalikeJDBC では nullable な値を考慮して Option 型をバインド引数として受け入れます。また、java.sql.* の型を利用するよりも Joda Time の DateTime や LocalDate といったクラスや Java SE 8 の Date Time API を使用することを推奨します。これらの型の値はそのままバインド引数として渡すことが可能です。

    DB autoCommit { implicit s =>
      val (name, memo, createdAt) = ("Alice", Some("Wonderland"), org.joda.DateTime.now)
      sql"insert into members values (${name}, ${memo}, ${createdAt})")
        .update.apply()
    }

サポートされていない型の場合はそのまま java.lang.Object として JDBC ドライバーに渡しますが、それだと困るというケースも多いかと思います。その場合は ParameterBinder を指定することで対応できます。

    val bytes = Array[Byte](1,2,3, ...)
    val in = ByteArrayInputStream(bytes)
    val bin = ParameterBinder(
      value = in,
      binder = (stmt, idx) => stmt.setBinaryStream(idx, in, bytes.length)
    )
    sql"insert into table (bin) values (${bin})".update.apply()

### auto-increment な id を取得する

auto-increment な PK を扱うには #updateAndReturnGeneratedKey を指定します。auto-increment な PK の値が Long 型で返ります。

    val id = DB localTx { implicit s =>
      val (name, createdAt) = ("Alice", org.joda.DateTime.now)
      sql"insert into members values (${name}, ${createdAt})"
        .updateAndReturnGeneratedKey.apply()
    }
    val createdMember = Member(id = id, name = name, createdAt = createdAt)

## Update

insert と何ら変わりません。#update を指定します。

    val (name, newName) = ("Bob", "Bobby")
    DB localTx { implicit s =>
      sql"update members set name = ${newName} where name = ${name}"
        .update.apply()
    }

## Delete

こちらも insert と同様に #update を指定します。

    val id = 1234
    DB localTx { implicit s =>
      sql"delete from members where id = ${id}".update.apply()
    }

## Batch

バッチ処理では #batch、#batchByName を使用し、バインド引数のリストを実行数分だけ一括で渡します。ある程度の件数以上であれば大きくパフォーマンスが変わってくるので、大量の更新処理などではこちらを使うことをおすすめします。

batch は通常の JDBC の SQL テンプレートに対して Seq[Any] を実行数分渡すためのメソッドです。

    val params: Seq[Seq[Any]] = (1 to 1000).map(i => Seq(i, "user_" + i))
    SQL("insert into members values (?, ?)").batch(params: _*).apply()

batchByName は 名前付き SQL テンプレート、または実行可能な SQL テンプレートに Seq[(Symbol, Any)] を実行数分渡すためのメソッドです。

    val params: Seq[Seq[(Symbol, Any)]] = (1 to 1000).map(i => Seq('id -> i, 'name -> "user_" + i))
    SQL("insert into members values ({id}, {name})").batchByName(params: _*).apply()


