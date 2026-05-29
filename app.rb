require 'sinatra'
require_relative 'lib/research_finder'

set :bind, '0.0.0.0'
set :port, ENV['PORT'] || 4567

get '/' do
  html = <<~HTML
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>自由研究ナビ</title>
      <style>
        body { font-family: sans-serif; max-width: 600px; margin: 40px auto; padding: 20px; }
        input[type="text"] { width: 70%; padding: 10px; font-size: 16px; }
        input[type="submit"] { padding: 10px 20px; font-size: 16px; cursor: pointer; }
        pre { background: #f4f4f4; padding: 15px; white-space: pre-wrap; word-wrap: break-word; }
      </style>
    </head>
    <body>
      <h2>🔍 自由研究資料・公的データ検索</h2>
      <form action="/search" method="get">
        <input type="text" name="keyword" placeholder="例：宇宙開発、深海" required>
        <input type="submit" value="検索">
      </form>
    </body>
    </html>
  HTML
  html
end

get '/search' do
  keyword = params[:keyword]
  
  old_stdout = $stdout
  captured_stdout = StringIO.new
  $stdout = captured_stdout

  ResearchFinder.search(keyword)

  $stdout = old_stdout
  result_text = captured_stdout.string

  html = <<~HTML
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>検索結果 - #{keyword}</title>
      <style>
        body { font-family: sans-serif; max-width: 800px; margin: 40px auto; padding: 20px; }
        pre { background: #f4f4f4; padding: 20px; border-radius: 5px; white-space: pre-wrap; font-size: 14px; line-height: 1.6; }
        a { display: inline-block; margin-top: 20px; color: #0076ff; text-decoration: none; }
      </style>
    </head>
    <body>
      <h2>検索結果: #{keyword}</h2>
      <pre>#{result_text}</pre>
      <a href="/">&larr; 戻る</a>
    </body>
    </html>
  HTML
  html
end
