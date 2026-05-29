require "net/http"
require "uri"
require "json"
require "rexml/document"

module ResearchFinder
  GEMINI_API_KEY = ENV['GEMINI_API_KEY']

  def self.search(keyword)
    # 🌟 全体のデザインを現代的かつミニマルに洗練
    puts "<div style='font-family: -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, \"Helvetica Neue\", Arial, sans-serif; color: #2d3748; line-height: 1.5; max-width: 720px; margin: 0 auto; padding: 15px; background-color: #fafafa; border-radius: 8px;'>"
    puts "  <div style='display: flex; align-items: center; border-bottom: 2px solid #3182ce; padding-bottom: 10px; margin-bottom: 20px;'>"
    puts "    <span style='font-size: 1.5em; margin-right: 10px;'>🔍</span>"
    puts "    <h2 style='margin: 0; font-size: 1.4em; color: #2b6cb0; font-weight: 700;'>「#{keyword}」の調査ナビ</h2>"
    puts "  </div>"

    suggestions = ask_ai_for_suggestions(keyword)
    
    if suggestions[:books].empty?
      suggestions[:books] = ["#{keyword}に関する解説書", "#{keyword}の研究ガイド", "#{keyword}の基礎知識"]
    end

    # --- 📚 書籍 & カーリル検索セクション ---
    puts "  <h3 style='font-size: 1.05em; color: #2b6cb0; background: #ebf8ff; padding: 6px 12px; border-radius: 4px; margin-top: 20px; margin-bottom: 12px; font-weight: 600;'>📚 おすすめの関連書籍（大阪府内図書館リンク付）</h3>"
    puts "  <div style='display: flex; flex-direction: column; gap: 8px;'>"
    suggestions[:books].each_with_index do |title, idx|
      clean_title = title.gsub(/[「」『』]/, "").strip
      search_url = "https://calil.jp/search?q=#{URI.encode_www_form_component(clean_title + ' 大阪')}"
      
      puts "    <div style='display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; background: white; border: 1px solid #e2e8f0; border-radius: 6px; box-shadow: 0 1px 2px rgba(0,0,0,0.05);'>"
      puts "      <div style='font-weight: 600; font-size: 0.95em; color: #1a202c;'>#{idx+1}. 『#{clean_title}』</div>"
      puts "      <a href='#{search_url}' target='_blank' style='white-space: nowrap; padding: 5px 12px; background: #3182ce; color: white; text-decoration: none; border-radius: 4px; font-size: 0.82em; font-weight: 600; transition: background 0.2s;'>蔵書を探す</a>"
      puts "    </div>"
    end
    puts "  </div>"

    # --- 🎓 CiNii 論文セクション ---
    puts "  <h3 style='font-size: 1.05em; color: #dd6b20; background: #fffaf0; padding: 6px 12px; border-radius: 4px; margin-top: 25px; margin-bottom: 12px; font-weight: 600;'>🎓 関連する専門論文・学術データ</h3>"
    search_ciniis(keyword)

    # --- 📊 政府統計・白書セクション ---
    puts "  <h3 style='font-size: 1.05em; color: #4a5568; background: #edf2f7; padding: 6px 12px; border-radius: 4px; margin-top: 25px; margin-bottom: 12px; font-weight: 600;'>📊 参考になる政府文書・公的統計データ</h3>"
    if suggestions[:documents].empty?
      suggestions[:documents] = ["#{keyword}に関する統計", "関連分野の白書データ"]
    end
    puts "  <div style='display: flex; flex-direction: column; gap: 8px;'>"
    suggestions[:documents].each do |doc|
      clean_doc = doc.gsub(/[「」『』]/, "").strip
      # 🌟 政府統計・白書用の検索リンク（国会図書館リサーチ・ナビ、またはGoogle検索を利用して資料へ誘導）
      doc_search_url = "https://www.google.com/search?q=#{URI.encode_www_form_component(clean_doc + ' filetype:pdf OR site:go.jp')}"
      
      puts "    <div style='display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; background: white; border: 1px solid #e2e8f0; border-radius: 6px; box-shadow: 0 1px 2px rgba(0,0,0,0.05);'>"
      puts "      <div style='font-weight: 600; font-size: 0.95em; color: #1a202c;'>📄 #{clean_doc}</div>"
      puts "      <a href='#{doc_search_url}' target='_blank' style='white-space: nowrap; padding: 5px 12px; background: #4a5568; color: white; text-decoration: none; border-radius: 4px; font-size: 0.82em; font-weight: 600;'>資料を閲覧</a>"
      puts "    </div>"
    end
    puts "  </div>"

    puts "</div>"
  end

  def self.ask_ai_for_suggestions(keyword)
    url = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{GEMINI_API_KEY}")

    # 🌟 ハルシネーション（架空のタイトル）を防ぐため、プロンプトの記述を「実在が極めて高いもの」へ徹底改修
    prompt = <<~TEXT
      テーマ「#{keyword}」について、日本国内の図書館や大学、国会図書館に【100%実在する】著名な学術書・新書・入門専門書籍のタイトルを正確に3冊、および最も信頼できる政府発出の公式白書や調査統計データの固有名称を2つ挙げてください。
      AIによる架空のタイトル創作は絶対に厳禁です。
      説明、挨拶、前置き、アドバイス、ISBNなどは1文字も出力せず、以下のフォーマット形式（カギカッコ付き）だけで出力してください。

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
    
    puts "  <div style='display: flex; flex-direction: column; gap: 8px;'>"
    begin
      request = Net::HTTP::Get.new(url)
      response = Net::HTTP.start(url.host, url.port, use_ssl: true) { |http| http.request(request) }
      doc = REXML::Document.new(response.body)
      items = doc.elements.to_a('//item')

      if items.empty?
        puts "    <div style='display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; background: white; border: 1px solid #e2e8f0; border-radius: 6px; box-shadow: 0 1px 2px rgba(0,0,0,0.05);'>"
        puts "      <div style='font-size: 0.9em; color: #718096;'>※ 自動抽出データなし。データベースから直接検索できます。</div>"
        puts "      <a href='#{cinii_search_url}' target='_blank' style='white-space: nowrap; padding: 5px 12px; background: #dd6b20; color: white; text-decoration: none; border-radius: 4px; font-size: 0.82em; font-weight: 600;'>CiNiiで探す</a>"
        puts "    </div>"
      else
        items.first(3).each_with_index do |item, idx|
          title = item.elements['title'] ? item.elements['title'].text : "無題の論文"
          link = item.elements['link'] ? item.elements['link'].text : "#"
          puts "    <div style='display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; background: white; border: 1px solid #e2e8f0; border-radius: 6px; box-shadow: 0 1px 2px rgba(0,0,0,0.05);'>"
          puts "      <div style='font-weight: 600; font-size: 0.95em; color: #1a202c;'>『#{title}』</div>"
          puts "      <a href='#{link}' target='_blank' style='white-space: nowrap; padding: 5px 12px; background: #dd6b20; color: white; text-decoration: none; border-radius: 4px; font-size: 0.82em; font-weight: 600;'>論文を読む</a>"
          puts "    </div>"
        end
      end
    rescue
      puts "    <div style='display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; background: white; border: 1px solid #e2e8f0; border-radius: 6px; box-shadow: 0 1px 2px rgba(0,0,0,0.05);'>"
      puts "      <a href='#{cinii_search_url}' target='_blank' style='white-space: nowrap; padding: 5px 12px; background: #dd6b20; color: white; text-decoration: none; border-radius: 4px; font-size: 0.82em; font-weight: 600;'>CiNiiで探す</a>"
      puts "    </div>"
    end
    puts "  </div>"
  end
end
