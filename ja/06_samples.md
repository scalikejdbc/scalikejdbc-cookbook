# 6. 一般的な利用のサンプル例

このセクションでは、ScalikeJDBC を使ったよくある実装のサンプルを例示します。

## Select

### PK 検索

PK 検索では、0 件または 1 件の結果がヒットすることが想定されます。このような場合は Option 型で結果が取得できるのが自然です。ScalikeJDBC は #single という指定で Option 型の結果が返ります。2 件以上ヒットした場合は例外を throw します。

    val id = 12345
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
      val * = (rs: WrappedResultSet) => Member(rs.long("id"), rs.string("name"))
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

### ジョインクエリ

すべて生の SQL を書いているとジョインクエリを書くのはなかなか骨の折れる作業になります。

元々存在する SQL があればそれを引き継いで組み込むのも現実かと思いますが、新しいプログラムであればなるべくメンテナンスしやすいものにしたいところです。

SQLInterpolation に SQLSyntaxSupport というジョインクエリを書く場合に強力な機能がありますので、これを紹介します。

まず、ベタに SQL を書くとこのようになるケースを考えます。

    case class Member(id: Long, teamId: Long)
    case class Team(id: Long, name: String)

    val membersWithTeam: List[(Member, Team)] = sql"""
      select m.id as m_id, m.team_id as m_tid, t.id as t_id, t.name as t_name
      from member m inner join team t on m.team_id = t.id
    """
      .map(rs => (Member(rs.long("m_id"), rs.long("m_tid")), Team(rs.long("t_id"), rs.string("t_name"))))
      .list.apply()

これを SQLSyntaxSupport を使うと以下のようになります。

    case class Member(id: Long, teamId: Long)
    case class Team(id: Long, name: String)

    object Member extends SQLSyntaxSupport[Member] {
      def apply(m: ResultName[Member])(implicit rs: WrappedResultSet): Member = {
        new Member(id = rs.long(m.id), teamId = rs.long(m.teamId))
      }
    }
    object Team extends SQLSyntaxSupport[Team] {
      def apply(m: ResultName[Team])(implicit rs: WrappedResultSet): Team = { 
        new Team(id = rs.long(m.id), name = rs.long(m.name))
      }
    }

上記のような定義をしておけば以下のようにクエリを書くことができます。

    val (m, t) = (Member.syntax("m"), Team.syntax("t"))
    val membersWithTeam: List[(Member, Team)] = sql"""
      select ${m.result.*}, ${t.result.*}
      from ${Member.as(m)} inner join ${Team.as(t)} on ${m.teamId} = ${t.id}
    """
      .map(implicit rs => (Member(m.resultName), Team(t.resultName)))
      .list.apply()

JPQL をご存知の方は何となく見た目が似ている印象をお持ちになるかもしれませんが、JPQL とは違って埋め込んでいるフィールドなどはすべてコンパイルチェック対象になりますし、埋め込んでいる部分は文字列として展開されるだけなので SQL 以外の独自文法は存在していません。

以下のルールを把握するだけです。

- m.teamId は m.team_id に展開されます
- m.resut.teamId は m.team_id as ti_on_m に展開されます
- m.resultName.teamId は ti_on_m に展開されます

よって実際の SQL は以下のようになります。

    select m.id as i_on_m, m.team_id as ti_on_m, t.id as i_on_t, t.name as n_on_t
    from member as m inner join team as t on m.team_id = t.id

実際、コンパニオンオブジェクトの定義などパッと見のコード量は増えているように思われる方もあるかもしれませんが

- 文字列指定がなくなってタイプセーフになった
- apply を一度定義するとマッピング処理はどんなジョインクエリでも再利用できる

という利点があります。実際に使ってみていただければ実感いただけるかと思います。

なお、Scala 2.10.1 時点で Scala の runtime reflection API にスレッドセーフでないという問題（SI-6240）があるため 1.5.1 時点ではまだリリースできていないのですが、この apply メソッドも自動生成が可能なので、将来的には基本の apply メソッドは手書きしなくてもすむようになる予定です（導入は scalikejdbc-interpolation 1.6 以降になる見込みです）。


## Insert

ScalikeJDBC では nullable な値を考慮して Option 型をバインド引数として受け入れます。また、java.sql.* の型を利用するよりも Joda Time の DateTime や LocalDate といったクラスを使用することを推奨します。これらの型の値はそのままバインド引数として渡すことが可能です。

    DB autoCommit { implicit s =>
      val (name, memo, createdAt) = ("Alice", Some("Wonderland"), org.joda.DateTime.now)
      sql"insert into members values (${name}, ${memo}, ${createdAt})")
        .update.apply()
    }

サポートされていない型の場合はそのまま java.lang.Object として JDBC ドライバーに渡します。1.4.3 の時点で拡張ポイントは提供していないので、もしまだ対応されていない型で対応すべき型があれば、GitHub での issue 登録、pull request をお待ちしております。

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
      SQL("update members set name = ${newName} where name = ${name}")
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


