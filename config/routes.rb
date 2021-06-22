Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  #Relationship routes

  post "/relationships", controller: "relationships", action: "create"

  patch "/relationships/:id", controller: "relationships", action: "update"

  delete "/relationships/:id", controller: "relationships", action: "destroy"

  # Favorite routes

  get "/favorites", controller: "favorites", action: "index"

  delete "/favorites/:id", controller: "favorites", action: "destroy"

  # Like routes 

  post "/likes", controller: "likes", action: "create"

  # User routes

  post "/user", controller: "user", action: "create"

  get "/user/:id", controller: "user", action: "show"

  patch "/user/:id", controller: "user", action: "update"

  delete "/user/:id", controller: "user", action: "destroy"

  # Authentication 

  post "/sessions", controller: "sessions", action: "create"






end
