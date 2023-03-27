module Ordering
  module Domain
    class Order
      include AggregateRoot
      class HasBeenAlreadySubmitted < StandardError; end
      class HasExpired < StandardError; end

      attr_reader :order_id

      def initialize(order_id: nil)
        @state = :new
        @order_id = order_id
      end

      # 注文を発注する
      def submit
        raise HasBeenAlreadySubmitted if state == :submitted
        raise HasExpired if state == :expired
        apply Domain::Event::OrderSubmitted.new(data: { order_id: order_id, delivery_date: Time.current + 24.hours })
      end

      # 注文が失効する
      def expire
        apply Domain::Event::OrderExpired.new(data: { order_id: order_id })
      end

      # 注文が確定する
      def place
        apply Domain::Event::OrderPlaced.new(data: { order_id: order_id })
      end

      on Domain::Event::OrderSubmitted do |event|
        @state = :submitted
        @delivery_date = event.data.fetch(:delivery_date)
        @order_id = event.data.fetch(:order_id)
      end

      on Domain::Event::OrderExpired do |event|
        @state = :expired
        @order_id = event.data.fetch(:order_id)
      end

      on Domain::Event::OrderPlaced do |event|
        @state = :placed
        @order_id = event.data.fetch(:order_id)
      end

      attr_reader :state
    end
  end
end
