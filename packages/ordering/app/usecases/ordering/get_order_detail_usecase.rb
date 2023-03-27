module Ordering
  class GetOrderDetailUsecase
    include Usecase

    attr_reader :id

    def execute
      stream_name = "Order#{id}"
      repository = AggregateRoot::Repository.new
      repository.load(Domain::Order.new, stream_name)
    end
  end
end
