module Invoicing
  module Domain
    class Invoice
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :order_id, :string

      validates :order_id, presence: true
    end
  end
end