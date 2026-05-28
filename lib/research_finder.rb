require "net/http"
require "uri"
require "json"
require "rexml/document"

module ResearchFinder
  GEMINI_API_KEY = "AIzaSyA6-SRF-xNP0C7cmL0kbAj0RKXJe9oeELo"

  def self.search(keyword)
    puts "========================================"
    puts "🔍 「#{keyword}」の自由研究資料・公的データを検索中..."
    puts "========================================\n\n"

    # ステップ1: AIから「一般書籍」と「政府文書・白書」のアイデアをもらう
    suggestions = ask_ai_for_suggestions(keyword)
    if suggestions[:books].empty? && suggestions[:documents].empty?
      puts "❌ AIからの提案が得られませんでした。もう一度試してください。"
      return
    end

    # ステップ2: 国会図書館で実在検証
    puts "🕵️‍♂️ 【国立国会図書館 蔵書目録】で存在チェック＆正式名を取得中...⏳"
    
    verified_books = verify_list(suggestions[:books])
    verified_docs = verify_list(suggestions[:documents])
    puts "\n"

    if verified_books.empty? && verified_docs.empty?
      puts "❌ 蔵書目録で実在を確認できた資料がありませんでした。"
      return
    end

    # ステップ3: 検証済みの確実なデータだけで、生徒向けのアドバイスを生成
    ask_ai_to_explain(keyword, verified_books, verified_docs)
  end

  # AIに書籍と白書・公的資料を分けて挙げてもらう処理
  def self.ask_ai_for_suggestions(keyword)
    puts "🤖 AIがWeb上の知識から資料をリストアップ中...⏳\n\n"
    url = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{GEMINI_API_KEY}")

    prompt = <<~TEXT
      あなたはプロの図書館司書です。中学生の自由研究テーマ「#{keyword}」について、以下の2つのカテゴリに合う、実在する分かりやすい資料をそれぞれ2〜3個ずつ挙げてください。

      1. 【一般書籍】（図鑑、新書、解説書など）
      2. 【政府の報告書・白書・統計データ】（文部科学省、内閣府、JAXAなどの公的文書や、宇宙開発に関する白書・報告書など）

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
      response = post_to_gemini(url, payload)
      result = JSON.parse(response)
      ai_reply = result["candidates"][0]["content"]["parts"][0]["text"]
      
      # [一般書籍] と [政府文書・白書] の部分を切り分ける
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

  # 国会図書館の蔵書目録で1件ずつ検証する共通処理
  def self.verify_list(titles)
    verified = []
    titles.each do |title|
      next if title.strip.empty?
      clean_title = title.gsub(/[「」『』:：]/, " ").strip
      safe_title = URI.encode_www_form_component(clean_title)
      
      # 官庁資料（白書等）も含まれるため、全体から検索できるように dpid は外します
      url = URI.parse("https://ndlsearch.ndl.go.jp/api/opensearch?title=#{safe_title}")
      
      begin
        request = Net::HTTP::Get.new(url)
        request["User-Agent"] = "Mozilla/5.0"
        response = Net::HTTP.start(url.host, url.port, use_ssl: true) { |http| http.request(request) }
        
        doc = REXML::Document.new(response.body.gsub('&', '&amp;'))
        first_item = doc.elements['//item']
        
        if first_item
          official_title = first_item.elements['title'] ? first_item.elements['title'].text : nil
          if official_title
            puts "  ・『#{title}』 -> ✅ 確認！(正式名: 『#{official_title}』)"
            verified << official_title
          end
        else
          puts "  ・『#{title}』 -> ❌ 蔵書目録にないため除外"
        end
      rescue
        # 通信エラー時はスキップ
      end
    end
    verified
  end

  # 解説を生成する処理
  def self.ask_ai_to_explain(keyword, books, docs)
    puts "📝 検証された資料を使って、自由研究のアドバイスを作成中...⏳\n\n"
    url = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{GEMINI_API_KEY}")

    prompt = <<~TEXT
      あなたは中学生の自由研究を助ける優しい図書館司書です。
      テーマ「#{keyword}」について、国会図書館で実在が確認された以下の資料リストを使い、中学生向けにおすすめの理由や自由研究への具体的な活かし方を解説してください。特に【政府文書・白書・統計データ】については、「国が出している信頼できるデータだよ」という点をアピールし、グラフや数字をどう研究に使うと良いかも優しく教えてあげてください。

      【実在する一般書籍】
      #{books.map { |t| "- #{t}" }.join("\n")}

      【実在する政府文書・白書・統計データ】
      #{docs.map { |t| "- #{t}" }.join("\n")}
    TEXT

    payload = { contents: [{ parts: [{ text: prompt }] }] }.to_json

    begin
      response = post_to_gemini(url, payload)
      result = JSON.parse(response)
      
      if result && result["candidates"] && result["candidates"][0]["content"]
        ai_reply = result["candidates"][0]["content"]["parts"][0]["text"]
        puts "========================================"
        puts "📚 信頼度100%！AI司書からの自由研究ナビ"
        puts "========================================"
        puts ai_reply
        puts "========================================"
      else
        puts "⚠️ AIからの詳細解説は取得できませんでしたが、以下の資料の実在を確認しました！"
        puts "\n【おすすめの一般書籍】"
        books.each { |t| puts " 📖 #{t}" }
        puts "\n【信頼できる政府文書・白書・統計データ】"
        docs.each { |t| puts " 📊 #{t}" }
      end
    rescue => e
      puts "エラーが発生しました: #{e.message}"
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