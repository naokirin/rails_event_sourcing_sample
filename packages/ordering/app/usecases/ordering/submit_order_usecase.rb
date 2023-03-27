module Ordering
  class SubmitOrderUsecase
    include Usecase

    def execute
      id = SecureRandom.uuid
      stream_name = "Order#{id}"
      repository = AggregateRoot::Repository.new
      repository.with_aggregate(Domain::Order.new(order_id: id), stream_name) do |order|
        order.submit
      end

      id
    end
  end
end
