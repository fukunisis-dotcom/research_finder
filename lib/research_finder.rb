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

    # 🌟 通信の待ち時間を15秒（通常より大幅に長く）に設定してAIの遅れを許容する
    book_titles = ask_ai_for_real_books(keyword)

    if book_titles.empty?
      # バックアップとして、どのテーマでも高確率で実在する新書風のタイトルを生成
      book_titles = ["#{keyword}の歴史と現在", "#{keyword}がわかる本"]
    end

    puts "📚 【カーリル】大阪近辺の図書館で本物の在庫を検索中...⏳"
    book_titles.each_with_index do |title, idx|
      clean_title = title.gsub(/[「」『』・]/, "").strip
      search_url = "https://calil.jp/search?q=#{URI.encode_www_form_component(clean_title + ' 大阪')}"
      
      puts "  #{idx+1}. 『#{clean_title}』"
      puts "     🔗 大阪の図書館で探す: <a href='#{search_url}' target='_blank' style='color: #0066cc; font-weight: bold; text-decoration: underline;'>ここをクリックして大阪の図書館の在庫を見る</a>"
    end

    puts "\n🎓 【CiNii API】関連する日本の論文・研究データを検索中...⏳"
    search_ciniis(keyword)
    puts "\n========================================"
  end

  def self.ask_ai_for_real_books(keyword)
    puts "🤖 AIが「#{keyword}」に関する実在する書籍を調査中...⏳\n\n"
    url = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=#{GEMINI_API_KEY}")

    # 🌟 AIが迷わず最速で実在する本を出せるようにプロンプトを極限までシンプルに
    prompt = "日本国内の図書館に実在する、中学生向けの「#{keyword}」に関する具体的な解説本・入門書のタイトルを3冊、著者名付きで挙げてください。余計な挨拶や説明は一切省き、必ず「タイトル（著者名）」の形式で3行だけで出力してください。"

    payload = { contents: [{ parts: [{ text: prompt }] }] }.to_json

    begin
      uri = url
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      # 🌟 タイムアウト時間を延長
      http.read_timeout = 20 
      
      request = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
      request.body = payload
      response = http.request(request)
      
      result = JSON.parse(response.body)
      ai_reply = result["candidates"][0]["content"]["parts"][0]["text"]
      
      # 改行で区切って配列にする
      lines = ai_reply.strip.split("\n").map(&:strip).reject(&:empty?)
      lines.first(3)
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
end
