module Invoicing
  module Infrastructure
    class InvoiceRepository
      def create!(order_id:)
        ::Invoice.create!(order_id: order_id)
      end

      def all
        records = ::Invoice.all
        records.map { |record| Domain::Invoice.new(order_id: record.order_id) }
      end
    end
  end
end
