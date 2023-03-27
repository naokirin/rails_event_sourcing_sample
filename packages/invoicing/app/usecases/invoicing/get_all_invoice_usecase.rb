module Invoicing
  class GetAllInvoiceUsecase
    include Usecase

    attr_reader :invoice_repository

    def execute
      invoice_repository.all
    end
  end
end
