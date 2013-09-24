# 5. 4 種類の SQL テンプレート

ScalikeJDBC では以下の 4 種類の SQL テンプレートをサポートしています。

## JDBC の SQL テンプレート　

JDBC の通常のテンプレートです。プレースホルダは「?」で表現され、バインド変数は #bind(...) で順序通り渡されます。

    val now = DateTime.now
    SQL("""
      insert into members (id, name, memo, created_at, updated_at) 
      values (?, ?, ?, ?, ?)
      """)
      .bind(123, "Alice", None, now, now)

## 名前付き SQL テンプレート

名前付きプレースホルダを「{name}」の名前付きの形式で指定し、バインド変数は #bindByName(...) で (Symbol -> Any) を順不同で指定します。これは Play! Framework で提供されている Anorm という DB アクセスライブラリと同様の仕様です。

    SQL("""
      insert into members (id, name, memo, created_at, updated_at) 
      values ({id}, {name}, {memo}, {now}, {now})
      """)
      .bindByName(
        'id -> 123, 
        'name -> "Alice", 
        'memo -> None,
        'now -> DateTime.now
      )

## 実行可能な SQL テンプレート

名前付きプレースホルダを「/＊'name＊/dummy_value」の形式で指定し、バインド変数は #bindByName(...) で (Symbol -> Any) を順不同で指定します。この SQL テンプレートがそのまま SQL として実行可能であるという利点があります。

バインド変数の名前を SQL コメント内に Scala のシンボルリテラルで指定し、そのすぐ後にダミー値を添えます。日本で 2 Way SQL と呼ばれるものから着想して実装したものですが、2 Way SQL が備える条件分岐のシンタックスなどはサポートしていません。

    SQL("""
      insert into members (id, name, memo, created_at, updated_at) values (
        /*'id*/12345,
        /*'name*/'Alice', 
        /*'memo*/'memo', 
        /*'now*/'2001-01-02 00:00:00', 
        /*'now*/'2001-01-02 00:00:00')
      """)
      .bindByName(
        'id -> 123, 
        'name -> "Alice",
        'memo -> None,
        'now -> DateTime.now
      )


## SQL インターポレーション

Scala 2.10.0 から使えるようになった SIP-11 String Interpolation による新しい SQL テンプレートです。

1.6.7 時点では Scala 2.9.x サポート継続のために拡張機能として別の jar になっています。sbt の設定に以下を追加してください。読者が既に Scala 2.10.0 以降を使用している場合は scalaVersion の指定は不要です。

    scalaVersion := "2.10.2"
    
    libraryDependencies += "com.github.seratch" %% "scalikejdbc-interpolation" % "[1.6,)",

「${expression}」でパラメータとして式を埋め込みます。

    val now = DateTime.now
    sql"""
      insert into members (id, name, memo, created_at, updated_at) values 
      (${123}, ${"Alice"}, ${None}, ${now}, ${now})
    """.update.apply()

### SQLSyntax とそれ以外

SQLSyntax という型があり、この型で渡した部分はバインド引数として展開されずにそのまま SQL の一部として組み込まれます。

SQL インジェクション脆弱性を防止するため SQLSyntax のインスタンスは `sqls"..."` でのみ生成可能です。

    val ordering: SQLSyntax = if (isDesc) sqls"desc" else sqls"asc" // or SQLSyntax("desc")
    val id: Int = 1234

    val names = sql"select name from member where id = ${id} order by id ${ordering}"
                  .map(rs => rs.long("name").list.apply()

は、以下のような SQL として展開されます、

    select name from member where id = ? order by id desc

また in 句を想定して Seq の値だけはカンマ区切りに展開されるようになっています。

    val ids = Seq(1, 2, 3)
    val names = sql"select name from member where id in (${ids})"
                  .map(rs => rs.long("name").list.apply()

これは以下のように展開されます。

    select name from member where id in (?, ?, ?)

SQL インターポレーションのテンプレート部分については以上の内容を把握しておけば十分です。

### SQLSyntaxSupport

SQLSyntaxSupport という trait を使うと特に join クエリでの SQL インターポレーションをより効率よく扱う事ができます。

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

`#syntax(String)` で SyntaxProvider を返します。これはスレッドセーフなのでキャッシュして使い回す事ができます。この SyntaxProvider は型引数で渡された class のフィールド名を使って SQLSyntax に展開してくれます。

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

なお、Scala 2.10.3 時点で Scala の runtime reflection API にスレッドセーフでないという問題（SI-6240）があるため 1.6.7 時点ではまだリリースできていないのですが、この apply メソッドも自動生成が可能なので、将来的には基本の apply メソッドは手書きしなくてもすむようになる予定です（導入は scalikejdbc-interpolation 1.7 以降になる見込みです）。

デフォルトではテーブル名はコンパニオンオブジェクトの名前をアンダースコア区切りに変換（例: TeamMember -> team_member）し、カラム名一覧は初回アクセス時に JDBC のメタ情報から取得して、キャッシュするようになっています。

これを明示したい場合は以下のようにします。

    object TeamMember {
      override val tableName = "team_members"
      override val columnNames = Seq("id", "name")
    }

フィールド名から実際のカラム名への変換もテーブル名と同様にスネークケースに変換するのですが、一部のルールをカスタマイズした場合は以下のようにします。

    case class TeamMember(id: Long, createdAt: DateTime)
    object TeamMember {
      override val columnNames = Seq("id", "name", "created_timestamp")
      override val nameConverters = Map("^createdAt$" -> "created_timestamp")
      // "At$" -> "_timestamp" でも可
    }


### QueryDSL

`sql"..."` を効率的に生成するための DSL として QueryDSL が 1.6 から導入されました。

例えば、先に例であげた以下の SQL は

    sql"""
      insert into members (id, name, memo, created_at, updated_at) values 
      (${123}, ${"Alice"}, ${None}, ${now}, ${now})
    """.update.apply()

は以下のように記述できます。SQL インターポレーションと違って SQLSyntaxSupport を継承した

    object Member extends SQLSyntaxSupport[Member] {
    
      withSQL { 
        insert.into(Member)
          .column(column.id, column.name, column.memo, column.createdAt, column.updatedAt)
          .values(123, "Alice", None, now, now)
      }.update.apply()
    }

    val ordering: SQLSyntax = if (isDesc) sqls"desc" else sqls"asc" // or SQLSyntax("desc")
    val id: Int = 1234
    
    val m = Member.syntax("m")
    val names = select(m.name).from(Member as m).where.eq(m.id, id).orderBy(m.id).append(ordering)
      .map(rs => rs.long("name").list.apply()

## まとめ

以上、ScalikeJDBC では計 4 種類の SQL テンプレートをサポートしていますが、基本的には用途や好みにあわせて使い分けていただくのがよいかと思います。

筆者としては Scala 2.10 以降であれば、利便性だけでなく、今後の発展性も考えて SQL インターポレーションを使うことを推奨いたします。

事情により Scala 2.9 での開発であれば、名前付きの SQL テンプレートをベースに利用されるのが良いのではないかと思います。


