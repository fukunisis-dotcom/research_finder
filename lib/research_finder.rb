require "net/http"
require "uri"
require "json"
require "rexml/document"

module ResearchFinder
  GEMINI_API_KEY = ENV['GEMINI_API_KEY']

  def self.search(keyword)
    puts "<div style='font-family: sans-serif; color: #333; line-height: 1.6; max-width: 800px; margin: 0 auto;'>"
    puts "  <h2 style='border-bottom: 3px solid #0066cc; padding-bottom: 8px; color: #0066cc; margin-top: 20px;'>🔍 「#{keyword}」の調査結果ナビ</h2>"

    suggestions = ask_ai_for_suggestions(keyword)
    
    if suggestions[:books].empty?
      suggestions[:books] = ["#{keyword}に関する入門書", "#{keyword}の歴史がわかる本", "#{keyword}の解説ガイド"]
    end

    # --- 📚 書籍 & カーリル検索セクション ---
    puts "  <h3 style='background: #f0f7ff; border-left: 5px solid #0066cc; padding: 8px 12px; margin-top: 25px; margin-bottom: 10px;'>📚 おすすめの関連書籍（大阪府内図書館リンク付）</h3>"
    puts "  <ul style='list-style-type: none; padding-left: 0;'>"
    suggestions[:books].each_with_index do |title, idx|
      clean_title = title.gsub(/[「」『』]/, "").strip
      search_url = "https://calil.jp/search?q=#{URI.encode_www_form_component(clean_title + ' 大阪')}"
      
      puts "    <li style='margin-bottom: 15px; padding: 10px; border: 1px solid #e0e0e0; border-radius: 4px; background: #fff;'>"
      puts "      <span style='font-weight: bold; font-size: 1.1em; color: #222;'>#{idx+1}. 『#{clean_title}』</span><br>"
      puts "      <a href='#{search_url}' target='_blank' style='display: inline-block; margin-top: 6px; padding: 4px 12px; background: #0066cc; color: white; text-decoration: none; border-radius: 3px; font-size: 0.9em; font-weight: bold;'>📍 大阪の図書館で在庫を探す</a>"
      puts "    </li>"
    end
    puts "  </ul>"

    # --- 🎓 CiNii 論文セクション ---
    puts "  <h3 style='background: #fff9e6; border-left: 5px solid #ffa500; padding: 8px 12px; margin-top: 25px; margin-bottom: 10px;'>🎓 関連する専門論文・データ</h3>"
    search_ciniis(keyword)

    # --- 📊 政府統計・白書セクション ---
    puts "  <h3 style='background: #f2f2f2; border-left: 5px solid #666; padding: 8px 12px; margin-top: 25px; margin-bottom: 10px;'>📊 参考になる政府文書・統計データ</h3>"
    if suggestions[:documents].empty?
      suggestions[:documents] = ["#{keyword}に関する統計データ", "関連分野の白書"]
    end
    puts "  <ul style='padding-left: 20px; color: #444;'>"
    suggestions[:documents].each do |doc|
      clean_doc = doc.gsub(/[「」『』]/, "").strip
      puts "    <li style='margin-bottom: 6px; font-weight: bold;'>#{clean_doc}</li>"
    end
    puts "  </ul>"

    puts "</div>"
  end

  def self.ask_ai_for_suggestions(keyword)
    url = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{GEMINI_API_KEY}")

    prompt = <<~TEXT
      テーマ「#{keyword}」について、実在する具体的な分かりやすい解説書籍を【必ず3冊】、および参考になる政府データや白書の名称を【必ず2つ】挙げてください。
      余計な解説、挨拶、アドバイス、ISBNなどは完全に一切省き、以下の形式（カギカッコ付き）だけで簡潔に出力してください。

      [一般書籍]
      「書籍タイトル1」
      「書籍タイトル2」
      「書籍タイトル3」
      [政府文書・白書]
      「白書・データタイトル1」
      「白書・データタイトル2」
    TEXT

    payload = { contents: [{ parts: [{ text: prompt }] }] }.to_json

    begin
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

  def self.search_ciniis(keyword)
    safe_keyword = URI.encode_www_form_component(keyword)
    cinii_search_url = "https://ci.nii.ac.jp/search?q=#{safe_keyword}"
    url = URI.parse("https://ci.nii.ac.jp/opensearch/article?q=#{safe_keyword}&format=rss")
    
    puts "  <ul style='list-style-type: none; padding-left: 0;'>"
    begin
      request = Net::HTTP::Get.new(url)
      response = Net::HTTP.start(url.host, url.port, use_ssl: true) { |http| http.request(request) }
      doc = REXML::Document.new(response.body)
      items = doc.elements.to_a('//item')

      if items.empty?
        puts "    <li style='margin-bottom: 10px; padding: 10px; border: 1px solid #e0e0e0; border-radius: 4px; background: #fff;'>️"
        puts "      <span style='color: #666;'>※ 自動通信では論文を絞り込めませんでした。以下の全体リンクから閲覧できます。</span><br>"
        puts "      <a href='#{cinii_search_url}' target='_blank' style='display: inline-block; margin-top: 6px; padding: 4px 12px; background: #ffa500; color: white; text-decoration: none; border-radius: 3px; font-size: 0.9em; font-weight: bold;'>🔎 CiNiiで直接「#{keyword}」の論文を検索する</a>"
        puts "    </li>"
      else
        items.first(3).each_with_index do |item, idx|
          title = item.elements['title'] ? item.elements['title'].text : "無題の論文"
          link = item.elements['link'] ? item.elements['link'].text : "#"
          puts "    <li style='margin-bottom: 10px; padding: 10px; border: 1px solid #e0e0e0; border-radius: 4px; background: #fff;'>"
          puts "      <span style='font-weight: bold; color: #222;'>『#{title}』</span><br>"
          puts "      <a href='#{link}' target='_blank' style='display: inline-block; margin-top: 6px; padding: 4px 12px; background: #ffa500; color: white; text-decoration: none; border-radius: 3px; font-size: 0.9em; font-weight: bold;'>📖 この論文を読む(CiNii)</a>"
          puts "    </li>"
        end
      end
    rescue
      puts "    <li style='margin-bottom: 10px; padding: 10px; border: 1px solid #e0e0e0; border-radius: 4px; background: #fff;'>"
      puts "      <a href='#{cinii_search_url}' target='_blank' style='display: inline-block; padding: 4px 12px; background: #ffa500; color: white; text-decoration: none; border-radius: 3px; font-size: 0.9em; font-weight: bold;'>🔎 CiNiiで直接「#{keyword}」の論文を検索する</a>"
      puts "    </li>"
    end
    puts "  </ul>"
  end
end
