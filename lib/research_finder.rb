require "net/http"
require "uri"
require "json"
require "rexml/document"

module ResearchFinder
  GEMINI_API_KEY = ENV['GEMINI_API_KEY']

  def self.search(keyword)
    puts "========================================"
    puts "🔍 「#{keyword}」の自由研究ナビ v2（大阪図書館・CiNii対応）"
    puts "========================================\n\n"

    # 🌟 AIには「実在する本の本物の名前」だけを集中して出させる（エラーの源であるISBNは探させない）
    book_titles = ask_ai_for_real_books(keyword)

    if book_titles.empty?
      # 最低限のセーフティネット（キーワードをそのまま本の名前に見立てる）
      book_titles = ["#{keyword}の基本がわかる本", "#{keyword}入門ガイド"]
    end

    puts "📚 【カーリル】大阪近辺の図書館で本物の在庫を検索中...⏳"
    book_titles.each_with_index do |title, idx|
      clean_title = title.gsub(/[「」『』]/, "").strip
      # 🌟 本のタイトルで直接大阪の図書館を検索する特製リンクを100%確実に作成！
      search_url = "https://calil.jp/search?q=#{URI.encode_www_form_component(clean_title + ' 大阪')}"
      
      puts "  #{idx+1}. 『#{clean_title}』"
      puts "     🔗 大阪の図書館で探す: <a href='#{search_url}' target='_blank' style='color: #0066cc; text-weight: bold; text-decoration: underline;'>ここをクリックして大阪の図書館の在庫を見る</a>"
    end

    puts "\n🎓 【CiNii API】関連する日本の論文・研究データを検索中...⏳"
    search_ciniis(keyword)

    puts "\n"
    ask_ai_to_explain(keyword, book_titles)
  end

  def self.ask_ai_for_real_books(keyword)
    puts "🤖 AIが「#{keyword}」に関する実在する書籍を調査中...⏳\n\n"
    url = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=#{GEMINI_API_KEY}")

    prompt = <<~TEXT
      あなたは優秀な学校図書館の司書です。中学生の自由研究テーマ「#{keyword}」について、日本国内の図書館に実際に蔵書として存在する、中学生向けに分かりやすい具体的な解説書籍・入門書・専門書を【必ず3冊、正確なタイトルと著者名で】挙げてください。

      【出力のルール】
      挨拶や余計な説明、ISBNなどは一切書かないでください。必ず以下の形式（カギカッコ付き）だけで出力してください。
      「書籍タイトル（著者名）」
      「書籍タイトル（著者名）」
      「書籍タイトル（著者名）」
    TEXT

    payload = { contents: [{ parts: [{ text: prompt }] }] }.to_json

    begin
      response = post_to_gemini(url, payload)
      result = JSON.parse(response)
      ai_reply = result["candidates"][0]["content"]["parts"][0]["text"]
      
      # カギカッコの中身を抽出
      titles = ai_reply.scan(/「([^」]+)」/).flatten
      titles.reject(&:empty?).first(3)
    rescue
      []
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
        puts "  🔎 自動通信では見つかりませんでしたが、直接CiNiiで豊富な論文を検索できます。"
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

  def self.ask_ai_to_explain(keyword, books)
    url = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=#{GEMINI_API_KEY}")

    prompt = <<~TEXT
      あなたは中学生の自由研究を助ける優しい図書館司書です。
      テーマ「#{keyword}」について、以下の本を参考にする場合、中学生向けにどのような点に注目して読めばいいか、具体的なアドバイスや研究のヒントを優しく解説してください。

      【参考書籍】
      #{books.map { |b| "- #{b}" }.join("\n")}
    TEXT

    payload = { contents: [{ parts: [{ text: prompt }] }] }.to_json

    begin
      response = post_to_gemini(url, payload)
      result = JSON.parse(response)
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
      puts "📚 新...自由研究ナビ v2"
      puts "========================================"
      puts "上の青いリンクをクリックして、大阪の図書館で本を借りたり、CiNiiの論文を読んで自由研究を組み立ててみよう！"
      puts "========================================"
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
