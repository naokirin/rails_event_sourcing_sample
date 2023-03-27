module Ordering
  class OrdersController < ApplicationController
    def submit
      id = SubmitOrderUsecase.new.execute

      render json: { status: :ok, order: { id: id } }
    end

    def expire
      id = params[:id]
      ExpireOrderUsecase.new(id: id).execute

      render json: { status: :ok }
    end

    def place
      id = params[:id]
      PlaceOrderUsecase.new(id: id).execute

      render json: { status: :ok }
    end

    def order
      id = params[:id]
      order = GetOrderDetailUsecase.new(id: id).execute

      render json: { order: { id: id, state: order.state } }
    end

    def events
      id = params[:id]
      events = GetOrderEventsUsecase.new(id: id).execute

      render json: { id: id, events: events.map { |event| { event_type: event.event_type, data: event.data, timestamp: event.timestamp } } }
    end
  end
end
