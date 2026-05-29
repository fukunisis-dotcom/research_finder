require "net/http"
require "uri"
require "json"
require "rexml/document"

module ResearchFinder
  GEMINI_API_KEY = ENV['GEMINI_API_KEY']
  CALIL_SYSTEM_IDS = "Pref_Osaka" # 大阪府内一括

  def self.search(keyword)
    puts "========================================"
    puts "🔍 「#{keyword}」の自由研究ナビ（大阪図書館・CiNii対応版）"
    puts "========================================\n\n"

    suggestions = ask_ai_for_suggestions(keyword)
    
    # 🌟 万が一AIの返却が空でも、キーワードそのものを使って強制的に本を探す仕組み（セーフティネット）
    if suggestions[:books].empty?
      suggestions[:books] = ["#{keyword}の基本がわかる本", "#{keyword}入門ガイド"]
    end

    puts "🕵️‍♂️ 【国立国会図書館 蔵書目録】で存在チェック中...⏳"
    verified_books = verify_list(suggestions[:books], keyword)
    
    puts "\n📚 【カーリル API】大阪近辺の図書館の在庫状況を調べています...⏳"
    check_calil_status(verified_books)

    puts "\n🎓 【CiNii API】関連する日本の論文・研究データを検索中...⏳"
    search_ciniis(keyword)

    puts "\n"
    ask_ai_to_explain(keyword, verified_books, suggestions[:documents])
  end

  def self.ask_ai_for_suggestions(keyword)
    puts "🤖 AIが資料をリストアップ中...⏳\n\n"
    url = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{GEMINI_API_KEY}")

    prompt = <<~TEXT
      あなたはプロの図書館司書です。中学生の自由研究テーマ「#{keyword}」について、以下の2つのカテゴリに合う、実在する分かりやすい資料をそれぞれ2〜3個ずつ挙げてください。

      【出力のルール】
      解説は一切書かず、以下の形式（カギカッコ付き）だけで出力してください。
      [一般書籍]
      「書籍タイトル1」
      「書籍タイトル2」
      [政府文書・白書]
      「白書・データタイトル1」
      「白書・データタイトル2」
    TEXT

    payload = { contents: [{ parts: [{ text: prompt }] }] }.to_json

    begin
      # タイムアウト対策を入れて通信を安定化
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.read_timeout = 15
      request = Net::HTTP::Post.new(url.request_uri, { 'Content-Type' => 'application/json' })
      request.body = payload
      response = http.request(request)
      
      result = JSON.parse(response.body)
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

  def self.verify_list(titles, keyword)
    verified = []
    titles.each do |title|
      next if title.strip.empty?
      clean_title = title.split("(ISBN")[0].gsub(/[「」『』:：・]/, " ").strip
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
          verified << { title: official_title || clean_title, is_real: true }
          puts "  ・『#{official_title || clean_title}』 -> ✅ 国会図書館で実在を確認！"
        else
          # 🌟AIが創作した嘘の本だった場合も、キーワード検索用として救済して残す
          verified << { title: clean_title, is_real: false }
          puts "  ・『#{clean_title}』 -> 🔎 直接検索リンクを生成します"
        end
      rescue
        verified << { title: clean_title, is_real: false }
      end
    end
    verified
  end

  def self.check_calil_status(books)
    books.each_with_index do |book, idx|
      # 大阪の図書館を一発で検索できるカーリルのURLを100%確実に生成
      search_url = "https://calil.jp/search?q=#{URI.encode_www_form_component(book[:title] + ' 大阪')}"
      
      puts "  #{idx+1}. 『#{book[:title]}』"
      puts "     🔗 在庫を見る: <a href='#{search_url}' target='_blank' style='color: #0066cc; font-weight: bold; text-decoration: underline;'>ここをクリックして大阪の図書館で探す</a>"
    end
  end

  def self.search_ciniis(keyword)
    safe_keyword = URI.encode_www_form_component(keyword)
    cinii_search_url = "https://ci.nii.ac.jp/search?q=#{safe_keyword}"
    url = URI.parse("https://ci.nii.ac.jp/opensearch/article?q=#{safe_keyword}&format=rss")
    
    begin
      request = Net::HTTP::Get.new(url)
      response = Net::HTTP.start(url.host, url.port, use_ssl: true) { |http| http.request(request) }
      doc = REXML::Document.new(response.body)
      items = doc.elements.to_a('//item')

      if items.empty?
        puts "  🔎 直接CiNiiで豊富な論文を検索できます。"
        puts "     🔗 論文を探す: <a href='#{cinii_search_url}' target='_blank' style='color: #0066cc; text-decoration: underline;'>ここをクリックしてCiNiiで直接「#{keyword}」の論文を検索する</a>"
      else
        items.first(3).each_with_index do |item, idx|
          title = item.elements['title'] ? item.elements['title'].text : "無題の論文"
          link = item.elements['link'] ? item.elements['link'].text : "#"
          puts "  #{idx+1}. 『#{title}』"
          puts "     🔗 論文を読む: <a href='#{link}' target='_blank' style='color: #0066cc; text-decoration: underline;'>ここをクリックしてCiNiiで論文を開く</a>"
        end
      end
    rescue
      puts "  🔗 論文を探す: <a href='#{cinii_search_url}' target='_blank' style='color: #0066cc; text-decoration: underline;'>ここをクリックしてCiNiiで直接「#{keyword}」の論文を検索する</a>"
    end
  end

  def self.ask_ai_to_explain(keyword, books, docs)
    url = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{GEMINI_API_KEY}")

    prompt = <<~TEXT
      あなたは中学生の自由研究を助ける優しい図書館司書です。
      テーマ「#{keyword}」について、以下の本やデータを調べる場合、どのような点に注目して読めばいいか、具体的なアドバイスや研究のヒントを優しく解説してください。

      【参考書籍】
      #{books.map { |b| "- #{b[:title]}" }.join("\n")}

      【政府文書・白書】
      #{docs ? docs.map { |t| "- #{t}" }.join("\n") : "特になし"}
    TEXT

    payload = { contents: [{ parts: [{ text: prompt }] }] }.to_json

    begin
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(url.request_uri, { 'Content-Type' => 'application/json' })
      request.body = payload
      response = http.request(request)
      
      result = JSON.parse(response.body)
      if result && result["candidates"] && result["candidates"][0]["content"]
        ai_reply = result["candidates"][0]["content"]["parts"][0]["text"]
        puts "========================================"
        puts "📚 司書AIからの自由研究アドバイス"
        puts "========================================"
        puts ai_reply
        puts "========================================"
      end
    rescue
      puts "========================================"
      puts "📚 新・自由研究ナビ v2"
      puts "========================================"
      puts "上の青いリンクをクリックして、大阪の図書館で本を借りたり、CiNiiの論文を読んで自由研究を組み立ててみよう！"
      puts "========================================"
    end
  end
end
