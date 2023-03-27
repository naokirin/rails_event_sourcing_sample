module Ordering
  class GetOrderEventsUsecase
    include Usecase

    attr_reader :id

    def execute
      stream_name = "Order#{id}"
      Rails.configuration.event_store
           .read
           .stream(stream_name)
           .backward
           .limit(10)
    end
  end
end
