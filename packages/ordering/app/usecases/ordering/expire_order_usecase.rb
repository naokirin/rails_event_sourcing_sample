module Ordering
  class ExpireOrderUsecase
    include Usecase

    attr_reader :id

    def execute
      stream_name = "Order#{id}"
      repository = AggregateRoot::Repository.new
      repository.with_aggregate(Domain::Order.new, stream_name) do |order|
        order.expire
      end
    end
  end
end
