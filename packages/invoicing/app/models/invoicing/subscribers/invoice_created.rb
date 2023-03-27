module Invoicing
  module Subscribers
    class InvoiceCreated
      def initialize(invoice_repository: )
        @invoice_repository = invoice_repository
      end

      def call(event)
        @invoice_repository.create!(order_id: event.data.fetch(:order_id))
      end
    end
  end
end