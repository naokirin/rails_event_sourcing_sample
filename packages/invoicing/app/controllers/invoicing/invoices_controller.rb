module Invoicing
  class InvoicesController < ApplicationController
    def index
      invoices = GetAllInvoiceUsecase.new(
        invoice_repository: Infrastructure::InvoiceRepository.new
      ).execute
      render json: { invoices: invoices.map { |invoice| { id: invoice.order_id } } }
    end
  end
end