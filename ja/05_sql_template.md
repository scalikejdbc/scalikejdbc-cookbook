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

1.5.1 時点では Scala 2.9.x サポート継続のために拡張機能として別の jar になっています。sbt の設定に以下を追加してください。読者が既に Scala 2.10.0 以降を使用している場合は scalaVersion の指定は不要です。

    scalaVersion := "2.10.0"
    
    libraryDependencies += "com.github.seratch" %% "scalikejdbc-interpolation" % "[1.4,)",

「${expression}」でパラメータとして式を埋め込みます。

    val now = DateTime.now
    sql"""
      insert into members (id, name, memo, created_at, updated_at) values 
      (${123}, ${"Alice"}, ${None}, ${now}, ${now})
    """.update.apply()

### SQLSyntax とそれ以外

SQLSyntax という型があり、この型で渡した部分はバインド引数として展開されずにそのまま SQL の一部として組み込まれます。

当然ながらここに外部からの入力をそのまま使うと SQL インジェクション脆弱性になりますので、その点は理解した上でご使用ください。

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


## まとめ

以上、ScalikeJDBC では計 4 種類の SQL テンプレートをサポートしていますが、基本的には用途や好みにあわせて使い分けていただくのがよいかと思います。

筆者としては Scala 2.10 以降であれば、利便性だけでなく、今後の発展性も考えて SQL インターポレーションを使うことを推奨いたします。

事情により Scala 2.9 での開発であれば、名前付きの SQL テンプレートをベースに利用されるのが良いのではないかと思います。


