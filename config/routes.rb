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

  post "/users", controller: "users", action: "create"

  get "/users/:id", controller: "users", action: "show"

  patch "/users/:id", controller: "users", action: "update"

  delete "/users/:id", controller: "users", action: "destroy"

  # Authentication 

  post "/sessions", controller: "sessions", action: "create"

  # Movies

  get "/movies/random", controller: "movies", action: "show"






end
