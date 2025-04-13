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
require 'git'

# 日付
today = Time.now.strftime('%Y-%m-%d')

# 結果を格納するハッシュ
results = []

# 対象のパス
target_paths = %w[app lib]

ANALYSERS =[
  RubyCritic::Analyser::FlaySmells,
  RubyCritic::Analyser::FlogSmells,
  RubyCritic::Analyser::ReekSmells,
  RubyCritic::Analyser::Complexity,
  RubyCritic::Analyser::Attributes,
  RubyCritic::Analyser::Coverage
]
working_dir = File.expand_path('../../..', __FILE__)
git = Git.open(working_dir, :log => Logger.new(STDOUT))

def smell_score(analyser_name, analysed_modules)
  smell_count = analysed_modules.map { |m| m.smells.select { |smell| smell.analyser == analyser_name }.size }.compact.sum
  smell_count * 1.0 / analysed_modules.count rescue 0
end

def complexity_score(analysed_modules)
  analysed_modules.map(&:complexity).compact.sum / analysed_modules.count rescue 0
end

def metrics(git, target_paths, date_string)
  commit_hash = ''
  if date_string == 'today'
    commit_hash = git.log(1).first.sha
  else
    commit_hash = git.log.since(date_string).last.sha
  end
  git.checkout(commit_hash) # 指定した日付のコミットにチェックアウト

  # RubyCriticのメトリクスを実行（Churnは除く）
  puts "Running RubyCritic metrics..."

  result = { date: date_string, metrics: {} }

  analysed_modules = RubyCritic::AnalysedModulesCollection.new(target_paths)
  ANALYSERS.each do |analyser_class|
    analyser_instance = analyser_class.new(analysed_modules)
    puts "running #{analyser_instance}"
    analyser_instance.run
  end

  # RubyCriticからのデータ集計
  flog_score = smell_score('flog', analysed_modules)
  flay_score = smell_score('flay', analysed_modules)
  complexity = complexity_score(analysed_modules)
  smells_count = analysed_modules.map { |m| m.smells.count }.sum

  result[:metrics] = {
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
    start_date: '1 month ago',
    file_extension: %w[rb]
  })
  churn_result = churn.report(false)

  # Churnデータを集計
  churn_classes = churn_result[:churn][:class_churn] || []
  churn_methods = churn_result[:churn][:method_churn] || []

  top_churned_classes = churn_classes.sort_by { |c| -c['times_changed'] }.first(5)
  top_churned_methods = churn_methods.sort_by { |method| -method['times_changed'] }.first(5)

  result[:metrics][:churn] = {
    average_class_churn: (churn_classes.empty? ? 0 : churn_classes.map { |c| c['times_changed'] }.sum / churn_classes.size.to_f).round(2),
    top_churned_classes: top_churned_classes.map { |c| "#{c['klass']['klass']} in #{c['klass']['file']} (#{c['times_changed']}回変更)" },
    top_churned_methods: top_churned_methods.map { |m| "#{m['method']['method']} in #{m['method']['file']} (#{m['times_changed']}回変更)" }
  }

  result
end

results << metrics(git, target_paths, 'today')
results << metrics(git, target_paths, '1 week ago')

# Slack通知用のWebhook URL
slack_webhook_url = ENV['SLACK_WEBHOOK_URL']
notifier = Slack::Notifier.new(slack_webhook_url)

result_today = results.find { |r| r[:date] == 'today' }
result_last_week = results.find { |r| r[:date] == '1 week ago' }

# Slack通知用のメッセージ作成
message = <<~MESSAGE
  :chart_with_upwards_trend: *コードメトリクスレポート (#{today})* :chart_with_upwards_trend:

  *基本メトリクス:*
  • 平均Flogカウント: #{result_today[:metrics][:average_flog_score]}（前週：#{result_last_week[:metrics][:average_flog_score]}）
  • 平均Flayカウント: #{result_today[:metrics][:average_flay_score]}（前週：#{result_last_week[:metrics][:average_flay_score]}）
  • 平均複雑度: #{result_today[:metrics][:average_complexity]}（前週：#{result_last_week[:metrics][:average_complexity]}）
  • コードスメル数: #{result_today[:metrics][:total_code_smells]}（前週：#{result_last_week[:metrics][:total_code_smells]}）

  *Churn (コード変更頻度):*
  • 平均クラス変更頻度: #{result_today[:metrics][:churn][:average_class_churn]}（前週：#{result_last_week[:metrics][:churn][:average_class_churn]}）
  
  *最も変更の多いクラス:*
  今週
  #{result_today[:metrics][:churn][:top_churned_classes].map { |f| "• #{f}" }.join("\n")}
  
  前週
  #{result_last_week[:metrics][:churn][:top_churned_classes].map { |f| "• #{f}" }.join("\n")}
  
  *最も変更の多いメソッド:*
  今週
  #{result_today[:metrics][:churn][:top_churned_methods].map { |m| "• #{m}" }.join("\n")}
  
  前週
  #{result_last_week[:metrics][:churn][:top_churned_methods].map { |m| "• #{m}" }.join("\n")}
MESSAGE

# Slackに通知
puts "Sending notification to Slack..."
notifier.ping(message)

puts "Code metrics completed and sent to Slack!"