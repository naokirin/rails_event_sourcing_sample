require 'json'
require 'slack-notifier'
require 'date'

# レポートJSONを読み込む
report_file = 'tmp/rubycritic/report.json'
unless File.exist?(report_file)
  puts "レポートファイルが見つかりません: #{report_file}"
  exit 1
end

report_data = JSON.parse(File.read(report_file))

# メトリクスを集計
total_files = report_data['analysed_modules'].size
average_complexity = report_data['analysed_modules'].sum { |m| m['churn'].to_f } / total_files rescue 0
average_rating = report_data['analysed_modules'].sum { |m| m['rating'].to_f } / total_files rescue 0
code_smells = report_data['analysed_modules'].sum { |m| m['smells'].size }

# ワースト5のファイルを取得
worst_files = report_data['analysed_modules'].sort_by { |m| m['rating'] }.first(5)
worst_files_text = worst_files.map do |file|
  "• #{file['name']} - 評価: #{file['rating']}, 複雑度: #{file['churn']}, コードスメル: #{file['smells'].size}"
end.join("\n")

# Slackに送信するメッセージを作成
date = Date.today.strftime('%Y年%m月%d日')
message = <<~MESSAGE
  :chart_with_upwards_trend: *#{date} コードメトリクスレポート* :chart_with_upwards_trend:

  *概要:*
  • 分析ファイル数: #{total_files}
  • 平均複雑度: #{average_complexity.round(2)}
  • 平均評価: #{average_rating.round(2)} / 100.0
  • 合計コードスメル: #{code_smells}

  *改善が必要な上位5ファイル:*
  #{worst_files_text}

  詳細レポートは<#{ENV['GITHUB_SERVER_URL']}/#{ENV['GITHUB_REPOSITORY']}/actions/runs/#{ENV['GITHUB_RUN_ID']}|こちら>で確認できます。
MESSAGE

# Slack Notifierを設定して送信
webhook_url = ENV['SLACK_WEBHOOK_URL']
if webhook_url.nil? || webhook_url.empty?
  puts "SLACK_WEBHOOK_URLが設定されていません"
  exit 1
end

notifier = Slack::Notifier.new(webhook_url)
notifier.ping(message)
puts "Slackにメトリクスレポートを送信しました"
