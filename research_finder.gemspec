# frozen_string_literal: true

require_relative "lib/research_finder/version"

Gem::Specification.new do |spec|
  spec.name = "research_finder"
  spec.version = ResearchFinder::VERSION
  spec.authors = ["Fukunishi Shohei"]
  spec.email = ["your-email@example.com"] # ご自身のメールアドレス（ダミーでも可）

  spec.summary = "中学生のための嘘のない自由研究資料・統計検索ツール"
  spec.description = "AIがWebから探した資料を、国立国会図書館のデータベースで実在検証するGemライブラリです。"
  spec.homepage = "https://github.com/fukunishishouhei/research_finder" # ダミーURLでも大丈夫です
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # 梱包するファイルを指定（一番シンプルで確実な方法に書き換えました）
  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*"]
  end
  
  spec.require_paths = ["lib"]
end