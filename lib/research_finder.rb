require "net/http"
require "uri"
require "json"
require "rexml/document"

module ResearchFinder
  GEMINI_API_KEY = ENV['GEMINI_API_KEY']

  def self.search(keyword)
    # 🌟 全体を「みっちー」のネオン世界観（ダークモード）にリニューアル
    puts "<div style='font-family: \"Helvetica Neue\", Arial, \"Hiragino Kaku Gothic ProN\", sans-serif; background-color: #121214; color: #e2e8f0; max-width: 900px; margin: 0 auto; padding: 25px; border: 2px solid #ff007f; border-radius: 12px; box-shadow: 0 0 20px rgba(255, 0, 127, 0.2);'>"
    
    # レイアウトを左右2カラムに分割（左：みっちー、右：検索結果）
    puts "  <div style='display: flex; flex-direction: row; gap: 30px; align-items: flex-start; flex-wrap: wrap;'>"
    
    # ── 左カラム：みっちー常駐エリア ──
    puts "    <div style='flex: 1; min-width: 260px; text-align: center; background: #1a1a1e; padding: 20px; border-radius: 8px; border: 1px solid #333;'>"
    # あなたの「みっちー」画像をベースにしたSVG風ネオンアバター（インライン表示）
    puts "      <svg width='200' height='220' viewBox='0 0 200 220' style='filter: drop-shadow(0 0 8px #00ffff);'>"
    puts "        <g stroke='#00ffff' stroke-width='2' fill='none'>"
    puts "          "
    puts "          <path d='M70,40 Q100,10 130,40 Z' stroke='#ecc94b' stroke-width='3' fill='rgba(236,201,75,0.1)'/>"
    puts "          <path d='M100,10 L100,40' stroke='#ecc94b'/>"
    puts "          <path d='M115,15 Q140,20 135,50' stroke='#48bb78' stroke-width='2'/>"
    puts "          "
    puts "          <path d='M50,80 Q45,140 100,180 Q155,140 150,80 Z' stroke='#9f7aea' stroke-width='4' fill='rgba(159,122,234,0.05)'/>"
    puts "          "
    puts "          <path d='M50,80 Q100,60 150,80 Q100,50 50,80' stroke='#3182ce' fill='#1a1a1e'/>"
    puts "          "
    puts "          <path d='M65,95 Q75,90 85,95' stroke='#3182ce' stroke-width='3'/>"
    puts "          <path d='M115,95 Q125,90 135,95' stroke='#3182ce' stroke-width='3'/>"
    puts "          <path d='M70,105 Q77,108 85,105' stroke='#00ffff'/>"
    puts "          <path d='M115,105 Q123,108 130,105' stroke='#00ffff'/>"
    puts "          <path d='M80,145 Q100,155 120,145' stroke='#3182ce' stroke-width='2'/>"
    puts "          <path d='M75,138 Q100,142 125,138' stroke='#3182ce' stroke-width='2'/>"
    puts "          "
    puts "          <circle cx='35' cy='140' r='12' stroke='#ff007f' stroke-width='2' fill='rgba(255,0,127,0.2)'/>"
    puts "          <circle cx='25' cy='165' r='8' stroke='#ff007f' stroke-width='2'/>"
    puts "          <path d='M20,130 Q35,150 45,180' stroke='#48bb78' stroke-width='2'/>"
    puts "        </g>"
    puts "      </svg>"
    puts "      <h1 style='font-size: 1.3em; color: #fff; margin-top: 15px; font-weight: 700; letter-spacing: 1px;'>みっちーの自由研究ナビ</h1>"
    puts "      <p style='font-size: 0.8em; color: #a0aec0; margin: 5px 0 0 0;'>Fukunishi Special Edition</p>"
    puts "    </div>"

    # ── 右カラム：情報表示エリア ──
    puts "    <div style='flex: 2; min-width: 320px;'>"
    puts "      <div style='border-bottom: 2px solid #ff007f; padding-bottom: 8px; margin-bottom: 20px;'>"
    puts "        <span style='font-size: 0.85em; color: #ff007f; font-weight: bold; text-transform: uppercase;'>Current Search Keyword</span>"
    puts "        <h2 style='margin: 2px 0 0 0; font-size: 1.5em; color: #fff; font-weight: 700;'>🎯 #{keyword}</h2>"
    puts "      </div>"

    suggestions = ask_ai_for_suggestions(keyword)

    # --- 📚 書籍セクション ---
    puts "      <h3 style='font-size: 0.95em; color: #00ffff; letter-spacing: 0.5px; margin-top: 20px; margin-bottom: 10px; font-weight: 700;'>■ おすすめの関連書籍（大阪府内図書館リンク）</h3>"
    puts "      <div style='display: flex; flex-direction: column; gap: 6px;'>"
    
    # 🌟 もしAIがハルシネーション本を出したら、最初から「一般検索」として安全に処理するフラグ
    suggestions[:books].each_with_index do |title, idx|
      clean_title = title.gsub(/[「」『』]/, "").strip
      
      # 判定：AIが「〜の基本がわかる本」などのテンプレ汎用名を出してきた場合は汎用検索へシフト
      is_hallucination = clean_title.include?("基本がわかる本") || clean_title.include?("入門ガイド") || clean_title.include?("分かりやすい入門")
      search_query = is_hallucination ? "#{keyword} 著" : clean_title
      
      search_url = "https://calil.jp/search?q=#{URI.encode_www_form_component(search_query + ' 大阪')}"
      
      puts "        <div style='display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; background: #1a1a1e; border: 1px solid #2d2d34; border-radius: 6px;'>"
      if is_hallucination
        puts "          <div style='font-size: 0.9em; color: #e2e8f0;'>#{idx+1}. <span style='color: #a0aec0;'>「#{keyword}」の関連書籍をまとめて検索</span></div>"
      else
        puts "          <div style='font-size: 0.9em; font-weight: 600; color: #e2e8f0;'>#{idx+1}. 『#{clean_title}』</div>"
      end
      puts "          <a href='#{search_url}' target='_blank' style='white-space: nowrap; padding: 4px 10px; background: #3182ce; color: white; text-decoration: none; border-radius: 4px; font-size: 0.8em; font-weight: bold; box-shadow: 0 0 8px rgba(49,130,206,0.3);'>蔵書を探す</a>"
      puts "        </div>"
    end
    puts "      </div>"

    # --- 🎓 CiNii 論文セクション ---
    puts "      <h3 style='font-size: 0.95em; color: #ff007f; letter-spacing: 0.5px; margin-top: 25px; margin-bottom: 10px; font-weight: 700;'>■ 関連する専門論文・学術データ</h3>"
    search_ciniis(keyword)

    # --- 📊 政府統計・白書セクション ---
    puts "      <h3 style='font-size: 0.95em; color: #a0aec0; letter-spacing: 0.5px; margin-top: 25px; margin-bottom: 10px; font-weight: 700;'>■ 参考になる政府文書・公的統計（直接PDF検索）</h3>"
    puts "      <div style='display: flex; flex-direction: column; gap: 6px;'>"
    suggestions[:documents].each do |doc|
      clean_doc = doc.gsub(/[「」『』]/, "").strip
      # 🌟 インターネット上の公式PDF、またはgo.jpドメインを直接狙い撃ちするURL
      doc_search_url = "https://www.google.com/search?q=#{URI.encode_www_form_component(clean_doc + ' filetype:pdf OR site:go.jp')}"
      
      puts "        <div style='display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; background: #1a1a1e; border: 1px solid #2d2d34; border-radius: 6px;'>"
      puts "          <div style='font-size: 0.9em; color: #e2e8f0;'>📄 #{clean_doc}</div>"
      puts "          <a href='#{doc_search_url}' target='_blank' style='white-space: nowrap; padding: 4px 10px; background: #4a5568; color: white; text-decoration: none; border-radius: 4px; font-size: 0.8em; font-weight: bold;'>資料PDF活動</a>"
      puts "        </div>"
    end
    puts "      </div>"

    puts "    </div>" # 右カラム終了
    puts "  </div>" # フレックス終了
    puts "</div>" # メインコンテナ終了
  end

  def self.ask_ai_for_suggestions(keyword)
    url = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{GEMINI_API_KEY}")

    # 🌟 ハルシネーション（嘘の書籍）を絶対に吐き出させないための超厳格プロンプト
    prompt = <<~TEXT
      あなたは大学の凄腕図書館司書です。テーマ「#{keyword}」について、日本国内に【確実に実在する】有名な新書・学術書・専門書のタイトルを「正確に3冊」、および最も関連性の高い政府発出の白書・統計データ名を「2つ」挙げてください。
      もし実在する本のタイトルに自信がない場合、無理に嘘のタイトルを作らず、必ず「#{keyword}の基本がわかる本」という固定テキストを出力してください。架空の書籍の創作はペナルティ対象です。
      挨拶、解説、ISBN、前置きは一切不要。以下のフォーマット（カギカッコ付き）のみで出力してください。

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
      # エラー時は安全なキーワードベースにフォールバック
      { 
        books: ["#{keyword}の基本がわかる本", "#{keyword}入門ガイド", "#{keyword}に関する研究書"], 
        documents: ["#{keyword}に関する政府統計データ", "関連分野の公定白書"] 
      }
    end
  end

  def self.search_ciniis(keyword)
    safe_keyword = URI.encode_www_form_component(keyword)
    cinii_search_url = "https://ci.nii.ac.jp/search?q=#{safe_keyword}"
    url = URI.parse("https://ci.nii.ac.jp/opensearch/article?q=#{safe_keyword}&format=rss")
    
    puts "  <div style='display: flex; flex-direction: column; gap: 6px;'>"
    begin
      request = Net::HTTP::Get.new(url)
      response = Net::HTTP.start(url.host, url.port, use_ssl: true) { |http| http.request(request) }
      doc = REXML::Document.new(response.body)
      items = doc.elements.to_a('//item')

      if items.empty?
        puts "    <div style='display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; background: #1a1a1e; border: 1px solid #2d2d34; border-radius: 6px;'>"
        puts "      <div style='font-size: 0.85em; color: #a0aec0;'>※ CiNiiから直接リアルタイムに論文群を検索します。</div>"
        puts "      <a href='#{cinii_search_url}' target='_blank' style='white-space: nowrap; padding: 4px 10px; background: #ff007f; color: white; text-decoration: none; border-radius: 4px; font-size: 0.8em; font-weight: bold; box-shadow: 0 0 8px rgba(255,0,127,0.3);'>CiNiiで探す</a>"
        puts "    </div>"
      else
        items.first(3).each_with_index do |item, idx|
          title = item.elements['title'] ? item.elements['title'].text : "無題の論文"
          link = item.elements['link'] ? item.elements['link'].text : "#"
          puts "    <div style='display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; background: #1a1a1e; border: 1px solid #2d2d34; border-radius: 6px;'>"
          puts "      <div style='font-size: 0.9em; color: #e2e8f0; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 380px;'>『#{title}』</div>"
          puts "      <a href='#{link}' target='_blank' style='white-space: nowrap; padding: 4px 10px; background: #ff007f; color: white; text-decoration: none; border-radius: 4px; font-size: 0.8em; font-weight: bold; box-shadow: 0 0 8px rgba(255,0,127,0.3);'>論文を読む</a>"
          puts "    </div>"
        end
      end
    rescue
      puts "    <div style='display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; background: #1a1a1e; border: 1px solid #2d2d34; border-radius: 6px;'>"
      puts "      <a href='#{cinii_search_url}' target='_blank' style='white-space: nowrap; padding: 4px 10px; background: #ff007f; color: white; text-decoration: none; border-radius: 4px; font-size: 0.8em; font-weight: bold;'>CiNiiで探す</a>"
      puts "    </div>"
    end
    puts "  </div>"
  end
end
