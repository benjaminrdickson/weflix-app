Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  #Relationship routes

  post "/relationships", controller: "relationships", action: "create"

  patch "/relationships/:id", controller: "relationships", action: "update"

  delete "/relationships/:id", controller: "relationships", action: "destroy"

  # Favorite routes

  get "/favorites", controller: "favorites", action: "index"

  delete "/favorites/:id", controller: "favorites", action: "destroy"

  # Friendship routes

  get    "/friendships",     controller: "friendships", action: "index"
  post   "/friendships",     controller: "friendships", action: "create"
  patch  "/friendships/:id", controller: "friendships", action: "update"
  delete "/friendships/:id", controller: "friendships", action: "destroy"

  # Like routes

  post "/likes", controller: "likes", action: "create"

  # User routes

  # get "/users/:username", controller: "users", action: "index"

  post "/users", controller: "users", action: "create"

  # get "/users/:username", controller: "users", action: "username"

  get "/users/:username", controller: "users", action: "show"

  patch "/users/:id", controller: "users", action: "update"

  post "/users/:id/profile_picture", controller: "users", action: "upload_profile_picture"

  delete "/users/:id", controller: "users", action: "destroy"

  # Authentication 

  post "/sessions", controller: "sessions", action: "create"

  # Movies / Browse
  get "/movies/random",  controller: "movies", action: "show"
  get "/browse",         controller: "movies", action: "browse"
  get "/browse/:id",     controller: "movies", action: "detail"

  # Passes
  post "/passes", controller: "passes", action: "create"

  # Genres
  get "/genres", controller: "genres", action: "index"






end
