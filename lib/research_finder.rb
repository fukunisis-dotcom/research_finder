require "net/http"
require "uri"
require "json"
require "rexml/document"

module ResearchFinder
  GEMINI_API_KEY = ENV['GEMINI_API_KEY']
  
  # 大阪近辺の主要図書館のコード（大阪市立、大阪府立、東大阪市立、堺市立など）
  # カーリルで一括検索するために「Pref_Osaka」を指定します
  CALIL_SYSTEM_IDS = "Pref_Osaka"

  def self.search(keyword)
    puts "========================================"
    puts "🔍 「#{keyword}」の自由研究ナビ v2（大阪図書館・CiNii対応）"
    puts "========================================\n\n"

    suggestions = ask_ai_for_suggestions(keyword)
    if suggestions[:books].empty? && suggestions[:documents].empty?
      puts "❌ AIからの提案が得られませんでした。時間を置いてもう一度試してください。"
      return
    end

    puts "🕵️‍♂️ 【国立国会図書館 蔵書目録】で存在チェック中...⏳"
    verified_books = verify_list(suggestions[:books])
    
    # 🌟 新機能1：カーリルで大阪近辺の図書館の貸出・配架状況をチェック！
    puts "\n📚 【カーリル API】大阪近辺の図書館の在庫状況を調べています...⏳"
    check_calil_status(verified_books)

    # 🌟 新機能2：CiNiiから関連する論文を検索！
    puts "\n🎓 【CiNii API】関連する日本の論文・研究データを検索中...⏳"
    search_ciniis(keyword)

    puts "\n"
    ask_ai_to_explain(keyword, verified_books, suggestions[:documents])
  end

  def self.ask_ai_for_suggestions(keyword)
    puts "🤖 AIがWeb上の知識から資料をリストアップ中...⏳\n\n"
    url = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{GEMINI_API_KEY}")

    prompt = <<~TEXT
      あなたはプロの図書館司書です。中学生の自由研究テーマ「#{keyword}」について、以下の2つのカテゴリに合う、実在する分かりやすい資料をそれぞれ2〜3個ずつ挙げてください。
      [一般書籍]には、できるだけISBN（10桁または13桁の数字）も一緒に調べて、タイトルと並べて書いてください。

      【出力のルール】
      解説は一切書かず、以下の形式（カギカッコ付き）だけで出力してください。ISBNがない場合はタイトルだけで構いません。
      [一般書籍]
      「書籍タイトル1 (ISBN: 数字)」
      「書籍タイトル2 (ISBN: 数字)」
      [政府文書・白書]
      「白書・データタイトル1」
      「白書・データタイトル2」
    TEXT

    payload = { contents: [{ parts: [{ text: prompt }] }] }.to_json

    begin
      response = post_to_gemini(url, payload)
      result = JSON.parse(response)
      ai_reply = result["candidates"][0]["content"]["parts"][0]["text"]
      
      parts = ai_reply.split(/\[政府文書・白書\]/)
      books_part = parts[0] || ""
      docs_part = parts[1] || ""

      {
        books: books_part.scan(/「([^」]+)」/).flatten,
        documents: docs_part.scan(/「([^」]+)」/).flatten
      }
    rescue
      { books: [], documents: [] }
    end
  end

  def self.verify_list(titles)
    verified = []
    titles.each do |title|
      next if title.strip.empty?
      clean_title = title.split("(ISBN")[0].gsub(/[「」『』:：]/, " ").strip
      safe_title = URI.encode_www_form_component(clean_title)
      
      url = URI.parse("https://ndlsearch.ndl.go.jp/api/opensearch?title=#{safe_title}")
      
      begin
        request = Net::HTTP::Get.new(url)
        request["User-Agent"] = "Mozilla/5.0"
        response = Net::HTTP.start(url.host, url.port, use_ssl: true) { |http| http.request(request) }
        
        doc = REXML::Document.new(response.body.gsub('&', '&amp;'))
        first_item = doc.elements['//item']
        
        if first_item
          official_title = first_item.elements['title'] ? first_item.elements['title'].text : nil
          isbn = title.match(/ISBN:\s*([0-9X]+)/) ? title.match(/ISBN:\s*([0-9X]+)/)[1] : nil
          verified << { title: official_title || clean_title, isbn: isbn }
          puts "  ・『#{official_title || clean_title}』 -> ✅ 国会図書館にあり"
        end
      rescue
      end
    end
    verified
  end

  # 🌟 カーリル検索の処理
  def self.check_calil_status(books)
    books.each do |book|
      if book[:isbn].nil?
        puts "  ・『#{book[:title]}』 -> ⚠️ ISBN不明のため大阪の蔵書検索をスキップ（直接検索してください）"
        next
      end

      # カーリルの無料API（テスト用キーを使用）
      url = URI.parse("https://api.calil.jp/check?appkey=98cc78fbdf30ea3e7e8346cb46f7d54e&isbn=#{book[:isbn]}&systemid=#{CALIL_SYSTEM_IDS}&format=json")
      begin
        response = Net::HTTP.get(url)
        # カーリルAPIの仕様（一回目のリクエストはcallbackになることがあるため簡易パース）
        json_text = response.match(/callback\((.*)\);/) ? response.match(/callback\((.*)\);/)[1] : response
        result = JSON.parse(json_text)
        
        system_data = result["books"][book[:isbn]][CALIL_SYSTEM_IDS]
        if system_data && system_data["libkey"]
          status = system_data["status"]
          puts "  ・『#{book[:title]}』 -> 📍 大阪府内図書館: 【#{status == 'OK' ? '蔵書あり(貸出状況はWebで)' : '検索中/確認を'}】"
          puts "     🔗 カーリルで見る: https://calil.jp/book/#{book[:isbn]}"
        else
          puts "  ・『#{book[:title]}』 -> 🔎 大阪の図書館に蔵書があるかカーリルで確認してください"
          puts "     🔗 リンク: https://calil.jp/book/#{book[:isbn]}"
        end
      rescue
        puts "  ・『#{book[:title]}』 -> 🔗 大阪の図書館の在庫を見る: https://calil.jp/book/#{book[:isbn]}"
      end
    end
  end

  # 🌟 CiNii 論文検索の処理
  def self.search_ciniis(keyword)
    safe_keyword = URI.encode_www_form_component(keyword)
    # CiNii ResearchのOpenSearch APIを使用
    url = URI.parse("https://ci.nii.ac.jp/opensearch/author?q=#{safe_keyword}&format=rss")
    
    begin
      request = Net::HTTP::Get.new(url)
      response = Net::HTTP.start(url.host, url.port, use_ssl: true) { |http| http.request(request) }
      
      doc = REXML::Document.new(response.body)
      items = doc.elements.to_a('//item')
      
      if items.empty?
        # キーワードを変えて再挑戦
        url_articles = URI.parse("https://ci.nii.ac.jp/opensearch/article?q=#{safe_keyword}&format=rss")
        response_articles = Net::HTTP.start(url_articles.host, url_articles.port, use_ssl: true) { |http| http.request(url_articles) }
        doc = REXML::Document.new(response_articles.body)
        items = doc.elements.to_a('//item')
      end

      if items.empty?
        puts "  ❌ 関連する論文が見つかりませんでした。別のキーワードを試してください。"
      else
        items.first(3).each_with_index do |item, idx|
          title = item.elements['title'] ? item.elements['title'].text : "無題の論文"
          link = item.elements['link'] ? item.elements['link'].text : "#"
          creator = item.elements['dc:creator'] ? item.elements['dc:creator'].text : "不明"
          puts "  #{idx+1}. 『#{title}』 (著者: #{creator})"
          puts "     🔗 論文を読む(CiNii): #{link}"
        end
      end
    rescue => e
      # エラーが起きても最低限リンクだけ出す
      puts "  🔗 CiNiiで直接論文を探す: https://ci.nii.ac.jp/search?q=#{safe_keyword}"
    end
  end

  def self.ask_ai_to_explain(keyword, books, docs)
    return if books.empty? && docs.empty?
    puts "📝 バージョン2のAI司書が、自由研究のアドバイスを作成中...⏳\n\n"
    url = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{GEMINI_API_KEY}")

    prompt = <<~TEXT
      あなたは中学生の自由研究を助ける優しい図書館司書です。
      テーマ「#{keyword}」について、実在が確認された一般書籍や政府データを使い、中学生向けにおすすめの理由や具体的な活かし方を解説してください。また、「CiNiiで論文を読んだり、地元のカーリルを使って大阪の図書館で本を借りてみよう！」というアドバイスも最後に優しく添えてあげてください。

      【一般書籍】
      #{books.map { |b| "- #{b[:title]}" }.join("\n")}

      【政府文書・白書・統計データ】
      #{docs.map { |t| "- #{t}" }.join("\n")}
    TEXT

    payload = { contents: [{ parts: [{ text: prompt }] }] }.to_json

    begin
      response = post_to_gemini(url, payload)
      result = JSON.parse(response)
      
      if result && result["candidates"] && result["candidates"][0]["content"]
        ai_reply = result["candidates"][0]["content"]["parts"][0]["text"]
        puts "========================================"
        puts "📚 信頼度200%！新・自由研究ナビ v2"
        puts "========================================"
        puts ai_reply
        puts "========================================"
      end
    rescue
      puts "⚠️ AI解説の生成でエラーが起きましたが、上記のカーリル・CiNiiの検索結果を参考にしてください！"
    end
  end

  def self.post_to_gemini(url, payload)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(url.request_uri, { 'Content-Type' => 'application/json' })
    request.body = payload
    response = http.request(request)
    response.body
  end
end
