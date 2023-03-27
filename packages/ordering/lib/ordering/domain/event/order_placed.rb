module Ordering
  module Domain
    module Event
      class OrderPlaced < RailsEventStore::Event; end
    end
  end
end
