Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"

  post 'submit', to: 'ordering/orders#submit'
  patch 'expire/:id', to: 'ordering/orders#expire'
  patch 'place/:id', to: 'ordering/orders#place'
  get 'order/:id', to: 'ordering/orders#order'
  get 'events/:id', to: 'ordering/orders#events'

  get 'invoices', to: 'invoicing/invoices#index'

  mount RailsEventStore::Browser => '/res' if Rails.env.development?
end
