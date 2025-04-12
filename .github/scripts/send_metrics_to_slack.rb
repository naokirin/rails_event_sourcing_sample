#!/usr/bin/env ruby
require 'rubycritic/core/analysed_modules_collection'
require 'rubycritic/analysers/smells/flay'
require 'rubycritic/analysers/smells/flog'
require 'rubycritic/analysers/smells/reek'
require 'rubycritic/analysers/complexity'
require 'rubycritic/analysers/attributes'
require 'rubycritic/analysers/coverage'
require 'churn/calculator'
require 'json'
require 'slack-notifier'

# Slack通知用のWebhook URL
slack_webhook_url = ENV['SLACK_WEBHOOK_URL']
notifier = Slack::Notifier.new(slack_webhook_url)

# 日付
today = Time.now.strftime('%Y-%m-%d')

# 結果を格納するハッシュ
results = {
  date: today,
  metrics: {}
}

# 対象のパス
target_paths = %w[app lib]

# RubyCriticのメトリクスを実行（Churnは除く）
puts "Running RubyCritic metrics..."

ANALYSERS =[
  RubyCritic::Analyser::FlaySmells,
  RubyCritic::Analyser::FlogSmells,
  RubyCritic::Analyser::ReekSmells,
  RubyCritic::Analyser::Complexity,
  RubyCritic::Analyser::Attributes,
  RubyCritic::Analyser::Coverage
]

analysed_modules = RubyCritic::AnalysedModulesCollection.new(target_paths)
ANALYSERS.each do |analyser_class|
  analyser_instance = analyser_class.new(analysed_modules)
  puts "running #{analyser_instance}"
  analyser_instance.run
end

# RubyCriticからのデータ集計
flog_score = analysed_modules.map(&:flog_score).compact.sum / analysed_modules.count rescue 0
flay_score = analysed_modules.map(&:flay_score).compact.sum / analysed_modules.count rescue 0
complexity = analysed_modules.map(&:complexity).compact.sum / analysed_modules.count rescue 0
smells_count = analysed_modules.map { |m| m.smells.count }.sum

results[:metrics] = {
  average_flog_score: flog_score.round(2),
  average_flay_score: flay_score.round(2),
  average_complexity: complexity.round(2),
  total_code_smells: smells_count
}

# 別途Churn gemで計算
# 1ヶ月分のChurnデータを取得
puts "Running Churn analysis..."
churn = Churn::ChurnCalculator.new({
  minimum_churn_count: 3,
  start_date: (Date.today - 30).to_s
})
churn_result = churn.report(false)

# Churnデータを集計
churn_classes = churn_result[:churn][:classes] || []
churn_methods = churn_result[:churn][:methods] || []

top_churned_files = churn_classes.sort_by { |file| -file[:times_changed] }.first(5)
top_churned_methods = churn_methods.sort_by { |method| -method[:times_changed] }.first(5)

results[:metrics][:churn] = {
  average_class_churn: (churn_classes.empty? ? 0 : churn_classes.map { |c| c[:times_changed] }.sum / churn_classes.size.to_f).round(2),
  top_churned_files: top_churned_files.map { |f| "#{f[:file_path]} (#{f[:times_changed]}回変更)" },
  top_churned_methods: top_churned_methods.map { |m| "#{m[:method_name]} in #{m[:file_path]} (#{m[:times_changed]}回変更)" }
}

# Slack通知用のメッセージ作成
message = <<~MESSAGE
  :chart_with_upwards_trend: *コードメトリクスレポート (#{today})* :chart_with_upwards_trend:

  *基本メトリクス:*
  • 平均Flogスコア: #{results[:metrics][:average_flog_score]}
  • 平均Flayスコア: #{results[:metrics][:average_flay_score]}
  • 平均複雑度: #{results[:metrics][:average_complexity]}
  • コードスメル数: #{results[:metrics][:total_code_smells]}

  *Churn (コード変更頻度):*
  • 平均クラス変更頻度: #{results[:metrics][:churn][:average_class_churn]}
  
  *最も変更の多いファイル:*
  #{results[:metrics][:churn][:top_churned_files].map { |f| "• #{f}" }.join("\n")}
  
  *最も変更の多いメソッド:*
  #{results[:metrics][:churn][:top_churned_methods].map { |m| "• #{m}" }.join("\n")}
MESSAGE

# Slackに通知
puts "Sending notification to Slack..."
notifier.ping(message)

puts "Code metrics completed and sent to Slack!"