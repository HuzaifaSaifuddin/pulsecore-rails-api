module QueryHelpers
  # Counts real SQL queries issued while the block runs, ignoring schema
  # introspection and transaction-control statements. Used to prove a
  # collection endpoint doesn't issue one query per row (N+1).
  def count_queries
    queries = 0
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA"
      next if payload[:sql].match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      queries += 1
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    queries
  end
end

RSpec.configure do |config|
  config.include QueryHelpers, type: :request
end
