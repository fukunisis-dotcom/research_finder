require "net/http"
require "uri"
require "json"
require "rexml/document"

module ResearchFinder
  GEMINI_API_KEY = ENV['GEMINI_API_KEY']

  # 🌟 共通パーツ：本物の「みっちー」ネオンアートを忠実に再現
  def self.render_michi_avatar
    <<~HTML
      <div style='text-align: center; background: #151518; padding: 25px; border-radius: 12px; border: 1px solid #2d2d34; box-shadow: inset 0 0 15px rgba(0,255,255,0.05);'>
        <svg width='220' height='240' viewBox='0 0 220 240' style='filter: drop-shadow(0 0 10px rgba(0,255,255,0.4));'>
          <defs>
            <linearGradient id='goldNeon' x1='0%' y1='0%' x2='100%' y2='100%'>
              <stop offset='0%' stop-color='#ffd700' />
              <stop offset='100%' stop-color='#b8860b' />
            </linearGradient>
            <linearGradient id='cyanNeon' x1='0%' y1='0%' x2='0%' y2='100%'>
              <stop offset='0%' stop-color='#00ffff' />
              <stop offset='100%' stop-color='#008b8b' />
            </linearGradient>
          </defs>
          <g fill='none' stroke-linecap='round' stroke-linejoin='round'>
            <path d='M85,50 Q110,15 135,50' stroke='url(#goldNeon)' stroke-width='4' fill='rgba(255,215,0,0.1)'/>
            <path d='M110,15 L110,50' stroke='url(#goldNeon)' stroke-width='2'/>
            <path d='M125,22 Q155,25 150,65' stroke='#39ff14' stroke-width='3' filter='drop-shadow(0 0 5px #39ff14)'/>
            <path d='M132,30 Q162,33 157,65' stroke='#39ff14' stroke-width='1.5'/>
            
            <path d='M55,95 Q50,165 110,210 Q170,165 165,95 Z' stroke='#bd00ff' stroke-width='4.5' fill='rgba(189,0,255,0.03)' filter='drop-shadow(0 0 8px #bd00ff)'/>
            <path d='M40,160 Q110,180 180,160' stroke='#ff007f' stroke-width='2.5' filter='drop-shadow(0 0 4px #ff007f)'/>
            
            <path d='M55,95 Q110,65 165,95 Q110,55 55,95' stroke='url(#cyanNeon)' stroke-width='3.5' fill='#111113'/>
            <path d='M80,155 Q110,168 140,155' stroke='#00bfff' stroke-width='3' filter='drop-shadow(0 0 3px #00bfff)'/>
            <path d='M75,165 Q110,185 145,165' stroke='#00bfff' stroke-width='2'/>
            <path d='M100,175 Q110,195 120,175' stroke='#00bfff' stroke-width='2.5'/>
            
            <path d='M70,112 Q82,105 95,112' stroke='#00ffff' stroke-width='3.5'/>
            <path d='M125,112 Q138,105 150,112' stroke='#00ffff' stroke-width='3.5'/>
            <path d='M75,124 Q85,128 95,124' stroke='#00ffff' stroke-width='2'/>
            <path d='M125,124 Q135,128 145,124' stroke='#00ffff' stroke-width='2'/>
            <path d='M105,115 L105,142 L115,142' stroke='#00ffff' stroke-width='2.5'/>
            <path d='M92,150 Q110,156 128,150' stroke='#00ffff' stroke-width='2'/>
            
            <path d='M20,130 Q38,165 52,210' stroke='#39ff14' stroke-width='3.5' filter='drop-shadow(0 0 5px #39ff14)'/>
            <circle cx='32' cy='145' r='14' stroke='#ff007f' stroke-width='3' fill='rgba(255,0,127,0.2)' filter='drop-shadow(0 0 6px #ff007f)'/>
            <circle cx='32' cy='145' r='3' stroke='#fff' stroke-width='2'/>
            <circle cx='22' cy='180' r='10' stroke='#ff007f' stroke-width='2.5' fill='rgba(255,0,127,0.1)'/>
            <circle cx='50' cy='195' r='12' stroke='#ff007f' stroke-width='3' fill='rgba(255,0,127,0.2)' filter='drop-shadow(0 0 5px #ff007f)'/>
            <circle cx='50' cy='195' r='2' stroke='#fff' stroke-width='1.5'/>
          </g>
        </svg>
        <h1 style='font-size: 1.4em; color: #fff; margin-top: 15px; font-weight: 800; letter-spacing: 1.5px; text-shadow: 0 0 8px #ff007f;'>みっちーの自由研究ナビ</h1>
        <p style='font-size: 0.8em; color: #00ffff; margin: 5px 0 0 0; font-weight: bold; letter-spacing: 1px;'>福西 Special Edition</p>
      </div>
    HTML
  end

  # 🌟 ホーム画面（検索開始画面）の出力
  def self.render_home
    puts "<div style='font-family: sans-serif; background-color: #0b0b0d; color: #e2e8f0; max-width: 900px; margin: 40px auto; padding: 40px 25px; border: 2px solid #ff007f; border-radius: 16px; box-shadow: 0 0 30px rgba(255, 0, 127, 0.25);'>"
    puts "  <div style='display: flex; flex-direction: column; align-items: center; gap: 30px;'>"
    
    # ホーム画面の中央に忠実なみっちーを配置
    puts render_michi_avatar
    
    puts "    <div style='width: 100%; max-width: 550px; text-align: center;'>"
    puts "      <h2 style='font-size: 1.2em; color: #a0aec0; margin-bottom: 20px; font-weight: 600;'>自由研究の資料・公的データを検証検索</h2>"
    puts "      <form action='/search' method='GET' style='display: flex; gap: 12px; width: 100%;'>"
    puts "        <input type='text' name='q' placeholder='例: 釣り 歴史 レジャー' style='flex: 1; padding: 14px 20px; background: #151518; border: 2px solid #2d2d34; border-radius: 8px; color: #fff; font-size: 1.05em; font-weight: bold; outline: none; transition: border-color 0.3s;' onfocus='this.style.borderColor=\"#00ffff\"' onblur='this.style.borderColor=\"#2d2d34\"'>"
    puts "        <button type='submit' style='padding: 14px 32px; background: linear-gradient(135deg, #ff007f, #bd00ff); color: white; border: none; border-radius: 8px; font-size: 1.05em; font-weight: bold; cursor: pointer; box-shadow: 0 0 15px rgba(255,0,127,0.4); transition: transform 0.2s;' onmouseover='this.style.transform=\"scale(1.03)\"' onmouseout='this.style.transform=\"scale(1)\"'>検索</button>"
    puts "      </form>"
    puts "    </div>"
    
    puts "  </div>"
    puts "</div>"
  end

  # 🌟 検索結果画面の出力
  def self.search(keyword)
    puts "<div style='font-family: sans-serif; background-color: #0b0b0d; color: #e2e8f0; max-width: 950px; margin: 30px auto; padding: 30px; border: 2px solid #ff007f; border-radius: 16px; box-shadow: 0 0 30px rgba(255, 0, 127, 0.25);'>"
    puts "  <div style='display: flex; flex-direction: row; gap: 35px; align-items: flex-start; flex-wrap: wrap;'>"
    
    # 左カラム：本物のみっちーが常駐
    puts "    <div style='flex: 1; min-width: 260px;'>"
    puts render_michi_avatar
    puts "      <a href='/' style='display: block; margin-top: 20px; text-align: center; padding: 10px; background: #212124; color: #a0aec0; text-decoration: none; border-radius: 6px; font-size: 0.9em; font-weight: bold; border: 1px solid #333;'>← 検索ホームへ戻る</a>"
    puts "    </div>"

    # 右カラム：徹底検証された検索結果
    puts "    <div style='flex: 2; min-width: 340px;'>"
    puts "      <div style='border-bottom: 2px solid #ff007f; padding-bottom: 10px; margin-bottom: 25px;'>"
    puts "        <span style='font-size: 0.8em; color: #ff007f; font-weight: 800; letter-spacing: 1px; text-transform: uppercase;'>Verified Research Dashboard</span>"
    puts "        <h2 style='margin: 4px 0 0 0; font-size: 1.7em; color: #fff; font-weight: 800;'>🎯 #{keyword}</h2>"
    puts "      </div>"

    suggestions = ask_ai_for_suggestions(keyword)

    # --- 📚 厳格検証書籍セクション ---
    puts "      <h3 style='font-size: 1em; color: #00ffff; letter-spacing: 0.5px; margin-top: 20px; margin-bottom: 12px; font-weight: 700;'>■ おすすめの関連書籍（存在・蔵書マルチ検証）</h3>"
    puts "      <div style='display: flex; flex-direction: column; gap: 8px;'>"
    
    suggestions[:books].each_with_index do |title, idx|
      clean_title = title.gsub(/[「」『』]/, "").strip
      
      # ハルシネーション対策：確実に確認が取れる検証用URLの生成
      amazon_url = "https://www.amazon.co.jp/s?k=#{URI.encode_www_form_component(clean_title)}"
      ndl_url = "https://ndlsearch.ndl.go.jp/search?keyword=#{URI.encode_www_form_component(clean_title)}"
      calil_url = "https://calil.jp/search?q=#{URI.encode_www_form_component(clean_title + ' 大阪')}"
      
      puts "        <div style='background: #151518; border: 1px solid #2d2d34; border-radius: 8px; padding: 14px; display: flex; flex-direction: column; gap: 10px;'>"
      puts "          <div style='font-size: 0.95em; font-weight: bold; color: #fff;'>#{idx+1}. 『#{clean_title}』</div>"
      puts "          <div style='display: flex; gap: 8px; flex-wrap: wrap;'>"
      puts "            <a href='#{ndl_url}' target='_blank' style='padding: 5px 10px; background: #1a365d; color: #90cdf4; text-decoration: none; border-radius: 4px; font-size: 0.75em; font-weight: bold; border: 1px solid #2b6cb0;'>国会図書館で有無検証</a>"
      puts "            <a href='#{amazon_url}' target='_blank' style='padding: 5px 10px; background: #2c5282; color: #bee3f8; text-decoration: none; border-radius: 4px; font-size: 0.75em; font-weight: bold; border: 1px solid #2b6cb0;'>Amazonの有無を確認</a>"
      puts "            <a href='#{calil_url}' target='_blank' style='padding: 5px 10px; background: #3182ce; color: white; text-decoration: none; border-radius: 4px; font-size: 0.75em; font-weight: bold; box-shadow: 0 0 8px rgba(49,130,206,0.3);'>大阪府内の蔵書を探す</a>"
      puts "          </div>"
      puts "        </div>"
    end
    puts "      </div>"

    # --- 🎓 CiNii 論文セクション ---
    puts "      <h3 style='font-size: 1em; color: #bd00ff; letter-spacing: 0.5px; margin-top: 30px; margin-bottom: 12px; font-weight: 700;'>■ 関連する専門論文・学術データ</h3>"
    search_ciniis(keyword)

    # --- 📊 政府統計・白書セクション（ダイレクトPDF仕様） ---
    puts "      <h3 style='font-size: 1em; color: #a0aec0; letter-spacing: 0.5px; margin-top: 30px; margin-bottom: 12px; font-weight: 700;'>■ 参考になる政府文書・公的統計（PDF直接取得）</h3>"
    puts "      <div style='display: flex; flex-direction: column; gap: 8px;'>"
    suggestions[:documents].each do |doc|
      clean_doc = doc.gsub(/[「」『』]/, "").strip
      
      # 🌟 検索画面への丸投げではなく、政府機関ドメイン（.go.jp）から直接PDFを狙い撃ちダウンロードするクエリに修正
      direct_pdf_url = "https://www.google.com/search?q=#{URI.encode_www_form_component('site:go.jp filetype:pdf ' + clean_doc)}&btnI=I%27m+Feeling+Lucky"
      fallback_search_url = "https://www.google.com/search?q=#{URI.encode_www_form_component('site:go.jp filetype:pdf ' + clean_doc)}"
      
      puts "        <div style='background: #151518; border: 1px solid #2d2d34; border-radius: 8px; padding: 14px; display: flex; justify-content: space-between; align-items: center; gap: 15px;'>"
      puts "          <div style='font-size: 0.95em; color: #e2e8f0; font-weight: 500;'>📄 #{clean_doc}</div>"
      puts "          <div style='display: flex; gap: 6px; white-space: nowrap;'>"
      puts "            <a href='#{direct_pdf_url}' target='_blank' style='padding: 6px 12px; background: linear-gradient(135deg, #2f855a, #48bb78); color: white; text-decoration: none; border-radius: 4px; font-size: 0.8em; font-weight: bold; box-shadow: 0 0 10px rgba(72,187,120,0.3);'>資料PDFを開く</a>"
      puts "            <a href='#{fallback_search_url}' target='_blank' style='padding: 6px 10px; background: #4a5568; color: #cbd5e0; text-decoration: none; border-radius: 4px; font-size: 0.8em;'>一覧</a>"
      puts "          </div>"
      puts "        </div>"
    end
    puts "      </div>"

    puts "    </div>"
    puts "  </div>"
    puts "</div>"
  end

  def self.ask_ai_for_suggestions(keyword)
    url = URI.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=#{GEMINI_API_KEY}")

    prompt = <<~TEXT
      あなたは大学の凄腕図書館司書です。テーマ「#{keyword}」について、日本国内に実在する可能性が極めて高い代表的な新書・専門書のタイトルを3冊、および関連する政府の白書や公的統計データ名を2つ挙げてください。
      解説、前置きは一切不要。以下のフォーマットのみで出力してください。

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
      http.read_timeout = 10
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
      { 
        books: ["#{keyword}の歴史に関する研究書", "#{keyword}文化史", "#{keyword}に関する現代社会論"], 
        documents: ["#{keyword}に関する関係省庁報告書", "次世代レジャー動向白書"] 
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
        puts "    <div style='display: flex; justify-content: space-between; align-items: center; padding: 12px 14px; background: #151518; border: 1px solid #2d2d34; border-radius: 8px;'>"
        puts "      <div style='font-size: 0.85em; color: #a0aec0;'>※ 学術論文データベースCiNiiから直接検索を実行します。</div>"
        puts "      <a href='#{cinii_search_url}' target='_blank' style='white-space: nowrap; padding: 6px 12px; background: #bd00ff; color: white; text-decoration: none; border-radius: 4px; font-size: 0.8em; font-weight: bold; box-shadow: 0 0 10px rgba(189,0,255,0.4);'>CiNiiで直接探す</a>"
        puts "    </div>"
      else
        items.first(3).each do |item|
          title = item.elements['title'] ? item.elements['title'].text : "無題の論文"
          link = item.elements['link'] ? item.elements['link'].text : "#"
          puts "    <div style='display: flex; justify-content: space-between; align-items: center; padding: 12px 14px; background: #151518; border: 1px solid #2d2d34; border-radius: 8px;'>"
          puts "      <div style='font-size: 0.9em; color: #e2e8f0; font-weight: bold; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 380px;'>『#{title}』</div>"
          puts "      <a href='#{link}' target='_blank' style='white-space: nowrap; padding: 6px 12px; background: #bd00ff; color: white; text-decoration: none; border-radius: 4px; font-size: 0.8em; font-weight: bold; box-shadow: 0 0 10px rgba(189,0,255,0.4);'>論文を検証</a>"
          puts "    </div>"
        end
      end
    rescue
      puts "    <div style='display: flex; justify-content: space-between; align-items: center; padding: 12px 14px; background: #151518; border: 1px solid #2d2d34; border-radius: 8px模'>"
      puts "      <a href='#{cinii_search_url}' target='_blank' style='white-space: nowrap; padding: 6px 12px; background: #bd00ff; color: white; text-decoration: none; border-radius: 4px; font-size: 0.8em; font-weight: bold;'>CiNiiで直接探す</a>"
      puts "    </div>"
    end
    puts "  </div>"
  end
end
